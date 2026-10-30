;;; Experimental external-checker rule for registered SAL safety theorems.
;;; The trusted boundary is the admitted translator plus SAL, not evidence
;;; reconstruction.  Registration is compiler API, never a prover command.
(in-package :pvs)

(defstruct sal-proof-target
  id theory declaration formula source assertion module selector view kind snapshots
  dependencies tccs proof-dependencies last-result)

(defvar *sal-proof-targets* (make-hash-table :test #'equal))

(defun sal-proof-target-key (id)
  (etypecase id (string id) (symbol (symbol-name id))))

(defun sal-safety-property-p (expression)
  (and (typep expression 'sal-ltl-g)
       (= (length (sal-application-arguments expression)) 1)
       (not (sal-pvs-temporal-p (first (sal-application-arguments expression))))))

(defun sal-view-backend-refusal (view)
  "Return a source-language semantic obstacle to trusted checker admission."
  (let ((integer-division nil))
    (dolist (context (remove nil
                            (append (sal-transition-view-contexts view)
                                    (list (sal-transition-view-flat-module view))
                                    (sal-transition-view-root-actuals view)
                                    (mapcar #'cdr (sal-transition-view-properties view)))))
      (sal-walk-ast
       (lambda (node)
         (when (or (typep node 'sal-idiv) (typep node 'sal-mod))
           (setf integer-division t)))
       context))
    (when integer-division
      "SAL DIV/MOD backend semantics have not been audited against the shallow PVS translation; diagnostic checks remain available.")))

(defun sal-theory-source-file (theory)
  (unless (from-prelude? theory)
    (let ((file (filename theory)) (directory (context-path theory)))
      (unless (and file directory)
        (error "Cannot capture PVS source for imported theory ~a" (id theory)))
      (or (probe-file (merge-pathnames (make-pathname :name file :type "pvs")
                                       (uiop:ensure-directory-pathname directory)))
          (error "PVS source is unavailable for theory ~a" (id theory))))))

(defun sal-check-library-sources (files)
  "Validate copied bridge libraries and return their authoritative source paths."
  (loop for file in files
        for canonical = (merge-pathnames
                         (concatenate 'string "theories/" (file-namestring file))
                         *sal-backend-directory*)
        when (probe-file canonical)
          collect (progn
                    (unless (string= (uiop:read-file-string file)
                                     (uiop:read-file-string canonical))
                      (error "Copied SAL bridge library changed: ~a; regenerate the view." file))
                    (truename canonical))))

(defun sal-register-proof-target (target-id theory declaration source assertion
                                 &key view module dependencies (kind :invariant))
  "Bind a translated SAL invariant to its exact typechecked PVS declaration.

This is the trusted frontend's registration API, not a tactic for selecting an
arbitrary SAL theorem to discharge a PVS goal.  VIEW must be the elaborated view
that generated THEORY.  Reimport and register after changing any source file.
DEPENDENCIES lists additional SAL source files; frontend admission must reject
untracked imported contexts.  Native PVS source dependencies are captured here."
  (let* ((theory (if (typep theory 'module) theory (get-theory theory)))
         (decl (if (typep declaration 'formula-decl) declaration
                   (and theory
                        (find-if (lambda (d) (and (formula-decl? d)
                                                 (string= (string declaration)
                                                          (string (id d)))))
                                 (theory theory)))))
         (source (or (probe-file source) (error "SAL source missing: ~a" source))))
    (unless (and theory decl (formula-decl? decl) (eq (module decl) theory)
                 (typechecked? theory) (typechecked? decl))
      (error "SAL target must name an existing typechecked theorem: ~a/~a"
             theory declaration))
    (unless (and (sal-transition-view-p view)
                 (eq kind :invariant)
                 (equal (truename source) (truename (sal-transition-view-source view)))
                 (string= (uiop:read-file-string source)
                          (sal-transition-view-source-text view))
                 (sal-transition-view-source-snapshots view)
                 (sal-snapshots-current-p (sal-transition-view-source-snapshots view))
                 (string= (string (id theory)) (sal-transition-view-theory-name view))
                 (string= (string (id decl)) (sal-pvs-name assertion))
                 (sal-safety-property-p
                  (cdr (assoc assertion (sal-transition-view-properties view) :test #'string=)))
                 (or (null module)
                     (string= module (sal-transition-view-module-name view)))
                 (equal (truename (sal-theory-source-file theory))
                        (truename (sal-transition-view-pvs-file view)))
                 (stringp (sal-transition-view-pvs-text view))
                 (string= (uiop:read-file-string (sal-transition-view-pvs-file view))
                          (sal-transition-view-pvs-text view))
                 (every (lambda (pair)
                          (and (probe-file (car pair))
                               (string= (uiop:read-file-string (car pair)) (cdr pair))))
                        (sal-transition-view-context-pvs-texts view)))
      (error "SAL target does not belong to the supplied generated transition view."))
    (when (or (formals theory) (formals decl) (decl-formals decl))
      (error "SAL proof targets must be closed concrete instances, not parameterized declarations."))
    (let ((refusal (sal-view-backend-refusal view)))
      (when refusal (error "~a" refusal)))
    (ensure-closed-definition decl)
    (let* ((theories (remove-duplicates (cons theory (all-importings theory)) :test #'eq))
           (files (remove nil (mapcar #'sal-theory-source-file theories)))
           (library-sources (sal-check-library-sources files))
           (rc (sal-user-configuration-path))
           (snapshots
            (append (sal-transition-view-source-snapshots view)
                    (mapcar #'sal-file-snapshot
                            (remove-duplicates
                             (append dependencies files library-sources (and rc (list rc)))
                             :test #'equal))))
           (tccs (loop for th in theories unless (from-prelude? th)
                       append (collect-tccs th)))
           (target (make-sal-proof-target
                    :id (sal-proof-target-key target-id) :theory theory
                    :declaration decl :formula (closed-definition decl)
                    :source source :assertion assertion :view view :kind kind
                    :module (or module (sal-transition-view-module-name view))
                    :selector (sal-transition-view-selector view)
                    :snapshots snapshots
                    :dependencies
                    (remove-duplicates
                     (append (sal-transition-view-dependency-files view) dependencies)
                     :test #'equal)
                    :tccs tccs)))
      (setf (gethash (sal-proof-target-id target) *sal-proof-targets*) target)
      target)))

(defun sal-target-unfinished-tccs (target)
  (remove-if (lambda (decl)
               (and (proved? decl) (string= (pc-complete decl) "complete")))
             (sal-proof-target-tccs target)))

(defun sal-target-refusal (target proofstate)
  "Return a refusal reason, or NIL for an exact, current, admissible goal."
  (cond
    ((null target) "Unknown SAL proof target; import, typecheck, and register the source first.")
    ((not (sal-snapshots-current-p (sal-proof-target-snapshots target)))
     "A SAL/PVS source or SAL configuration file changed; reimport and typecheck before replay.")
    ((not (eq (sal-proof-target-theory target)
              (get-theory (id (sal-proof-target-theory target)))))
     "The PVS theory was reloaded; register the newly typechecked view before replay.")
    ((not (and (typechecked? (sal-proof-target-theory target))
               (typechecked? (sal-proof-target-declaration target))))
     "The PVS declaration is no longer typechecked; reimport and typecheck before replay.")
    ((not (and *top-proofstate*
               (eq (declaration *top-proofstate*) (sal-proof-target-declaration target))))
     "This is not the PVS declaration registered for that SAL assertion.")
    ((let* ((sequent (current-goal proofstate)) (forms (s-forms sequent)))
       (not (and (= (length forms) 1) (null (hidden-s-forms sequent))
                 (null (neg-s-forms forms))
                 (tc-eq (formula (first forms)) (sal-proof-target-formula target)))))
     "The goal changed; sal-check only accepts the original singleton safety sequent.")
    ((sal-target-unfinished-tccs target)
     (format nil "Unproved native PVS TCCs remain: ~{~a~^, ~}."
             (mapcar #'id (sal-target-unfinished-tccs target))))
    (t nil)))

(defun sal-check-rule (target-id backend depth)
  (lambda (proofstate)
    (block sal-check-rule-result
     (handler-case
        (let* ((target (gethash (sal-proof-target-key target-id) *sal-proof-targets*))
               (refusal (sal-target-refusal target proofstate)))
          (when refusal
            (commentary "SAL: ~a" refusal)
            (return-from sal-check-rule-result (values 'X nil nil)))
          ;; Only finite-state exhaustive checking and finite BMC induction are
          ;; admitted here.  Infinite BMC remains available as a diagnostic API:
          ;; its treatment of subtype constraints needs a separate exactness audit.
          (unless (member backend '(:smc :bmc))
            (commentary "SAL: proof closure currently admits :smc and :bmc induction only.")
            (return-from sal-check-rule-result (values 'X nil nil)))
          (let ((result (sal-run-check (sal-proof-target-source target)
                                      (sal-proof-target-assertion target)
                                      :backend backend :depth depth
                                      :induction (eq backend :bmc)
                                      :module (sal-proof-target-module target)
                                      :selector (sal-proof-target-selector target)
                                      :dependencies (sal-proof-target-dependencies target))))
            (setf (sal-proof-target-last-result target) result)
            (commentary "SAL ~a: ~a (~a), result ~a."
                        backend (sal-proof-target-source target)
                        (sal-proof-target-assertion target)
                        (sal-check-result-outcome result))
            (if (and (eq (sal-check-result-outcome result) :proved)
                     (sal-check-result-exact-p result)
                     (sal-snapshots-current-p (sal-proof-target-snapshots target)))
                (progn
                  (commentary "Accepted by the experimental trusted SAL rule; no proof evidence was reconstructed.")
                  (values '! nil
                          (list 'dependent-decls
                                (remove-duplicates
                                 (append (sal-proof-target-tccs target)
                                         (sal-proof-target-proof-dependencies target))
                                 :test #'eq))))
                (progn
                  (commentary "Goal remains open. Use (sal-show-check) for the retained SAL output.")
                  (values 'X nil nil)))))
      (error (condition)
        (commentary "SAL check refused: ~a" condition)
        (values 'X nil nil))))))

(addrule 'sal-check (target) ((backend :smc) (depth 10))
  (sal-check-rule target backend depth)
  "Check the exact registered SAL safety theorem with the experimental trusted
SAL backend. Refuses modified goals, stale source, unproved typing TCCs, and
inexact/unknown results. :smc is exhaustive; :bmc requests k-induction. Evidence
reconstruction is not implemented. Example: (sal-check \"counter/bounded\")."
  "Checking registered SAL target ~a")

(addrule 'sal-show-check () ()
  (lambda (proofstate)
    (declare (ignore proofstate))
    (commentary "~a" (with-output-to-string (stream)
                          (sal-print-check-result *sal-last-check-result* stream)))
    (values 'X nil nil))
  "Display the latest SAL backend result and source counterexample without changing the goal."
  "Showing retained SAL output")

(addrule 'sal-source () ()
  (lambda (proofstate)
    (declare (ignore proofstate))
    (let ((target
           (and *top-proofstate*
                (loop for target being the hash-values of *sal-proof-targets*
                      when (eq (sal-proof-target-declaration target)
                               (declaration *top-proofstate*))
                      return target))))
      (if (and target (eq (sal-proof-target-kind target) :pvs-invariant))
          (commentary "Native PVS theorem ~a; extracted SAL machine: ~a"
                      (sal-proof-target-id target) (sal-proof-target-source target))
          (if target
          (progn
            (commentary "Original SAL theorem (transformed sequents remain PVS):")
            (commentary "~a"
                        (with-output-to-string (stream)
                          (sal-show-source (sal-proof-target-view target)
                                           (id (sal-proof-target-declaration target))
                                           stream))))
          (commentary "This declaration has no registered SAL source theorem."))))
    (values 'X nil nil))
  "Display the original source theorem and source location for the current SAL
proof target. This is an origin view; it does not backtranslate transformed PVS
sequents. It never changes the goal."
  "Showing original SAL theorem")

(export '(sal-register-proof-target sal-proof-target sal-proof-target-last-result
          sal-target-unfinished-tccs sal-safety-property-p
          sal-view-backend-refusal
          sal-check sal-show-check sal-source *sal-proof-targets*))
