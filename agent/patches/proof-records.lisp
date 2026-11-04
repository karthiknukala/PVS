(in-package :pvs)

;;; Native sources: src/utils.lisp (formula-decl metadata accessors and
;;; make-prf-info); src/prover/eproofcheck.lisp (output-proofstate and
;;; save-proof-info).  Keep one native alternative per proof session.  In
;;; particular, Q.E.D.'s early status/dependency writes must not touch the
;;; declaration's selected default while the session script is saved elsewhere.

(defvar *agent-proof-record-declaration* nil)
(defvar *agent-proof-record* nil)
(defvar *agent-saving-proof-record* nil)

(defun agent-session-proof-info (session)
  "Return SESSION's native proof-info, without changing the selected default."
  (when (typep session 'proof-session)
    (bt:with-lock-held (*agent-metadata-lock*)
      (find (id session) (proofs (formula-decl session)) :key #'id :test #'eq))))

(defun agent-call-with-proof-record (decl thunk)
  ;; A nested prove-decl is a legacy recursive proof, not a second attempt by
  ;; the enclosing session.  Clear the binding even when DECL happens to EQ
  ;; the outer declaration.  Its native recursive save suppression still applies.
  (let* ((session (and (not *in-checker*) (current-session)))
         (record
           (when (typep session 'proof-session)
             (bt:with-lock-held (*agent-metadata-lock*)
               ;; Must precede make-prf-info: it must not accidentally become
               ;; the default when the formula has no previous alternatives.
               (ensure-default-proof decl)
               (or (find (id session) (proofs decl) :key #'id :test #'eq)
                   (let ((info (make-prf-info decl nil (id session) "")))
                     (setf (status info) 'unfinished
                           (interactive? info) (not *noninteractive*))
                     info))))))
    (let ((*agent-proof-record-declaration* (and record decl))
          (*agent-proof-record* record)
          (*agent-saving-proof-record* nil))
      (funcall thunk))))

(defun agent-record-for-declaration (decl)
  (and (eq decl *agent-proof-record-declaration*) *agent-proof-record*))

(defmethod (setf proof-status) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record (setf (status record) value) (call-next-method))))

(defmethod (setf proof-refers-to) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record (setf (refers-to record) value) (call-next-method))))

(defmethod (setf justification) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record
        (setf (script record) (extract-justification-sexp value))
        (call-next-method))))

(defmethod (setf decision-procedure-used) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record (setf (decision-procedure-used record) value) (call-next-method))))

(defmethod (setf real-time) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record (setf (real-time record) value) (call-next-method))))

(defmethod (setf run-time) :around (value (decl formula-decl))
  (let ((record (agent-record-for-declaration decl)))
    (if record (setf (run-time record) value) (call-next-method))))

;;; Leave declaration getters unchanged: rerun and DP selection read the
;;; selected input proof.  Save only redirects the native allocator, for this
;;; declaration and session ID, so its existing script/prompt/timing logic uses
;;; exactly the record receiving the early Q.E.D. writes.  Capture functions
;;; once rather than stacking wrappers if this file is reloaded before sessions.
(agent-remember-original 'make-prf-info)
(agent-remember-original 'save-proof-info)

(defun make-prf-info (fdecl script &optional id description)
  (if (and *agent-saving-proof-record*
           (agent-record-for-declaration fdecl)
           (eq id (id *agent-proof-record*)))
      *agent-proof-record*
      (funcall (agent-original 'make-prf-info) fdecl script id description)))

(defun save-proof-info (decl init-real-time init-run-time)
  (let ((*agent-saving-proof-record* (agent-record-for-declaration decl)))
    (multiple-value-prog1
        (funcall (agent-original 'save-proof-info) decl init-real-time init-run-time)
      ;; The native allocator initializes this to the global default, although
      ;; determine-decision-procedure may choose the selected proof's backend.
      (when *agent-saving-proof-record*
        (setf (decision-procedure-used *agent-saving-proof-record*)
              *current-decision-procedure*)))))
