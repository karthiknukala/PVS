"""Reject external proof/context changes before native default selection or save."""
import asyncio
import os
from pathlib import Path
import shutil
import sys

import pytest

AGENT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AGENT))
from server import PVSClient, RPCError


def formula(context, name="left_bound"):
    return f"{context / 'agent_fixture.pvs'}#agent_fixture#{name}"


async def prove(client, context, name="left_bound"):
    sid = (await client.proof_open(formula(context, name)))["session_id"]
    result = await client.command(sid, "(grind)")
    assert result["proof_result"] == "proved"
    return sid


async def selected(client, sid):
    # Read the already-loaded declaration directly, without a native resolver
    # that might reload disk state and mask a rejected save's selection changes.
    code = (
        "(string (id (default-proof (formula-decl "
        f'(agent-session-data-session (agent-session-state "{sid}")))))))'
    )
    return await client.require_control().call("lisp", [code])


def copy_fixture(context):
    shutil.copy(AGENT / "tests/fixtures/agent_fixture.pvs", context)


@pytest.mark.parametrize(
    ("file_name", "action", "seed"),
    [
        ("agent_fixture.prf", "create", False),
        ("agent_fixture.prf", "modify", True),
        ("agent_fixture.prf", "delete", True),
        (".pvscontext", "modify", True),
        (".pvscontext", "delete", True),
    ],
)
def test_external_persistence_changes_are_rejected(tmp_path, file_name, action, seed):
    copy_fixture(tmp_path)
    source_before = (tmp_path / "agent_fixture.pvs").read_bytes()

    async def scenario():
        client = PVSClient(library_path="")
        try:
            await client.start(str(tmp_path), "agent_fixture", timeout=30)
            if seed:
                first = await prove(client, tmp_path)
                await client.save(formula(tmp_path), first)
            sid = await prove(client, tmp_path)
            before_default = await selected(client, sid)
            assert before_default != sid
            path = tmp_path / file_name
            if action == "create":
                assert not path.exists()
                path.write_text("; externally created proof file\n")
            elif action == "modify":
                original_stat = path.stat()
                path.write_bytes(path.read_bytes() + b"\n; external edit with preserved timestamp\n")
                os.utime(path, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
            else:
                path.unlink()
            external_bytes = path.read_bytes() if path.exists() else None
            with pytest.raises(RPCError, match="Persistence file changed"):
                await client.save(formula(tmp_path), sid)
            assert await selected(client, sid) == before_default
            assert (path.read_bytes() if path.exists() else None) == external_bytes
            assert (tmp_path / "agent_fixture.pvs").read_bytes() == source_before
            # Re-preparation cannot bless new disk bytes while retaining the
            # stale cached proof objects. A fresh process must restore them.
            with pytest.raises(RPCError, match="Persistence file changed"):
                await client.prepare(str(tmp_path), "agent_fixture")
        finally:
            await client.close()

    asyncio.run(asyncio.wait_for(scenario(), 45))


def test_own_saves_refresh_baselines_and_keep_unrelated_proofs(tmp_path):
    copy_fixture(tmp_path)

    async def scenario():
        client = PVSClient(library_path="")
        try:
            await client.start(str(tmp_path), "agent_fixture", timeout=30)
            left = await prove(client, tmp_path, "left_bound")
            await client.save(formula(tmp_path), left)
            right = await prove(client, tmp_path, "right_bound")
            await client.save(formula(tmp_path, "right_bound"), right)
            # A third save also exercises refreshed .pvscontext and .prf state.
            await client.save(formula(tmp_path), left)
            records = await client.require_control().call(
                "agent-proof-records", [formula(tmp_path, "right_bound")]
            )
            assert any(row["id"] == right and row["is-default"] == "yes" for row in records)
            saved = (tmp_path / "agent_fixture.prf").read_text()
            assert left in saved and right in saved
        finally:
            await client.close()

    asyncio.run(asyncio.wait_for(scenario(), 45))


def test_failed_prepare_does_not_reuse_previous_save_baseline(tmp_path):
    copy_fixture(tmp_path)

    async def scenario():
        client = PVSClient(library_path="")
        try:
            await client.start(str(tmp_path), "agent_fixture", timeout=30)
            sid = await prove(client, tmp_path)
            with pytest.raises(RPCError):
                await client.prepare(str(tmp_path), "missing_file")
            with pytest.raises(RPCError, match="preparation failed"):
                await client.save(formula(tmp_path), sid)
            assert not (tmp_path / "agent_fixture.prf").exists()
            # A corrected preparation restores readiness when disk proofs have
            # not changed; a failed attempt does not permanently poison it.
            await client.prepare(str(tmp_path), "agent_fixture")
            await client.save(formula(tmp_path), sid)
        finally:
            await client.close()

    asyncio.run(asyncio.wait_for(scenario(), 45))
