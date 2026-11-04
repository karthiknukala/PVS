#!/usr/bin/env python3
"""Persistent, native PVS sessions exposed through MCP or a JSON-lines CLI.

Run with agent/.venv/bin/python agent/server.py mcp (default), or "repl".
The CLI accepts {"operation": "start", "context": "/path", "file": "example"}
and subsequent operations on the same process. No arbitrary Lisp RPC is exposed.
"""
from __future__ import annotations

import argparse
import asyncio
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import sys
import tempfile
import time
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse
import uuid

from recovery import RecoveryMixin

import websockets
from websockets.exceptions import ConnectionClosed

ROOT = Path(__file__).resolve().parent.parent
READY = re.compile(r"PVS-AGENT-READY\s+(\d+)")
TERMINAL = {"closed", "finished", "inactive", "proved", "qed", "failed", "dead"}
REQUIRED_METHODS = {
    "agent-info", "agent-prepare", "agent-inspect", "agent-load-strategy",
    "agent-close", "agent-evaluator-start", "agent-save", "agent-verify", "agent-validate-context",
    "prove-formula", "proof-command", "prover-status", "pvsio-eval", "interrupt-proof",
}


class PVSError(RuntimeError):
    """An explicit native or adapter error."""


class RPCError(PVSError):
    def __init__(self, error: Any):
        self.error = error
        super().__init__(json.dumps(error, ensure_ascii=False))


class ConnectionLost(PVSError):
    """The command outcome may be unknown; never resend automatically."""


async def settle_tasks(tasks: list[asyncio.Task[Any]], timeout: float) -> bool:
    """Bound teardown without waiting indefinitely for cancellation acknowledgement."""
    if not tasks:
        return True
    done, pending = await asyncio.wait(tasks, timeout=timeout)
    for task in done:
        with contextlib.suppress(asyncio.CancelledError, Exception):
            task.result()
    for task in pending:
        task.cancel()
        task.add_done_callback(lambda completed: None if completed.cancelled() else completed.exception())
    return not pending


class RPCConnection:
    def __init__(self, socket: Any, record: Any):
        self.socket = socket
        self.record = record
        self.pending: dict[str, asyncio.Future[Any]] = {}
        self.closing = False
        self.reader = asyncio.create_task(self._read())

    @classmethod
    async def open(cls, url: str, record: Any) -> RPCConnection:
        ws = await websockets.connect(url, max_size=32 * 1024 * 1024,
                                      open_timeout=15, close_timeout=2,
                                      ping_interval=None)
        return cls(ws, record)

    async def _read(self) -> None:
        try:
            async for raw in self.socket:
                message = json.loads(raw)
                self.record("received", message)
                future = self.pending.get(message.get("id"))
                if future is not None and not future.done() and "method" not in message:
                    if "error" in message:
                        future.set_exception(RPCError(message["error"]))
                    elif "result" in message:
                        future.set_result(message["result"])
                elif "error" in message and message.get("id") is None:
                    for waiting in self.pending.values():
                        if not waiting.done():
                            waiting.set_exception(ConnectionLost(
                                f"Uncorrelated PVS error; command outcome is uncertain: {message['error']}"))
                # PVS may emit messages with IDs that aren't replies. Preserve
                # them; never confuse them with the outstanding result.
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            self.record("connection_error", str(exc))
        finally:
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(ConnectionLost(
                        "PVS connection closed; the last command may have executed. "
                        "Do not resend it automatically."))

    async def call(self, method: str, params: list[Any] | None = None) -> Any:
        if self.closing or self.reader.done():
            raise ConnectionLost("PVS connection is closed.")
        request_id = uuid.uuid4().hex
        request = {"jsonrpc": "2.0", "id": request_id,
                   "method": method, "params": params or []}
        future = asyncio.get_running_loop().create_future()
        self.pending[request_id] = future
        try:
            self.record("sent", request)
            await self.socket.send(json.dumps(request))
            return await future
        except (ConnectionClosed, OSError) as exc:
            raise ConnectionLost("PVS connection failed; do not automatically resend the command.") from exc
        finally:
            self.pending.pop(request_id, None)
            # A disconnect can resolve the reply while send/caller cancellation
            # is still unwinding. Consume that exception even if it was never awaited.
            if future.done() and not future.cancelled():
                future.exception()

    async def close(self, timeout: float = 3) -> None:
        self.closing = True
        for future in self.pending.values():
            if not future.done():
                future.set_exception(ConnectionLost("PVS connection closed during cleanup; command outcome may be unknown."))
        closer = asyncio.create_task(self.socket.close())
        try:
            await settle_tasks([closer], timeout)
        finally:
            # A native worker in its debugger may never answer the handshake.
            # Abort the local transport before waiting for reader cancellation.
            transport = getattr(self.socket, "transport", None)
            if transport is not None:
                transport.abort()
            self.reader.cancel()
            if not await settle_tasks([closer, self.reader], min(timeout, 1)):
                self.record("cleanup_warning", "Socket tasks did not finish after transport abort.")


@dataclass
class Session:
    id: str
    kind: str
    connection: RPCConnection
    latest: Any = None
    revision: int = 0
    pending: asyncio.Task[Any] | None = None
    closed: bool = False
    uncertain: bool = False
    last_error: str | None = None
    proof_result: str | None = None
    batch_owner: asyncio.Task[Any] | None = None
    elapsed_ms: float | None = None
    delta: dict[str, Any] | None = None
    formula: str = ""
    active_command: str | None = None
    watchdog: asyncio.Task[Any] | None = None
    recovery: dict[str, Any] | None = None


class PVSClient(RecoveryMixin):
    """A small in-memory client; PVS owns proof records and proof navigation."""

    _error = PVSError
    _connection_lost = ConnectionLost

    def __init__(self, pvs: str | Path = ROOT / "pvs",
                 loader: str | Path = ROOT / "agent" / "load.lisp",
                 library_path: str | None = "", observer_mode: str = "off", port: int = 0):
        if not 0 <= port <= 65535:
            raise ValueError("PVS port must be between 0 and 65535")
        self.worker_port = port
        self.observer_mode = observer_mode
        self.observer = None
        self.observer_error = None
        self.observer_lock = asyncio.Lock()
        self.pvs = Path(pvs).resolve()
        self.loader = Path(loader).resolve()
        self.library_path = library_path
        self.url: str | None = None
        self.control: RPCConnection | None = None
        self.process: asyncio.subprocess.Process | None = None
        self.process_reader: asyncio.Task[Any] | None = None
        self.temp: tempfile.TemporaryDirectory[str] | None = None
        self.sessions: dict[str, Session] = {}
        self._event_index: list[tuple[Path, int] | dict[str, Any]] = []
        self.info: dict[str, Any] = {}
        self.methods: set[str] = set()
        self.context: Path | None = None
        self.strategy_sources: dict[str, bytes] = {}
        self.generation = 0
        self.setup_lock = asyncio.Lock()
        self.transcript_path: Path | None = None
        self.init_recovery()

    def record(self, kind: str, data: Any) -> None:
        event = {"index": len(self._event_index), "time": time.time(), "kind": kind, "data": data}
        if self.transcript_path:
            payload = (json.dumps(event, ensure_ascii=False) + "\n").encode("utf-8")
            try:
                with self.transcript_path.open("ab") as stream:
                    stream.write(payload)
                    stream.flush()
                    offset = stream.tell() - len(payload)
                self._event_index.append((self.transcript_path, offset))
                return
            except OSError as error:
                self.journal_error = str(error)
        # Preserve pagination for events recorded before startup or after a write failure.
        self._event_index.append(event)

    def _read_events(self, start: int, stop: int) -> list[dict[str, Any]]:
        result = []
        with contextlib.ExitStack() as stack:
            streams = {}
            for index in range(*slice(start, stop).indices(len(self._event_index))):
                entry = self._event_index[index]
                if isinstance(entry, dict):
                    result.append(entry)
                    continue
                path, offset = entry
                if path not in streams:
                    streams[path] = stack.enter_context(path.open("rb"))
                stream = streams[path]
                stream.seek(offset)
                event = json.loads(stream.readline())
                if event["index"] != index:
                    raise PVSError(f"Transcript changed at event {index} in {path}")
                result.append(event)
        return result

    @property
    def events(self) -> list[dict[str, Any]]:
        return self._read_events(0, len(self._event_index))

    def require_control(self) -> RPCConnection:
        if self.runtime_failure:
            raise ConnectionLost(self.runtime_failure + " Inspect health/recovery evidence before explicitly starting a new worker.")
        if self.control is None:
            raise PVSError("Start or connect to PVS first.")
        return self.control

    def session(self, session_id: str) -> Session:
        try:
            return self.sessions[session_id]
        except KeyError:
            raise PVSError(f"Unknown client session {session_id!r}; list sessions first.") from None

    def require_idle(self) -> None:
        self.require_control()
        busy = [s.id for s in self.sessions.values() if s.batch_owner is not None or (s.pending and not s.pending.done())]
        if busy:
            raise PVSError(f"Wait for or interrupt active commands before setup/save: {busy}")

    async def _launch(self, context: Path, timeout: float) -> str:
        if not self.pvs.is_file() or not self.loader.is_file():
            raise PVSError(f"PVS executable/extension missing: {self.pvs}, {self.loader}")
        self.temp = tempfile.TemporaryDirectory(prefix="pvs-agent-")
        logs = Path(self.temp.name) / "logs"
        logs.mkdir()
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", self.worker_port))
            port = listener.getsockname()[1]
        env = os.environ.copy()
        for name in ("PVSEVALLOAD", "PVSPORT", "PVSPATH", "PVSNONINTERACTIVE",
                     "PVSTIMEOUT", "PVSINEMACS", "PVSEMACS", "PVSIMAGE"):
            env.pop(name, None)
        env["PVS_LOG_DIR"] = str(logs)
        if self.library_path is not None:
            env["PVS_LIBRARY_PATH"] = self.library_path
        escaped = str(self.loader).replace("\\", "\\\\").replace('"', '\\"')
        expression = (
            f'(handler-case (progn (load "{escaped}") (pvs::agent-start-server {port})) '
            '(error (condition) (format t "~&PVS-AGENT-STARTUP-FAILED: ~a~%" condition) '
            '(finish-output) (uiop:quit 1)))')
        self.process = await asyncio.create_subprocess_exec(
            str(self.pvs), "-raw", "-q", "-patchlevel", "none", "-E", expression,
            cwd=context, env=env, stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
            limit=1024 * 1024, start_new_session=True)
        ready: asyncio.Future[int] = asyncio.get_running_loop().create_future()

        async def drain() -> None:
            assert self.process and self.process.stdout
            while chunk := await self.process.stdout.read(4096):
                output = chunk.decode(errors="replace")
                self.record("process", output)
                self.process_output(output)
                match = READY.search(self.process_tail)
                if match and not ready.done():
                    ready.set_result(int(match.group(1)))
            self.fail_runtime("PVS process output closed; the worker exited or lost its output channel.")
            if not ready.done():
                output = self.process_tail[-12000:]
                ready.set_exception(PVSError(f"PVS exited before its READY marker:\n{output}"))

        self.process_reader = asyncio.create_task(drain())
        try:
            actual_port = await asyncio.wait_for(ready, timeout)
        except asyncio.TimeoutError as exc:
            output = self.process_tail[-12000:]
            raise PVSError(f"PVS did not become ready within {timeout}s. Most recent startup output:\n{output}") from exc
        return f"ws://127.0.0.1:{actual_port}"

    async def start(self, context: str = "", file: str = "", url: str = "",
                    timeout: float = 60, transcript: str = "") -> dict[str, Any]:
        """Start a dedicated patched PVS, or explicitly connect to a local extension."""
        async with self.setup_lock:
            if self.control is not None:
                raise PVSError("Already connected; close the client before starting another process.")
            self.context = Path(context or os.getcwd()).resolve()
            if not self.context.is_dir():
                raise PVSError(f"Context is not a directory: {self.context}")
            if transcript:
                self.transcript_path = Path(transcript).resolve()
                self.transcript_path.parent.mkdir(parents=True, exist_ok=True)
            if url:
                parsed = urlparse(url)
                if parsed.scheme not in {"ws", "wss"} or parsed.hostname not in {
                    "127.0.0.1", "::1", "localhost"
                } or parsed.username or parsed.password:
                    raise PVSError("Only explicit local WebSocket URLs are supported.")
            self.begin_journal()
            deadline = time.monotonic() + timeout

            def remaining() -> float:
                return max(0, deadline - time.monotonic())

            try:
                self.url = url or await self._launch(self.context, remaining())
                # Clack starts its listener asynchronously. Retry only socket
                # establishment, before any RPC can have been sent.
                while True:
                    try:
                        self.control = await asyncio.wait_for(
                            RPCConnection.open(self.url, self.record), remaining())
                        break
                    except ConnectionRefusedError:
                        if remaining() <= 0:
                            raise PVSError("PVS did not accept a connection before the startup deadline.")
                        await asyncio.sleep(min(.05, remaining()))
                methods = await asyncio.wait_for(self.control.call("list-methods"), remaining())
                self.methods = set(methods or [])
                missing = REQUIRED_METHODS - self.methods
                if missing:
                    raise PVSError(f"PVS agent extension missing required methods: {sorted(missing)}")
                info = await asyncio.wait_for(self.control.call("agent-info"), remaining())
                if not isinstance(info, dict) or not info.get("version"):
                    raise PVSError("agent-info did not return a versioned extension object.")
                if info.get("loaded") is False:
                    raise PVSError("PVS extension is not ready.")
                if url and not file and info.get("context"):
                    native_context = Path(info["context"]).resolve()
                    if context and self.context != native_context:
                        raise PVSError("Connected PVS has a different context; use prepare explicitly.")
                    self.context = native_context
                self.info = info
                self.generation += 1
                if file:
                    await asyncio.wait_for(
                        self.control.call("agent-prepare", [str(self.context), file]), remaining())
                dashboard = None
                if self.observer_mode != "off":
                    dashboard = await self.dashboard()
                return {"url": self.url, "generation": self.generation, "info": info,
                        "dashboard": dashboard, "recovery_dir": str(self.recovery_dir)}
            except BaseException:
                await self.close()
                raise

    async def dashboard(self) -> dict[str, Any]:
        """Return/start the read-only viewer; failures never invalidate a proof."""
        async with self.observer_lock:
            return await self._dashboard()

    async def _dashboard(self) -> dict[str, Any]:
        if self.observer is None:
            if "agent-observer-drain" not in self.methods:
                return {"error": "This worker predates the viewer; start a new MCP worker."}
            from observer import ProofObserver
            observer = ProofObserver(self)
            try:
                await observer.start(open_browser=self.observer_mode == "auto")
                self.observer = observer
                for session in self.sessions.values(): observer.session(session)
            except Exception as error:
                await observer.close()
                self.observer_error = str(error)
                return {"error": self.observer_error}
        return {"url": self.observer.url, "read_only": True}

    def observe(self, session: Session, **extra) -> None:
        if self.observer:
            try: self.observer.session(session, **extra)
            except Exception as error: self.observer_error = str(error)

    async def list_sessions(self) -> dict[str, Any]:
        if self.control is None:
            self.require_control()
        try:
            info = await asyncio.wait_for(self.require_control().call("agent-info"), 3)
        except (PVSError, asyncio.TimeoutError) as error:
            info = {"unavailable": str(error) or "Native health query timed out"}
        return {"generation": self.generation, "native": info, "health": self.health(),
                "dashboard": self.observer.url if self.observer else None,
                "client": [{"id": s.id, "kind": s.kind, "revision": s.revision,
                            "running": bool(s.pending and not s.pending.done()),
                            "closed": s.closed, "uncertain": s.uncertain,
                            "error": s.last_error} for s in self.sessions.values()]}

    async def prepare(self, context: str, file: str) -> Any:
        async with self.setup_lock:
            self.require_idle()
            result = await self.require_control().call("agent-prepare", [context, file])
            self.context = Path(context).resolve()
            return result

    async def _open(self, kind: str, method: str, params: list[Any]) -> dict[str, Any]:
        async with self.setup_lock:
            self.require_idle()  # Native startup may load strategies/attachments.
            assert self.url is not None, "Start PVS first."
            info = await self.require_control().call("agent-info")
            live = [s for s in (info.get("sessions") or [])
                    if s.get("alive", True)
                    and str(s.get("state", s.get("status", ""))).lower() not in TERMINAL]
            if live and not info.get("parallel_proofs", False):
                raise PVSError("This extension supports one live session per process.")
            if live and (kind == "evaluator" or any(s.get("kind") in {"pvsio", "evaluator"} for s in live)) and not info.get("parallel_evaluator", False):
                raise PVSError("Parallel evaluator use is not enabled for this extension.")
            conn = await RPCConnection.open(self.url, self.record)
            try:
                result = await conn.call(method, params)
                rows = result if isinstance(result, list) else [result]
                native_id = next((r.get("id") or r.get("sessionId") for r in reversed(rows)
                                  if isinstance(r, dict) and (r.get("id") or r.get("sessionId"))), None)
                if native_id is None:
                    raise PVSError(f"Native session initialization returned no session ID: {result}")
                session = Session(str(native_id), kind, conn, result, formula=params[0])
                self.sessions[session.id] = session
                if kind == "proof":
                    await self._refresh_proof_status(session)
                self.observe(session, formula=params[0], actor="Agent")
                if self.observer:
                    with contextlib.suppress(Exception): await self.observer.refresh_strategies()
                self.checkpoint()
                return self.state(session)
            except BaseException:
                await conn.close()
                raise

    async def proof_open(self, formula: str, rerun: bool = False) -> dict[str, Any]:
        return await self._open("proof", "agent-proof-open" if "agent-proof-open" in self.methods else "prove-formula", [formula, rerun])

    async def evaluator_open(self, theory: str) -> dict[str, Any]:
        return await self._open("evaluator", "agent-evaluator-start", [theory])

    async def _refresh_proof_status(self, session: Session) -> None:
        rows = await session.connection.call("prover-status", [session.id])
        rows = rows if isinstance(rows, list) else [rows]
        status = next((row.get("status") for row in rows if isinstance(row, dict)), None)
        if not isinstance(status, str):
            raise PVSError(f"Invalid native prover-status response: {rows}")
        session.proof_result = status.lower()
        session.closed = session.proof_result != "active"

    def state(self, session: Session, full: bool = False) -> dict[str, Any]:
        result: dict[str, Any] = {
            "session_id": session.id, "generation": self.generation,
            "revision": session.revision, "kind": session.kind,
            "running": bool(session.pending and not session.pending.done()),
            "uncertain": session.uncertain, "error": session.last_error,
            "closed": session.closed, "proof_result": session.proof_result,
        }
        native = session.latest
        if isinstance(native, dict) and native.get("compact") and not full:
            result.update({k: v for k, v in native.items() if k not in {"id", "compact"}})
            result["delta"] = session.delta
            result["details"] = "Full metadata is lazy: inspect full; open goals: inspect tree."
        elif full or session.kind != "proof" or not isinstance(native, list):
            result["native"] = native
        else:
            states = [item for item in native if isinstance(item, dict)]
            if states:
                focus = states[-1]
                result.update({key: focus[key] for key in
                               ("label", "status", "path", "commentary", "action", "children")
                               if key in focus})
                sequent = focus.get("sequent") or {}
                result["sequent"] = {
                    side: [{k: v for k, v in f.items() if k != "names-info"}
                           for f in (sequent.get(side) or [])]
                    for side in ("antecedents", "succedents")
                }
                result["hidden_counts"] = {
                    side: len(sequent.get("hidden-" + side) or [])
                    for side in ("antecedents", "succedents")
                }
                result["intermediate_states"] = [
                    {k: state[k] for k in ("label", "status", "unique-ps-id", "action") if k in state}
                    for state in states[:-1]]
                result["details"] = "Use inspect(kind='full') for complete native states and names-info."
        if session.recovery:
            result["recovery"] = session.recovery
        if self.runtime_failure:
            result["runtime_failure"] = self.runtime_failure
            result["running"] = False
            result["outcome"] = "uncertain"
            result["cached_state"] = True
        return result

    async def _execute(self, session: Session, method: str, params: list[Any],
                       update_state: bool = True) -> Any:
        started = time.monotonic()
        try:
            result = await session.connection.call(method, params)
            if update_state:
                before = self.state(session).get("sequent", {})
                session.latest = result
                session.revision += 1
                if session.kind == "proof":
                    await self._refresh_proof_status(session)
                    after = self.state(session).get("sequent", {})
                    def formulas(sequent):
                        return [(side, f.get("formula")) for side in ("antecedents", "succedents") for f in sequent.get(side, [])]
                    old, new = formulas(before), formulas(after)
                    session.delta = {"added": [x for x in new if x not in old], "removed": [x for x in old if x not in new]}
            session.elapsed_ms = (time.monotonic() - started) * 1000
            session.last_error = None
            return result
        except Exception as exc:
            session.last_error = str(exc)
            session.uncertain = isinstance(exc, ConnectionLost)
            if update_state and session.kind == "proof" and not self.runtime_failure:
                # Status reconciliation is read-only. Never resend a failed RPC.
                with contextlib.suppress(Exception):
                    await asyncio.wait_for(self._refresh_proof_status(session), 3)
            raise
        finally:
            if update_state:
                # The task is still inside its finally block, so mark settled explicitly.
                self.observe(session, running=False)
                if not session.uncertain:
                    session.active_command = None
                self.record("command_result", {"session_id": session.id,
                                              "state": {**self.state(session), "running": False}})
                try:
                    self.checkpoint(settled=session.id)
                except OSError as error:
                    self.journal_error = str(error)

    async def _command(self, session_id: str, kind: str, method: str, params: list[Any],
                       wait: float, expected_revision: int | None, label: str = "", actor: str = "",
                       time_limit: float = 60) -> dict[str, Any]:
        if not 0 <= time_limit <= 86400:
            raise PVSError("time_limit must be 0 (disabled) or at most 86400 seconds.")
        async with self.setup_lock:
            self.require_control()
            session = self.session(session_id)
            if session.batch_owner is not None and session.batch_owner is not asyncio.current_task():
                raise PVSError("This session is reserved by a bounded command sequence.")
            if session.kind != kind or session.closed:
                raise PVSError(f"Session is not an open {kind} session.")
            if session.uncertain:
                raise PVSError("The prior outcome is unknown; inspect/recover explicitly before continuing.")
            if session.pending and not session.pending.done():
                raise PVSError("A command is still running in this session; inspect or interrupt it.")
            if expected_revision is not None and expected_revision != session.revision:
                raise PVSError(f"Stale revision {expected_revision}; current revision is {session.revision}.")
            session.active_command = params[1]
            session.recovery = None
            self.checkpoint()  # Persist the prior acknowledged state BEFORE executing.
            session.pending = asyncio.create_task(self._execute(session, method, params))
            if time_limit:
                session.watchdog = asyncio.create_task(self.watch_command(session, session.pending, time_limit))
            # Retrieve exceptions even when the tool returns before the command.
            session.pending.add_done_callback(lambda task: None if task.cancelled() else task.exception())
            self.observe(session, command=params[1], command_label=label,
                         **({"actor": actor} if actor else {}))
        try:
            await asyncio.wait_for(asyncio.shield(session.pending), max(0.01, wait))
        except asyncio.TimeoutError:
            pass  # Waiting timed out; native work remains active.
        return self.state(session)

    async def command(self, session_id: str, command: str, wait: float = 15,
                      expected_revision: int | None = None, label: str = "", actor: str = "",
                      time_limit: float = 60) -> dict[str, Any]:
        return await self._command(session_id, "proof", "agent-proof-step" if "agent-proof-step" in self.methods else "proof-command",
                                   [session_id, command], wait, expected_revision, label, actor, time_limit)

    async def evaluate(self, session_id: str, expression: str, wait: float = 15,
                       expected_revision: int | None = None, time_limit: float = 60) -> dict[str, Any]:
        return await self._command(session_id, "evaluator", "pvsio-eval",
                                   [session_id, expression, "pvs"], wait, expected_revision, time_limit=time_limit)

    async def inspect(self, session_id: str = "", kind: str = "state",
                      since: int = 0, limit: int = 100) -> Any:
        if kind == "health":
            return self.health(details=True)
        if kind == "transcript":
            total = len(self._event_index)
            stop = min(total, since + max(1, min(limit, 1000)))
            return {"events": self._read_events(since, stop), "next": stop, "total": total}
        session = self.session(session_id)
        if kind == "state" or (kind == "full" and "agent-full" not in self.methods):
            return self.state(session, full=kind == "full")
        if kind == "full" and session.closed:
            return {**self.state(session), "native": await session.connection.call("agent-full", [session_id])}
        async with self.setup_lock:
            if session.closed or (session.pending and not session.pending.done()):
                raise PVSError("Computed inspection requires an idle target session.")
            session.pending = asyncio.create_task(self._execute(
                session, "agent-full" if kind == "full" else "agent-tree" if kind == "tree" else "agent-inspect",
                [session_id] if kind == "full" else [session_id, since, limit] if kind == "tree" else [session_id, kind], update_state=False))
            session.pending.add_done_callback(lambda task: None if task.cancelled() else task.exception())
        value = await asyncio.shield(session.pending)
        return {**self.state(session), "native": value} if kind == "full" else value

    async def _query(self, session_id: str, method: str, params: list[Any], expected_revision: int | None = None) -> Any:
        async with self.setup_lock:
            session = self.session(session_id)
            if session.closed or (session.pending and not session.pending.done()):
                raise PVSError("Inspection requires an idle live session.")
            if expected_revision is not None and expected_revision != session.revision:
                raise PVSError("Stale revision; inspect current state first.")
            session.pending = asyncio.create_task(self._execute(session, method, params, update_state=False))
        return await asyncio.shield(session.pending)

    async def expression(self, session_id: str, fnum: int, path: list[int] | None = None,
                         expected_revision: int | None = None) -> Any:
        return await self._query(session_id, "agent-expression", [session_id, fnum, path or []], expected_revision)

    async def preview(self, session_id: str, provider: str = "cmr98",
                      expected_revision: int | None = None) -> Any:
        session = self.session(session_id)
        result = await self._query(session_id, "agent-preview", [session_id, provider], expected_revision)
        return {**result, "session_id": session_id, "revision": session.revision,
                "note": "Candidate only. Execute script with expected_revision; PVS checks every obligation."}

    async def evaluator_prepare(self, session_id: str, expression: str) -> Any:
        async with self.setup_lock:
            self.require_idle()
            return await self.require_control().call("agent-evaluator-prepare", [session_id, expression])

    async def batch(self, session_id: str, commands: list[str], expected_revision: int,
                    wait: float = 30, expected_label: str | None = None) -> dict[str, Any]:
        if not 1 <= len(commands) <= 32:
            raise PVSError("A sequence must have 1–32 commands.")
        session = self.session(session_id)
        if session.batch_owner is not None:
            raise PVSError("A sequence already owns this session.")
        if expected_revision != session.revision:
            raise PVSError("Stale revision; inspect first.")
        if expected_label is not None and self.state(session).get("label") != expected_label:
            raise PVSError("Unexpected focus label; inspect first.")
        session.batch_owner = asyncio.current_task()
        deadline = time.monotonic() + max(.01, min(wait, 60))
        states, reason = [], "exhausted"
        try:
            for command in commands:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    reason = "budget"
                    break
                try:
                    state = await self.command(session_id, command, remaining, session.revision)
                except Exception as exc:
                    reason = "error"
                    states.append({**self.state(session), "error": str(exc)})
                    break
                states.append(state)
                if state["running"] or state["closed"] or state.get("uncertain") or state.get("command_error") or state.get("render_error") or state.get("outcome") == "interrupted":
                    reason = state.get("outcome") or "running"
                    if state["running"]: reason = "running"
                    break
                if expected_label is not None and state.get("label") != expected_label:
                    reason = "focus_changed"
                    break
        finally:
            session.batch_owner = None
        return {"states": states, "stop_reason": reason, "executed": len(states), "remaining": len(commands) - len(states)}

    async def navigate(self, session_id: str, goal_id: str, expected_revision: int) -> dict[str, Any]:
        session = self.session(session_id)
        if expected_revision != session.revision:
            raise PVSError("Stale revision; inspect tree first.")
        if session.batch_owner is not None:
            raise PVSError("A sequence already owns this session.")
        session.batch_owner = asyncio.current_task()
        try:
            tree = await self.inspect(session_id, "tree", limit=100)
            target = next((g for g in tree["goals"] if g["id"] == goal_id), None)
            if target is None:
                raise PVSError("Target is not in the first 100 open goals; use native postpone for larger trees.")
            # PVS owns navigation; never transplant proofstate pointers.
            state = self.state(session)
            for _ in range(tree["total"]):
                if state.get("label") == target["label"]: return state
                state = await self.command(session_id, "(postpone)", expected_revision=session.revision)
                if state["running"] or state["closed"] or state.get("command_error"):
                    return state
            if state.get("label") == target["label"]: return state
            raise PVSError("Target may have closed during native postpone; inspect the updated tree.")
        finally:
            session.batch_owner = None

    async def obligations(self, theory: str) -> Any:
        async with self.setup_lock:
            self.require_idle()
            return await self.require_control().call("agent-obligations", [theory])

    async def help(self, command: str) -> Any:
        return await self.require_control().call("proof-help", [command])

    async def lookup(self, identifier: str) -> Any:
        return await self.require_control().call("find-declaration", [identifier])

    async def proofs(self, formula: str) -> Any:
        """List native proof alternatives, with dependencies when supported."""
        method = "agent-proof-records" if "agent-proof-records" in self.methods else "all-proofs-of-formula"
        return await self.require_control().call(method, [formula])

    async def load_strategy(self, path: str) -> Any:
        source = Path(path).resolve()
        content = source.read_bytes()
        async with self.setup_lock:
            self.require_idle()
            result = await self.require_control().call("agent-load-strategy", [str(source)])
            if isinstance(result, dict) and (result.get("error") or result.get("loaded") is False):
                raise PVSError(f"Strategy load failed (partial definitions may remain): {result}")
            self.strategy_sources.pop(str(source), None)
            self.strategy_sources[str(source)] = content
            if self.observer:
                with contextlib.suppress(Exception): await self.observer.refresh_strategies()
            return result

    async def interrupt(self, session_id: str) -> Any:
        result = await self.recover(session_id, wait=1)
        return {"requested": result["status"] not in {"idle", "runtime_failed", "uncertain"}, **result}

    async def close_session(self, session_id: str) -> Any:
        session = self.session(session_id)
        method = "agent-proof-step" if session.kind == "proof" and not session.closed and "agent-proof-step" in self.methods else "agent-close"
        result = await self.require_control().call(method, [session_id, "(quit)"] if method == "agent-proof-step" else [session_id])
        if session.kind == "proof":
            await self._refresh_proof_status(session)
        session.closed = True
        self.observe(session)
        await session.connection.close()
        return {"session_id": session_id, "closed": True, "native": result}

    async def save(self, formula: str, proof_id: str) -> Any:
        async with self.setup_lock:
            self.require_idle()
            return await self.require_control().call("agent-save", [formula, proof_id])

    async def verify(self, formula: str, scope: str = "declaration",
                     timeout: float = 120) -> Any:
        """Replay saved proofs in a fresh isolated context; reject external imports."""
        if scope not in {"declaration", "theory", "importchain"}:
            raise PVSError("scope must be declaration, theory, or importchain")
        if self.context is None:
            raise PVSError("Prepare a context before verifying.")
        parts = formula.split("#")
        if len(parts) != 3:
            raise PVSError("Verification requires an explicit file.pvs#Theory#declaration reference.")
        source = Path(parts[0])
        source = (self.context / source).resolve() if not source.is_absolute() else source.resolve()
        try:
            relative = source.relative_to(self.context)
        except ValueError:
            raise PVSError("The verification target must be inside the prepared context.") from None
        async with self.setup_lock:
            self.require_idle()
            await self.require_control().call("agent-validate-context")
            info = await self.require_control().call("agent-info")
            if info.get("pvs_path") and Path(info["pvs_path"]).resolve() != self.pvs.parent:
                raise PVSError("Connected PVS differs from the configured verifier installation; specify the matching --pvs.")
            for automatic in (self.pvs.parent / "pvs-strategies", Path.home() / "pvs-strategies"):
                if automatic.is_file() and not automatic.resolve().is_relative_to(self.context):
                    raise PVSError(f"External automatic strategy file is unsupported for isolated replay: {automatic}")
            for name in info.get("strategy_files", []) or []:
                path = Path(name).resolve()
                if not path.is_relative_to(self.context) and str(path) not in self.strategy_sources:
                    raise PVSError(f"Uncaptured external strategy file: {path}; isolated replay refused.")
            dependencies = await self.require_control().call(
                "collect-theory-usings", [f"{source}#{parts[1]}", None, False])
            if not isinstance(dependencies, list) or not dependencies:
                raise PVSError("Cannot establish dependency paths; isolated verification refused.")
            for dep in dependencies:
                name = dep.get("fileName") if isinstance(dep, dict) else None
                if not name:
                    raise PVSError("A dependency has no source path; isolated verification refused.")
                path = Path(name)
                path = (self.context / path).resolve() if not path.is_absolute() else path.resolve()
                builtin = path in {(self.pvs.parent / "lib" / n).resolve()
                                   for n in ("prelude.pvs", "pvsio_prelude.pvs")}
                if not path.is_relative_to(self.context) and not builtin:
                    raise PVSError(f"External import cannot be isolated automatically: {path}. "
                                   "Use a context containing the dependency closure.")
            for path in self.context.rglob("*"):
                if path.suffix == ".pvs":
                    source_text = "\n".join(line.split("%", 1)[0] for line in path.read_text().splitlines())
                    if re.search(r"\bLIBRARY\b|(?:[\w.-]+|\"[^\"]*\")\s*@", source_text, re.I):
                        raise PVSError(f"Library-qualified source requires explicit path mirroring: {path}. "
                                       "Automatic isolated replay supports local imports only.")
                if path.is_symlink():
                    raise PVSError(f"Symlinked context entry is unsupported for isolated replay: {path}")
            # Only disposable copies lose caches. Authoritative contexts are untouched.
            with tempfile.TemporaryDirectory(prefix="pvs-agent-verify-") as temp:
                copied = Path(temp) / "context"
                shutil.copytree(self.context, copied, ignore=shutil.ignore_patterns(
                    ".git", ".venv", "pvsbin", ".pvscontext", "__pycache__", ".cache"))
                verify_formula = f"{copied / relative}#{parts[1]}#{parts[2]}"
                verifier = PVSClient(self.pvs, self.loader, library_path="")
                try:
                    await verifier.start(str(copied), str(relative), timeout=timeout)
                    if verifier.info.get("version") != info.get("version"):
                        raise PVSError("Verifier extension version differs from the live session.")
                    for index, (name, content) in enumerate(self.strategy_sources.items()):
                        source_path = Path(name)
                        strategy = (copied / source_path.relative_to(self.context)
                                    if source_path.is_relative_to(self.context)
                                    else Path(temp) / f"strategy-{index}-{source_path.name}")
                        strategy.parent.mkdir(parents=True, exist_ok=True)
                        strategy.write_bytes(content)
                        await verifier.load_strategy(str(strategy))
                    result = await asyncio.wait_for(verifier.require_control().call(
                        "agent-verify", [verify_formula, scope]), timeout)
                    # Native CL-JSON encodes Lisp NIL as null, including booleans.
                    result["verified"] = result.get("verified") is True
                    for row in result.get("details", []):
                        row["proved"] = row.get("proved") is True
                    return {"formula": formula, "scope": scope, "isolated": True,
                            "native": result,
                            "strategy_hashes": {name: hashlib.sha256(content).hexdigest()
                                                for name, content in self.strategy_sources.items()}}
                except asyncio.TimeoutError as exc:
                    raise PVSError("Fresh replay timed out; its isolated worker was stopped.") from exc
                finally:
                    await verifier.close()

    async def close(self) -> None:
        self.stopping = True
        for session in self.sessions.values():
            if session.watchdog and not session.watchdog.done():
                session.watchdog.cancel()
        if self.observer:
            await self.observer.close()
            self.observer = None
        if self.process:
            # Stop the process we own before waiting on sockets: a PVS worker
            # in its debugger may not process close frames or native requests.
            with contextlib.suppress(ProcessLookupError):
                os.killpg(self.process.pid, signal.SIGTERM)
        elif self.control:
            requests = [asyncio.create_task(self.control.call("agent-close", [session.id]))
                        for session in self.sessions.values() if not session.closed]
            if not await settle_tasks(requests, 3):
                self.record("cleanup_warning", "Native session close did not finish; closing local connections.")
        connections = {session.connection for session in self.sessions.values()}
        if self.control:
            connections.add(self.control)
        # Sessions close independently, so one stalled handshake cannot delay
        # every later connection by another full timeout.
        await settle_tasks([asyncio.create_task(conn.close()) for conn in connections], 5)
        self.control = None
        if self.process:
            if not await settle_tasks([asyncio.create_task(self.process.wait())], 3):
                with contextlib.suppress(ProcessLookupError):
                    os.killpg(self.process.pid, signal.SIGKILL)
                if not await settle_tasks([asyncio.create_task(self.process.wait())], 2):
                    self.record("cleanup_warning", "Owned PVS did not report exit after SIGKILL.")
        if self.process_reader:
            if not await settle_tasks([self.process_reader], 1):
                if self.process:
                    with contextlib.suppress(ProcessLookupError):
                        os.killpg(self.process.pid, signal.SIGKILL)
                if not await settle_tasks([self.process_reader], 1):
                    self.record("cleanup_warning", "PVS output reader did not finish after cancellation.")
        self.process = None
        self.process_reader = None
        self.sessions.clear()
        self.methods.clear()
        self.url = None
        if self.temp:
            self.temp.cleanup()
            self.temp = None


OPERATIONS = {"dashboard", "obligations", "batch", "expression", "preview", "navigate", "evaluator_prepare", 
    "start", "prepare", "list_sessions", "proof_open", "command", "inspect", "recover",
    "help", "lookup", "proofs", "load_strategy", "evaluator_open", "evaluate", "interrupt",
    "close_session", "save", "verify",
}


async def json_repl(client: PVSClient) -> None:
    try:
        while line := await asyncio.to_thread(sys.stdin.readline):
            try:
                request = json.loads(line)
                operation = request.pop("operation")
                if operation not in OPERATIONS:
                    raise PVSError(f"Unknown operation: {operation}")
                result = await getattr(client, operation)(**request)
                response = {"result": result}
            except Exception as exc:
                response = {"error": str(exc)}
            print(json.dumps(response, ensure_ascii=False), flush=True)
    finally:
        await client.close()


def run_mcp(client: PVSClient) -> None:
    from mcp.server.fastmcp import FastMCP

    @contextlib.asynccontextmanager
    async def lifespan(_: Any):
        try:
            yield {}
        finally:
            await client.close()

    mcp = FastMCP("PVS interactive prover", lifespan=lifespan)

    @mcp.tool()
    async def pvs_start(context: str, file: str = "", url: str = "") -> dict[str, Any]:
        """Start patched PVS in a context, or connect to an explicit local extension URL."""
        return await client.start(context, file, url)

    @mcp.tool()
    async def pvs_dashboard() -> dict[str, Any]:
        """Open/locate the live read-only proof tree. Viewing never moves proof cursors."""
        return await client.dashboard()

    @mcp.tool()
    async def pvs_prepare(context: str, file: str) -> Any:
        """Prepare/typecheck a fixed context after affected sessions have closed."""
        return await client.prepare(context, file)

    @mcp.tool()
    async def pvs_sessions() -> dict[str, Any]:
        """List native sessions and running client operations."""
        return await client.list_sessions()

    @mcp.tool()
    async def pvs_proof_open(formula: str, rerun: bool = False) -> dict[str, Any]:
        """Open a named proof using file.pvs#Theory#declaration. Keep its session alive."""
        return await client.proof_open(formula, rerun)

    @mcp.tool()
    async def pvs_command(session_id: str, command: str, wait: float = 15,
                          expected_revision: int | None = None, label: str = "", actor: str = "",
                          time_limit: float = 60) -> dict[str, Any]:
        """Send one PVS command. Optional label/actor annotate its live tree. Undo/postpone/redo are native commands. wait only controls tool latency; time_limit (default 60s, 0 disables) requests native restore."""
        return await client.command(session_id, command, wait, expected_revision, label, actor, time_limit)

    @mcp.tool()
    async def pvs_inspect(session_id: str = "", kind: str = "state",
                          since: int = 0, limit: int = 100) -> Any:
        """Read state/full native output/transcript, or an extension inspection view."""
        return await client.inspect(session_id, kind, since, limit)

    @mcp.tool()
    async def pvs_batch(session_id: str, commands: list[str], expected_revision: int,
                        wait: float = 30, expected_label: str | None = None) -> dict[str, Any]:
        """Run up to 32 steps, stopping on errors/completion/time budget or unexpected focus. Never retry."""
        return await client.batch(session_id, commands, expected_revision, wait, expected_label)

    @mcp.tool()
    async def pvs_expression(session_id: str, fnum: int, path: list[int] | None = None,
                             expected_revision: int | None = None) -> Any:
        """Read typed AST at a signed formula number and child-index path. No parsing or mutation."""
        return await client.expression(session_id, fnum, path, expected_revision)

    @mcp.tool()
    async def pvs_preview(session_id: str, provider: str = "cmr98",
                          expected_revision: int | None = None) -> Any:
        """Preview candidate script, checking obligations, and lemmas without executing it."""
        return await client.preview(session_id, provider, expected_revision)

    @mcp.tool()
    async def pvs_navigate(session_id: str, goal_id: str, expected_revision: int) -> Any:
        """Focus an open goal from inspect tree, using native postpone steps."""
        return await client.navigate(session_id, goal_id, expected_revision)

    @mcp.tool()
    async def pvs_evaluator_prepare(session_id: str, expression: str) -> Any:
        """Parse/typecheck/cache a ground expression at an idle boundary, without executing it."""
        return await client.evaluator_prepare(session_id, expression)

    @mcp.tool()
    async def pvs_obligations(theory: str) -> Any:
        """List named formula and TCC statuses in an already prepared theory at an idle boundary."""
        return await client.obligations(theory)

    @mcp.tool()
    async def pvs_help(command: str) -> Any:
        """Read installed proof-command help."""
        return await client.help(command)

    @mcp.tool()
    async def pvs_lookup(identifier: str) -> Any:
        """Find declarations with this exact identifier in the loaded context."""
        return await client.lookup(identifier)

    @mcp.tool()
    async def pvs_proofs(formula: str) -> Any:
        """List native proof alternatives and their IDs before selecting one to save."""
        return await client.proofs(formula)

    @mcp.tool()
    async def pvs_load_strategy(path: str) -> Any:
        """Load strategy definitions while all sessions are idle; retain source for fresh replay."""
        return await client.load_strategy(path)

    @mcp.tool()
    async def pvs_evaluator_open(theory: str) -> dict[str, Any]:
        """Open PVSio with the extension's TCC reporting policy."""
        return await client.evaluator_open(theory)

    @mcp.tool()
    async def pvs_evaluate(session_id: str, expression: str, wait: float = 15, time_limit: float = 60) -> dict[str, Any]:
        """Evaluate a concrete PVS expression. Results are diagnostic evidence, not proofs."""
        return await client.evaluate(session_id, expression, wait, time_limit=time_limit)

    @mcp.tool()
    async def pvs_interrupt(session_id: str) -> Any:
        """Interrupt and wait up to one second; pending is not proof of restoration."""
        return await client.interrupt(session_id)

    @mcp.tool()
    async def pvs_recover(session_id: str, wait: float = 5) -> Any:
        """Bounded native restore; reports restored/pending/unresponsive/runtime_failed. Never restarts or replays."""
        return await client.recover(session_id, wait)

    @mcp.tool()
    async def pvs_close(session_id: str) -> Any:
        """Close one native proof/evaluator session."""
        return await client.close_session(session_id)

    @mcp.tool()
    async def pvs_save(formula: str, proof_id: str) -> Any:
        """Select and save an explicit native proof alternative. This does not verify it."""
        return await client.save(formula, proof_id)

    @mcp.tool()
    async def pvs_verify(formula: str, scope: str = "declaration",
                         timeout: float = 120) -> Any:
        """Force fresh replay of a saved proof in an isolated copy; external imports are refused."""
        return await client.verify(formula, scope, timeout)

    mcp.run(transport="stdio")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("mcp", "repl"), default="mcp")
    parser.add_argument("--pvs", default=str(ROOT / "pvs"))
    parser.add_argument("--port", type=int, default=0, help="Stable PVS worker port for replacement/reconnect (0 chooses a free port)")
    parser.add_argument("--loader", default=str(ROOT / "agent" / "load.lisp"))
    parser.add_argument("--library-path", default="", help="Explicit PVS library path; defaults to empty")
    parser.add_argument("--viewer", choices=("auto", "headless", "off"),
                        default=os.environ.get("PVS_AGENT_VIEWER", "auto"),
                        help="MCP live tree: auto opens a browser; headless returns URL; off disables capture")
    args = parser.parse_args()
    client = PVSClient(args.pvs, args.loader, library_path=args.library_path,
                       observer_mode=args.viewer if args.mode == "mcp" else "off", port=args.port)
    if args.mode == "repl":
        asyncio.run(json_repl(client))
    else:
        run_mcp(client)


if __name__ == "__main__":
    main()
