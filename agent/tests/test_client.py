"""Adapter regressions with a fake native peer; these tests never launch PVS."""
import asyncio
import contextlib
import json
from pathlib import Path
import shlex
import sys
import time
from unittest.mock import patch

import pytest
import websockets

AGENT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AGENT))
from server import ConnectionLost, PVSClient, PVSError, REQUIRED_METHODS, RPCConnection, Session, settle_tasks


class FakePVS:
    def __init__(self, rich_records=True):
        self.rich_records = rich_records
        self.calls = []
        self.sessions = {}
        self.release = asyncio.Event()

    def state(self, sid):
        # A native child-node '!' does not establish that the entire proof closed.
        return [{"id": sid, "label": "lemma.1", "status": "!", "sequent": {
            "antecedents": None,
            "succedents": [{"formula": "TRUE", "names-info": ["details"]}],
            "hidden-antecedents": None, "hidden-succedents": None}}]

    async def handler(self, socket):
        async for raw in socket:
            request = json.loads(raw)
            method, params = request["method"], request["params"]
            self.calls.append((method, params))
            if method == "list-methods":
                result = sorted(REQUIRED_METHODS | ({"agent-proof-records"} if self.rich_records else set()))
            elif method == "agent-info":
                result = {"version": "test", "loaded": True, "parallel_proofs": True,
                          "parallel_evaluator": True, "sessions": [
                              {"id": sid, "kind": "proof", "state": "idle" if status == "active" else "closed"}
                              for sid, status in self.sessions.items()]}
            elif method == "prove-formula":
                sid = f"proof-{len(self.sessions) + 1}"
                self.sessions[sid] = "active"
                result = self.state(sid)
            elif method == "prover-status":
                result = [{"proof-id": params[0], "status": self.sessions[params[0]]}]
            elif method == "proof-command":
                sid, command = params
                if command == "(disconnect)":
                    await socket.close()
                    continue
                if command == "(uncorrelated-error)":
                    await socket.send(json.dumps({"jsonrpc": "2.0", "id": None,
                                                  "error": {"code": -1, "message": "native failure"}}))
                    continue
                # A notification can carry the same ID. It still isn't a reply.
                await socket.send(json.dumps({"jsonrpc": "2.0", "id": request["id"],
                                              "method": "pvsMessage", "params": ["working"]}))
                if command == "(slow)":
                    await self.release.wait()
                if command == "(finish)":
                    self.sessions[sid] = "proved"
                result = self.state(sid)
            elif method == "agent-inspect":
                result = {"session_id": params[0], "view": params[1]}
            elif method == "agent-proof-records":
                result = [{"id": "candidate", "dependencies": [{"name": "helper", "theory": "fixture"}]}]
            elif method == "all-proofs-of-formula":
                result = [{"id": "candidate"}]
            elif method == "agent-close":
                self.sessions[params[0]] = "quit"
                result = {"closed": True}
            else:
                result = {"ok": True}
            await socket.send(json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}))

    @contextlib.asynccontextmanager
    async def connect(self, context):
        async with websockets.serve(self.handler, "127.0.0.1", 0) as listener:
            url = f"ws://127.0.0.1:{listener.sockets[0].getsockname()[1]}"
            client = PVSClient()
            try:
                await client.start(str(context), url=url)
                yield client
            finally:
                self.release.set()
                await client.close()


def test_pending_commands_inspection_revisions_and_terminal_status(tmp_path):
    async def scenario():
        peer = FakePVS()
        async with peer.connect(tmp_path) as client:
            first = await client.proof_open("fixture.pvs#fixture#first")
            sid = first["session_id"]
            assert first["proof_result"] == "active" and not first["closed"]
            assert first["sequent"]["antecedents"] == []
            assert first["hidden_counts"] == {"antecedents": 0, "succedents": 0}
            assert "names-info" not in first["sequent"]["succedents"][0]
            full = await client.inspect(sid, "full")
            assert full["native"][0]["sequent"]["succedents"][0]["names-info"] == ["details"]
            second = await client.proof_open("fixture.pvs#fixture#second")
            pending = await client.command(sid, "(slow)", wait=.01, expected_revision=0)
            assert pending["running"]
            with pytest.raises(PVSError, match="still running"):
                await client.command(sid, "(slow)")
            # Native owner-thread inspection is safe on another idle proof.
            inspected = await client.inspect(second["session_id"], "locals")
            assert inspected["view"] == "locals"
            assert (await client.inspect(second["session_id"]))["revision"] == 0
            peer.release.set()
            await asyncio.wait_for(asyncio.shield(client.session(sid).pending), 1)
            settled = await client.inspect(sid)
            assert not settled["running"] and settled["revision"] == 1
            with pytest.raises(PVSError, match="Stale revision"):
                await client.command(sid, "(slow)", expected_revision=0)
            finished = await client.command(sid, "(finish)", expected_revision=1)
            assert finished["proof_result"] == "proved" and finished["closed"]
            with pytest.raises(PVSError, match="not an open proof"):
                await client.command(sid, "(finish)")
            assert sum(method == "proof-command" for method, _ in peer.calls) == 2
            assert any(event["kind"] == "received" and event["data"].get("method") == "pvsMessage"
                       for event in client.events)
    asyncio.run(scenario())


@pytest.mark.parametrize("command", ["(disconnect)", "(uncorrelated-error)"])
def test_uncertain_outcome_is_not_retried(tmp_path, command):
    async def scenario():
        peer = FakePVS()
        async with peer.connect(tmp_path) as client:
            sid = (await client.proof_open("fixture.pvs#fixture#first"))["session_id"]
            with pytest.raises(ConnectionLost):
                await client.command(sid, command)
            assert (await client.inspect(sid))["uncertain"]
            with pytest.raises(PVSError, match="prior outcome is unknown"):
                await client.command(sid, command)
            assert sum(method == "proof-command" for method, _ in peer.calls) == 1
    asyncio.run(scenario())


@pytest.mark.parametrize("rich_records", [True, False])
def test_proof_records_negotiate_optional_dependencies(tmp_path, rich_records):
    async def scenario():
        peer = FakePVS(rich_records)
        async with peer.connect(tmp_path) as client:
            records = await client.proofs("fixture.pvs#fixture#first")
            assert records[0]["id"] == "candidate"
            assert ("dependencies" in records[0]) == rich_records
            expected = "agent-proof-records" if rich_records else "all-proofs-of-formula"
            assert peer.calls[-1][0] == expected
    asyncio.run(scenario())


def test_initial_refused_connection_is_retried_before_rpc(tmp_path):
    async def scenario():
        original = RPCConnection.open
        attempts = 0

        async def initially_refused(*args, **kwargs):
            nonlocal attempts
            attempts += 1
            if attempts < 3:
                raise ConnectionRefusedError("listener is starting")
            return await original(*args, **kwargs)

        peer = FakePVS()
        with patch.object(RPCConnection, "open", side_effect=initially_refused):
            async with peer.connect(tmp_path):
                assert attempts == 3
                assert [name for name, _ in peer.calls] == ["list-methods", "agent-info"]
    asyncio.run(scenario())


def test_startup_failure_reports_diagnostics_without_waiting(tmp_path):
    executable = tmp_path / "fake-pvs"
    arguments = tmp_path / "arguments"
    executable.write_text("#!/bin/sh\n"
                          f"printf '%s\\n' \"$@\" > {shlex.quote(str(arguments))}\n"
                          "printf '%s\\n' 'PVS-AGENT-STARTUP-FAILED: synthetic loader failure'\n"
                          "exit 1\n")
    executable.chmod(0o755)
    loader = tmp_path / "load.lisp"
    loader.write_text("; fake loader\n")

    async def scenario():
        client = PVSClient(executable, loader)
        before = time.monotonic()
        with pytest.raises(PVSError, match="synthetic loader failure"):
            await client.start(str(tmp_path), timeout=2)
        assert time.monotonic() - before < 2
        assert client.process is None and client.control is None
        args = arguments.read_text()
        assert "-raw\n-q\n-patchlevel\nnone\n-E\n" in args
        assert "(handler-case" in args and "(uiop:quit 1)" in args
    asyncio.run(scenario())


def test_mcp_stdio_discovery_and_controlled_not_started_error():
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    async def scenario():
        params = StdioServerParameters(command=sys.executable, args=[str(AGENT / "server.py"), "mcp"])
        async with stdio_client(params) as (reader, writer):
            async with ClientSession(reader, writer) as session:
                await session.initialize()
                listed = await session.list_tools()
                assert {"pvs_prepare", "pvs_proofs", "pvs_verify", "pvs_command", "pvs_inspect"} <= {
                    tool.name for tool in listed.tools}
                result = await session.call_tool("pvs_sessions", {})
                assert result.isError
                assert "Start or connect to PVS first" in result.content[0].text
    asyncio.run(scenario())


def test_socket_cleanup_aborts_a_peer_that_ignores_cancellation():
    async def scenario():
        released = asyncio.Event()
        sent = asyncio.Event()

        class StuckSocket:
            def __init__(self):
                self.transport = self
                self.aborted = False

            def __aiter__(self):
                return self

            async def wait_for_abort(self):
                while not released.is_set():
                    try:
                        await released.wait()
                    except asyncio.CancelledError:
                        pass  # Simulate a close/reader waiting on an unresponsive peer.

            async def __anext__(self):
                await self.wait_for_abort()
                raise StopAsyncIteration

            async def send(self, message):
                sent.set()

            async def close(self):
                await self.wait_for_abort()

            def abort(self):
                self.aborted = True
                released.set()

        socket = StuckSocket()
        connection = RPCConnection(socket, lambda *args: None)
        command = asyncio.create_task(connection.call("proof-command", ["proof", "(grind)"]))
        await sent.wait()
        before = time.monotonic()
        try:
            await connection.close(timeout=.02)
            assert time.monotonic() - before < .5
            assert socket.aborted and connection.reader.done()
            with pytest.raises(ConnectionLost, match="cleanup"):
                await command
            with pytest.raises(ConnectionLost, match="closed"):
                await connection.call("proof-command", ["proof", "(grind)"])
        finally:
            released.set()
            await asyncio.gather(command, connection.reader, return_exceptions=True)
    asyncio.run(scenario())


def test_owned_process_is_stopped_before_socket_cleanup():
    async def scenario():
        order = []

        class Process:
            pid = 12345

            async def wait(self):
                order.append("process-wait")
                return 0

        class Connection:
            async def close(self):
                order.append("socket-close")

        client = PVSClient()
        client.process = Process()
        client.control = Connection()
        client.sessions["proof"] = Session("proof", "proof", client.control)
        with patch("server.os.killpg", side_effect=lambda *args: order.append("terminate")):
            await client.close()
        assert order[0] == "terminate"
        assert order.count("socket-close") == 1
        assert client.process is None and client.control is None
    asyncio.run(scenario())


def test_output_reader_cancellation_does_not_block_client_close():
    async def scenario():
        released = asyncio.Event()
        started = asyncio.Event()

        async def stuck_reader():
            started.set()
            while not released.is_set():
                try:
                    await released.wait()
                except asyncio.CancelledError:
                    pass

        async def short_settle(tasks, timeout):
            return await settle_tasks(tasks, min(timeout, .02))

        client = PVSClient()
        reader = client.process_reader = asyncio.create_task(stuck_reader())
        await started.wait()
        before = time.monotonic()
        try:
            with patch("server.settle_tasks", side_effect=short_settle):
                await client.close()
            assert time.monotonic() - before < .5
            assert any(event["kind"] == "cleanup_warning" for event in client.events)
            assert client.process_reader is None
        finally:
            released.set()
            await reader
    asyncio.run(scenario())


def test_verification_revalidates_live_sources_before_inspection_or_copy(tmp_path):
    async def scenario():
        methods = []

        class Control:
            async def call(self, method, params=None):
                methods.append(method)
                raise PVSError("Prepared source changed")

        client = PVSClient()
        client.context = tmp_path
        client.control = Control()
        with pytest.raises(PVSError, match="Prepared source changed"):
            await client.verify(str(tmp_path / "fixture.pvs") + "#fixture#lemma")
        assert methods == ["agent-validate-context"]
    asyncio.run(scenario())


def test_transcript_paging_across_journals_and_write_failure(tmp_path):
    client = PVSClient()
    client.record("process", "before startup")
    first = tmp_path / "first.jsonl"
    first.write_text('{"previous":"worker"}\n')
    client.transcript_path = first
    client.record("receive", {"message": "λ" * 4096})
    client.transcript_path = tmp_path / "absent" / "events.jsonl"
    client.record("process", "write failed")
    client.transcript_path = tmp_path / "second.jsonl"
    client.record("send", "after recovery")

    page = asyncio.run(client.inspect(kind="transcript", since=1, limit=2))
    assert page["next"] == 3 and page["total"] == 4
    assert [event["data"] for event in page["events"]] == [{"message": "λ" * 4096}, "write failed"]
    assert [event["index"] for event in client.events] == list(range(4))
    assert client.journal_error
