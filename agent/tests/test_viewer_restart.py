"""Persistent viewer, distinct PVS generations, native per-thread text capture."""
import asyncio
import json
import shutil
from pathlib import Path
from urllib.parse import urlsplit

from test_observer import AGENT, get
from server import PVSClient

async def until(predicate, timeout=12):
    async with asyncio.timeout(timeout):
        while not predicate():
            await asyncio.sleep(.05)


def test_same_worker_reconnect_and_replacement_keep_viewer_url(tmp_path):
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs', tmp_path)
    formula=f'{tmp_path}/agent_fixture.pvs#agent_fixture#branching'
    async def run():
        owner=PVSClient()
        view=PVSClient(observer_mode='headless')
        replacement=None
        try:
            await owner.start(str(tmp_path), 'agent_fixture')
            first=(await owner.proof_open(formula))['session_id']
            await view.start(url=owner.url)
            o=view.observer
            url=o.url
            generation=o.worker_generation
            identity=o.worker_id
            await owner.command(first,'(skosimp*)')
            await owner.command(first,'(split)')
            await until(lambda: first in o.buffers and 'x!1' in o.buffers[first]['sequent'])
            old_nodes=set(o.nodes)
            assert old_nodes
            old_rpc=o.rpc
            await old_rpc.close()
            await until(lambda: o.rpc is not None and o.rpc is not old_rpc and o.connection_state=='connected')
            assert o.worker_id==identity and o.worker_generation==generation
            assert old_nodes <= set(o.nodes)
            assert o.url==url
            # The HTTP server remains alive during an actual worker outage.
            port=urlsplit(owner.url).port
            await owner.close()
            await until(lambda:o.connection_state=='reconnecting')
            assert b'200' in (await get(url+'snapshot'))[0]
            snapshot=json.loads((await get(url+'snapshot'))[1])
            assert snapshot['connection']['state']=='reconnecting'
            replacement=PVSClient(port=port)
            await replacement.start(str(tmp_path),'agent_fixture')
            await until(lambda:o.worker_id!=identity and o.connection_state=='connected')
            assert o.url==url and o.worker_generation==generation+1
            assert not o.nodes and not o.buffers and not o.sessions
            again=(await replacement.proof_open(formula))['session_id']
            assert again==first  # Native IDs are reused; generations must not mix.
            await replacement.command(again,'(grind)')
            await until(lambda: o.buffers.get(again,{}).get('status')=='proved')
            assert o.sessions[again]['proof_result']=='proved'
            assert o.buffers[again]['command']=='(grind)'
            assert '(split)' not in o.buffers[again]['transcript']
            assert 'Q.E.D.' in o.buffers[again]['output']
            assert json.loads((await get(url+'snapshot'))[1])['connection']['generation']==generation+1
        finally:
            await view.close()
            await owner.close()
            if replacement: await replacement.close()
    asyncio.run(asyncio.wait_for(run(),50))


def test_native_thread_buffers_are_isolated_read_only_and_bounded(tmp_path):
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs', tmp_path)
    ref=lambda n:f'{tmp_path}/agent_fixture.pvs#agent_fixture#{n}'
    async def run():
        c=PVSClient()
        try:
            await c.start(str(tmp_path),'agent_fixture')
            a=(await c.proof_open(ref('branching')))['session_id']
            b=(await c.proof_open(ref('left_bound')))['session_id']
            ev=(await c.evaluator_open(f'{tmp_path}/agent_fixture.pvs#agent_fixture'))['session_id']
            await c.evaluator_prepare(ev,'inc(41)')
            await asyncio.gather(c.command(a,'(lisp (session-output "ONLY-THREAD-A"))'),
                                 c.command(b,'(lisp (session-output "ONLY-THREAD-B"))'),
                                 c.evaluate(ev,'inc(41)'))
            snapshot=await c.require_control().call('agent-observer-state',[0])
            rows={r['session_id']:r for r in snapshot['buffers']}
            assert 'ONLY-THREAD-A' in rows[a]['output'] and 'ONLY-THREAD-B' not in rows[a]['output']
            assert 'ONLY-THREAD-B' in rows[b]['output'] and 'ONLY-THREAD-A' not in rows[b]['output']
            assert '42' in rows[ev]['output'] and rows[ev]['command']=='inc(41)'
            assert 'FORALL' in rows[a]['sequent'] and '|-------' in rows[a]['sequent']
            revision=(await c.inspect(a))['revision']
            await c.inspect(a,'tree')
            unchanged=await c.require_control().call('agent-observer-state',[snapshot['revision']])
            assert not unchanged['buffers']
            assert (await c.inspect(a))['revision']==revision
            await c.command(a,'(skosimp*)')
            before=await c.require_control().call('agent-observer-state',[0])
            before=next(r for r in before['buffers'] if r['session_id']==a)['sequent']
            await c.command(a,'(split)')
            await c.command(a,'(undo)')
            after=await c.require_control().call('agent-observer-state',[0])
            row=next(r for r in after['buffers'] if r['session_id']==a)
            assert row['sequent']==before
            assert row['command']=='(undo)'
            await c.command(a,'(agent-no-such-rule)')
            error_rows=(await c.require_control().call('agent-observer-state',[0]))['buffers']
            assert 'AGENT-NO-SUCH-RULE' in next(r for r in error_rows if r['session_id']==a)['output'].upper()
            await c.command(a,r'(lisp (session-output (make-string 100000 :initial-element #\x)))')
            rows=(await c.require_control().call('agent-observer-state',[0]))['buffers']
            row=next(r for r in rows if r['session_id']==a)
            assert row['truncated'] and len(row['transcript'])<=65536 and len(row['output'])<=32768
            await c.command(a,'(lisp (loop))', wait=.01, time_limit=0)
            running=(await c.require_control().call('agent-observer-state',[0]))['buffers']
            assert next(r for r in running if r['session_id']==a)['status']=='running'
            await c.recover(a)
            recovered=(await c.require_control().call('agent-observer-state',[0]))['buffers']
            assert next(r for r in recovered if r['session_id']==a)['status']=='interrupted'
        finally: await c.close()
    asyncio.run(asyncio.wait_for(run(),45))
