;;; Agent-only helpers; native proof/evaluator RPCs remain available.
(in-package :pvs)

(defvar *agent-preparation-status* nil)
(defvar *agent-prepared-persistence-files* nil)

(defun agent-persistence-fingerprint (path)
  ;; Absence is part of the baseline: creation and deletion are conflicts too.
  (if (probe-file path) (agent-source-fingerprint path) :absent))

(defun agent-record-prepared-persistence ()
  (let ((paths
          (remove-duplicates
           (loop for (source . hash) in *agent-prepared-files*
                 append (list (namestring (make-prf-pathname source))
                              (namestring (merge-pathnames
                                           ".pvscontext"
                                           (uiop:pathname-directory-pathname source)))))
           :test #'string=)))
    (setf *agent-prepared-persistence-files*
          (mapcar (lambda (path) (cons path (agent-persistence-fingerprint path))) paths))))

(defun agent-check-prepared-persistence (&optional require-ready)
  (when (and require-ready (not (eq *agent-preparation-status* :ready)))
    (error "A successful preparation is required before saving"))
  (dolist (entry *agent-prepared-persistence-files*)
    (unless (equal (cdr entry) (agent-persistence-fingerprint (car entry)))
      ;; Do not let re-prepare silently accept new bytes with cached old proof
      ;; objects. Restart/reload is the explicit recovery for an external writer.
      (setf *agent-preparation-status* :conflict)
      (error "Persistence file changed outside this PVS process: ~a. Restart PVS and prepare again."
             (car entry))))
  t)

(defun agent-refresh-saved-persistence (paths)
  ;; Refresh only files this save owns, never bless unrelated external changes.
  (dolist (path paths)
    (let ((entry (assoc path *agent-prepared-persistence-files* :test #'string=)))
      (unless entry (error "Saved path was not prepared: ~a" path))
      (setf (cdr entry) (agent-persistence-fingerprint path)))))

(defun agent-require-no-sessions ()
  (when (some #'session-alive-p *all-sessions*)
    (error "Close active proof/evaluator sessions before preparing or verifying a context")))

(defun agent-check-prepared-sources ()
  (when (eq *agent-preparation-status* :failed)
    (error "The last preparation failed; prepare successfully before continuing"))
  (let ((buffer (agent-fingerprint-buffer)))
    (dolist (entry *agent-prepared-files*)
      (unless (and (probe-file (car entry))
                   (string-equal (cdr entry) (agent-source-fingerprint (car entry) buffer)))
        (error "Source changed since preparation: ~a. Close sessions and prepare again." (car entry)))))
  t)

(defun agent-theory-source-path (theory)
  ;; Native MAKE-SPECPATH on a theory uses its ID, not its owning filename.
  ;; A source file may contain several theories with different names.
  (let ((*default-pathname-defaults* (context-path theory)))
    (make-specpath (filename theory))))

(defun agent-record-prepared-sources (theories)
  ;; Several imported theories can live in a single physical file.
  (let ((seen (make-hash-table :test #'equal))
        (buffer (agent-fingerprint-buffer)))
    (setq *agent-prepared-files*
          (loop for th in (remove-duplicates
                           (loop for th in theories
                                 append (cons th (all-imported-theories th))) :test #'eq)
                for path = (ignore-errors (agent-theory-source-path th))
                for file = (and path (probe-file path))
                when (and file (not (gethash file seen)))
                collect (progn (setf (gethash file seen) t)
                               (cons (namestring file) (agent-source-fingerprint file buffer)))))))

(defun agent-prepare (context file)
  (agent-call-with-setup
   (lambda ()
     (agent-require-no-sessions)
     ;; Existing snapshots survive a failed preparation. A retry must not
     ;; silently adopt external proof changes into cached declaration objects.
     (agent-check-prepared-persistence)
     (setf *agent-preparation-status* :failed *agent-prepared-files* nil)
     (multiple-value-bind (theories output)
         (agent-capture-output
          (lambda ()
            (let ((*proceed-without-asking* t))
              (change-context context)
              (typecheck-file file))))
       (unless theories (error "Typechecking returned no theories for ~a: ~a" file output))
       (agent-record-prepared-sources theories)
       (agent-record-prepared-persistence)
       (setf *agent-preparation-status* :ready)
       `(("context" . ,(namestring (current-context-path))) ("file" . ,file)
         ("theories" . ,(coerce (mapcar (lambda (th) (string (id th))) theories) 'vector))
         ("output" . ,output))))))

;; Native strategy timestamps are set before LOAD and errors are swallowed.
;; Only commit timestamps on success; propagate errors and permit a forced retry.
(defun load-strategies-file (file dates)
  (let ((*loading-files* :strategies))
    (when (file-exists-p file)
      (let ((stamp (file-write-time file)))
        (unless (eql stamp (car dates))
          (handler-case
              (progn (load file :verbose nil)
                     (add-lowercase-prover-ids)
                     (setf (car dates) stamp)
                     (pushnew (namestring (truename file)) *agent-strategy-files* :test #'string=))
            (error (condition)
              (setf (car dates) 0)
              (add-lowercase-prover-ids)
              (error "Strategy load failed (partial definitions may remain): ~a: ~a"
                     file condition))))))))

(defun load-library-strategy-file (lib)
  (let* ((file (merge-pathnames "pvs-strategies" lib))
         (entry (assoc lib *library-strategy-file-dates* :test #'equal))
         (dates (list (or (cdr entry) 0))))
    (handler-case
        (progn
          (load-strategies-file file dates)
          (if entry (setf (cdr entry) (car dates))
              (push (cons lib (car dates)) *library-strategy-file-dates*)))
      (error (condition)
        (when entry (setf (cdr entry) 0))
        (error condition)))))

(defun agent-load-strategy (path)
  (agent-call-with-setup
   (lambda ()
     (agent-check-prepared-sources)
     (read-strategies-files)
     (let ((file (truename path)))
       (multiple-value-bind (value output)
           (agent-capture-output
            (lambda ()
              (let ((*package* (find-package :pvs)) (*loading-files* :strategies))
                (unwind-protect (load file :verbose nil)
                  (add-lowercase-prover-ids)))))
         (declare (ignore value))
         (agent-check-prepared-sources)
         (pushnew (namestring file) *agent-strategy-files* :test #'string=)
         `(("loaded" . t) ("path" . ,(namestring file))
           ("fingerprint" . ,(agent-source-fingerprint file)) ("output" . ,output)))))))

(defun agent-info ()
  `(("version" . ,*agent-version*) ("loaded" . ,(eq *agent-loaded* :ready))
    ("worker_id" . ,(when (boundp '*agent-worker-id*) (symbol-value '*agent-worker-id*)))
    ("pvs_path" . ,(namestring *pvs-path*))
    ("context" . ,(namestring (current-context-path)))
    ("parallel_proofs" . t) ("parallel_evaluator" . t)
    ("backend" . "shostak")
    ("sessions" . ,(coerce (agent-session-info) 'vector))
    ("strategy_files" . ,(coerce *agent-strategy-files* 'vector))))

(defun agent-explain-current-tcc ()
  "Explain a side obligation or the named TCC declaration being proved."
  (cond
    ;; Native EXPLAIN-TCC expects this special proofstate class, not merely a
    ;; top-level declaration of class TCC-DECL.
    ((tcc-proofstate? *ps*) (call-explain-tcc))
    ((tcc-decl? (declaration *top-proofstate*))
     (let* ((decl (declaration *top-proofstate*))
            (origin (origin decl)))
       (format t "~a.~a~%" (id (module decl)) (id decl))
       (when (newline-comment decl)
         (format t "~a~%" (newline-comment decl)))
       (when (typep origin 'tcc-origin)
         (format t "Kind: ~a~%" (kind origin))
         (when (expr origin)
           (format t "Generated by: ~a~%" (expr origin)))
         (when (type origin)
           (format t "Expected type: ~a~%" (type origin))))
       (format t "Obligation: ~a~%" (str (definition decl)))))
    (t (format t "The current goal and declaration are not TCCs."))))

(defun agent-inspect (session-id kind)
  (agent-call-in-session
   session-id
   (lambda ()
     (let ((ps (agent-current-proofstate)))
       (cond
         ((string= kind "locals")
          (coerce (mapcar (lambda (decl)
                            `(("name" . ,(string (id decl)))
                              ("type" . ,(str (type decl)))
                              ("definition" . ,(when (definition decl) (str (definition decl))))))
                          (collect-skolem-constants)) 'vector))
         ((string= kind "dependencies")
          (coerce (mapcar (lambda (decl)
                            `(("name" . ,(string (id decl)))
                              ("theory" . ,(when (module decl) (string (id (module decl)))))))
                          (dependent-decls ps)) 'vector))
         ((member kind '("state" "sequent" "hidden") :test #'string=)
          (pvs-jsonrpc::pvs2json-response
           `(("id" . ,session-id) ("proofstate" . ,ps)
             ("status" . "waiting") ("commentary" . nil))))
         ((member kind '("rewrites" "expanded" "tcc") :test #'string=)
          (multiple-value-bind (value output)
              (agent-capture-output
               (lambda ()
                 (cond ((string= kind "rewrites") (show-auto-rewrites))
                       ((string= kind "expanded") (show-expanded-sequent t))
                       (t (agent-explain-current-tcc)))))
            (declare (ignore value))
            `(("kind" . ,kind) ("text" . ,output))))
         (t (error "Unsupported inspection ~s; use state, locals, dependencies, rewrites, expanded, or tcc"
                   kind)))))))

(defun agent-save (form-ref proof-id)
  (agent-call-with-setup
   (lambda ()
     (agent-check-prepared-sources)
     ;; Check before resolving the reference: native resolution can typecheck
     ;; and restore proofs. A rejected save must not alter selection or disk.
     (agent-check-prepared-persistence t)
     (let* ((decl (get-formula-decl form-ref))
            (proof (find proof-id (proofs decl) :key #'id :test #'string-equal))
            (th (module decl))
            (source (namestring (truename (agent-theory-source-path th))))
            (proof-path (namestring (make-prf-pathname source)))
            (context-path (namestring (merge-pathnames
                                      ".pvscontext"
                                      (uiop:pathname-directory-pathname source))))
            (previous (default-proof decl))
            (saved nil))
       (unless proof (error "No proof alternative ~a for ~a" proof-id form-ref))
       (unless (and (assoc source *agent-prepared-files* :test #'string=)
                    (assoc proof-path *agent-prepared-persistence-files* :test #'string=)
                    (assoc context-path *agent-prepared-persistence-files* :test #'string=))
         (error "Prepare the source and proof file before saving ~a" form-ref))
       (when (some (lambda (sess)
                     (and (typep sess 'proof-session)
                          (eq decl (formula-decl sess)) (session-alive-p sess)))
                   *all-sessions*)
         (error "Finish or close attempts of ~a before saving" form-ref))
       (agent-check-prepared-persistence t)
       (unwind-protect
            (progn
              (setf (default-proof decl) proof)
              (with-workspace (context-path th)
                (let ((*proceed-without-asking* t))
                  (unless (eq t (save-all-proofs th t))
                    (error "Native proof saving did not confirm success for ~a" proof-path))
                  (save-context nil t)))
              (agent-refresh-saved-persistence (list proof-path context-path))
              (setf saved t))
         (unless saved (setf (default-proof decl) previous)))
       `(("formula_ref" . ,(make-formref decl)) ("proof_id" . ,(string (id proof)))
         ("status" . ,(string-downcase (string (status proof))))
         ("file" . ,source) ("theory" . ,(string (id th)))
         ("context" . ,(namestring (context-path th))))))))

(defun agent-verification-row (decl)
  `(("formula" . ,(make-formref decl))
    ("status" . ,(string-downcase (string (proof-status decl))))
    ("chain" . ,(pc-complete decl)) ("proved" . ,(not (null (proved? decl))))))

;; Native proof-chain replay discovers dependencies while replaying. Check every
;; attempted declaration, not only the initial target.
(defvar *agent-verifying* nil)
(agent-remember-original 'pvs-prove-decl)
(defun pvs-prove-decl (decl retry?)
  (when *agent-verifying* (agent-check-proof-backend decl))
  (funcall (agent-original 'pvs-prove-decl) decl retry?))

(defun agent-verify (form-ref scope)
  (agent-call-with-setup
   (lambda ()
     (agent-require-no-sessions)
     (agent-check-prepared-sources)
     (let* ((decl (get-formula-decl form-ref)) (th (module decl))
            (theories
              (cond ((member scope '("declaration" "theory") :test #'string=) (list th))
                    ((string= scope "importchain")
                     (remove-duplicates (cons th (collect-theory-usings th)) :test #'eq))
                    (t (error "Unknown verification scope ~a" scope))))
            (targets
              (if (string= scope "declaration") (list decl)
                  (remove-if-not #'provable-formula?
                   (loop for theory in theories
                         unless (from-prelude? theory)
                         append (all-formulas theory))))))
       (unless (and (provable-formula? decl) targets)
         (error "Verification requires a provable declaration and a nonempty scope"))
       (multiple-value-bind (ignored output)
           (agent-capture-output
            (lambda ()
              (let ((*noninteractive* t) (*noninteractive-timeout* 120)
                    (*agent-verifying* t)
                    (*proceed-without-asking* t))
                (read-strategies-files)
                (dolist (target targets)
                  (agent-check-proof-backend target)
                  (prove-proofchain-decl target t nil)))))
         (declare (ignore ignored))
         (let* ((replayed (remove-duplicates
                           (loop for target in targets
                                 append (remove-if-not #'provable-formula? (get-proofchain target)))
                           :test #'eq))
                (rows (mapcar #'agent-verification-row replayed))
                (success (and targets rows
                              (every (lambda (target) (member target replayed :test #'eq)) targets)
                              (every (lambda (row)
                                       (and (string= "proved" (cdr (assoc "status" row :test #'string=)))
                                            (cdr (assoc "proved" row :test #'string=))
                                            (string= "complete" (cdr (assoc "chain" row :test #'string=)))))
                                     rows))))
           `(("verified" . ,(not (null success))) ("scope" . ,scope)
             ("status" . ,(if success "verified" "failed"))
             ("native_proofchain_replayed" . t)
             ("details" . ,(coerce rows 'vector)) ("output" . ,output))))))))

(defun agent-start-server (port)
  (unless (eq *agent-loaded* :ready) (error "Agent extension is not ready"))
  (when pvs-websocket::*websocket-server* (error "A PVS server is already running"))
  (setf pvs-websocket::*debug-ws* nil hunchentoot:*default-connection-timeout* 18000)
  (setf pvs-websocket::*websocket-server*
        (clack:clackup #'pvs-websocket::websocket-pvs-server
                      :server :hunchentoot :address "127.0.0.1" :port port :use-thread t))
  (format t "~&PVS-AGENT-READY ~d~%" port)
  (finish-output)
  port)

(in-package :pvs-jsonrpc)
(defrequest agent-info () "Inspect the loaded extension and native sessions."
  (pvs::agent-info))
(defrequest agent-validate-context () "Reject a source changed since preparation."
  (pvs::agent-check-prepared-sources))
(defrequest agent-prepare (context file) "Typecheck a fixed context before sessions start."
  (pvs::agent-prepare context file))
(defrequest agent-inspect (session-id kind) "Inspect on the owning proof thread without a proof step."
  (pvs::agent-inspect session-id kind))
(defrequest agent-load-strategy (path) "Load a strategy file while sessions are idle; errors propagate."
  (pvs::agent-load-strategy path))
(defrequest agent-evaluator-start (theory-ref) "Start a native evaluator with TCC checking."
  (pvs::agent-pvsio-init theory-ref))
(defrequest agent-close (session-id) "Close the named native proof or evaluator session."
  (let ((session (pvs::get-session session-id)))
    (cond ((null session) '(("state" . "closed")))
          ((typep session 'pvs::proof-session)
           (pvs2json-response (pvs::prover-step session-id "(quit)")))
          ((typep session 'pvs::pvsio-session) (pvs::pvsio-eval session-id "quit" "pvs"))
          (t (error "Unsupported session kind")))))
(defrequest agent-save (form-ref proof-id) "Select and save one explicit native proof alternative."
  (pvs::agent-save form-ref proof-id))
(defrequest agent-verify (form-ref scope) "Force replay in this fresh isolated process."
  (pvs::agent-verify form-ref scope))


(defrequest agent-proof-records (form-ref)
  "Native proof alternatives with dependency identities for agent diagnostics."
  (let ((decl (pvs:get-formula-decl form-ref)))
    (coerce
     (mapcar
      (lambda (proof)
        (append
         (pvs2alist-proof proof (pvs:default-proof decl))
         (list (cons "dependencies"
                     (coerce
                      (mapcar (lambda (dependency)
                                `(("name" . ,(string (pvs:id dependency)))
                                  ("theory" . ,(when (pvs:module dependency)
                                                 (string (pvs:id (pvs:module dependency)))))))
                              (pvs::refers-to proof))
                      'vector)))))
      (pvs:proofs decl))
     'vector)))
