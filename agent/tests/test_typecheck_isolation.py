"""Force overlapping native typechecking scopes, without timing-dependent sleeps."""
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
(defvar *agent-types-ready* (make-queue))
(defvar *agent-types-read* (make-queue))
(defvar *agent-types-key* (make-instance 'name-expr :id 'probe))
(defun agent-test-types-interleaving (role)
  (let ((*in-typechecker* nil))
    (protect-types-hash *agent-types-key*
      (if (eq role 'writer)
          (let ((cache *expression-types*) (empty *empty-expression-types*))
            (setf (types *agent-types-key*) (list *boolean*))
            (push-queue :ready *agent-types-ready*)
            (pop-queue *agent-types-read*)
            (unless (types *agent-types-key*)
              (return-from agent-test-types-interleaving "TYPE-CACHE-CLOBBERED"))
            (agent-call-with-proof-runtime
             (lambda ()
               (assert (not (eq cache *expression-types*)))
               (assert (not (eq empty *empty-expression-types*)))))
            (assert (eq cache *expression-types*))
            (assert (eq empty *empty-expression-types*))
            (assert (types *agent-types-key*)))
          (progn
            (pop-queue *agent-types-ready*)
            ;; TYPES is native scratch storage, never the expression's TYPE slot.
            (setf (types *agent-types-key*) nil)
            (push-queue :read *agent-types-read*))))
    "TYPE-CACHE-ISOLATED"))
(defstep agent-types-probe (role)
  (let ((message (agent-test-types-interleaving role))) (skip-msg message))
  "Test native typechecker cache ownership" "Testing typechecker isolation")
'''

def test_native_typechecker_scopes_are_private(tmp_path):
    shutil.copy(AGENT/'tests/fixtures/agent_fixture.pvs',tmp_path/'agent_fixture.pvs')
    strategy=tmp_path/'types-probe.lisp';strategy.write_text(STRATEGY)
    async def run():
        c=PVSClient()
        try:
            await c.start(str(tmp_path),'agent_fixture')
            await c.load_strategy(str(strategy))
            ref=f'{tmp_path}/agent_fixture.pvs#agent_fixture#left_bound'
            ids=[(await c.proof_open(ref))['session_id'] for _ in range(2)]
            rows=await asyncio.gather(c.command(ids[0],'(agent-types-probe$ writer)',wait=10),
                                      c.command(ids[1],'(agent-types-probe$ reader)',wait=10))
            assert not any(row['running'] for row in rows), 'Proof scopes serialized/deadlocked'
            assert all('TYPE-CACHE-ISOLATED' in row['commentary'] for row in rows), json.dumps(rows,indent=2)
            rows=await asyncio.gather(*(c.command(sid,'(grind)') for sid in ids))
            assert all(row['proof_result']=='proved' for row in rows), rows
        finally:await c.close()
    asyncio.run(asyncio.wait_for(run(),30))
