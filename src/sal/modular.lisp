;;; Hierarchical SAL elaboration into native PVS module theories.
(in-package :pvs)

(defstruct sal-structural-module context name parameters variables body properties)
(defvar *sal-modular-stream*)
(defvar *sal-modular-view*)
(defvar *sal-modular-names*)
(defvar *sal-pvs-state-projections* nil)

(defun sal-read-structural-modules (view xml)
  (let ((known (make-hash-table :test #'equal)))
    (dolist (ctx (sal-transition-view-contexts view))
      (setf (gethash (sal-declaration-name ctx) known) ctx))
    (setf (sal-transition-view-structural-modules view)
          (loop for entry in (sal-xml-elements (sal-xml-child (sal-view-read-xml xml) "STRUCTURALMODULES" t))
                for context = (gethash (sal-xml-attribute entry "CONTEXT") known)
                for state = (sal-view-xml-state context)
                collect
                (progn
                  (setf (sal-xml-state-external-contexts state) known)
                  (let ((nodes (sal-xml-elements (sal-xml-child entry "MODULEPARAMETERS" t))))
                    (multiple-value-bind (parameters scope)
                        (sal-predeclare-locals state nodes 'sal-var-decl)
                      (sal-call-with-scope state scope
                        (lambda ()
                          (sal-populate-local-types state nodes parameters)
                          (let* ((var-nodes (sal-xml-elements (sal-xml-child entry "STATEVARS" t)))
                                 (vars (mapcar (lambda (n) (sal-make-state-var state n)) var-nodes))
                                 (fields (make-hash-table :test #'equal)))
                            (dolist (v vars) (sal-scope-bind fields :value v))
                            (sal-call-with-scope state fields
                              (lambda ()
                                (loop for n in var-nodes for v in vars do (sal-populate-state-var state n v))
                                (make-sal-structural-module
                                 :context context :name (sal-xml-attribute entry "NAME")
                                 :parameters parameters :variables vars
                                 :properties (mapcar (lambda (p) (cons (sal-xml-attribute p "NAME")
                                                         (sal-convert-expression state (first (sal-xml-elements p)))))
                                                     (sal-xml-elements (sal-xml-child entry "PROPERTIES" t)))
                                 :body (sal-convert-module state
                                         (first (sal-xml-elements (sal-xml-child entry "STRUCTURE" t))))))))))))))))
  view)

(defun sal-modular-theory-name (m)
  (format nil "~a__~a" (sal-pvs-name (sal-declaration-name (sal-structural-module-context m)))
          (sal-pvs-name (sal-structural-module-name m))))

(defun sal-modular-find (context name)
  (or (find-if (lambda (m) (and (eq context (sal-structural-module-context m))
                               (string= name (sal-structural-module-name m))))
               (sal-transition-view-structural-modules *sal-modular-view*))
      (error "Missing structural module ~a!~a" (sal-declaration-name context) name)))

(defun sal-modular-properties (view module)
  (declare (ignore view))
  (sal-structural-module-properties module))

(defun sal-modular-emit (name text origin)
  (sal-pvs-write-declaration *sal-modular-stream* name text origin))

(defun sal-modular-and (items) (sal-pvs-infix "AND" items))
(defun sal-modular-or (items) (sal-pvs-infix "OR" items "FALSE"))
(defun sal-modular-fresh (stem)
  (loop for n from 1
        for name = (if (= n 1) stem (format nil "~a_~d" stem n))
        unless (gethash name *sal-modular-names*) do
          (setf (gethash name *sal-modular-names*) t)
          (return name)))
(defun sal-modular-args (binders)
  (if binders (format nil ", ~a" (sal-pvs-join (mapcar #'sal-pvs-binding-name binders) ", ")) ""))
(defun sal-modular-formals (binders)
  (if binders (format nil ", ~a" (sal-pvs-bindings binders)) ""))

(defun sal-modular-definition (definition guard-name binders stem &optional (guard-binders binders))
  "Give assignment values native result types, under their command's guard."
  (typecase definition
    (sal-for-all-definition
     (let ((more (local-decls definition)))
       (format nil "FORALL (~a): ~a" (sal-pvs-bindings more)
               (sal-modular-and
                (mapcar (lambda (d) (sal-modular-definition d guard-name (append binders more) stem guard-binders))
                        (definitions definition))))))
    (sal-simple-selection-definition
     (let* ((value (sal-pvs-expression (lhs definition)))
            (predicate (rhs definition))
            (ty (sal-pvs-unalias-type (sal-pvs-expression-type predicate)))
            (domain (if (and (typep predicate 'sal-lambda) (= (length (local-decls predicate)) 1))
                        (type (first (local-decls predicate)))
                        (and (typep ty 'sal-function-type) (domain ty)))))
       (unless domain
         (sal-elaboration-fail definition "Selection needs a predicate type"))
       ;; Equal domains need no existential witness. This is also important for
       ;; large symbolic models whose unconstrained IN assignments are total.
       (let* ((same-domain (equal (sal-pvs-type domain)
                                 (sal-pvs-type (sal-pvs-expression-type (lhs definition)))))
              (body (if same-domain
                        (format nil "(~a)(~a)" (sal-pvs-expression predicate) value)
                        (format nil "EXISTS (choice: ~a): choice = ~a AND (~a)(choice)"
                                (sal-pvs-type domain) value (sal-pvs-expression predicate)))))
         ;; Check each selection under its guard, independently of the other
         ;; simultaneous assignments. An inconsistent sibling must not hide a
         ;; partial predicate or array index from the PVS typechecker.
         (if (and same-domain (sal-pvs-total-helper-value-p (lhs definition))
                  (typep predicate 'sal-lambda)
                  (member (sal-pvs-type domain) '("bool" "real") :test #'equal)
                  (sal-pvs-total-helper-value-p (expr predicate)))
             body
             (let ((name (sal-modular-fresh (format nil "~a_selection" stem))))
               (sal-modular-emit name
                 (format nil "~a(s: State~a, next: ~a): bool =~%    ~a"
                         name (sal-modular-formals binders)
                         (if guard-name
                             (format nil "{candidate: State | ~a(s, candidate~a)}"
                                     guard-name (sal-modular-args guard-binders))
                             "State") body) definition)
               (format nil "~a(s~a, next)" name (sal-modular-args binders)))))))
    (sal-simple-definition
     (let* ((lhs (lhs definition)) (rhs (rhs definition))
            (target-type (sal-pvs-expression-type lhs))
            (name (sal-modular-fresh (format nil "~a_value" stem)))
            (arguments (sal-modular-args binders)))
       (unless target-type (sal-elaboration-fail definition "Assignment target has no type"))
       (when (and (member (sal-pvs-type target-type) '("bool" "real") :test #'equal)
                  (sal-pvs-total-helper-value-p lhs) (sal-pvs-total-helper-value-p rhs))
         (return-from sal-modular-definition
           (format nil "~a = ~a" (sal-pvs-expression lhs) (sal-pvs-expression rhs))))
       (sal-modular-emit name
         (format nil "~a(s: State~a, next: ~a): ~a =~%    ~a"
                 name (sal-modular-formals binders)
                 (if guard-name
                     (format nil "{candidate: State | ~a(s, candidate~a)}"
                             guard-name (sal-modular-args guard-binders))
                     "State")
                 (sal-pvs-type target-type) (sal-pvs-expression rhs)) definition)
       (let ((location (sal-pvs-expression lhs)))
         (unless (sal-pvs-total-helper-value-p lhs)
           (let ((target (sal-modular-fresh (format nil "~a_target" stem))))
             (sal-modular-emit target
               (format nil "~a(s: State~a, next: ~a): ~a =~%    ~a"
                       target (sal-modular-formals binders)
                       (if guard-name
                           (format nil "{candidate: State | ~a(s, candidate~a)}"
                                   guard-name (sal-modular-args guard-binders))
                           "State")
                       (sal-pvs-type target-type) location) definition)
             (setf location (format nil "~a(s~a, next)" target arguments))))
         (format nil "~a = ~a(s~a, next)" location name arguments))))
    (t (sal-elaboration-fail definition "Unknown structural definition ~a" (type-of definition)))))

(defun sal-modular-command-guard (command &optional hoist)
  (typecase command
    (sal-labeled-command (sal-modular-command-guard (command command) hoist))
    (sal-multi-command
     (format nil "EXISTS (~a): ~a" (sal-pvs-bindings (local-decls command))
             (sal-modular-command-guard (command command))))
    (sal-guarded-command (if hoist (sal-pvs-relation-expression (guard command) t)
                              (sal-pvs-expression (guard command))))
    (t "TRUE")))

(defun sal-modular-command (command phase &optional binders name else-guard)
  (typecase command
    (sal-labeled-command
     (sal-modular-command (command command) phase binders
                         (sal-pvs-name (label command)) else-guard))
    (sal-multi-command
     (let ((more (local-decls command)))
       (format nil "EXISTS (~a): ~a" (sal-pvs-bindings more)
               (sal-modular-command (command command) phase (append binders more) name else-guard))))
    ((or sal-guarded-command sal-else-command)
     (let* ((name (sal-modular-fresh (or name phase)))
            (guard-name (sal-modular-fresh (format nil "~a_enabled" name)))
            (guard (or else-guard (sal-modular-command-guard command (null binders))))
            (args (sal-modular-args binders))
            (formals (sal-modular-formals binders)))
       (sal-modular-emit guard-name
         (format nil "~a(s, next: State~a): bool = ~a" guard-name formals guard) command)
       (let ((body (sal-modular-and
                    (mapcar (lambda (d) (sal-modular-definition d guard-name binders name))
                            (assignments command)))))
         (sal-modular-emit name
           (format nil "~a(s, next: State~a): bool =~%    ~a(s, next~a) AND ~a"
                   name formals guard-name args body) command))
       (format nil "~a(s, next~a)" name args)))
    (t (sal-elaboration-fail command "Unknown structural command ~a" (type-of command)))))

(defun sal-modular-section (definitions section phase &optional binders)
  (let ((parts nil))
    (when definitions
      (setf parts (mapcar (lambda (d) (sal-modular-definition d nil binders phase)) definitions)))
    (when section
      (let* ((commands (commands section))
             (arms (mapcar (lambda (c) (sal-modular-command c phase binders)) commands)))
        (when (else-command section)
          (setf arms (append arms
                       (list (sal-modular-command (else-command section) phase binders
                               (format nil "~a_else" phase)
                               (format nil "NOT (~a)" (sal-modular-or (mapcar #'sal-modular-command-guard commands))))))))
        (push (if arms (sal-modular-or arms) "TRUE") parts)))
    (sal-modular-and parts)))

(defun sal-modular-lhs-variable (lhs)
  (typecase lhs
    (sal-name-expr (decl lhs))
    (sal-next-operator (sal-modular-lhs-variable (name-expr lhs)))
    (sal-application (sal-modular-lhs-variable (fun lhs)))
    (sal-selection (sal-modular-lhs-variable (target lhs)))
    (t (sal-elaboration-fail lhs "Invalid assignment target"))))

(defun sal-modular-location (name mapping state)
  (let ((entry (assoc name mapping :test #'equal)))
    (if entry (funcall (cdr entry) state)
        (format nil "~a`~a" state (sal-pvs-name name)))))

(defun sal-modular-rebind (expression mapping)
  (lambda (state)
    (let ((*sal-pvs-state* state) (*sal-pvs-state-projections* mapping))
      (sal-pvs-expression expression))))

(defun sal-modular-child-map (child mapping &optional sibling position index)
  (loop for v in (state-vars child)
        for name = (sal-declaration-name v)
        collect
        (let ((name name)
              (local (and (typep v 'sal-local-state-var-decl)
                          (or index (find name (state-vars sibling)
                                          :key #'sal-declaration-name :test #'equal)))))
          (cons name
                (lambda (state)
                  (let ((location (sal-modular-location name mapping state)))
                    (cond ((and local index) (format nil "(~a)(~a)" location (sal-pvs-binding-name index)))
                          (local (format nil "(~a)`~d" location position))
                          (t location))))))))

(defun sal-modular-base (node &optional mapping binders prefix)
  (let* ((*sal-pvs-state-declarations* (state-vars node))
         (*sal-pvs-state-projections* mapping)
         (defined-vars nil)
         (defs (sal-modular-section (definitions node) nil "definition" binders))
         (init (sal-modular-section (initialization-definitions node)
                                    (initialization-command-section node) "initialize" binders))
         (step (sal-modular-section (transition-definitions node)
                                    (transition-command-section node) "transition" binders))
         (defined-name (if prefix (sal-modular-fresh (concatenate 'string prefix "_defined")) "defined"))
         (initial-name (if prefix (sal-modular-fresh (concatenate 'string prefix "_initial")) "initial"))
         (step-name (if prefix (sal-modular-fresh (concatenate 'string prefix "_step")) "step"))
         (idle-name (if prefix (sal-modular-fresh (concatenate 'string prefix "_idle")) "idle"))
         (formals (sal-modular-formals binders))
         (args (sal-modular-args binders)))
    (dolist (d (definitions node))
      (sal-walk-ast (lambda (x)
                      (when (typep x 'sal-simple-definition)
                        (pushnew (sal-declaration-name (sal-modular-lhs-variable (lhs x))) defined-vars :test #'equal))) d))
    (sal-modular-emit defined-name
      (format nil "~a(s: State~a): bool =~%    ~a" defined-name formals
              (if (equal defs "TRUE") "TRUE" (format nil "LET next = s IN ~a" defs))) node)
    (sal-modular-emit initial-name
      (format nil "~a(s: State~a): bool =~%    ~a(s~a) AND (LET next = s IN ~a)"
              initial-name formals defined-name args init) node)
    (sal-modular-emit step-name
      (format nil "~a(s, next: State~a): bool =~%    ~a(s~a) AND ~a(next~a) AND ~a"
              step-name formals defined-name args defined-name args step) node)
    (sal-modular-emit idle-name
      (format nil "~a(s, next: State~a): bool =~%    ~a(s~a) AND ~a(next~a) AND ~a"
              idle-name formals defined-name args defined-name args
              (sal-modular-and
               (loop for v in (state-vars node)
                     for name = (sal-declaration-name v)
                     unless (or (typep v '(or sal-input-state-var-decl sal-global-state-var-decl))
                                (member name defined-vars :test #'equal))
                       collect (format nil "~a = ~a" (sal-modular-location name mapping "next")
                                       (sal-modular-location name mapping "s"))))) node)
    (if binders
        (format nil "(# defined := LAMBDA (s: State): ~a(s~a), init := LAMBDA (s: State): ~a(s~a), step := LAMBDA (s, next: State): ~a(s, next~a), idle := LAMBDA (s, next: State): ~a(s, next~a) #)"
                defined-name args initial-name args step-name args idle-name args)
        (format nil "(# defined := ~a, init := ~a, step := ~a, idle := ~a #)"
                defined-name initial-name step-name idle-name))))

(defun sal-modular-projection (expression mapping)
  (let ((*sal-pvs-state-projections* mapping)) (sal-pvs-expression expression)))

(defun sal-modular-frame (names mapping)
  (format nil "LAMBDA (s, next: State): ~a"
          (sal-modular-and
           (mapcar (lambda (name) (format nil "~a = ~a"
                              (sal-modular-location name mapping "next")
                              (sal-modular-location name mapping "s"))) names))))

(defun sal-modular-other-globals (parent child)
  (loop for v in (state-vars parent)
        for name = (sal-declaration-name v)
        when (and (typep v 'sal-global-state-var-decl)
                  (not (find-if (lambda (c) (and (typep c 'sal-global-state-var-decl)
                                                 (equal name (sal-declaration-name c)))) (state-vars child))))
          collect name))

(defun sal-modular-compose (node mapping &optional binders)
  (typecase node
    (sal-base-module
     (sal-modular-base node mapping binders (sal-modular-fresh "component")))
    (sal-module-instance
     (let* ((ref (module-name node))
            (owner (context (decl ref)))
            (m (sal-modular-find owner (sal-declaration-name (decl ref))))
            (actuals (append (if (typep ref 'sal-qualified-module-name) (actuals ref)
                                (mapcar (lambda (p) (make-instance 'sal-name-expr :decl p)) (params owner)))
                             (actuals node)))
            (instance (format nil "~a~a" (sal-modular-theory-name m)
                              (if actuals (format nil "[~a]" (sal-pvs-join (mapcar #'sal-pvs-actual actuals) ", ")) "")))
            (project (sal-modular-fresh (format nil "~a_state" (sal-pvs-name (sal-structural-module-name m)))))
            (args (sal-modular-args binders)))
       (sal-pvs-note-origin (concatenate 'string "import_" (sal-modular-theory-name m)) node)
       (format *sal-modular-stream* "  IMPORTING ~a~%~%"
               (if binders (sal-modular-theory-name m) instance))
       (sal-modular-emit project
         (format nil "~a(s: State~a): ~a.State =~%    ~a"
                 project (sal-modular-formals binders) instance
                 (if (sal-structural-module-variables m)
                     (format nil "(# ~a #)" (sal-pvs-join
                  (loop for v in (sal-structural-module-variables m)
                        for name = (sal-declaration-name v)
                        collect (format nil "~a := ~a" (sal-pvs-name v)
                                        (sal-modular-location name mapping "s"))) ", "))
                     (format nil "~a.bridge_unit" instance))) node)
       (let* ((component (sal-modular-fresh
                          (format nil "~a_~a" (sal-pvs-name (sal-structural-module-name m))
                                  (if binders "at" "component"))))
              (parameters (if binders (format nil "(~a)" (sal-pvs-bindings binders)) ""))
              (arguments (if binders (format nil "(~a)" (sal-pvs-join (mapcar #'sal-pvs-binding-name binders) ", ")) "")))
         (sal-modular-emit component
           (format nil "~a~a: SAL_Module[State].Module =~%    SAL_Module_Lift[State, ~a.State,~%      LAMBDA (s: State): ~a(s~a)].lift(~a.machine)"
                   component parameters instance project args instance) node)
         (concatenate 'string component arguments))))
    (sal-with-module (sal-modular-compose (module node) mapping binders))
    (sal-renaming
     (sal-modular-compose
      (module node)
      (append (mapcar (lambda (r) (cons (sal-identifier-text (from-name r))
                                      (sal-modular-rebind (to-expr r) mapping))) (renames node)) mapping)
      binders))
    (sal-hiding (sal-modular-compose (module node) mapping binders))
    (sal-new-output
     (format nil "SAL_Module[State].frame_idle(~a, ~a)"
             (sal-modular-compose (module node) mapping binders)
             (sal-modular-frame (mapcar #'sal-identifier-text (identifiers node)) mapping)))
    (sal-module-composition
     (let ((left (sal-modular-compose (module1 node)
                    (sal-modular-child-map (module1 node) mapping (module2 node) 1) binders))
           (right (sal-modular-compose (module2 node)
                    (sal-modular-child-map (module2 node) mapping (module1 node) 2) binders)))
       (when (typep node 'sal-asynch-composition)
         (let ((left-frame (sal-modular-other-globals node (module1 node)))
               (right-frame (sal-modular-other-globals node (module2 node))))
           (when left-frame
             (setf left (format nil "SAL_Module[State].frame_step(~a, ~a)"
                                left (sal-modular-frame left-frame mapping))))
           (when right-frame
             (setf right (format nil "SAL_Module[State].frame_step(~a, ~a)"
                                 right (sal-modular-frame right-frame mapping))))))
       (format nil "SAL_Module[State].~a(~a,~%      ~a)"
               (if (typep node 'sal-asynch-composition) "asynchronous" "synchronous") left right)))
    (sal-multi-composition
     (let* ((more (local-decls node))
            (declarations (sal-pvs-bindings more))
            (body (sal-modular-compose (module node)
                    (sal-modular-child-map (module node) mapping nil nil (first more))
                    (append binders more))))
       (unless (= (length more) 1) (sal-elaboration-fail node "Indexed composition expects one binder"))
       (format nil "SAL_Indexed_Module[State, ~a].~a(~%      LAMBDA (~a): ~a)"
               (sal-pvs-type (type (first more)))
               (if (typep node 'sal-multi-asynch-composition) "asynchronous" "synchronous") declarations body)))
    (t (sal-elaboration-fail node "Unknown structural module ~a" (type-of node)))))

(defun sal-modular-formal-text (module view)
  (let ((local (copy-sal-transition-view view)))
    (setf (sal-transition-view-context local) (sal-structural-module-context module)
          (sal-transition-view-module-parameters local) (sal-structural-module-parameters module)
          (sal-transition-view-contexts local)
          (cons (sal-structural-module-context module)
                (sal-pvs-context-dependencies (sal-structural-module-context module))))
    (sal-pvs-view-formal-text local)))

(defun sal-render-structural-module (m view)
  (let* ((*sal-modular-view* view)
         (*sal-modular-names* (make-hash-table :test #'equal))
         (*sal-pvs-readable-names* t)
         (*sal-pvs-context* (sal-structural-module-context m))
         (*sal-pvs-origin-table* (sal-transition-view-origins view))
         (*sal-pvs-origin-prefix* (sal-modular-theory-name m))
         (*sal-pvs-local-names* (make-hash-table :test #'eq))
         (*sal-pvs-pending-helpers* nil)
         (*sal-pvs-fresh-counter* 0)
         (*sal-pvs-state-declarations* (sal-structural-module-variables m))
         (name *sal-pvs-origin-prefix*)
         (*sal-pvs-system-alias* (format nil "~a_semantics" name))
         (*sal-pvs-ctl-alias* (format nil "~a_ctl" name)))
    (dolist (table (list (constant-declarations *sal-pvs-context*)
                        (type-declarations *sal-pvs-context*)))
      (maphash (lambda (key value)
                 (declare (ignore value))
                 (setf (gethash (sal-pvs-name key) *sal-modular-names*) t)) table))
    (dolist (parameter (append (params *sal-pvs-context*)
                              (sal-structural-module-parameters m)))
      (setf (gethash (sal-pvs-name parameter) *sal-modular-names*) t))
    (dolist (property (sal-modular-properties view m))
      (setf (gethash (sal-pvs-name (car property)) *sal-modular-names*) t))
    (sal-walk-ast
     (lambda (node)
       (when (typep node 'sal-var-decl)
         (setf (gethash (sal-pvs-name node) *sal-modular-names*) t)))
     (sal-structural-module-body m))
    (with-output-to-string (*sal-modular-stream*)
      (format *sal-modular-stream* "~a~a: THEORY~%BEGIN~%  IMPORTING ~a~%~%"
              name (sal-modular-formal-text m view) (sal-pvs-context-instance *sal-pvs-context* nil))
      (sal-modular-emit "State"
        (if (sal-structural-module-variables m)
            (format nil "State: TYPE = [# ~a #]"
                (sal-pvs-join (mapcar (lambda (v) (format nil "~a: ~a" (sal-pvs-name v) (sal-pvs-type (type v))))
                                     (sal-structural-module-variables m)) ", "))
            "State: TYPE = {bridge_unit}") (sal-structural-module-body m))
      (format *sal-modular-stream* "  s, next: VAR State~%~%")
      (format *sal-modular-stream* "  IMPORTING SAL_Module[State]~a~%~%"
              (if (typep (sal-structural-module-body m) 'sal-base-module) ""
                  ", SAL_Module_Lift, SAL_Indexed_Module"))
      (let ((value (if (typep (sal-structural-module-body m) 'sal-base-module)
                       (sal-modular-base (sal-structural-module-body m))
                       (sal-modular-compose (sal-structural-module-body m) nil))))
        (sal-modular-emit "machine" (format nil "machine: SAL_Module[State].Module =~%    ~a" value) (sal-structural-module-body m)))
      (unless (typep (sal-structural-module-body m) 'sal-base-module)
        (format *sal-modular-stream* "  defined(s: State): bool = machine`defined(s)~%  initial(s: State): bool = machine`init(s)~%  step(s, next: State): bool = machine`step(s, next)~%  idle(s, next: State): bool = machine`idle(s, next)~%~%"))
      (format *sal-modular-stream* "  IMPORTING SAL_Transition_System[State, initial, step] AS ~a~%~%" *sal-pvs-system-alias*)
      (when (some (lambda (property) (sal-pvs-ctl-p (cdr property))) (sal-modular-properties view m))
        (format *sal-modular-stream* "  IMPORTING SAL_CTL[State, step] AS ~a~%~%" *sal-pvs-ctl-alias*))
      (dolist (property (sal-modular-properties view m))
        (sal-modular-emit (sal-pvs-name (car property))
          (format nil "~a: THEOREM ~a" (sal-pvs-name (car property)) (sal-pvs-property-body (cdr property)))
          (gethash (car property) (assertion-declarations *sal-pvs-context*))))
      (format *sal-modular-stream* "END ~a~%" name))))

(defun sal-elaborate-modular-view (view directory &key (progress-checks t))
  (let* ((*sal-modular-view* view) (*sal-pvs-readable-names* t)
         (directory (uiop:ensure-directory-pathname (sal-bridge-output-path directory)))
         (m (sal-modular-find (sal-transition-view-context view) (sal-transition-view-module-name view)))
         (contexts (mapcar (lambda (c) (cons (merge-pathnames (format nil "~a.pvs" (sal-pvs-context-theory-name c)) directory)
                                           (sal-pvs-render-context c view))) (sal-transition-view-contexts view)))
         (modules (mapcar (lambda (mod) (cons (merge-pathnames (format nil "~a.pvs" (sal-modular-theory-name mod)) directory)
                                            (sal-render-structural-module mod view)))
                          (sal-transition-view-structural-modules view)))
         (file (merge-pathnames (format nil "~a.pvs" (sal-modular-theory-name m)) directory)))
    (setf (sal-transition-view-source-module view) (sal-structural-module-body m)
          (sal-transition-view-module-parameters view) (sal-structural-module-parameters m)
          (sal-transition-view-theory-name view) (sal-modular-theory-name m)
          (sal-transition-view-pvs-file view) file
          (sal-transition-view-pvs-text view) (cdr (assoc file modules :test #'equal))
          (sal-transition-view-context-pvs-files view) (mapcar #'car (append contexts modules))
          (sal-transition-view-context-pvs-texts view) (append contexts modules)
          (sal-transition-view-properties view) (sal-modular-properties view m)
          (sal-transition-view-property-origins view)
          (mapcar (lambda (p) (cons (car p) (gethash (car p) (assertion-declarations (sal-transition-view-context view)))))
                  (sal-transition-view-properties view)))
    (sal-prepare-output-directory directory)
    (dolist (pair (append contexts modules)) (sal-write-file-if-changed (car pair) (cdr pair)))
    (when progress-checks
      (let* ((text (sal-pvs-render-progress-view view))
             (file (merge-pathnames (format nil "~a.pvs" (sal-transition-view-progress-theory-name view)) directory)))
        (sal-write-file-if-changed file text)
        (setf (sal-transition-view-progress-pvs-file view) file)))
    view))

(defun sal-write-modular-comparison (structured flat directory)
  "Generate state-map and relation equalities between the two real translations."
  (let* ((*sal-pvs-readable-names* t) (*sal-modular-view* structured)
         (m (sal-modular-find (sal-transition-view-context structured)
                              (sal-transition-view-module-name structured)))
         (*sal-pvs-context* (sal-structural-module-context m))
         (*sal-pvs-local-names* (make-hash-table :test #'eq))
         (formals (sal-pvs-view-formals structured))
         (actuals (if formals (format nil "[~a]" (sal-pvs-join (mapcar #'sal-pvs-name formals) ", ")) ""))
         (name (format nil "~a__comparison" (sal-transition-view-theory-name structured)))
         (file (merge-pathnames (format nil "~a.pvs" name) directory)))
    (sal-write-file-if-changed file
      (with-output-to-string (out)
        (format out "~a~a: THEORY~%BEGIN~%  IMPORTING ~a~a AS modular, ~a~a AS flat~%~%"
                name (sal-pvs-formals formals) (sal-transition-view-theory-name structured) actuals
                (sal-transition-view-theory-name flat) actuals)
        (format out "  to_flat(s: modular.State): flat.State =~%    ~a~%~%"
                (if (sal-structural-module-variables m)
                    (format nil "(# ~a #)" (sal-pvs-join
                 (loop for v in (sal-structural-module-variables m)
                       for readable = (sal-pvs-name v)
                       for encoded = (let ((*sal-pvs-readable-names* nil)) (sal-pvs-name v))
                       collect (format nil "~a := s`~a" encoded readable)) ", "))
                    "flat.bridge_unit"))
        (dolist (relation '("defined" "initial" "step" "idle"))
          (let ((binary (member relation '("step" "idle") :test #'equal)))
            (format out "  ~a_equivalent: THEOREM~%    FORALL (s~a: modular.State):~%      modular.~a(s~a) IFF flat.~a(to_flat(s)~a)~%~%"
                    relation (if binary ", t" "") relation (if binary ", t" "") relation
                    (if binary ", to_flat(t)" ""))))
        (format out "END ~a~%" name)))
    file))

(export '(sal-write-modular-comparison))
