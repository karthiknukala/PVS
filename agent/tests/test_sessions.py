"""End-to-end tests against the real PVS executable, in disposable contexts."""
import asyncio
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import pytest

AGENT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AGENT))
from server import PVSClient, PVSError, RPCError

@pytest.fixture
def context(tmp_path):
    shutil.copy(AGENT / "tests/fixtures/agent_fixture.pvs", tmp_path)
    return tmp_path

def ref(context, name, theory="agent_fixture"):
    return f"{context / 'agent_fixture.pvs'}#{theory}#{name}"

async def start(context):
    client = PVSClient(library_path="")
    try:
        await client.start(str(context), "agent_fixture", timeout=30,
                           transcript=str(context / "agent-test-transcript.jsonl"))
        return client
    except BaseException:
        for event in client.events:
            if event["kind"] == "process":
                print(event["data"])
        raise

def native_text(value):
    return json.dumps(value).lower()

async def settle(client, sid, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        state = await client.inspect(sid)
        if not state["running"]:
            if state.get("error"):
                raise PVSError(state["error"])
            return state
        await asyncio.sleep(.05)
    raise AssertionError("operation failed to settle")

def test_interactive_navigation_strategy_and_fresh_replay(context):
    async def scenario():
        client = await start(context)
        try:
            state = await client.proof_open(ref(context, "branching"))
            sid = state["session_id"]
            await client.command(sid, "(skosimp*)")
            split = await client.command(sid, "(split)")
            first = split.get("label")
            second = await client.command(sid, "(postpone)")
            assert second.get("label") != first
            again = await client.command(sid, "(postpone)")
            assert again.get("label") == first
            hidden = await client.command(sid, "(hide 1)")
            assert len(hidden["sequent"]["succedents"]) < len(again["sequent"]["succedents"])
            undo = await client.command(sid, "(undo)")
            assert undo["sequent"] == again["sequent"]
            redo = await client.command(sid, "(undo undo)")
            assert redo["sequent"] == hidden["sequent"]
            await client.command(sid, "(undo)")
            # Inspection must not introduce a proof command/revision.
            before = await client.inspect(sid, "full")
            locals_ = await client.inspect(sid, "locals")
            after = await client.inspect(sid, "full")
            assert before == after
            assert locals_ and any(row["type"] == "nat" for row in locals_)
            bad = await client.command(sid, "(agent-no-such-rule)")
            assert "agent-no-such-rule" in native_text(await client.inspect(sid, "full"))
            strategy = context / "finish.lisp"
            strategy.write_text('(in-package :pvs)\n(defstep agent-finish () (grind) "Finish fixture" "Finishing")\n')
            await client.load_strategy(str(strategy))
            # This strategy closes all residual branches through native query.
            for _ in range(4):
                result = await client.command(sid, "(agent-finish)")
                if result.get("proof_result") == "proved":
                    break
            proof_list = await client.require_control().call("all-proofs-of-formula", [ref(context, "branching")])
            assert "proved" in native_text(proof_list)
            await client.save(ref(context, "branching"), sid)
            assert (context / "agent_fixture.prf").exists()
            verified = await client.verify(ref(context, "branching"))
            assert verified["native"]["verified"] is True, verified
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

@pytest.mark.parametrize("order", [(0, 1), (1, 0)])
def test_parallel_proof_records_and_false_goal(context, order):
    async def scenario():
        client = await start(context)
        try:
            for name in ("left_bound", "right_bound"):
                sid = (await client.proof_open(ref(context, name)))["session_id"]
                await client.command(sid, "(grind)")
                await client.save(ref(context, name), sid)
            formula = ref(context, "alternative")
            a = (await client.proof_open(formula))["session_id"]
            baseline = await client.require_control().call("agent-proof-records", [formula])
            default = next(row for row in baseline if row["is-default"] == "yes")
            b = (await client.proof_open(formula))["session_id"]
            false = (await client.proof_open(ref(context, "false_goal")))["session_id"]
            attempts = [(a, "left_bound"), (b, "right_bound")]
            for index in order:
                sid, lemma = attempts[index]
                result = await client.command(sid, f'(lemma "{lemma}")')
                if result.get("proof_result") != "proved":
                    await client.command(sid, "(grind)")
            false_result = await client.command(false, "(grind)")
            assert false_result.get("proof_result") != "proved"
            records = await client.require_control().call("agent-proof-records", [formula])
            rows = {row["id"]: row for row in records}
            assert rows[default["id"]] == default
            for sid, lemma in attempts:
                row = rows[sid]
                assert row["status"].lower() == "proved"
                assert row["is-default"] == "no"
                assert lemma in native_text(row["script"])
                dependencies = {dep["name"] for dep in row["dependencies"]}
                assert lemma in dependencies
                assert ({"left_bound", "right_bound"} - {lemma}).isdisjoint(dependencies)
            for sid in (a, b):
                await client.save(formula, sid)
                assert (await client.verify(formula))["native"]["verified"] is True
            await client.close_session(false)
            await client.save(ref(context, "false_goal"), false)
            rejected = await client.verify(ref(context, "false_goal"))
            assert rejected["native"]["verified"] is False
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

def test_evaluator_alongside_proofs_errors_tcc_and_lifecycle(context):
    async def scenario():
        client = await start(context)
        try:
            a = (await client.proof_open(ref(context, "branching")))["session_id"]
            b = (await client.proof_open(ref(context, "alternative")))["session_id"]
            ev = (await client.evaluator_open(f"{context / 'agent_fixture.pvs'}#agent_fixture"))["session_id"]
            valid = (await client.evaluate(ev, "inc(41)"))["native"]
            assert valid["pvsResult"].strip() == "42" and valid["errOut"] == ""
            invalid = (await client.evaluate(ev, "inc(-1)"))["native"]
            assert invalid["pvsResult"] == "" and invalid["tccMsg"]
            assert "unresolved TCCs" in invalid["errOut"]
            invalid_name = (await client.evaluate(ev, "missing_identifier(1)"))["native"]
            assert invalid_name["errOut"] and not invalid_name["pvsResult"]
            recovered = (await client.evaluate(ev, "inc(1)"))["native"]
            assert recovered["pvsResult"].strip() == "2" and recovered["errOut"] == ""
            await client.evaluate(ev, "inc(7)")  # prepare once at an idle boundary
            # Sleeping proof commands expose true overlap without CPU timing assumptions.
            begin = time.monotonic()
            await asyncio.gather(client.command(a, "(lisp (sleep 1))", wait=.1),
                                 client.command(b, "(lisp (sleep 1))", wait=.1))
            evaluated = await client.evaluate(ev, "inc(7)")
            assert evaluated["native"]["pvsResult"].strip() == "8"
            assert time.monotonic() - begin < 1.0, "evaluator waited for sleeping proofs"
            await asyncio.gather(settle(client, a), settle(client, b))
            await client.close_session(ev)
            with pytest.raises(RPCError):
                await client.require_control().call("pvsio-eval", [ev, "inc(2)", "pvs"])
            await client.command(a, "(grind)")
            await client.command(b, "(grind)")
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

def test_cancellation_stale_source_and_repeated_load(context):
    async def scenario():
        client = await start(context)
        try:
            a = (await client.proof_open(ref(context, "branching")))["session_id"]
            await client.command(a, "(lisp (sleep 10))", wait=.1)
            request = await client.interrupt(a)
            assert request["requested"]
            await settle(client, a, timeout=5)
            finished = await client.command(a, "(grind)")
            assert finished.get("proof_result") == "proved"
            records = await client.require_control().call("agent-proof-records", [ref(context, "branching")])
            assert next(row for row in records if row["id"] == a)["status"].lower() == "proved"
            # Re-loading the same extension is idempotent, not another wrapper.
            await client.require_control().call("lisp", [f'(load "{AGENT / "load.lisp"}")'])
            b = (await client.proof_open(ref(context, "false_goal")))["session_id"]
            source = context / "agent_fixture.pvs"
            source.write_text(source.read_text() + "\n% external change\n")
            with pytest.raises(RPCError, match="changed"):
                await client.command(b, "(grind)")
            await client.close_session(b)
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

def test_failed_strategy_load_can_retry(context):
    async def scenario():
        client = await start(context)
        try:
            sid = (await client.proof_open(ref(context, "branching")))["session_id"]
            strategy = context / "retry.lisp"
            strategy.write_text('(in-package :pvs)\n(error "deliberate load failure")\n')
            with pytest.raises(RPCError, match="deliberate"):
                await client.load_strategy(str(strategy))
            strategy.write_text('(in-package :pvs)\n(defstep retry-finish () (grind) "Finish" "Finishing")\n')
            await client.load_strategy(str(strategy))
            await client.command(sid, "(retry-finish)")
            await client.save(ref(context, "branching"), sid)
            assert (await client.verify(ref(context, "branching")))["native"]["verified"] is True
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

def test_session_contexts_implicit_load_gate_and_scope_verification(context):
    async def scenario():
        client = await start(context)
        try:
            a = (await client.proof_open(ref(context, "branching")))["session_id"]
            real_formula = ref(context, "real_bound", "agent_other")
            b = (await client.proof_open(real_formula))["session_id"]
            await client.command(a, "(skosimp*)")
            await client.command(b, "(skosimp*)")
            assert any(row["type"] == "nat" for row in await client.inspect(a, "locals"))
            assert any(row["type"] == "real" for row in await client.inspect(b, "locals"))
            before = await client.inspect(b, "full")
            await client.command(a, "(lisp (sleep 1))", wait=.1)
            assert await client.inspect(b, "locals")
            assert await client.inspect(b, "full") == before
            with pytest.raises(RPCError, match="idle"):
                await client.require_control().call("prove-formula", [ref(context, "alternative"), False])
            await settle(client, a)
            implicit = context / "pvs-strategies"
            implicit.write_text('(in-package :pvs)\n(error "implicit strategy failure")\n')
            stamp = implicit.stat().st_mtime
            with pytest.raises(RPCError, match="implicit strategy failure"):
                await client.proof_open(ref(context, "alternative"))
            implicit.write_text('(in-package :pvs)\n(defstep implicit-finish () (grind) "Finish" "Finishing")\n')
            os.utime(implicit, (stamp, stamp))
            c = (await client.proof_open(ref(context, "alternative")))["session_id"]
            assert (await client.command(c, "(implicit-finish)"))["proof_result"] == "proved"
            assert (await client.command(b, "(grind)"))["proof_result"] == "proved"
            await client.save(real_formula, b)
            for scope in ("theory", "importchain"):
                checked = await client.verify(real_formula, scope)
                assert checked["native"]["verified"] is True, checked
            await client.close_session(a)
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))

def test_evaluator_interrupt_and_proof_only_shutdown(context):
    async def scenario():
        client = await start(context)
        try:
            p = (await client.proof_open(ref(context, "branching")))["session_id"]
            ev = (await client.evaluator_open(f"{context / 'agent_fixture.pvs'}#agent_fixture"))["session_id"]
            assert (await client.evaluate(ev, "inc(1)"))["native"]["pvsResult"].strip() == "2"
            connection = client.session(ev).connection
            pending = asyncio.create_task(connection.call("pvsio-eval", [ev, "(sleep 10)", "lisp"]))
            await asyncio.sleep(.2)
            await client.interrupt(ev)
            interrupted = await asyncio.wait_for(pending, 5)
            assert "interrupted" in interrupted["errOut"].lower()
            assert (await client.evaluate(ev, "inc(1)"))["native"]["pvsResult"].strip() == "2"
            await client.require_control().call("quit-all-proof-sessions")
            assert (await client.evaluate(ev, "inc(1)"))["native"]["pvsResult"].strip() == "2"
            with pytest.raises(RPCError):
                await client.require_control().call("proof-command", [ev, "(grind)"])
            with pytest.raises(RPCError):
                await client.require_control().call("pvsio-eval", [p, "1", "pvs"])
            await client.close_session(ev)
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(scenario(), 60))
