;;; Isolated assertions for the two proof patches.  Run via test_runtime.py;
;;; all PVS-generated files stay under its temporary context.
(in-package :pvs)

(setq *noninteractive* t *proof-prompt-behavior* :noquestions
      *proceed-without-asking* t)
(change-context (uiop:getenv "PVS_AGENT_TEST_CONTEXT"))
(typecheck-file "runtime_probe")
(read-strategies-files)

(defparameter *agent-test-theory* (get-typechecked-theory "runtime_probe"))
(defun agent-test-declaration (name)
  (or (find name (theory *agent-test-theory*)
            :key (lambda (decl) (string (id decl))) :test #'string=)
      (error "Missing test declaration ~a" name)))
(defparameter *agent-test-decl* (agent-test-declaration "target"))
(defparameter *agent-test-serial* (prove-decl *agent-test-decl* :strategy '(grind)))
(assert (eq (status-flag *agent-test-serial*) '!))
(assert (eq (proof-status *agent-test-decl*) 'proved))
(format t "~%AGENT-TEST SERIAL-LEGACY-PASS~%")

(defun agent-test-record-snapshot (record)
  (copy-tree
   (mapcar (lambda (slot) (slot-value record slot))
           '(script status refers-to real-time run-time decision-procedure-used))))
(let* ((default (default-proof *agent-test-decl*))
       (snapshot (agent-test-record-snapshot default))
       (session (make-instance 'proof-session :id 'agent-test-attempt
                              :formula-decl *agent-test-decl*
                              :thread (bt:current-thread)))
       (*all-sessions* (list session)))
  (agent-call-with-proof-record *agent-test-decl*
    (lambda ()
      (assert (not (eq *agent-proof-record* default)))
      (let ((record *agent-proof-record*))
        (setf (proof-status *agent-test-decl*) 'proved
              (proof-refers-to *agent-test-decl*)
                (list (agent-test-declaration "support"))
              (real-time *agent-test-decl*) 17
              (run-time *agent-test-decl*) 19
              (decision-procedure-used *agent-test-decl*) 'shostak)
        (let ((*top-proofstate* *agent-test-serial*)
              (*context-modified* nil)
              ;; No backend is executed here.  Verify save records the selected
              ;; backend instead of the allocator's global default value.
              (*current-decision-procedure* 'agent-test-selected-backend))
          (save-proof-info *agent-test-decl* (get-internal-real-time) (get-run-time)))
        (assert (eq record (agent-session-proof-info session)))
        (assert (= 1 (count 'agent-test-attempt (proofs *agent-test-decl*) :key #'id)))
        (assert (eq (status record) 'proved))
        (assert (script record))
        (assert (equal (refers-to record) (list (agent-test-declaration "support"))))
        (assert (eq (decision-procedure-used record) 'agent-test-selected-backend))
        (assert (equal snapshot (agent-test-record-snapshot default)))
        (assert (null (agent-record-for-declaration (agent-test-declaration "support"))))
        ;; A nested proof even of the same declaration does not inherit the
        ;; outer session's metadata destination.  Native nested-save suppression
        ;; and metadata behavior remain in charge.
        (let ((*in-checker* t))
          (agent-call-with-proof-record *agent-test-decl*
            (lambda () (assert (null *agent-proof-record*)))))))))
(format t "~%AGENT-TEST RECORD-DEFAULT-SAVE-NESTING-PASS~%")

(defparameter *agent-test-cache-symbols*
  '(*canon-hash* *expression-types* *empty-expression-types*
    *auto-rewrites* *auto-rewrites-ops* *match-cache* *subtype-of-hash*
    *create-formulas-cache* *term-print-strings* *translate-id-hash*
    *translate-to-prove-hash* *top-translate-to-prove-hash*
    *beta-cache* *let-reduce-beta-cache* *subst-fields-hash*))
(let* ((workspace *workspace-session*)
       (workspace-cache (all-subst-mod-params-caches workspace))
       (globals (mapcar #'symbol-value *agent-test-cache-symbols*))
       (marker (gensym)))
  (setf (gethash :agent-sentinel workspace-cache) marker)
  (agent-call-with-proof-runtime
    (lambda ()
      (let ((private (all-subst-mod-params-caches workspace))
            (outer (mapcar #'symbol-value *agent-test-cache-symbols*)))
        (assert (every (lambda (a b) (not (eq a b))) globals outer))
        (assert (not (eq private workspace-cache)))
        (setf (gethash :agent-sentinel private) marker)
        (dolist (table outer) (setf (gethash :agent-sentinel table) marker))
        (catch 'agent-test-unwind
          (agent-call-with-proof-runtime
            (lambda ()
              (assert (not (eq private (all-subst-mod-params-caches workspace))))
              (dolist (sym *agent-test-cache-symbols*)
                (assert (null (gethash :agent-sentinel (symbol-value sym)))))
              (reset-beta-cache)
              (reset-pseudo-normalize-caches)
              (setf (all-subst-mod-params-caches workspace)
                    (make-pvs-hash-table :strong-eq? t))
              (throw 'agent-test-unwind nil))))
        (assert (eq private (all-subst-mod-params-caches workspace)))
        (assert (eq marker (gethash :agent-sentinel private)))
        (dolist (table outer) (assert (eq marker (gethash :agent-sentinel table)))))))
  (assert (eq workspace-cache (all-subst-mod-params-caches workspace)))
  (assert (eq marker (gethash :agent-sentinel workspace-cache)))
  (assert (every #'eq globals (mapcar #'symbol-value *agent-test-cache-symbols*)))
  (remhash :agent-sentinel workspace-cache))
(format t "~%AGENT-TEST CACHE-NESTING-UNWIND-WORKSPACE-PASS~%")

;;; Use queues, not timing assumptions, to overlap two private runtimes.  One
;;; thread's native startup/cleanup resets must leave the other's sentinels.
(let* ((workspace *workspace-session*)
       (ready (make-queue)) (continue (make-queue)) (result (make-queue))
       (worker
         (bt:make-thread
          (lambda ()
            (handler-case
                (agent-call-with-proof-runtime
                  (lambda ()
                    (let ((marker (gensym))
                          (tables (cons (all-subst-mod-params-caches workspace)
                                        (mapcar #'symbol-value *agent-test-cache-symbols*))))
                      (dolist (table tables)
                        (setf (gethash :agent-sentinel table) marker))
                      (push-queue :ready ready)
                      (pop-queue continue)
                      (dolist (table tables)
                        (assert (eq marker (gethash :agent-sentinel table))))
                    (push-queue :passed result))))
              (error (condition)
                ;; Wake the coordinator even if startup failed before READY.
                (push-queue condition ready)
                (push-queue condition result))))
          :name "agent-runtime-cache-probe")))
  (unwind-protect
       (progn
         (assert (eq (pop-queue ready) :ready))
         (agent-call-with-proof-runtime
           (lambda ()
             (dolist (sym *agent-test-cache-symbols*)
               (assert (null (gethash :agent-sentinel (symbol-value sym)))))
             (reset-pseudo-normalize-caches)
             (clear-proof-hashes)
             (clrhash *subst-fields-hash*)
             (setf (all-subst-mod-params-caches workspace)
                   (make-pvs-hash-table :strong-eq? t))))
         (push-queue :continue continue)
         (assert (eq (pop-queue result) :passed))
         (bt:join-thread worker))
    (when (bt:thread-alive-p worker) (bt:destroy-thread worker))))
(format t "~%AGENT-TEST CONCURRENT-CACHE-SENTINELS-PASS~%")

(let* ((root (uiop:ensure-directory-pathname (uiop:getenv "PVS_AGENT_TEST_ROOT")))
       (saved-save (agent-original 'save-proof-info))
       (saved-make (agent-original 'make-prf-info)))
  (load (merge-pathnames "patches/proof-records.lisp" root))
  (load (merge-pathnames "patches/proof-runtime.lisp" root))
  (assert (eq saved-save (agent-original 'save-proof-info)))
  (assert (eq saved-make (agent-original 'make-prf-info)))
  ;; Execute the wrapper after reloading, not just compare the saved pointer.
  (let ((proof (prove-decl *agent-test-decl* :strategy '(grind))))
    (assert (eq (status-flag proof) '!))
    (assert (eq (proof-status *agent-test-decl*) 'proved))))
(format t "~%AGENT-TEST RELOAD-PASS~%")
(uiop:quit 0)
