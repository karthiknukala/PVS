"""Real concurrent PVS observation; browsers never claim native proof cursors."""
import asyncio
import json
from pathlib import Path
import shutil
import sys
from urllib.parse import urlsplit

AGENT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(AGENT))
from server import PVSClient
from observer import ProofObserver

async def get(url, host=None):
    u = urlsplit(url)
    r, w = await asyncio.open_connection(u.hostname, u.port)
    w.write(f'GET {u.path} HTTP/1.1\r\nHost: {host or u.netloc}\r\n\r\n'.encode())
    await w.drain()
    data = await r.read()
    w.close(); await w.wait_closed()
    head, body = data.split(b'\r\n\r\n', 1)
    return head, body


def test_live_tree_concurrent_proofs_and_read_only_http(tmp_path, monkeypatch):
    for name in ('cmr98_bv.pvs','cmr98_bv.prf','cmr98_examples.pvs','cmr98_examples.prf',
                 'pvs-strategies','cmr98_solver.lisp','cmr98_pvs.lisp'):
        shutil.copy(AGENT/'cmr98'/name, tmp_path/name)
    opened = []
    monkeypatch.setattr('webbrowser.open', lambda url: opened.append(url))
    async def run():
        c = PVSClient(observer_mode='auto', library_path='')
        try:
            started = await c.start(str(tmp_path), 'cmr98_examples')
            assert started['dashboard']['url'] and c.observer
            url = c.observer.url
            assert await c.dashboard() == started['dashboard']
            ref = lambda n: f'{tmp_path}/cmr98_examples.pvs#cmr98_examples#{n}'
            ids = [(await c.proof_open(ref(n)))['session_id'] for n in ('propagate','overlap','false_equality')]
            assert all(c.observer.sessions[s].get('proofstate_id') for s in ids)
            assert len(c.observer.nodes) >= 3
            root_ids={s:c.observer.sessions[s]['observer_id'] for s in ids}
            root_sequents={s:c.observer.nodes[s+':'+root_ids[s]]['sequent'] for s in ids}
            await c.command(ids[2], '(skosimp*)')
            before = (await c.inspect(ids[2]))['sequent']
            await c.command(ids[2], '(case "x!1=bvec0[8]")')
            await c.command(ids[2], '(undo)')
            assert (await c.inspect(ids[2]))['sequent'] == before
            await asyncio.gather(*(c.command(s, '(cmr98-bv$)', wait=.01,
                                             label='Project equal columns', actor=f'Agent {i+1}')
                                   for i,s in enumerate(ids[:2])))
            # Browser snapshots never consume an agent's proof operation slot.
            for _ in range(4):
                head, body = await get(url+'snapshot')
                assert b'200' in head
                json.loads(body)
            for sid in ids[:2]:
                for _ in range(200):
                    state=await c.inspect(sid)
                    if not state['running']: break
                    await asyncio.sleep(.02)
                assert state['proof_result']=='proved', state
            await asyncio.sleep(.6)
            head, body = await get(url+'snapshot')
            view = json.loads(body)
            assert not view['capture_error'], view['capture_error']
            for sid in ids:
                current = c.observer.nodes[sid+':'+root_ids[sid]]['sequent']
                for side in ('antecedents', 'succedents'):
                    assert [' '.join(x.split()) for x in current[side]] == [' '.join(x.split()) for x in root_sequents[sid][side]]
            assert len({s['name'] for s in view['strategies']}) == len(view['strategies'])
            assert opened == [url], opened
            assert len(view['nodes']) > 20, view
            assert any(len(n['children']) > 1 for n in view['nodes'])
            assert any(n.get('expansion') and n.get('parent') for n in view['nodes'])
            assert all('sequent' in n for n in view['nodes'])
            assert any(n.get('command') for n in view['nodes'])
            assert any(e.get('label') == 'Project equal columns' for n in view['nodes'] for e in n['edges'].values())
            assert any(s['name']=='cmr98-bv' and s['doc'] for s in view['strategies'])
            assert any(s.get('command_label')=='Project equal columns' for s in view['sessions'])
            assert (await c.inspect(ids[2]))['proof_result']=='active'
            assert c.generation == started['generation']
            assert b'403' in (await get(url+'snapshot', host='attacker.invalid'))[0]
            assert b'404' in (await get(url+'../../server.py'))[0]
            # Native cursor revisions do not change as the viewer reads history.
            revision=(await c.inspect(ids[2]))['revision']
            await get(url); await get(url+'app.js'); await get(url+'snapshot')
            assert (await c.inspect(ids[2]))['revision']==revision
            # An SSE client can attach and disconnect without affecting PVS.
            u=urlsplit(url);r,w=await asyncio.open_connection(u.hostname,u.port,limit=32*1024*1024)
            w.write(f'GET {u.path}events HTTP/1.1\r\nHost: {u.netloc}\r\n\r\n'.encode());await w.drain()
            response=await asyncio.wait_for(r.readuntil(b'\n\n'),3)
            assert b'"kind": "snapshot"' in response
            w.close();await w.wait_closed()
            await c.command(ids[2], '(cmr98-bv$)')
            assert (await c.inspect(ids[2]))['proof_result']=='active'
        finally: await c.close()
    asyncio.run(asyncio.wait_for(run(),60))


def test_retention_is_bounded_and_gaps_are_explicit():
    observer=ProofObserver(None,max_nodes=3)
    for i in range(20):
        observer.ingest([{'session_id':'s','id':str(i),'children':[],'command':'skip','sequent':{}}])
    assert len(observer.nodes)==3 and observer.gaps==17
    assert any('remove' in event for _,event in observer.events)


def test_retention_limits_bytes_and_alternative_edges():
    observer=ProofObserver(None,max_bytes=1200)
    for i in range(20):
        observer.ingest([{'session_id':'s','id':str(i),'children':[],
                         'command':'skip','sequent':{'succedents':['x'*300]}}])
    assert observer.node_bytes <= 1200 and len(observer.nodes) < 20
    observer=ProofObserver(None)
    for i in range(150):
        observer.ingest([{'session_id':'s','id':'root','children':[str(i)],
                         'command':'case','sequent':{}}])
    assert len(observer.nodes['s:root']['edges']) == 128


def test_lazy_derived_steps_preserve_goals_undo_and_portable_replay(tmp_path):
    """Lazy display is backed by real APPLY boundaries and ordinary justifications."""
    for name in ('cmr98_bv.pvs', 'cmr98_bv.prf', 'cmr98_examples.pvs',
                 'cmr98_examples.prf', 'pvs-strategies', 'cmr98_solver.lisp', 'cmr98_pvs.lisp'):
        shutil.copy(AGENT/'cmr98'/name, tmp_path/name)
    definitions = tmp_path/'lazy-test.lisp'
    definitions.write_text('''(in-package :pvs)
(defstep/lazy lazy-test-split (formula) (case formula)
  "Explore both cases" "Splitting into cases")
(lazy-strategies lazy-test-split)
(lazy-strategies lazy-test-split)
''')
    async def run():
        c = PVSClient(observer_mode='headless', library_path='')
        ref = lambda base, name: f'{base}/cmr98_examples.pvs#cmr98_examples#{name}'
        try:
            await c.start(str(tmp_path), 'cmr98_examples')
            pid = c.process.pid
            await c.load_strategy(str(definitions))
            sid = (await c.proof_open(ref(tmp_path, 'false_equality')))['session_id']
            before = await c.command(sid, '(skosimp*)')
            split = await c.command(sid,
                '(lazy-step (lazy-test-split$ "x!1=bvec0[8]") "Explore zero")')
            assert split['open_goals'] == 2 and split['proof_result'] == 'active', split
            await asyncio.sleep(.6)
            # Internal branches exist but native result goals are direct children
            # of the boundary, so hiding implementation does not hide obligations.
            rows = [n for n in c.observer.nodes.values() if n['session_id'] == sid]
            boundary = next(n for n in rows if n['id'] == before['observer_id'])
            assert len(boundary['children']) == 2
            assert any(n.get('expansion') and n['parent'] == boundary['id'] for n in rows)
            undone = await c.command(sid, '(undo)')
            assert undone['sequent'] == before['sequent']
            await c.close_session(sid)
            ids = [(await c.proof_open(ref(tmp_path, n)))['session_id'] for n in ('overlap', 'multi')]
            results = await asyncio.gather(*(c.command(s, '(cmr98-bv$)', wait=30) for s in ids))
            assert all(r['proof_result'] == 'proved' for r in results), results
            await asyncio.sleep(.6)
            assert not c.observer.capture_error
            for sid in ids:
                root = c.observer.nodes[sid+':'+c.observer.sessions[sid]['observer_id']]
                assert any(e.get('expansion') for e in root['edges'].values())
                assert not root['children']  # implementation is not a remaining obligation
            for name, sid in zip(('overlap', 'multi'), ids):
                await c.save(ref(tmp_path, name), sid)
            assert c.process.pid == pid
        finally:
            await c.close()
        # Replay these newly saved proofs without the CMR planner or lazy test
        # definitions. This checks today's wrappers, not preexisting PRF files.
        replay = tmp_path/'replay'
        replay.mkdir()
        for name in ('cmr98_bv.pvs', 'cmr98_bv.prf', 'cmr98_examples.pvs', 'cmr98_examples.prf'):
            shutil.copy(tmp_path/name, replay/name)
        scripts = (replay/'cmr98_examples.prf').read_text().upper()
        assert '(RERUN' in scripts  # native expanded alternatives must survive saving
        v = PVSClient(library_path='')
        try:
            await v.start(str(replay), 'cmr98_examples')
            for name in ('overlap', 'multi'):
                result = await v.require_control().call('agent-verify', [ref(replay, name), 'declaration'])
                assert result['verified'] is True, result
        finally:
            await v.close()
    asyncio.run(asyncio.wait_for(run(), 90))


def test_observer_attached_to_external_client_and_persistent_disconnect(tmp_path):
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs', tmp_path)
    async def run():
        owner = PVSClient()
        viewer = PVSClient(observer_mode='headless')
        try:
            await owner.start(str(tmp_path), 'agent_fixture')
            sid = (await owner.proof_open(f'{tmp_path}/agent_fixture.pvs#agent_fixture#branching'))['session_id']
            await viewer.start(url=owner.url)
            observer = viewer.observer
            assert sid in observer.sessions
            assert sid not in viewer.sessions  # No command ownership was acquired.
            await owner.command(sid, '(skosimp*)')
            split = await owner.command(sid, '(split)')
            for _ in range(50):
                if any(len(n.get('children', [])) == 2 for n in observer.nodes.values()): break
                await asyncio.sleep(.05)
            assert any(len(n.get('children', [])) == 2 for n in observer.nodes.values())
            assert observer.sessions[sid].get('observer_id')
            await owner.command(sid, '(undo)')
            revision = (await owner.inspect(sid))['revision']
            await get(observer.url+'snapshot')
            assert (await owner.inspect(sid))['revision'] == revision
            # A fresh browser snapshot must retain the native disconnect error.
            await observer.rpc.close()
            for _ in range(50):
                if observer.connection_error: break
                await asyncio.sleep(.05)
            view = json.loads((await get(observer.url+'snapshot'))[1])
            assert view['connection_error']
            assert view['worker_url'] == owner.url
            assert view['sessions'][0]['uncertain']
            assert not view['sessions'][0]['running']
            await viewer.close()
            assert (await owner.inspect(sid))['proof_result'] == 'active'
            assert (await owner.command(sid, '(grind)'))['proof_result'] == 'proved'
        finally:
            await viewer.close()
            await owner.close()
    asyncio.run(asyncio.wait_for(run(), 35))
