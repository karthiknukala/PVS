"""Run CMR certificates on two native proof threads in an existing worker."""
import asyncio, json, sys, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from server import RPCConnection
ROOT=Path(__file__).resolve().parent
async def main():
 c=await RPCConnection.open(sys.argv[1],lambda *a:None)
 names=sys.argv[2:] or ['nested','shared','crossing','propagate','overlap','conflict','multi','constants','wide','false_equality','false_overlap']
 report=[]
 for start in range(0,len(names),2):
  work=[]
  for name in names[start:start+2]:
   conn=await RPCConnection.open(sys.argv[1],lambda *a:None)
   ref=f'{ROOT}/cmr98_examples.pvs#cmr98_examples#{name}'
   r=await conn.call('prove-formula',[ref,False]);work.append((name,ref,r[-1]['id'],conn))
  async def prove(item):
   name,ref,sid,conn=item;begin=time.monotonic()
   try:
    r=await asyncio.wait_for(conn.call('proof-command',[sid,'(cmr98-bv$)']),90)
   except Exception as exc:
    r=[{'response_error':str(exc)}]  # Never resend an uncertain command.
   status=(await conn.call('prover-status',[sid]))[0]['status']
   row={'name':name,'id':sid,'status':status,'seconds':round(time.monotonic()-begin,3)}
   if status!='proved':
    def compact(v):
     if isinstance(v,dict):return {k:compact(x) for k,x in v.items() if k not in ('names-info',)}
     if isinstance(v,list):return [compact(x) for x in v]
     return v
    row['residual']=compact(r[-1])
   return row
  rows=await asyncio.gather(*(prove(item) for item in work))
  for row,item in zip(rows,work):
   if row['status']=='proved':await c.call('agent-save',[item[1],item[2]])
   print(json.dumps({k:v for k,v in row.items() if k!='residual'}),flush=True)
   report.append(row);await item[3].close()
 (ROOT/'examples-results.json').write_text(json.dumps(report,indent=2))
 await c.close()
asyncio.run(main())
