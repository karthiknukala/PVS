"""Local, read-only proof tree. Browsers never issue PVS requests or own cursors."""
from __future__ import annotations
import asyncio
from collections import OrderedDict, deque
import contextlib
import json
from pathlib import Path
import secrets
import sys
import time
import webbrowser

ASSETS = Path(__file__).with_name('web')
if not ASSETS.is_dir():
    ASSETS = Path(sys.prefix) / 'share' / 'pvs-agent' / 'web'


class ProofObserver:
    def __init__(self, client, max_nodes=6000, max_bytes=24*1024*1024):
        self.client = client
        self.max_nodes = max_nodes
        self.max_bytes = max_bytes
        self.node_bytes = 0
        self.sizes = {}
        self.annotations = {}
        self.event_bytes = 0
        self.nodes = OrderedDict()
        self.sessions = {}
        self.strategies = []
        self.sequence = 0
        self.events = deque()
        self.changed = asyncio.Event()
        self.gaps = 0
        self.connections = set()
        self.server = None
        self.poller = None
        self.rpc = None
        self.token = secrets.token_urlsafe(24)
        self.url = None
        self.opened = False
        self.closed = False
        self.capture_error = None
        self.connection_error = None
        self.last_inventory = 0
        self.worker_id = None
        self.owner_worker_id = None
        self.worker_generation = 0
        self.worker_url = client.url if client else None
        self.accept_local_sessions = True
        self.buffer_supported = False
        self.buffer_revision = 0
        self.buffers = {}
        self.connection_state = 'connecting' 

    def emit(self, kind, value):
        self.sequence += 1
        payload = json.dumps({'kind': kind, 'value': value}, separators=(',', ':'))
        self.events.append((self.sequence, payload))
        self.event_bytes += len(payload)
        while len(self.events) > 1024 or (self.event_bytes > 8*1024*1024 and len(self.events) > 1):
            self.event_bytes -= len(self.events.popleft()[1])
        self.changed.set()

    def owns_session(self, sid):
        return self.accept_local_sessions and self.client is not None and sid in self.client.sessions

    def session(self, session, **extra):
        if not self.accept_local_sessions:
            return  # Never mix a dead command client's IDs into its replacement.
        state = self.client.state(session)
        fields = ('session_id', 'generation', 'revision', 'kind', 'running', 'uncertain',
                  'error', 'closed', 'proof_result', 'label', 'observer_id', 'proofstate_id')
        row = {**self.sessions.get(session.id, {}), **{k: state[k] for k in fields if k in state}, **extra}
        # Never ship giant legacy native renderings in browser lifecycle updates.
        row.pop('native', None)
        if session.kind == 'evaluator':
            native = session.latest if isinstance(session.latest, dict) else {}
            row['evaluation'] = {k: native.get(k) for k in ('inputExpr', 'pvsResult', 'errOut', 'tccMsg')}
        self.sessions[session.id] = row
        nid = row.get('observer_id')
        if session.kind == 'proof' and nid:
            key = session.id + ':' + nid
            if key not in self.nodes and state.get('sequent'):
                seq = state['sequent']
                self.ingest([{'session_id': session.id, 'id': nid, 'parent': None,
                              'label': row.get('label'), 'command': '', 'children': [],
                              'sequent': {side: [f.get('formula', '')[:2000] for f in seq.get(side, [])[:40]]
                                          for side in ('antecedents', 'succedents')}}])
            if 'command' in extra:
                self.annotations[key] = {'label': extra.get('command_label', ''), 'command': extra['command']}
        self.emit('session', row)

    def native_sessions(self, rows):
        """Discover other clients' native cursors without taking their claims."""
        for native in rows:
            sid = native['id']
            if self.owns_session(sid):
                continue  # The owner has richer labels, actor names and results.
            old = self.sessions.get(sid, {})
            row = {**old, 'session_id': sid,
                   'kind': 'evaluator' if native['kind'] in ('pvsio', 'evaluator') else 'proof',
                   'actor': old.get('actor', 'Native client'),
                   'running': native.get('state') in ('starting', 'queued', 'running', 'inspecting'),
                   'closed': native.get('state') in ('closed', 'failed', 'aborted'),
                   'proof_result': native.get('proofStatus'),
                   'proofstate_id': native.get('proofstateId'),
                   'error': native.get('error'), 'uncertain': False}
            if row != old:
                self.sessions[sid] = row
                self.emit('session', row)

    def connection_failure(self, error):
        self.connection_state = 'reconnecting'
        self.connection_error = str(error)
        for row in self.sessions.values():
            row.update(running=False, uncertain=True)
            self.emit('session', row)
        self.emit('connection', self.connection_status())

    def ingest(self, rows, dropped=0):
        if dropped:
            self.gaps += dropped
            self.emit('gap', self.gaps)
        for row in rows:
            if row['session_id'] not in self.sessions:
                self.sessions[row['session_id']] = {'session_id': row['session_id'], 'kind': 'proof',
                                                  'actor': 'Native client', 'running': True, 'closed': False}
                self.emit('session', self.sessions[row['session_id']])
            if row.get('kind') == 'cursor':
                session = self.sessions.get(row['session_id'])
                if session and (session.get('running') or self.client is None or not self.owns_session(row['session_id'])):
                    session['observer_id'] = row['id']
                    self.emit('session', session)
                continue
            key = row['session_id'] + ':' + row['id']
            old = self.nodes.get(key, {})
            edges = dict(old.get('edges', {}))
            annotation = self.annotations.get(key, {})
            for child in row.get('children', []):
                edges[child] = {'command': row.get('command', ''), 'label': annotation.get('label') or row.get('command_label')}
            for edge in edges.values():
                if edge.get('expansion'):
                    edge['label'] = annotation.get('label') or row.get('command_label') or edge.get('label')
            edges = dict(list(edges.items())[-128:])
            row = {**row, 'edges': edges, 'input_command': annotation.get('command'), 'command_label': annotation.get('label') or row.get('command_label')}
            self.node_bytes -= self.sizes.get(key, 0)
            self.sizes[key] = len(json.dumps(row))
            self.node_bytes += self.sizes[key]
            self.nodes[key] = row
            self.nodes.move_to_end(key)
            self.emit('node', row)
            if row.get('expansion') and row.get('parent'):
                parent_key = row['session_id'] + ':' + row['parent']
                parent = self.nodes.get(parent_key)
                if parent:
                    parent['edges'][row['id']] = {'command': parent.get('command', ''), 'expansion': True,
                                                'label': parent.get('command_label')}
                    self.node_bytes -= self.sizes[parent_key]
                    self.sizes[parent_key] = len(json.dumps(parent))
                    self.node_bytes += self.sizes[parent_key]
                    self.emit('node', parent)
            while len(self.nodes) > self.max_nodes or self.node_bytes > self.max_bytes:
                removed, _ = self.nodes.popitem(last=False)
                self.node_bytes -= self.sizes.pop(removed)
                self.annotations.pop(removed, None)
                self.gaps += 1
                self.emit('remove', {'key': removed, 'gaps': self.gaps})

    def snapshot(self):
        return {'sequence': self.sequence, 'sessions': list(self.sessions.values()),
                'nodes': list(self.nodes.values()), 'strategies': self.strategies,
                'gaps': self.gaps, 'closed': self.closed, 'capture_error': self.capture_error,
                'connection_error': self.connection_error, 'worker_url': self.worker_url,
                'connection': self.connection_status(), 'buffers': list(self.buffers.values())}

    def connection_status(self):
        return {'state': self.connection_state, 'error': self.connection_error,
                'worker_id': self.worker_id, 'generation': self.worker_generation,
                'buffers': self.buffer_supported}

    def ingest_buffers(self, rows):
        for row in rows:
            self.buffers[row['session_id']] = row
            self.emit('buffer', row)
        while len(self.buffers) > 128:
            self.buffers.pop(next(iter(self.buffers)))

    async def refresh_strategies(self):
        self.strategies = await asyncio.wait_for(self.rpc.call('agent-observer-strategies'), 3) or []
        self.emit('strategies', self.strategies)

    async def connect(self):
        from server import RPCConnection
        rpc = None
        try:
            # Only follow the configured endpoint, never scan for another worker.
            url = self.client.url
            rpc = await asyncio.wait_for(RPCConnection.open(url, lambda *_: None), 3)
            methods = await asyncio.wait_for(rpc.call('list-methods'), 3)
            if not {'agent-info', 'agent-observer-drain', 'agent-observer-enable'} <= set(methods):
                raise RuntimeError('The endpoint is not a compatible PVS worker')
            info = await asyncio.wait_for(rpc.call('agent-info'), 3)
            supported = 'agent-observer-state' in methods
            state = await asyncio.wait_for(rpc.call('agent-observer-state', [0]), 3) if supported else info
            # Legacy workers have no trustworthy identity: every reconnection
            # starts a fresh display generation instead of merging reused IDs.
            worker_id = state.get('worker_id') or info.get('worker_id') or 'legacy-' + secrets.token_hex(12)
            changed = worker_id != self.worker_id
            first = self.worker_id is None
            if changed:
                self.worker_generation += 1
                self.nodes.clear(); self.sessions.clear(); self.buffers.clear()
                self.sizes.clear(); self.annotations.clear()
                self.node_bytes = 0; self.gaps = 0; self.capture_error = None
                self.buffer_revision = 0
            self.worker_id = worker_id
            self.worker_url = url
            if first:
                self.owner_worker_id = worker_id
            self.accept_local_sessions = (self.owner_worker_id == worker_id or self.client.info.get('worker_id') == worker_id)
            self.buffer_supported = supported
            self.rpc = rpc
            await asyncio.wait_for(rpc.call('agent-observer-enable', [True]), 3)
            # Strategy inventories are global; only refresh at idle boundaries.
            if not any(n.get('state') in ('running', 'starting', 'queued', 'inspecting')
                       for n in state.get('sessions') or []):
                await self.refresh_strategies()
            elif changed:
                self.strategies = []
            self.native_sessions(state.get('sessions') or [])
            if self.accept_local_sessions:
                for session in self.client.sessions.values():
                    self.session(session)
            if supported:
                self.ingest_buffers(state.get('buffers') or [])
                self.buffer_revision = state['revision']
            self.connection_error = None
            self.connection_state = 'connected'
            # Keep the HTTP/SSE server and its URL alive; replace the snapshot
            # atomically on a new worker so old QEDs/IDs cannot masquerade as new.
            self.emit('snapshot', self.snapshot())
        except BaseException:
            if rpc:
                await rpc.close(timeout=1)
            self.rpc = None
            raise

    async def start(self, open_browser=False, port=0, token=None):
        if token is not None:
            self.token = token
        self.server = await asyncio.start_server(self.http, '127.0.0.1', port, limit=16384)
        self.port = self.server.sockets[0].getsockname()[1]
        self.url = f'http://127.0.0.1:{self.port}/{self.token}/'
        try:
            await self.connect()
        except Exception as error:
            self.connection_failure(str(error) or 'PVS is unavailable')
        self.poller = asyncio.create_task(self.poll())
        if open_browser:
            self.opened = True
            asyncio.create_task(self.open_browser())
        return self.url

    async def open_browser(self):
        try:
            await asyncio.to_thread(webbrowser.open, self.url)
        except Exception as error:
            self.emit('error', f'Browser launch failed: {error}')

    async def poll(self):
        delay = .25
        while not self.closed:
            try:
                if self.rpc is None:
                    await self.connect()
                batch = await asyncio.wait_for(self.rpc.call('agent-observer-drain'), 3)
                self.ingest(batch.get('nodes') or [], batch.get('dropped') or 0)
                if batch.get('error'):
                    self.capture_error = batch['error']
                    self.emit('error', 'Snapshot capture: ' + self.capture_error)
                if self.buffer_supported:
                    state = await asyncio.wait_for(self.rpc.call('agent-observer-state', [self.buffer_revision]), 3)
                    self.native_sessions(state.get('sessions') or [])
                    self.ingest_buffers(state.get('buffers') or [])
                    self.buffer_revision = state['revision']
                elif time.monotonic() - self.last_inventory >= 1:
                    info = await asyncio.wait_for(self.rpc.call('agent-info'), 3)
                    self.native_sessions(info.get('sessions') or [])
                    self.last_inventory = time.monotonic()
                delay = .25
                await asyncio.sleep(.1 if any(s.get('running') for s in self.sessions.values()) else .4)
            except asyncio.CancelledError:
                raise
            except Exception as error:
                if not self.connection_error:
                    self.connection_failure(str(error) or 'PVS observer request timed out')
                if self.rpc:
                    await self.rpc.close(timeout=1)
                    self.rpc = None
                await asyncio.sleep(delay)
                delay = min(5, delay * 2)

    async def http(self, reader, writer):
        self.connections.add(writer)
        try:
            request = await asyncio.wait_for(reader.readuntil(b'\r\n\r\n'), 3)
            lines = request.decode('latin1').split('\r\n')
            method, target, _ = lines[0].split(' ', 2)
            headers = dict(line.lower().split(':', 1) for line in lines[1:] if ':' in line)
            if (method != 'GET' or headers.get('host', '').strip() != f'127.0.0.1:{self.port}'
                    or not target.startswith('/' + self.token + '/')):
                await self.reply(writer, 403, b'Forbidden', 'text/plain'); return
            route = target.split('?', 1)[0][len(self.token) + 2:]
            if route == 'events':
                writer.write(b'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n')
                cursor = int(headers.get('last-event-id', '0').strip() or '0')
                if not cursor or cursor > self.sequence or (self.events and cursor < self.events[0][0] - 1):
                    writer.write(f'id: {self.sequence}\ndata: {json.dumps({"kind": "snapshot", "value": self.snapshot()})}\n\n'.encode())
                    cursor = self.sequence
                while not self.closed:
                    self.changed.clear()
                    if self.events and cursor < self.events[0][0] - 1:
                        payload = {'kind': 'snapshot', 'value': self.snapshot()}
                        writer.write(f'id: {self.sequence}\ndata: {json.dumps(payload)}\n\n'.encode())
                        cursor = self.sequence
                    else:
                        for sequence, event in list(self.events):
                            if sequence > cursor:
                                writer.write(f'id: {sequence}\ndata: {event}\n\n'.encode())
                                cursor = sequence
                    await asyncio.wait_for(writer.drain(), 2)
                    try: await asyncio.wait_for(self.changed.wait(), 10)
                    except asyncio.TimeoutError: writer.write(b': alive\n\n')
                return
            if route == 'snapshot':
                await self.reply(writer, 200, json.dumps(self.snapshot()).encode(), 'application/json'); return
            files = {'': ('index.html', 'text/html'), 'app.js': ('app.js', 'text/javascript'),
                     'style.css': ('style.css', 'text/css')}
            if route not in files:
                await self.reply(writer, 404, b'Not found', 'text/plain'); return
            name, mime = files[route]
            await self.reply(writer, 200, (ASSETS / name).read_bytes(), mime)
        except (ValueError, asyncio.TimeoutError, ConnectionError, asyncio.IncompleteReadError, asyncio.LimitOverrunError):
            pass
        finally:
            self.connections.discard(writer)
            writer.close()
            with contextlib.suppress(Exception): await writer.wait_closed()

    async def reply(self, writer, status, body, mime):
        writer.write((f'HTTP/1.1 {status} OK\r\nContent-Type: {mime}; charset=utf-8\r\nContent-Length: {len(body)}\r\n'
                      "Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n"
                      "Content-Security-Policy: default-src 'self'; frame-ancestors 'none'; object-src 'none'\r\n"
                      'Connection: close\r\n\r\n').encode() + body)
        await asyncio.wait_for(writer.drain(), 2)

    async def close(self):
        self.closed = True
        self.changed.set()
        if self.poller:
            self.poller.cancel()
            with contextlib.suppress(asyncio.CancelledError): await self.poller
        if self.rpc:
            await self.rpc.close()
        if self.server:
            self.server.close(); await self.server.wait_closed()
        for writer in list(self.connections): writer.close()
