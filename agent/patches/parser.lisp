(in-package :pvs)
;;; PARSE/INIT-PARSER reset process-global ERGO lexer/operator position state.
;;; Proof commands and pp-with-view (including JSON tooltips) both parse.
;;; Lock the complete parse transaction; proof reasoning remains concurrent.
(defvar *agent-parser-lock* (bt:make-lock "agent parser transaction"))
(defvar *agent-in-parser* nil)
(defun agent-call-with-parser (thunk)
  (if *agent-in-parser* (funcall thunk)
      (bt:with-lock-held (*agent-parser-lock*)
        (let ((*agent-in-parser* t)) (funcall thunk)))))
(dolist (name '(parse parse-expr psa ps)) (agent-remember-original name))
(defun parse (&rest keys)
  (agent-call-with-parser (lambda () (apply (agent-original 'parse) keys))))
(defun parse-expr (string)
  (agent-call-with-parser (lambda () (funcall (agent-original 'parse-expr) string))))
(defun psa (string &optional (nt 'adt-or-modules))
  (agent-call-with-parser (lambda () (funcall (agent-original 'psa) string nt))))
(defun ps (string &optional (nt 'adt-or-modules))
  (agent-call-with-parser (lambda () (funcall (agent-original 'ps) string nt))))
