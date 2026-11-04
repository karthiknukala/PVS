"""Retain a native concurrent CMR failure for diagnosis; never retry commands.

Run from the repository: agent/.venv/bin/python agent/tests/stress_cmr.py
On failure in a terminal, JSON-lines operations inspect the still-live worker.
"""
import argparse
import asyncio
import json
from pathlib import Path
import shutil
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import PVSClient, json_repl

CMR = Path(__file__).resolve().parents[1] / 'cmr98'
NAMES = ('overlap', 'propagate', 'multi', 'crossing', 'nested', 'shared',
         'constants', 'conflict', 'false_equality', 'false_overlap')


async def settle(client, row):
    deadline = time.monotonic() + 90
    while row.get('running') and time.monotonic() < deadline:
        await asyncio.sleep(.1)
        row = await client.inspect(row['session_id'])
    return row


async def run(rounds, fanout, diagnose=False, viewer='off'):
    with tempfile.TemporaryDirectory(prefix='cmr-race-') as temp:
        context = Path(temp)
        for name in ('cmr98_bv.pvs', 'cmr98_bv.prf', 'cmr98_examples.pvs',
                     'cmr98_examples.prf', 'pvs-strategies', 'cmr98_solver.lisp',
                     'cmr98_pvs.lisp'):
            shutil.copy(CMR / name, context / name)
        loader = CMR.parent / 'load.lisp'
        if diagnose:
            loader = context / 'diagnostic-loader.lisp'
            loader.write_text(
                f'(load "{CMR.parent / "load.lisp"}")\n'
                f'(load "{CMR.parent / "tests/race-diagnostics.lisp"}")\n')
        client = PVSClient(loader=loader, library_path='', observer_mode=viewer)
        started = time.monotonic()
        try:
            await client.start(temp, 'cmr98_examples')
            pid = client.process.pid
            evaluator = (await client.evaluator_open(
                f'{temp}/cmr98_examples.pvs#cmr98_examples'))['session_id']
            expression = '(bvec0[8] o bvec1[8])(0)'
            await client.evaluator_prepare(evaluator, expression)
            print(json.dumps({'url': client.url, 'context': temp, 'pid': pid}), flush=True)
            for round_number in range(rounds):
                names = [NAMES[(round_number + j) % len(NAMES)] for j in range(fanout)]
                ids = []
                for name in names:
                    opened = await client.proof_open(
                        f'{temp}/cmr98_examples.pvs#cmr98_examples#{name}')
                    ids.append(opened['session_id'])

                async def prove(sid):
                    try:
                        return await client.command(sid, '(cmr98-bv$)', wait=60)
                    except Exception as error:
                        return {'session_id': sid, 'exception': str(error)}

                rows = await asyncio.gather(
                    *(prove(sid) for sid in ids),
                    client.evaluate(evaluator, expression, wait=60))
                rows = await asyncio.gather(*(settle(client, row) for row in rows))
                for name, row in zip(names, rows[:-1]):
                    expected = 'active' if name.startswith('false_') else 'proved'
                    # CMR can report a harmless "No suitable redexes" even at QED.
                    # Native hash/type/assertion failures are never harmless.
                    error = row.get('command_error') or ''
                    native_failure = any(fragment in error for fragment in (
                        'concurrent operations', 'Corrupt NEXT-chain', 'failed AVER',
                        'assertion', 'Incompatible types'))
                    if (row.get('proof_result') != expected or row.get('running')
                            or row.get('exception') or row.get('error') or native_failure):
                        dump = {'round': round_number, 'ids': ids, 'state': row,
                                'states': rows, 'events': client.events}
                        try:
                            dump['full'] = await client.inspect(row['session_id'], 'full')
                        except Exception as error:
                            dump['render_error'] = str(error)
                        diagnostic = Path('/tmp') / f'cmr-race-{pid}.json'
                        diagnostic.write_text(json.dumps(dump, indent=2))
                        print(json.dumps({'FAILURE': row, 'diagnostic': str(diagnostic),
                                          'url': client.url}), flush=True)
                        if sys.stdin.isatty():
                            await json_repl(client)
                        raise AssertionError(f'Concurrent proof failure; see {diagnostic}')
                assert not rows[-1].get('running'), rows[-1]
                assert rows[-1]['native']['pvsResult'].strip() == 'TRUE', rows[-1]
                assert client.process.pid == pid and client.process.returncode is None
                # Release native sockets before hitting the server connection limit.
                await asyncio.gather(*(client.close_session(sid) for sid in ids))
                print(json.dumps({'round': round_number + 1, 'checked': len(ids),
                                  'pid': pid}), flush=True)
            if client.observer:
                batch = await client.observer.rpc.call('agent-observer-drain')
                client.observer.ingest(batch.get('nodes') or [], batch.get('dropped') or 0)
                assert not batch.get('error'), batch.get('error')
                assert not client.observer.capture_error, client.observer.capture_error
                print(json.dumps({'observer_nodes': len(client.observer.nodes),
                                  'observer_gaps': client.observer.gaps}), flush=True)
            print(json.dumps({'result': 'STRESS PASSED', 'proof_attempts': rounds * fanout,
                              'evaluations': rounds, 'pid': pid,
                              'elapsed_seconds': round(time.monotonic() - started, 2)}), flush=True)
        finally:
            await client.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--rounds', type=int, default=100)
    parser.add_argument('--fanout', type=int, default=8)
    parser.add_argument('--diagnose', action='store_true')
    parser.add_argument('--viewer', choices=('headless', 'off'), default='off')
    args = parser.parse_args()
    if args.rounds < 1 or args.fanout < 2:
        parser.error('rounds must be positive and fanout at least two')
    asyncio.run(run(args.rounds, args.fanout, args.diagnose, args.viewer))
