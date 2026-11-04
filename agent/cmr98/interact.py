"""Compact CLI over the existing PVS WebSocket; never starts/stops PVS.
Usage: interact.py URL METHOD JSON_PARAMS. Native IDs survive reconnection.
"""
import asyncio, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import RPCConnection
async def main():
    c = await RPCConnection.open(sys.argv[1], lambda *args: None)
    try:
        result = await c.call(sys.argv[2], json.loads(sys.argv[3]))
        def compact(value):
            if isinstance(value,dict):
                return {k:compact(v) for k,v in value.items() if k not in ('names-info',)}
            if isinstance(value,list): return [compact(v) for v in value]
            return value
        result=compact(result)
        if sys.argv[2] in ('proof-command', 'prove-formula'):
            rows = result if isinstance(result, list) else [result]
            print(json.dumps([{k:v for k,v in row.items() if k in
                ('id','label','status','commentary','sequent','error')}
                for row in rows], default=str))
        else:
            print(json.dumps(result, default=str))
    finally:
        await c.close()
asyncio.run(main())
