"""Bounded recovery and durable evidence; never replay or restart implicitly."""
from __future__ import annotations
import asyncio
import contextlib
import json
import os
from pathlib import Path
import re
import tempfile
import time

FATAL = re.compile(r'fatal error encountered in SBCL|CORRUPTION WARNING|Welcome to LDB|ldb>', re.I)


class RecoveryMixin:
    def init_recovery(self):
        self.runtime_failure = None
        self.process_tail = ''
        self.recovery_dir = None
        self.journal_error = None
        self.stopping = False

    def begin_journal(self):
        # Separate from PVS's temporary directory: close/reconnect retains evidence.
        base = Path(os.environ.get('PVS_AGENT_RECOVERY_DIR', self.loader.parent / '.recovery'))
        base.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.recovery_dir = Path(tempfile.mkdtemp(prefix='worker-', dir=base))
        if not self.transcript_path:
            self.transcript_path = self.recovery_dir / 'events.jsonl'

    def checkpoint(self, settled=None):
        if self.recovery_dir is None:
            return
        data = {'format': 1, 'time': time.time(), 'url': self.url,
                'generation': self.generation, 'context': str(self.context),
                'runtime_failure': self.runtime_failure,
                'transcript': str(self.transcript_path),
                'note': 'Last acknowledged states and command journal; not a saved PVS proof or certificate. Never automatically replay an in-flight command.',
                'sessions': [{**self.state(s), 'formula': s.formula,
                              'in_flight_command': s.active_command} for s in self.sessions.values()]}
        for state in data['sessions']:
            if state['session_id'] == settled:
                state['running'] = False
        path = self.recovery_dir / 'checkpoint.json'
        tmp = path.with_suffix('.tmp')
        with tmp.open('w') as stream:
            json.dump(data, stream, ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        tmp.replace(path)

    def process_output(self, output):
        # Chunked reads also recognize an LDB prompt with no trailing newline.
        self.process_tail = (self.process_tail + output)[-16000:]
        if FATAL.search(self.process_tail):
            self.fail_runtime('SBCL reported a fatal runtime fault; Lisp restore is unavailable.')

    def fail_runtime(self, reason):
        if self.runtime_failure or self.stopping:
            return
        self.runtime_failure = reason
        for s in self.sessions.values():
            s.uncertain = True
            s.last_error = reason
        connections = {s.connection for s in self.sessions.values()}
        if self.control:
            connections.add(self.control)
        for conn in connections:
            for future in list(conn.pending.values()):
                if not future.done():
                    future.set_exception(self._connection_lost(reason))
        with contextlib.suppress(OSError):
            self.checkpoint()
        for s in self.sessions.values():
            self.observe(s, running=False)
        if self.observer:
            self.observer.emit('error', reason)

    def health(self, details=False):
        if self.process and self.process.returncode is not None:
            self.fail_runtime(f"PVS exited with status {self.process.returncode}.")
        return {'status': 'runtime_failed' if self.runtime_failure else 'unknown',
                'failure': self.runtime_failure,
                'process_exit_code': self.process.returncode if self.process else None,
                'recovery_dir': str(self.recovery_dir) if self.recovery_dir else None,
                'journal_error': self.journal_error,
                **({'process_tail': self.process_tail[-8000:]} if details else {}),
                'note': 'Cached runtime evidence; absence of a fault is not a liveness check.'}

    async def recover(self, session_id, wait=5):
        """Request native restore and wait boundedly for this command's reply."""
        if not 0 < wait <= 30:
            raise self._error('Recovery wait must be greater than zero and at most 30 seconds.')
        s = self.session(session_id)
        if self.runtime_failure:
            return {'status': 'runtime_failed', 'restored': False,
                    'state': self.state(s), 'health': self.health()}
        if s.closed:
            return {'status': 'idle', 'restored': False, 'state': self.state(s)}
        pending = s.pending
        if pending is None or pending.done():
            if s.uncertain:
                return {'status': 'uncertain', 'restored': False,
                        'state': self.state(s), 'health': self.health()}
            # Native callers may have started work outside the Python task
            # wrapper. Preserve the native interrupt API, but never claim its
            # completion from this client's cached state.
            requested = False
            try:
                async with asyncio.timeout(wait):
                    async with self.setup_lock:
                        requested = True
                        native = await self.require_control().call('interrupt-proof', [session_id])
            except Exception as error:
                if requested:
                    s.uncertain = True
                    s.last_error = f'Native interrupt was not acknowledged: {error or "deadline expired"}'
                return {'status': 'runtime_failed' if self.runtime_failure else 'unresponsive' if requested else 'pending',
                        'restored': False, 'requested': requested, 'state': self.state(s), 'health': self.health()}
            return {'status': 'idle' if native == 'Session is idle' else 'pending',
                    'restored': False, 'native': native, 'state': self.state(s),
                    'note': 'No client-owned command to acknowledge. Native callers must await their original response.'}
        deadline = time.monotonic() + wait
        # Hold admission until the interrupt RPC has acknowledged. If it times
        # out, reject later commands as uncertain: a delayed request must not
        # interrupt an unrelated new command.
        requested = False
        try:
            async with asyncio.timeout(wait):
                async with self.setup_lock:
                    if s.pending is not pending or pending.done():
                        return {'status': 'settled', 'restored': False, 'state': self.state(s)}
                    requested = True
                    native = await self.require_control().call('interrupt-proof', [session_id])
            await asyncio.wait([pending], timeout=max(0, deadline - time.monotonic()))
        except Exception as error:
            if requested:
                s.uncertain = True
                s.last_error = f'Recovery request was not acknowledged: {error or "deadline expired"}'
            s.recovery = {'status': 'runtime_failed' if self.runtime_failure else 'unresponsive' if requested else 'pending',
                          'restored': False, 'requested': requested,
                          'error': s.last_error if requested else 'Recovery deadline expired waiting for setup admission.'}
        else:
            if s.pending is not pending:
                return {'status': 'settled', 'restored': False, 'state': self.state(s),
                        'note': 'The prior command settled and this cursor has advanced.'}
            succeeded = pending.done() and not pending.cancelled() and pending.exception() is None
            restored = succeeded and self.state(s).get('outcome') == 'interrupted'
            # PVSio uses its native errOut instead of the proof outcome field.
            if s.kind == 'evaluator' and succeeded and isinstance(s.latest, dict):
                restored = 'interrupt' in str(s.latest.get('errOut', '')).lower()
            s.recovery = {'status': 'restored' if restored else 'settled' if pending.done() else 'pending',
                          'restored': restored, 'native': native}
        if self.runtime_failure:
            s.recovery = {'status': 'runtime_failed', 'restored': False}
        self.checkpoint()
        return {**s.recovery, 'state': self.state(s), 'health': self.health(),
                'note': 'Pending is not restored. Do not resend the command. Runtime faults require a new worker and explicit reconstruction from durable evidence.'}

    async def watch_command(self, session, pending, time_limit):
        done, _ = await asyncio.wait([pending], timeout=time_limit)
        if done or session.pending is not pending:
            return
        self.record('command_deadline', {'session_id': session.id, 'time_limit': time_limit})
        try:
            await self.recover(session.id, wait=5)
        except Exception as error:
            session.recovery = {'status': 'recovery_error', 'error': str(error), 'restored': False}
