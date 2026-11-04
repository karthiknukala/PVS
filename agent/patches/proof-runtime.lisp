(in-package :pvs)

;;; Native sources: src/prover/eproofcheck.lisp (prove-decl :around, startup,
;;; cleanup); src/prover/checker-macros.lisp (init-if-rec); src/utils.lisp and
;;; src/prover/beta-reduce.lisp (cache resets); src/subst-mod-params.lisp and
;;; src/classes-decl.lisp (workspace substitution cache accessor).
;;;
;;; Binding fresh tables before entering compiled native code avoids changing
;;; init-if-rec's macro definition without recompiling its callers.  These
;;; caches are disposable; do not copy tables whose entries contain mutable
;;; proof-local objects.  This is not a claim that every backend or attachment
;;; is thread-safe.  Concurrent execution remains gated by qualification.

(defvar *agent-proof-workspace-caches* nil)
(defvar *agent-observer-cache* nil)

(defun agent-fresh-proof-cache (cache)
  "An empty table with CACHE's equality test, for the supported Lisp build."
  (assert (hash-table-p cache))
  (make-hash-table :test (hash-table-test cache)
                   :size (hash-table-size cache)
                   :rehash-size (hash-table-rehash-size cache)
                   :rehash-threshold (hash-table-rehash-threshold cache)))

(defmethod all-subst-mod-params-caches :around ((workspace workspace))
  (if *agent-proof-workspace-caches*
      (or (gethash workspace *agent-proof-workspace-caches*)
          (setf (gethash workspace *agent-proof-workspace-caches*)
                (make-pvs-hash-table :strong-eq? t)))
      (call-next-method)))

(defmethod (setf all-subst-mod-params-caches) :around
    (value (workspace workspace))
  (if *agent-proof-workspace-caches*
      (setf (gethash workspace *agent-proof-workspace-caches*) value)
      (call-next-method)))

(defun agent-call-with-proof-runtime (thunk)
  "Run THUNK with private proof caches, including nested-proof restoration."
  (let ((*agent-observer-cache* (make-hash-table :test #'eq :weakness :key))
        (*agent-proof-workspace-caches* (make-hash-table :test #'eq))
        (*auto-rewrites* (agent-fresh-proof-cache *auto-rewrites*))
        (*auto-rewrites-ops* (agent-fresh-proof-cache *auto-rewrites-ops*))
        (*auto-rewrites!-names* nil)
        (*first-strategy-error* nil) (*last-strategy-error* nil)
        (*rewrite-hits* 0) (*rewrite-misses* 0)
        ;; Shostak CANON clears this memo table on entry; CANON-HASH fills it
        ;; during reasoning. A process-global table lets another proof clear
        ;; entries or race a hash growth (reproduced by concurrent CMR proofs).
        ;; Bind it here so nested runtimes restore their caller's table too.
        (*canon-hash* (agent-fresh-proof-cache *canon-hash*))
        ;; PROTECT-TYPES-HASH lends EMPTY-EXPRESSION-TYPES to the native
        ;; typechecker and replaces it on unwind. Both the loan and the spare
        ;; must belong to this runtime, including mid-proof CASE/INST calls.
        (*expression-types* (agent-fresh-proof-cache *expression-types*))
        (*empty-expression-types* (agent-fresh-proof-cache *empty-expression-types*))
        (*match-cache* (agent-fresh-proof-cache *match-cache*))
        (*subtype-of-hash* (agent-fresh-proof-cache *subtype-of-hash*))
        (*create-formulas-cache* (agent-fresh-proof-cache *create-formulas-cache*))
        (*term-print-strings* (agent-fresh-proof-cache *term-print-strings*))
        (*translate-id-hash* (agent-fresh-proof-cache *translate-id-hash*))
        (*translate-to-prove-hash* (agent-fresh-proof-cache *translate-to-prove-hash*))
        (*top-translate-to-prove-hash*
          (agent-fresh-proof-cache *top-translate-to-prove-hash*))
        (*beta-cache* (agent-fresh-proof-cache *beta-cache*))
        (*let-reduce-beta-cache* (agent-fresh-proof-cache *let-reduce-beta-cache*))
        (*subst-fields-hash* (agent-fresh-proof-cache *subst-fields-hash*))
        (*pseudo-normalize-hash* nil)
        (*pseudo-normalize-translate-id-hash* nil)
        (*pseudo-normalize-translate-to-prove-hash* nil)
        (*pseudo-normalize-subtype-hash* nil)
        (*subst-mod-params-cache* nil)
        (*subst-mod-params-eq-cache* nil)
        ;; Native initprover runs once before dpi-start's dynamic bindings.
        (typealist nil) (sigalist nil) (findalist nil) (usealist nil)
        (applysymlist nil)
        (*integer-pred* nil) (*rational-pred* nil) (*real-pred* nil)
        ;; The native LET binds the current counter closure, which would
        ;; otherwise remain shared by top-level proof sessions.
        (*bdd-counter* nil))
    (newcounter *bdd-counter*)
    (funcall thunk)))

;;; One owner for this method.  Preserve the stock timeout wrapper and keep it
;;; inside the record binding, so its timeout write also goes to this attempt.
;;; Ordinary serial entry takes the original path.  Recursive entry from an
;;; agent proof gets another private cache scope, restored on every unwind.
(defmethod prove-decl :around ((decl formula-decl) &key strategy)
  (declare (ignore strategy))
  (flet ((prove-with-native-timeout ()
           (if (and *noninteractive* *noninteractive-timeout*)
               (with-timeout (*noninteractive-timeout*
                              (progn
                                (setf (proof-status decl) 'timeout)
                                (pvs-message "Interrupted: ~a sec timeout"
                                             *noninteractive-timeout*)))
                 (call-next-method))
               (call-next-method))))
    (if (or *agent-proof-workspace-caches*
            (typep (current-session) 'proof-session))
        (agent-call-with-proof-record
          decl (lambda ()
                 (agent-call-with-proof-runtime #'prove-with-native-timeout)))
        (prove-with-native-timeout))))
