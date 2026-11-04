"""Deterministic guards for the shared-state failures exposed by CMR proofs."""
import asyncio
from pathlib import Path
import sys

AGENT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(AGENT))
from server import PVSClient

PROBE=r'''
(progn
  ;; Each invocation, including a nested invocation, owns its memo table.
  (let ((obj (list nil)) outer inner)
    (mapobject (lambda (x)
                 (declare (ignore x))
                 (setf outer *mapobject-cache*)
                 (mapobject (lambda (y) (declare (ignore y))
                              (setf inner *mapobject-cache*) t) obj)
                 t) obj)
    (assert (and inner (not (eq outer inner)))))
  (let ((obj "probe") outer inner)
    (gensubst obj
      (lambda (x)
        (setf outer *gensubst-cache*)
        (gensubst x (lambda (y) (setf inner *gensubst-cache*) y)
                    (constantly t)))
      (constantly t))
    (assert (and inner (not (eq outer inner)))))
  ;; Native error output must not enter BREAK/the background debugger.
  (let* ((sess (make-instance 'proof-session :id "condition-probe"))
         (*agent-bound-session* sess))
    (session-output (make-condition 'unbound-variable :name 'example))
    (assert (typep (car (outputs sess)) 'cl:simple-error)))
  ;; Simultaneous parser/pretty-printer clients and narrow BDD transactions.
  (let* ((done (make-queue)) (active 0) (peak 0)
         (input "FORALL (x: nat): (x + 1 > x) AND (x * 2 >= x)")
         (expected (str (parse :string input :nt 'expr)))
         (threads
           (loop repeat 4 collect
             (bt:make-thread
               (lambda ()
                 (handler-case
                     (progn
                       (dotimes (i 50)
                         (let ((expr (parse :string input :nt 'expr)))
                           (assert (string= expected (str expr)))
                           (multiple-value-bind (text view) (pp-with-view expr)
                             (assert (and text view))))
                         (agent-call-with-bdd
                           (lambda ()
                             (incf active) (setf peak (max peak active))
                             (agent-call-with-bdd (lambda () (assert (= active 1))))
                             (sleep 0.001) (decf active))))
                       (push-queue :pass done))
                   (error (c) (push-queue (princ-to-string c) done))))))))
    (dotimes (i 4) (let ((result (pop-queue done))) (assert (eq result :pass) () "~a" result)))
    (mapc #'bt:join-thread threads)
    (assert (= peak 1)))
  "NATIVE-CONCURRENCY-PASS")
'''

def test_parser_traversal_bdd_and_condition_isolation(tmp_path):
    (tmp_path/'probe.pvs').write_text('probe: THEORY BEGIN ok: LEMMA TRUE END probe\n')
    async def run():
        client=PVSClient(library_path='')
        try:
            await client.start(str(tmp_path),'probe',timeout=30)
            answer=await client.require_control().call('lisp',[PROBE])
            assert answer=='NATIVE-CONCURRENCY-PASS', answer
        finally:
            await client.close()
    asyncio.run(asyncio.wait_for(run(),45))
