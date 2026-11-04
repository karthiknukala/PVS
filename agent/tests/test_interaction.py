"""End-to-end tests of compact public MCP interaction using the CMR development."""
import asyncio
import json
from pathlib import Path
import shutil
import sys
import time
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from test_mcp import call, registered_or_default_parameters
AGENT=Path(__file__).resolve().parents[1]


def test_cmr_compact_interaction(tmp_path):
    for name in ('cmr98_bv.pvs','cmr98_bv.prf','cmr98_examples.pvs','cmr98_examples.prf',
                 'pvs-strategies','cmr98_solver.lisp','cmr98_pvs.lisp'):
        shutil.copy(AGENT/'cmr98'/name,tmp_path/name)
    async def scenario():
        params=registered_or_default_parameters(command=sys.executable,args=[str(AGENT/'server.py'),'mcp'])
        async with stdio_client(params) as (r,w):
            async with ClientSession(r,w) as s:
                await s.initialize()
                start=await call(s,'pvs_start',context=str(tmp_path),file='cmr98_examples')
                assert start['info']['parallel_proofs'] and start['info']['parallel_evaluator']
                ref=lambda name:f'{tmp_path}/cmr98_examples.pvs#cmr98_examples#{name}'
                first=await call(s,'pvs_proof_open',formula=ref('false_equality'))
                second=await call(s,'pvs_proof_open',formula=ref('false_equality'))
                assert first['session_id']!=second['session_id'] # IDs must not collide with node IDs.
                assert first['open_goals']==1 and 'names-info' not in json.dumps(first)
                sid=first['session_id']
                batch=await call(s,'pvs_batch',session_id=sid,commands=['(skosimp*)','(case "x!1=bvec0[8]")'],expected_revision=0)
                state=batch['states'][-1]
                tree=await call(s,'pvs_inspect',session_id=sid,kind='tree',limit=10)
                assert tree['total']==state['open_goals']
                if tree['total']>1:
                    nav=await call(s,'pvs_navigate',session_id=sid,goal_id=tree['goals'][-1]['id'],expected_revision=state['revision'])
                    assert nav['label']==tree['goals'][-1]['label']
                # Typed data comes from the stored AST. Inspection doesn't advance revision.
                other=second['session_id']
                state=await call(s,'pvs_command',session_id=other,command='(skosimp*)')
                before=state['sequent']
                await call(s,'pvs_command',session_id=other,command='(hide 1)')
                state=await call(s,'pvs_command',session_id=other,command='(undo)')
                assert state['sequent']==before
                revision=state['revision']
                typed=await call(s,'pvs_expression',session_id=other,fnum=1,path=[0],expected_revision=revision)
                assert typed['type'] and typed['class']
                assert (await call(s,'pvs_inspect',session_id=other))['revision']==revision
                full=await call(s,'pvs_inspect',session_id=other,kind='full')
                assert 'names-info' in json.dumps(full)
                failure=await call(s,'pvs_batch',session_id=other,commands=['(agent-no-such-rule)','(quit)'],expected_revision=revision)
                assert failure['executed']==1 and failure['remaining']==1, failure
                assert not (await call(s,'pvs_inspect',session_id=other))['closed']
                await call(s,'pvs_close',session_id=sid)
                await call(s,'pvs_close',session_id=other)
                loaded=await call(s,'pvs_load_strategy',path=str(tmp_path/'pvs-strategies'))
                assert any(x['name']=='cmr98-bv' and x['fingerprint'] for x in loaded['definitions'])
                ev=await call(s,'pvs_evaluator_open',theory=f'{tmp_path}/cmr98_examples.pvs#cmr98_examples')
                expr='(bvec0[8] o bvec1[8])(0)'
                prep=await call(s,'pvs_evaluator_prepare',session_id=ev['session_id'],expression=expr)
                assert prep['prepared'] and not prep['executed']
                ids=[]
                for name in ('propagate','overlap'):
                    opened=await call(s,'pvs_proof_open',formula=ref(name));ids.append(opened['session_id'])
                for sid in ids:await call(s,'pvs_command',session_id=sid,command='(skosimp*)')
                plan=await call(s,'pvs_preview',session_id=ids[0],expected_revision=1)
                assert plan['obligations'] and plan['lemmas'] and not plan['trusted']
                assert (await call(s,'pvs_inspect',session_id=ids[0]))['revision']==1
                started=time.monotonic()
                outcomes=await asyncio.gather(
                    call(s,'pvs_command',session_id=ids[0],command=plan['script'],expected_revision=plan['revision'],wait=30),
                    call(s,'pvs_command',session_id=ids[1],command='(cmr98-bv$)',wait=30),
                    call(s,'pvs_evaluate',session_id=ev['session_id'],expression=expr,wait=30))
                parallel_seconds=time.monotonic()-started
                assert all(row['proof_result']=='proved' for row in outcomes[:2]),outcomes
                assert outcomes[2]['native']['pvsResult'].strip()=='TRUE'
                for name,sid in zip(('propagate','overlap'),ids):await call(s,'pvs_save',formula=ref(name),proof_id=sid)
                # The same managed worker/generation survives all interactions.
                assert (await call(s,'pvs_sessions'))['generation']==start['generation']
                await call(s,'pvs_close',session_id=ev['session_id'])
                replay=await call(s,'pvs_verify',formula=ref('propagate'),timeout=60)
                assert replay['native']['verified']
                print(json.dumps({'parallel_seconds':parallel_seconds,
                                  'compact_bytes':len(json.dumps(state)), 'full_bytes':len(json.dumps(full))}))
    asyncio.run(asyncio.wait_for(scenario(),120))


def test_render_failure_preserves_completion(tmp_path):
    sys.path.insert(0,str(AGENT))
    from server import PVSClient
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs',tmp_path/'agent_fixture.pvs')
    # Fault injection is installed at startup, before any native sessions.
    loader=tmp_path/'render-fault.lisp'
    loader.write_text(f'(load "{AGENT / "load.lisp"}")\n(in-package :pvs)\n'
                      '(let ((original (symbol-function \'agent-compact-state)))\n'
                      ' (setf (symbol-function \'agent-compact-state)\n'
                      '  (lambda (ps) (if (eq (status-flag ps) \'!)\n'
                      '   (error "injected render failure") (funcall original ps)))))\n')
    async def run():
        c=PVSClient(loader=loader)
        try:
            await c.start(str(tmp_path),'agent_fixture')
            opened=await c.proof_open(f'{tmp_path}/agent_fixture.pvs#agent_fixture#left_bound')
            state=await c.command(opened['session_id'],'(grind)')
            assert state['proof_result']=='proved' and state['closed']
            assert 'injected render failure' in state['render_error']
            assert state['outcome']=='proved' and not state['uncertain']
        finally:await c.close()
    asyncio.run(run())


def test_metatheory_saved_proofs_without_custom_strategies():
    sys.path.insert(0,str(AGENT/'cmr98'))
    from verify_metatheory import verify
    reports=asyncio.run(verify())
    assert sum(row['replayed'] for row in reports)==24
