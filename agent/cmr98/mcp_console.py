"""Persistent JSON-lines console over the actual public MCP stdio transport.
Input: {"tool": "pvs_start", "arguments": {...}}. EOF closes the server.
This is a development client, not an alternative PVS RPC or proof interface.
"""
import asyncio, json, sys
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    params = StdioServerParameters(command=sys.executable, args=[str(Path(__file__).resolve().parents[1] / 'server.py'), 'mcp'])
    async with stdio_client(params) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            print('MCP-CONSOLE-READY', flush=True)
            async def call(request):
                result = await session.call_tool(request['tool'], request.get('arguments', {}))
                value = result.structuredContent
                if value is None:
                    rows = []
                    for x in result.content:
                        if x.type == 'text':
                            try: rows.append(json.loads(x.text))
                            except ValueError: rows.append(x.text)
                    value = rows[0] if len(rows) == 1 else rows
                print(json.dumps({'tag':request.get('tag'), 'error':result.isError, 'result':value}),flush=True)
            while line := await asyncio.to_thread(sys.stdin.readline):
                try:
                    request=json.loads(line)
                    await asyncio.gather(*(call(r) for r in request)) if isinstance(request,list) else await call(request)
                except Exception as e: print(json.dumps({'error':str(e)}),flush=True)
asyncio.run(main())
