;;; Recover a transition-system view from the exact, typechecked PVS theorem.
;;; Definition unfolding uses PVS resolutions, including theory interpretations;
;;; printed names and caller-supplied associations never select the semantics.
(in-package :pvs)

(defun sal-pvs-original-declarations (decl)
  "Include copied interpretation declarations and their source declarations."
  (loop for current = decl then (generated-by current)
        while (declaration? current)
        collect current into result
        when (member (generated-by current) result :test #'eq) do
          (error "Cyclic PVS declaration provenance for ~a" (id decl))
        finally (return result)))

(defun sal-pvs-canonical-invariant-p (decl)
  "Recognize only the invariant owned by the unchanged semantic library."
  (let ((owner (and (declaration? decl) (module decl))))
    (when (and owner
               (string= (string (id owner)) "SAL_Transition_System")
               (string= (string (id decl)) "invariant"))
      (let* ((canonical (merge-pathnames "theories/SAL_Transition_System.pvs"
                                         *sal-bridge-directory*))
             (source (sal-theory-source-file owner))
             (owned (remove-if-not
                     (lambda (d) (and (const-decl? d)
                                      (string= (string (id d)) "invariant")))
                     (theory owner))))
        (unless (and (typechecked? owner) (typechecked? decl) (parsed? owner)
                     (equal (filename owner) "SAL_Transition_System")
                     (null (generated-by decl))
                     (equal owned (list decl))
                     (probe-file canonical)
                     (string= (uiop:read-file-string canonical)
                              (uiop:read-file-string source)))
          (error "PVS-to-SAL requires the unchanged, freshly typechecked SAL_Transition_System.invariant"))
        t))))

(defun sal-pvs-unfold-view-wrapper (expr op)
  "Unfold one typed definition with PVS's native instance substitution."
  (let ((decl (declaration op)))
    (unless (and (const-decl? decl) (definition decl)
                 (not (def-decl? decl)))
      (error "PVS-to-SAL expected a canonical invariant instance; cannot unfold ~a" (str op)))
    (dolist (axiom (create-formulas (resolution op)))
      (multiple-value-bind (bindings rhs) (match-defns expr (list axiom))
        (unless (eq bindings 'fail)
          (return-from sal-pvs-unfold-view-wrapper
            (beta-reduce (substit rhs bindings))))))
    (error "PVS-to-SAL could not instantiate the definition of ~a" (str op))))

(defun sal-pvs-invariant-components (decl)
  "Return S, initial, step, property, and unfolded declarations for DECL.
Only definitional aliases around the canonical invariant are admitted.  The
caller retains DECL's original closed formula for exact proof-goal matching."
  (unless (and (formula-decl? decl) (not (axiom? decl))
               (typechecked? decl) (module decl)
               (typechecked? (module decl))
               (null (formals-sans-usings (module decl)))
               (null (formals decl)) (null (decl-formals decl)))
    (error "PVS-to-SAL requires a concrete, typechecked theorem declaration"))
  (let ((*current-context* (context decl))
        (*generate-tccs* 'none)
        (used nil)
        (seen nil))
    (ensure-closed-definition decl)
    (when (or (freevars (closed-definition decl))
              (free-params (closed-definition decl)))
      (error "PVS-to-SAL requires a closed theorem without free parameters"))
    (loop with expr = (beta-reduce (closed-definition decl))
          repeat 64 do
      (when (some (lambda (old) (tc-eq expr old)) seen)
        (error "PVS-to-SAL encountered a cyclic invariant wrapper"))
      (push expr seen)
      (let* ((op (if (application? expr) (operator expr) expr))
             (res (and (name-expr? op) (resolution op)))
             (op-decl (and res (declaration res))))
        (unless op-decl
          (error "PVS-to-SAL requires a theorem that is a canonical transition-system invariant: ~a" (str expr)))
        (dolist (source-decl (sal-pvs-original-declarations op-decl))
          (pushnew source-decl used :test #'eq))
        (when (sal-pvs-canonical-invariant-p op-decl)
          (let* ((instance (module-instance res))
                 (actuals (and instance (actuals instance))))
            (unless (and (application? expr)
                         (= (length actuals) 3)
                         (null (mappings instance))
                         (null (dactuals instance))
                         (null (free-params expr)))
              (error "PVS-to-SAL requires a fully instantiated, unmapped canonical invariant"))
            (let ((state (actual-value (first actuals)))
                  (initial (actual-value (second actuals)))
                  (step (actual-value (third actuals)))
                  (property (argument expr)))
              (unless (and (type-expr? state) (expr? initial) (expr? step)
                           (expr? property))
                (error "PVS-to-SAL found malformed transition-system actuals"))
              (return-from sal-pvs-invariant-components
                (values state initial step property (nreverse used))))))
        (setf expr (sal-pvs-unfold-view-wrapper expr op))))
    (error "PVS-to-SAL invariant wrapper nesting exceeds 64 definitions")))

(export '(sal-pvs-invariant-components))
