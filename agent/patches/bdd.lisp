(in-package :pvs)
;;; src/BDD/bdd.lisp initializes/quits a process-global C BDD manager.
;;; Dynamic proof caches do not isolate that foreign memory. Serialize just
;;; each complete BDD translation/simplification/conversion transaction.
(defvar *agent-bdd-lock* (bt:make-lock "agent native BDD transaction"))
(defvar *agent-in-bdd* nil)
(defun agent-call-with-bdd (thunk)
  (if *agent-in-bdd* (funcall thunk)
      (bt:with-lock-held (*agent-bdd-lock*)
        (let ((*agent-in-bdd* t)) (funcall thunk)))))
(agent-remember-original 'run-bddsimp)
(agent-remember-original 'bdd-simplify)
(defun run-bddsimp (ps fnums dynamic-ordering? irredundant?)
  (agent-call-with-bdd
   (lambda () (funcall (agent-original 'run-bddsimp)
                       ps fnums dynamic-ordering? irredundant?))))
(defun bdd-simplify (expr &optional ignore-boolean-equalities?)
  (agent-call-with-bdd
   (lambda () (funcall (agent-original 'bdd-simplify)
                       expr ignore-boolean-equalities?))))
