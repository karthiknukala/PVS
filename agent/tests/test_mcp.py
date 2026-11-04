"""Exercise the public MCP stdio interface against real, isolated PVS processes."""
import asyncio
import json
import os
import tomllib
from pathlib import Path
import shutil
import sys

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

AGENT = Path(__file__).resolve().parents[1]


def registered_or_default_parameters(**defaults):
    """Opt-in validation of the actual saved Codex stdio registration."""
    config_path = os.environ.get("PVS_MCP_CONFIG")
    if not config_path:
        defaults["env"] = {**defaults.get("env", {}), "PVS_AGENT_VIEWER": "headless"}
        return StdioServerParameters(**defaults)
    config = tomllib.loads(Path(config_path).read_text())
    entry = config["mcp_servers"]["pvs"]
    assert entry.get("enabled", True), "Registered PVS server is disabled"
    assert "command" in entry and "url" not in entry, "Expected local stdio PVS server"
    env = {key: os.environ[key] for key in entry.get("env_vars", []) if key in os.environ}
    env.update(entry.get("env", {}))
    env["PVS_AGENT_VIEWER"] = "headless"
    return StdioServerParameters(command=entry["command"], args=entry.get("args", []),
                                 cwd=entry.get("cwd"), env=env)


async def call(session, name, **arguments):
    result = await session.call_tool(name, arguments)
    diagnostic = "\n".join(block.text for block in result.content if block.type == "text")
    assert not result.isError, f"{name} failed:\n{diagnostic}"
    value = result.structuredContent
    if value is None:
        rows = [json.loads(block.text) for block in result.content if block.type == "text"]
        # Any-returning list tools have no output schema. FastMCP emits one
        # text block per item, including when the native list has one row.
        if name == "pvs_proofs" or (name == "pvs_inspect" and arguments.get("kind") in {"locals", "dependencies"}):
            return rows
        assert len(rows) == 1, (name, result)
        return rows[0]
    # FastMCP wraps Any-returning tools in a single 'result' property.
    return value["result"] if set(value) == {"result"} else value


def test_real_mcp_proof_save_and_fresh_verification(tmp_path):
    source = tmp_path / "agent_fixture.pvs"
    shutil.copy(AGENT / "tests/fixtures/agent_fixture.pvs", source)
    formula = f"{source}#agent_fixture#left_bound"

    async def scenario():
        parameters = registered_or_default_parameters(
            command=sys.executable,
            args=[str(AGENT / "server.py"), "mcp", "--pvs", str(AGENT.parent / "pvs"),
                  "--loader", str(AGENT / "load.lisp"), "--library-path", ""],
            cwd=str(tmp_path), env={"PVS_LIBRARY_PATH": ""})
        async with stdio_client(parameters) as (reader, writer):
            async with ClientSession(reader, writer) as session:
                await session.initialize()
                tools = {tool.name for tool in (await session.list_tools()).tools}
                assert {"pvs_start", "pvs_prepare", "pvs_proof_open", "pvs_command",
                        "pvs_inspect", "pvs_proofs", "pvs_save", "pvs_verify", "pvs_close", "pvs_dashboard"} <= tools
                started = await call(session, "pvs_start", context=str(tmp_path))
                assert started["info"]["loaded"] is True
                assert started["dashboard"]["url"]
                assert await call(session, "pvs_dashboard") == started["dashboard"]
                prepared = await call(session, "pvs_prepare", context=str(tmp_path), file="agent_fixture")
                assert "agent_fixture" in prepared["theories"]
                opened = await call(session, "pvs_proof_open", formula=formula)
                sid = opened["session_id"]
                assert opened["proof_result"] == "active" and not opened["closed"]
                inspected = await call(session, "pvs_inspect", session_id=sid)
                assert inspected["sequent"] == opened["sequent"]
                skolemized = await call(session, "pvs_command", session_id=sid,
                                        command="(skosimp*)", expected_revision=0,
                                        label="Introduce variables", actor="MCP test")
                assert skolemized["revision"] == 1 and skolemized["proof_result"] == "active"
                locals_ = await call(session, "pvs_inspect", session_id=sid, kind="locals")
                assert any(row["type"] == "nat" for row in locals_)
                finished = await call(session, "pvs_command", session_id=sid,
                                      command="(grind)", expected_revision=1)
                assert finished["proof_result"] == "proved" and finished["closed"]
                records = await call(session, "pvs_proofs", formula=formula)
                candidate = next(row for row in records if row["id"] == sid)
                assert candidate["status"].lower() == "proved"
                saved = await call(session, "pvs_save", formula=formula, proof_id=sid)
                assert saved["proof_id"] == sid and saved["status"] == "proved"
                proof_file = tmp_path / "agent_fixture.prf"
                assert proof_file.is_file() and "left_bound" in proof_file.read_text()
                verified = await call(session, "pvs_verify", formula=formula, scope="declaration", timeout=30)
                assert verified["isolated"] is True and verified["native"]["verified"] is True, verified
                rows = verified["native"]["details"]
                assert len(rows) == 1 and rows[0]["proved"] is True and rows[0]["chain"] == "complete"
                await call(session, "pvs_close", session_id=sid)
                sessions = await call(session, "pvs_sessions")
                assert next(row for row in sessions["client"] if row["id"] == sid)["closed"]

    asyncio.run(asyncio.wait_for(scenario(), 60))


def test_real_mcp_recovery_and_deadline(tmp_path):
    shutil.copy(AGENT / "tests/fixtures/agent_fixture.pvs", tmp_path)
    async def scenario():
        parameters = registered_or_default_parameters(
            command=sys.executable, args=[str(AGENT / "server.py"), "mcp"],
            cwd=str(tmp_path))
        async with stdio_client(parameters) as (reader, writer):
            async with ClientSession(reader, writer) as session:
                await session.initialize()
                schema = {t.name: t for t in (await session.list_tools()).tools}
                assert "pvs_recover" in schema
                assert "time_limit" in schema["pvs_command"].inputSchema["properties"]
                started = await call(session, "pvs_start", context=str(tmp_path), file="agent_fixture")
                opened = await call(session, "pvs_proof_open",
                                    formula=f"{tmp_path}/agent_fixture.pvs#agent_fixture#branching")
                sid = opened['session_id']
                await call(session, "pvs_command", session_id=sid, command="(skosimp*)")
                split = await call(session, "pvs_command", session_id=sid, command="(split)")
                assert split['open_goals'] == 2
                await call(session, "pvs_command", session_id=sid, command="(lisp (loop))", wait=.01, time_limit=0)
                recovered = await call(session, "pvs_recover", session_id=sid)
                assert recovered['status'] == 'restored'
                assert recovered['state']['open_goals'] == 2
                debugger = await call(session, "pvs_command", session_id=sid, command='(lisp (break "MCP recovery"))')
                assert debugger['outcome'] == 'interrupted'
                timed = await call(session, "pvs_command", session_id=sid, command="(lisp (loop))", time_limit=.2)
                assert timed['outcome'] == 'interrupted'
                assert timed['generation'] == started['generation']
                await call(session, "pvs_command", session_id=sid, command="(grind)")
                qed = await call(session, "pvs_command", session_id=sid, command="(grind)")
                assert qed['proof_result'] == 'proved'
                assert Path(started['recovery_dir'], 'checkpoint.json').exists()
                crash = await call(session, "pvs_proof_open",
                                   formula=f"{tmp_path}/agent_fixture.pvs#agent_fixture#false_goal")
                failed = await session.call_tool("pvs_command", {
                    "session_id": crash['session_id'], "command": "(lisp (uiop:quit 42))"})
                assert failed.isError
                for _ in range(20):
                    health = await call(session, "pvs_inspect", kind="health")
                    if health['status'] == 'runtime_failed': break
                    await asyncio.sleep(.05)
                assert health['status'] == 'runtime_failed'
                restored = await call(session, "pvs_recover", session_id=crash['session_id'])
                assert restored['status'] == 'runtime_failed'
                assert restored['state']['uncertain']

    asyncio.run(asyncio.wait_for(scenario(), 40))
