#!/usr/bin/env python3
"""Codex-facing JSONL proof driver for PVS.

This script starts a headless PVS process, loads the Codex stdio bridge,
then proxies JSON-RPC requests over stdin/stdout.
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import select
import signal
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path
from typing import Any

PROXY_OUTPUT_LOCK = threading.Lock()


class DriverError(RuntimeError):
    """Raised when the Codex proof driver returns an RPC error."""

    def __init__(self, error: dict[str, Any], response: dict[str, Any]):
        super().__init__(error.get("message", "PVS driver error"))
        self.error = error
        self.response = response


class CodexPVSProcess:
    """Manage a persistent PVS subprocess speaking JSON-RPC over stdio."""

    def __init__(
        self,
        repo_root: Path | None = None,
        pvs_executable: Path | None = None,
        driver_lisp: Path | None = None,
        startup_timeout: float = 120.0,
    ) -> None:
        repo_root = repo_root or Path(__file__).resolve().parents[3]
        self.repo_root = repo_root
        self.pvs_executable = pvs_executable or repo_root / "pvs"
        self.driver_lisp = driver_lisp or Path(__file__).resolve().with_name("proof-driver.lisp")
        self.startup_timeout = startup_timeout
        self.process: subprocess.Popen[str] | None = None
        self._ready = threading.Event()
        self._stdout_lock = threading.Lock()
        self._write_lock = threading.Lock()
        self._pending: dict[str, "queue.Queue[dict[str, Any]]"] = {}
        self._pending_lock = threading.Lock()
        self.notifications: "queue.Queue[dict[str, Any]]" = queue.Queue()
        self.startup_log: list[str] = []
        self._reader_thread: threading.Thread | None = None

    def start(self) -> None:
        if self.process is not None and self.process.poll() is None:
            return
        if self.process is not None and self.process.poll() is not None:
            self.process = None
            self._ready.clear()
        cmd = [
            str(self.pvs_executable),
            "-raw",
            "-L",
            str(self.driver_lisp),
            "-E",
            "(pvs::codex-proof-driver-main)",
        ]
        self.process = subprocess.Popen(
            cmd,
            cwd=self.repo_root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            start_new_session=True,
        )
        self._reader_thread = threading.Thread(target=self._read_stdout, daemon=True)
        self._reader_thread.start()
        if not self._ready.wait(self.startup_timeout):
            startup_tail = "\n".join(self.startup_log[-20:])
            self.close(force=True)
            raise RuntimeError(
                "Timed out waiting for the PVS Codex driver to become ready.\n"
                f"Last startup lines:\n{startup_tail}"
            )

    def close(self, force: bool = False) -> None:
        if self.process is None:
            return
        if self.process.poll() is not None:
            self.process = None
            return
        if not force:
            try:
                self.request("shutdown", timeout=10.0)
            except Exception:
                force = True
            else:
                try:
                    self.process.wait(timeout=2.0)
                except subprocess.TimeoutExpired:
                    force = True
        if force and self.process.poll() is None:
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.process.wait(timeout=5.0)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.process.wait(timeout=5.0)
        self.process = None

    def _read_stdout(self) -> None:
        assert self.process is not None and self.process.stdout is not None
        for raw_line in self.process.stdout:
            line = raw_line.rstrip("\n")
            if not line.replace("\x00", "").strip():
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                if self._ready.is_set() and line.strip():
                    self.notifications.put(
                        {"jsonrpc": "2.0", "method": "log", "params": {"message": line}}
                    )
                elif not self._ready.is_set():
                    self.startup_log.append(line)
                continue
            if not isinstance(message, dict):
                self.notifications.put({"jsonrpc": "2.0", "method": "log", "params": {"value": message}})
                continue
            if message.get("method") == "ready":
                self._ready.set()
                self.notifications.put(message)
                continue
            if "id" in message and ("result" in message or "error" in message):
                req_id = str(message["id"])
                with self._pending_lock:
                    reply_queue = self._pending.pop(req_id, None)
                if reply_queue is not None:
                    reply_queue.put(message)
                else:
                    self.notifications.put(
                        {"jsonrpc": "2.0", "method": "orphan-response", "params": {"response": message}}
                    )
                continue
            self.notifications.put(message)

    def request_raw(self, method: str, params: list[Any] | None = None, timeout: float = 60.0) -> dict[str, Any]:
        self.start()
        assert self.process is not None and self.process.stdin is not None
        req_id = uuid.uuid4().hex
        reply_queue: "queue.Queue[dict[str, Any]]" = queue.Queue(maxsize=1)
        with self._pending_lock:
            self._pending[req_id] = reply_queue
        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params or [],
        }
        with self._write_lock:
            self.process.stdin.write(json.dumps(payload) + "\n")
            self.process.stdin.flush()
        try:
            return reply_queue.get(timeout=timeout)
        except queue.Empty as exc:
            with self._pending_lock:
                self._pending.pop(req_id, None)
            raise RuntimeError(f"Timed out waiting for response to {method}") from exc

    def request(self, method: str, params: list[Any] | None = None, timeout: float = 60.0) -> Any:
        response = self.request_raw(method, params=params, timeout=timeout)
        if "error" in response:
            raise DriverError(response["error"], response)
        return response.get("result")


def emit_json(message: dict[str, Any]) -> None:
    with PROXY_OUTPUT_LOCK:
        print(json.dumps(message, sort_keys=True), flush=True)


def forward_notifications(driver: CodexPVSProcess, stop_event: threading.Event) -> None:
    while not stop_event.is_set():
        try:
            message = driver.notifications.get(timeout=0.1)
        except queue.Empty:
            continue
        emit_json(message)


def handle_request(
    driver: CodexPVSProcess,
    request: dict[str, Any],
    request_timeout: float,
    stop_event: threading.Event,
) -> None:
    method = request.get("method")
    params = request.get("params") or []
    if not isinstance(params, list):
        emit_json(
            {
                "jsonrpc": "2.0",
                "id": request.get("id"),
                "error": {
                    "code": -32602,
                    "message": "params must be a JSON array",
                },
            }
        )
        return
    try:
        response = driver.request_raw(method, params=params, timeout=request_timeout)
    except Exception as exc:
        emit_json(
            {
                "jsonrpc": "2.0",
                "id": request.get("id"),
                "error": {
                    "code": -32000,
                    "message": str(exc),
                },
            }
        )
        return
    if request.get("id") is not None and response.get("id") != request["id"]:
        response["id"] = request["id"]
    emit_json(response)
    if method == "shutdown":
        stop_event.set()
        def _terminate_proxy() -> None:
            time.sleep(0.1)
            driver.close(force=True)
            os._exit(0)

        threading.Thread(target=_terminate_proxy, daemon=True).start()


def proxy_stdio(args: argparse.Namespace) -> int:
    driver = CodexPVSProcess(startup_timeout=args.startup_timeout)
    stop_event = threading.Event()
    forwarder: threading.Thread | None = None
    workers: set[threading.Thread] = set()

    def install_signal_handlers() -> None:
        def _handle_signal(signum: int, _frame: Any) -> None:
            stop_event.set()
            driver.close(force=True)
            raise SystemExit(128 + signum)

        signal.signal(signal.SIGINT, _handle_signal)
        signal.signal(signal.SIGTERM, _handle_signal)

    try:
        install_signal_handlers()
        driver.start()
        forwarder = threading.Thread(target=forward_notifications, args=(driver, stop_event), daemon=True)
        forwarder.start()
        emit_json(
            {
                "jsonrpc": "2.0",
                "method": "proxy-ready",
                "params": {
                    "driver": "pvs-codex-proof-driver-proxy",
                    "protocol": "jsonrpc-stdio",
                },
            }
        )
        while not stop_event.is_set():
            readable, _, _ = select.select([sys.stdin], [], [], 0.1)
            if not readable:
                continue
            raw_line = sys.stdin.readline()
            if raw_line == "":
                break
            line = raw_line.strip()
            if not line:
                continue
            request = json.loads(line)
            worker = threading.Thread(
                target=handle_request,
                args=(driver, request, args.request_timeout, stop_event),
                daemon=True,
            )
            workers.add(worker)
            worker.start()
        return 0
    finally:
        stop_event.set()
        driver.close(force=False)
        if forwarder is not None:
            forwarder.join(timeout=1.0)
        for worker in list(workers):
            worker.join(timeout=1.0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the Codex PVS proof driver proxy.")
    parser.add_argument(
        "--startup-timeout",
        type=float,
        default=120.0,
        help="Seconds to wait for the PVS subprocess to announce readiness.",
    )
    parser.add_argument(
        "--request-timeout",
        type=float,
        default=60.0,
        help="Seconds to wait for each forwarded request.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return proxy_stdio(args)


if __name__ == "__main__":
    raise SystemExit(main())
