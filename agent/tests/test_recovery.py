"""Recovery through native restore, with real concurrent workers and durable evidence."""
import asyncio
import json
import sys
from pathlib import Path

import pytest
from test_sessions import context, ref, start, settle
from server import PVSClient, Session, ConnectionLost


def test_restore_loops_debugger_branches_parallel_and_replay(context):
    source = context / 'agent_fixture.pvs'
    source.write_text(source.read_text().replace('END agent_fixture', '''
 six_branches: THEOREM FORALL (x:nat):
   x+1>x AND x+2>x AND x+3>x AND x+4>x AND x+5>x AND x+6>x
END agent_fixture'''))
    async def scenario():
        c = await start(context)
        try:
            a = (await c.proof_open(ref(context, 'six_branches')))['session_id']
            b = (await c.proof_open(ref(context, 'left_bound')))['session_id']
            ev = (await c.evaluator_open(f'{context}/agent_fixture.pvs#agent_fixture'))['session_id']
            await c.evaluator_prepare(ev, 'inc(41)')
            await c.command(a, '(skolem!)')
            branches = await c.command(a, '(split)')
            assert branches['open_goals'] == 6
            baseline = await c.command(a, '(grind)')
            assert baseline['open_goals'] == 5
            generation = c.generation
            for _ in range(3):
                await c.command(a, '(lisp (loop))', wait=.01, time_limit=0)
                other, evaluated, recovered = await asyncio.gather(
                    c.command(b, '(lisp (sleep .2))'),
                    c.evaluate(ev, 'inc(41)'), c.recover(a))
                assert evaluated['native']['pvsResult'] == '42'
                assert recovered['status'] == 'restored', recovered
                assert recovered['state']['open_goals'] == 5
                assert recovered['state']['sequent'] == baseline['sequent']
                assert c.generation == generation
            debugger = await c.command(a, '(lisp (break "recovery-test"))')
            assert debugger['outcome'] == 'interrupted', debugger
            assert 'recovery-test' in debugger['recovery_note']
            # A deadline must restore native state, not just cancel a Python wait.
            await c.command(a, '(lisp (loop))', wait=.01, time_limit=.2)
            timed = await settle(c, a, 5)
            assert timed['outcome'] == 'interrupted'
            assert timed['open_goals'] == 5
            for expression in ('(loop)', '(break "evaluator recovery")'):
                await c._command(ev, 'evaluator', 'pvsio-eval',
                                 [ev, expression, 'lisp'], .01, None, time_limit=.2)
                evstate = await settle(c, ev, 5)
                assert 'interrupted' in evstate['native']['errOut']
                assert (await c.evaluate(ev, 'inc(41)'))['native']['pvsResult'] == '42'
            # A completed watchdog must never interrupt the following command.
            await c.command(b, '(skip)', time_limit=.1)
            await c.command(b, '(lisp (sleep .25))', time_limit=0)
            assert (await c.inspect(b))['outcome'] != 'interrupted'
            # The recovered partial proof can be persisted without claiming QED.
            await c.close_session(a)
            await c.save(ref(context, 'six_branches'), a)
            assert (context / 'agent_fixture.prf').exists()
            a2 = (await c.proof_open(ref(context, 'six_branches')))['session_id']
            await c.command(a2, '(grind)')
            await c.command(b, '(grind)')
            await c.save(ref(context, 'six_branches'), a2)
            assert (await c.verify(ref(context, 'six_branches')))['native']['verified']
            folder = c.recovery_dir
        finally:
            await c.close()
        assert folder.exists()
        checkpoint = json.loads((folder/'checkpoint.json').read_text())
        assert checkpoint['sessions']
        events = [json.loads(line) for line in (context/'agent-test-transcript.jsonl').read_text().splitlines()]
        assert any(e['kind'] == 'command_deadline' for e in events)
    asyncio.run(asyncio.wait_for(scenario(), 60))


def test_unresponsive_interrupt_is_bounded_and_blocks_late_commands():
    class Stalled:
        async def call(self, *args):
            await asyncio.Future()
    async def scenario():
        c = PVSClient()
        c.control = Stalled()
        s = Session('stuck', 'proof', c.control)
        c.sessions[s.id] = s
        s.pending = asyncio.create_task(asyncio.sleep(60))
        result = await c.recover(s.id, wait=.02)
        assert result['status'] == 'unresponsive'
        assert s.uncertain and not result['restored']
        s.pending.cancel()
        with pytest.raises(asyncio.CancelledError): await s.pending
        with pytest.raises(Exception, match='unknown'):
            await c.command(s.id, '(grind)')
    asyncio.run(scenario())


def test_fatal_prompt_without_newline_preserves_evidence(tmp_path):
    async def scenario():
        c = PVSClient(loader=tmp_path/'load.lisp')
        c.begin_journal()
        class Conn:
            pending = {}
        c.control = Conn()
        future = asyncio.get_running_loop().create_future()
        c.control.pending = {'command': future}
        c.sessions['a'] = Session('a', 'proof', c.control, {'last': 'acknowledged'})
        c.process_output('fatal error encountered in S')
        assert c.runtime_failure is None
        c.process_output('BCL pid 123: memory fault\nldb> ')
        with pytest.raises(ConnectionLost): await future
        result = await c.recover('a')
        assert result['status'] == 'runtime_failed'
        assert result['state']['uncertain']
        assert json.loads((c.recovery_dir/'checkpoint.json').read_text())['runtime_failure']
        with pytest.raises(ConnectionLost): c.require_control()
    asyncio.run(scenario())


def test_process_exit_unblocks_pending_command_and_health(context):
    async def scenario():
        c = await start(context)
        try:
            sid = (await c.proof_open(ref(context, 'branching')))['session_id']
            with pytest.raises(ConnectionLost):
                await c.command(sid, '(lisp (uiop:quit 42))', wait=5)
            for _ in range(20):
                health = await c.inspect(kind='health')
                if health['status'] == 'runtime_failed': break
                await asyncio.sleep(.05)
            assert health['status'] == 'runtime_failed'
            assert (await c.recover(sid))['status'] == 'runtime_failed'
            assert (await c.list_sessions())['health']['status'] == 'runtime_failed'
            checkpoint = json.loads((c.recovery_dir/'checkpoint.json').read_text())
            assert checkpoint['sessions'][0]['sequent']
            assert checkpoint['sessions'][0]['in_flight_command'] == '(lisp (uiop:quit 42))'
        finally:
            await c.close()
    asyncio.run(asyncio.wait_for(scenario(), 25))


def test_recovery_deadline_includes_setup_admission():
    async def scenario():
        c = PVSClient()
        s = Session('waiting', 'proof', None)
        c.sessions[s.id] = s
        s.pending = asyncio.create_task(asyncio.sleep(60))
        async with c.setup_lock:
            result = await asyncio.wait_for(c.recover(s.id, wait=.02), .5)
            assert result['status'] == 'pending' and not result['requested']
            assert not s.uncertain
        s.pending.cancel()
        with pytest.raises(asyncio.CancelledError): await s.pending
    asyncio.run(scenario())


def test_recover_closed_proof_does_not_change_proved_status():
    async def scenario():
        c = PVSClient()
        s = Session('proved', 'proof', None, closed=True, proof_result='proved')
        c.sessions[s.id] = s
        result = await c.recover(s.id)
        assert result['status'] == 'idle'
        assert result['state']['proof_result'] == 'proved'
        assert not s.uncertain
    asyncio.run(scenario())
