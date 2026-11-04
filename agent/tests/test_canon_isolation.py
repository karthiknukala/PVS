"""Force the native Shostak canon cache interleaving seen in CMR failures."""
import asyncio
import json
from pathlib import Path
import shutil
import sys
AGENT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(AGENT))
from server import PVSClient

STRATEGY=r'''
(in-package :pvs)
(defvar *agent-canon-ready* (make-queue))
(defvar *agent-canon-cleared* (make-queue))
(defun agent-test-canon-interleaving (role)
  (if (eq role 'writer)
      (let ((cache *canon-hash*) (key (list 'private-marker)))
        (setf (gethash key cache) :retained)
        (push-queue :ready *agent-canon-ready*)
        (pop-queue *agent-canon-cleared*)
        (unless (eq (gethash key cache) :retained)
          (return-from agent-test-canon-interleaving "CANON-CACHE-CLOBBERED by another native proof"))
        ;; Nested runtimes have independent caches and restore their caller.
        (agent-call-with-proof-runtime
         (lambda ()
           (assert (not (eq cache *canon-hash*)))
           (canon 'true)))
        (assert (eq cache *canon-hash*))
        (assert (eq (gethash key cache) :retained)))
      (progn
        (pop-queue *agent-canon-ready*)
        ;; Real native entry, whose CLRHASH used to clear the writer's table.
        (unwind-protect (canon 'true)
          (push-queue :cleared *agent-canon-cleared*))))
  "CANON-CACHE-ISOLATED")
(defstep agent-canon-probe (role)
  (let ((message (agent-test-canon-interleaving role))) (skip-msg message))
  "Test native Shostak cache ownership" "Testing Shostak isolation")
'''

def test_native_canon_cache_is_private_with_overlap_and_nested_runtime(tmp_path):
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs',tmp_path/'agent_fixture.pvs')
    strategy=tmp_path/'canon-probe.lisp';strategy.write_text(STRATEGY)
    async def run():
        c=PVSClient()
        try:
            await c.start(str(tmp_path),'agent_fixture')
            await c.load_strategy(str(strategy))
            ref=f'{tmp_path}/agent_fixture.pvs#agent_fixture#left_bound'
            ids=[(await c.proof_open(ref))['session_id'] for _ in range(2)]
            pid=c.process.pid
            rows=await asyncio.gather(c.command(ids[0],'(agent-canon-probe$ writer)',wait=10),
                                      c.command(ids[1],'(agent-canon-probe$ clearer)',wait=10))
            assert not any(row['running'] for row in rows), 'Proof operations were serialized or deadlocked'
            assert all(not row.get('command_error') for row in rows), rows
            assert all('CANON-CACHE-ISOLATED' in row['commentary'] for row in rows), json.dumps(rows,indent=2)
            rows=await asyncio.gather(*(c.command(sid,'(grind)') for sid in ids))
            assert all(row['proof_result']=='proved' for row in rows), rows
            assert c.process.pid==pid
        finally:await c.close()
    asyncio.run(asyncio.wait_for(run(),30))
