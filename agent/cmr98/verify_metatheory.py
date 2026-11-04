"""Verify both saved metatheory theories using public MCP and isolated replay.
The proof development is retained in cmr98_metatheory.prf. This verifier copies
only the specification and proof file: no CMR Lisp or strategies are loaded.
"""
import asyncio, json, sys, tempfile, shutil
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT = Path(__file__).resolve().parent
async def call(session, name, **arguments):
 r=await session.call_tool(name,arguments)
 if r.isError: raise RuntimeError('\n'.join(x.text for x in r.content if x.type=='text'))
 value=r.structuredContent
 if value is None:
  rows=[]
  for x in r.content:
   if x.type=='text':
    try:rows.append(json.loads(x.text))
    except ValueError: rows.append(x.text)
  return rows[0] if len(rows)==1 else rows
 return value['result'] if set(value)=={'result'} else value
async def verify():
 with tempfile.TemporaryDirectory(prefix='cmr-meta-') as temp:
  context=Path(temp)
  for name in ('cmr98_metatheory.pvs','cmr98_metatheory.prf'):
   shutil.copy(ROOT/name,context/name)
  params=StdioServerParameters(command=sys.executable,args=[str(ROOT.parent/'server.py'),'mcp'])
  async with stdio_client(params) as (r,w):
   async with ClientSession(r,w) as session:
    await session.initialize()
    await call(session,'pvs_start',context=str(context),file='cmr98_metatheory')
    reports=[]
    for theory,lemma,count in (('cmr98_metatheory','canonical_complete',14),('cmr98_partition','solver_correct',10)):
     inventory=await call(session,'pvs_obligations',theory=f'{context}/cmr98_metatheory.pvs#{theory}')
     assert len(inventory)>=count and any(row['name']==lemma for row in inventory),inventory
     ref=f'{context}/cmr98_metatheory.pvs#{theory}#{lemma}'
     result=await call(session,'pvs_verify',formula=ref,scope='theory',timeout=120)
     assert result['native']['verified'] and len(result['native']['details'])==count,result
     reports.append({'theory':theory,'verified':True,'replayed':count})
    return reports
if __name__=='__main__': print(json.dumps(asyncio.run(verify()),indent=2))
