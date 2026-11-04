"""Warm compact/native comparison in the same persistent PVS process.
Times are transport+native step+status wall time, not solver speedups.
"""
import asyncio, json, statistics, sys, tempfile, shutil, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from server import PVSClient
ROOT=Path(__file__).resolve().parent
async def main():
 with tempfile.TemporaryDirectory(prefix='cmr-bench-') as temp:
  for name in ('cmr98_bv.pvs','cmr98_bv.prf','cmr98_examples.pvs','cmr98_examples.prf'):
   shutil.copy(ROOT/name,Path(temp)/name)
  c=PVSClient()
  try:
   await c.start(temp,'cmr98_examples')
   pid=c.process.pid
   opened=await c.proof_open(f'{temp}/cmr98_examples.pvs#cmr98_examples#false_overlap')
   sid=opened['session_id']
   await c.command(sid,'(skosimp*)')
   report={}
   # Alternate order to reduce warm-cache bias.
   measurements={key:[] for key in ('compact','native')}
   for mode in ('compact','native','native','compact'):
    if mode=='compact': c.methods.add('agent-proof-step')
    else:c.methods.discard('agent-proof-step')
    for _ in range(10):
     started=time.perf_counter()
     await c.command(sid,'(skip)')
     milliseconds=1000*(time.perf_counter()-started)
     payload=len(json.dumps(c.session(sid).latest))
     measurements[mode].append((milliseconds,payload))
   for mode,rows in measurements.items():
    report[mode]={'median_ms':round(statistics.median(x[0] for x in rows),3),
                  'median_native_response_bytes':statistics.median(x[1] for x in rows),'samples':len(rows)}
   assert c.process.pid==pid
   print(json.dumps(report,indent=2))
  finally:await c.close()
if __name__=='__main__':asyncio.run(main())
