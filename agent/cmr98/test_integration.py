"""Real PVS regression: certificates, concurrent sessions, and planner-free replay."""
import asyncio
import json
from pathlib import Path
import shutil
import sys
import time

ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent))
from server import PVSClient

POSITIVE=('identity','nested','shared','crossing','propagate','overlap',
          'conflict','multi','constants','wide')
NEGATIVE=('false_equality','false_overlap')

def copy_context(path, strategies):
    for name in ('cmr98_bv.pvs','cmr98_bv.prf','cmr98_examples.pvs','cmr98_examples.prf'):
        shutil.copy(ROOT/name,path/name)
    if strategies:
        for name in ('pvs-strategies','cmr98_solver.lisp','cmr98_pvs.lisp'):
            shutil.copy(ROOT/name,path/name)

def ref(path,name,theory='cmr98_examples'):
    return f'{path / (theory+".pvs")}#{theory}#{name}'

async def settled(client,sid):
    limit=time.monotonic()+60
    while time.monotonic()<limit:
        state=await client.inspect(sid)
        if not state['running']:
            assert not state.get('error'), state
            return state
        await asyncio.sleep(.05)
    raise AssertionError('PVS operation did not settle')

def test_parallel_certificates_and_live_reload(tmp_path):
    copy_context(tmp_path,True)
    async def run():
        client=PVSClient(library_path='')
        try:
            await client.start(str(tmp_path),'cmr98_examples',timeout=40)
            process=client.process.pid
            evaluator=(await client.evaluator_open(
                f'{tmp_path / "cmr98_examples.pvs"}#cmr98_examples'))['session_id']
            expression='(bvec0[8] o bvec1[8])(0)'
            value=await client.evaluate(evaluator,expression)
            assert value['native']['pvsResult'].strip()=='TRUE',value
            # Repeat different pairs: heavy AST parsing/projection + BDD work.
            for names in (POSITIVE, tuple(reversed(POSITIVE))):
                for at in range(0,len(names),2):
                    ids=[(await client.proof_open(ref(tmp_path,n)))['session_id']
                         for n in names[at:at+2]]
                    await asyncio.gather(*(client.command(s,'(cmr98-bv$)',wait=1) for s in ids),
                                         client.evaluate(evaluator,expression,wait=1))
                    value=await settled(client,evaluator)
                    assert value['native']['pvsResult'].strip()=='TRUE',value
                    for sid in ids:
                        state=await settled(client,sid)
                        if state.get('proof_result') != 'proved':
                            diagnostic = {'state': state, 'full': await client.inspect(sid, 'full')}
                            (tmp_path/'unfinished-concurrent-proof.json').write_text(json.dumps(diagnostic, indent=2))
                        assert state.get('proof_result')=='proved', json.dumps(state, indent=2)
                        text=json.dumps(state.get('native',state))
                        assert 'Corrupt NEXT-chain' not in text
                    assert client.process.pid==process and client.process.returncode is None
            # A retained cursor survives undo, strategy load, and another solver call.
            sid=(await client.proof_open(ref(tmp_path,'false_equality')))['session_id']
            await client.command(sid,'(skosimp*)')
            before=(await client.inspect(sid))['sequent']
            await client.command(sid,'(hide 1)')
            after=await client.command(sid,'(undo)')
            assert after['sequent']==before
            await client.load_strategy(str(tmp_path/'pvs-strategies'))
            await client.command(sid,'(cmr98-bv$)',wait=1)
            assert (await settled(client,sid)).get('proof_result')!='proved'
            await client.close_session(sid)
            sid=(await client.proof_open(ref(tmp_path,'false_overlap')))['session_id']
            await client.command(sid,'(skosimp*)')
            report=await client.command(sid,'(cmr98-solved-form$)')
            assert 'Candidate only' in json.dumps(report)
            assert 'SOLVED' in json.dumps(report)
            await client.command(sid,'(cmr98-bv$)',wait=1)
            assert (await settled(client,sid)).get('proof_result')!='proved'
            await client.close_session(sid)
            # A malicious candidate identity cannot close its checking branch.
            bad=tmp_path/'bad-certificate.lisp'
            bad.write_text('(in-package :pvs)\n'
                '(defstep cmr98-bad-certificate () '
                '(let ((script (cmr98-check-normalization "x!1=y!1"))) '
                '(then script (assert))) "Test rejected candidate" "Checking bad candidate")\n')
            await client.load_strategy(str(bad))
            sid=(await client.proof_open(ref(tmp_path,'false_equality')))['session_id']
            await client.command(sid,'(skosimp*)')
            await client.command(sid,'(cmr98-bad-certificate$)',wait=1)
            assert (await settled(client,sid)).get('proof_result')!='proved'
            assert client.process.pid==process
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(run(),180))

def test_saved_proofs_replay_without_cmr_lisp(tmp_path):
    copy_context(tmp_path,False)
    assert not list(tmp_path.glob('*.lisp'))
    assert not (tmp_path/'pvs-strategies').exists()
    # The generated example proofs must have expanded every custom strategy.
    scripts=(tmp_path/'cmr98_examples.prf').read_text().upper()
    assert '(CMR98-' not in scripts
    assert '.PROJECT_EQUAL' in scripts and '.CONSTANT_CONFLICT' in scripts
    async def run():
        client=PVSClient(library_path='')
        try:
            await client.start(str(tmp_path),'cmr98_examples',timeout=40)
            result=await client.require_control().call('agent-verify',[
                ref(tmp_path,'slice_point','cmr98_bv'),'theory'])
            assert result['verified'] is True, result
            for name in POSITIVE:
                result=await client.require_control().call('agent-verify',[ref(tmp_path,name),'declaration'])
                assert result['verified'] is True, (name,result)
            for name in NEGATIVE:
                result=await client.require_control().call('agent-verify',[ref(tmp_path,name),'declaration'])
                assert result['verified'] is not True, (name,result)
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(run(),180))
