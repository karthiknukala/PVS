;; Read-only SAL frontend export for the PVS bridge. Loaded by salenv.
;; All overrides are local to this short-lived process; no SAL files change.

(define (view/node tag children source)
  (let ((node (make-simple-sxml-node tag children)))
    (when source
      (let* ((place (slot-value source :place))
             (context (sal-ast/context source))
             (file (and context (slot-value context :file-name))))
        (when place (sxml/set-attribute! node 'PLACE (sal-place->string place)))
        (when file (sxml/set-attribute! node 'SOURCEFILE file))))
    node))

(define (view/export-list tag children source)
  (view/node tag (map sal-ast->sxml children) source))

(define (view/builtin-name name source)
  (let ((node (view/node 'NAMEEXPR (list name) source)))
    (sxml/set-attribute! node 'BUILTIN "true")
    node))

(define-method (sal-ast->sxml (ast <sal-qualified-name-expr>))
  ;; SAL's ordinary XML erases prelude qualification. Preserve that identity
  ;; explicitly so a user declaration named max/G/etc. cannot become builtin.
  (if (sal-name-ref/builtin? ast)
      (view/builtin-name (sal-name-ref/name ast) ast)
      (view/node 'QUALIFIEDNAMEEXPR
                 (list (view/node 'IDENTIFIER (list (sal-name-ref/name ast)) ast)
                       (view/node 'CONTEXTNAME
                                  (append
                                   (list (view/node 'IDENTIFIER
                                                    (list (sal-context/name
                                                           (slot-value ast :context-ref))) ast))
                                   (if (null? (slot-value ast :actuals)) '()
                                       (list (view/export-list 'ACTUALPARAMETERS
                                                               (slot-value ast :actuals) ast)))) ast)) ast)))

;; The legacy exporter folds n-ary expressions through mixed AST/SXML values,
;; and spells multiplication '-'. Export their argument tuple directly.
(define (view/application ast operator)
  (view/node 'APPLICATION
             (list (view/builtin-name operator ast)
                   (view/export-list 'TUPLELITERAL
                                     (sal-application/argument-list ast) ast))
             ast))
(define-method (sal-ast->sxml (ast <sal-and>)) (view/application ast 'AND))
(define-method (sal-ast->sxml (ast <sal-or>)) (view/application ast 'OR))
(define-method (sal-ast->sxml (ast <sal-add>)) (view/application ast '+))
(define-method (sal-ast->sxml (ast <sal-mul>)) (view/application ast '*))

(define-method (sal-ast->sxml (ast <sal-ring-application>))
  ;; The native bound accessor expands qualified aliases with their actuals.
  ;; Export that same bound explicitly: looking through the generic source
  ;; declaration in PVS would lose the imported context's type substitution.
  (let* ((operand (slot-value ast :arg))
         (type (sal-expr/type operand))
         (bounded (sal-type->bounded-subtype (sal-type/expand-if-type-name type)))
         (node (view/node 'BRIDGERINGAPPLICATION
                          (list (view/node 'OPERAND (list (sal-ast->sxml operand)) operand)
                                (view/node 'OPERANDTYPE (list (sal-ast->sxml bounded)) operand)) ast)))
    (sxml/set-attribute! node 'OPERATOR
                         (if (instance-of? ast <sal-ring-pre>) "RPRED" "RSUCC"))
    node))

;; Carry compiler distinctions as attributes on ordinary SAL XML expressions.
(define-method (sal-ast->sxml (ast <sal-assignment>))
  (let* ((args (sal-application/argument-list ast))
         (lhs (car args)) (rhs (cadr args)))
    (view/node 'BRIDGEASSIGNMENT
               (list (view/node 'LHS (list (sal-ast->sxml lhs)) lhs)
                     (view/node 'RHS (list (sal-ast->sxml rhs)) rhs)
                     (view/node 'TARGETTYPE (list (sal-ast->sxml (sal-expr/type lhs))) lhs)) ast)))
(define-method (sal-ast->sxml (ast <sal-choice>))
  (let ((node (view/application ast 'OR)))
    (sxml/set-attribute! node 'BRIDGEKIND "choice")
    node))
(define-method (sal-ast->sxml (ast <sal-multi-choice-expr>))
  (let ((node (view/node 'QUANTIFIEDEXPRESSION
                        (list (view/node 'QUANTIFIER '(EXISTS) ast)
                              (view/export-list 'VARDECLS
                                                (slot-value ast :local-decls) ast)
                              (sal-ast->sxml (slot-value ast :expr))) ast)))
    (sxml/set-attribute! node 'BRIDGEKIND "multi-choice")
    node))
(define-method (sal-ast->sxml (ast <sal-in>))
  (let ((node (view/node 'APPLICATION
                         (list (sal-ast->sxml (slot-value ast :fun))
                               (sal-ast->sxml (slot-value ast :arg))) ast)))
    (sxml/set-attribute! node 'BRIDGEKIND "membership")
    node))
(define-method (sal-ast->sxml (ast <sal-definition-expression>))
  ;; Logical meaning is EXPR; LHS metadata is retained separately for checks.
  (let ((node (sal-ast->sxml (slot-value ast :expr))))
    (view/node 'BRIDGEDEFINITION
               (list (view/export-list 'LHS (slot-value ast :lhs-list) ast)
                     node) ast)))

;; These two legacy methods pass AST objects as SXML children.
(define-method (sal-ast->sxml (ast <sal-set-pred-expr>))
  (let ((decl (car (slot-value ast :local-decls))))
    (view/node 'SETPREDEXPRESSION
               (list (sal-ast->sxml (slot-value decl :id))
                     (sal-ast->sxml (slot-value decl :type))
                     (sal-ast->sxml (slot-value ast :expr))) ast)))
(define-method (sal-ast->sxml (ast <sal-for-all-definition>))
  (view/node 'FORALLDEFINITION
             (cons (view/export-list 'VARDECLS (slot-value ast :local-decls) ast)
                   (map sal-ast->sxml (slot-value ast :definitions))) ast))

(define (view/command-section tag definitions command source)
  (if (and (null? definitions) (not command))
      '()
      (list (view/export-list tag
                              (append definitions (if command (list command) '()))
                              source))))
(define-method (sal-ast->sxml (ast <sal-base-module>))
  ;; The legacy method APPENDs a DEFDECL node where a list is required.
  (view/node 'BASEMODULE
             (append (map sal-ast->sxml (slot-value ast :state-vars))
                     (if (null? (slot-value ast :definitions)) '()
                         (list (view/export-list 'DEFDECL
                                                 (slot-value ast :definitions) ast)))
                     (view/command-section 'INITDECL
                                           (slot-value ast :initialization-definitions)
                                           (slot-value ast :initialization-command-section) ast)
                     (view/command-section 'TRANSDECL
                                           (slot-value ast :transition-definitions)
                                           (slot-value ast :transition-command-section) ast)) ast))

(define (view/flat-node flat)
  (view/node 'FLATMODULE
             (cons (view/export-list 'STATEVARS (sal-module/state-variables flat) flat)
                   (map (lambda (pair)
                          (view/node (car pair)
                                     (list (sal-ast->sxml
                                            (slot-value flat (cdr pair)))) flat))
                        '((DEFINITION . :definition)
                          (INITIALIZATION . :initialization)
                          (TRANSITION . :transition)
                          (SKIP . :skip)))) flat))

(define (view/hygienic-flat module)
  ;; Flattening substitutes declaration identities and may introduce a free
  ;; state reference underneath a same-spelled local binder. Native XML carries
  ;; names, so alpha-rename with SAL's own binder-aware operation first.
  (let* ((flat (sal-ast/flat-modules module))
         (renamed (sal-ast/rename-variables flat)))
    (unless (equal? (map sal-decl/name (sal-module/state-variables flat))
                    (map sal-decl/name (sal-module/state-variables renamed)))
      (sign-error "Alpha-renaming unexpectedly changed the state interface" module))
    renamed))

(define (view/context-file context)
  (and context (slot-value context :file-name)))

(define-method (sal-ast->sxml (ast <sal-context-name-decl>))
  (view/node 'CONTEXTDECLARATION
             (list (sal-ast->sxml (slot-value ast :id))
                   (view/node 'CONTEXTNAME
                              (append
                               (list (view/node 'IDENTIFIER
                                                (list (sal-context/name (slot-value ast :context-ref))) ast))
                               (if (null? (slot-value ast :actuals)) '()
                                   (list (view/export-list 'ACTUALPARAMETERS (slot-value ast :actuals) ast)))) ast)) ast))

(define (view/empty-env)
  (make-wt-tree
   (make-wt-tree-type
    (lambda (a b) (< (sal-ast/internal-idx a) (sal-ast/internal-idx b))))))

(define (view/for-each proc roots)
  ;; The native mapper is exported to salenv; its traversal knows binder scopes.
  ;; Return each original node so this read-only walk never rewrites the model.
  (letrec ((walk (lambda (ast env)
                   (proc ast)
                   (cond
                    ((instance-of? ast <sal-type-decl>)
                     (when (slot-value ast :type) (walk (slot-value ast :type) env)))
                    ((instance-of? ast <sal-constant-decl>)
                     (walk (slot-value ast :type) env)
                     (when (slot-value ast :value) (walk (slot-value ast :value) env)))
                    ((instance-of? ast <sal-module-decl>)
                     (walk (slot-value ast :parametric-module) env))
                    ((instance-of? ast <sal-assertion-decl>)
                     (walk (slot-value ast :assertion-expr) env))
                    ((instance-of? ast <sal-context-name-decl>)
                     (for-each (lambda (actual) (walk actual env)) (slot-value ast :actuals)))
                    (else (sal-ast/map ast env walk)))
                   ast)))
    (for-each (lambda (ast) (walk ast (view/empty-env)))
              roots)))

(define *view-temporal-declarations* '())

(define (view/temporal-declaration? declaration)
  (and (instance-of? declaration <sal-constant-decl>)
       (slot-value declaration :value)
       (let ((cached (assq declaration *view-temporal-declarations*)))
         (if cached (cdr cached)
             (let ((entry (cons declaration #f)) (found? #f))
               ;; Recursive references stop at the current declaration; direct
               ;; temporal operators elsewhere in its body still classify it.
               (set! *view-temporal-declarations*
                     (cons entry *view-temporal-declarations*))
               (view/for-each
                (lambda (node)
                  (when (or (instance-of? node <sal-temporal-application>)
                            (and (instance-of? node <sal-name-expr>)
                                 (view/temporal-declaration? (slot-value node :decl))))
                    (set! found? #t)))
                (list (slot-value declaration :value)))
               (set-cdr! entry found?)
               found?)))))

(define-method (sal-ast->sxml (ast <sal-constant-decl>))
  (let ((node (view/node 'CONSTANTDECLARATION
                         (append (list (sal-ast->sxml (slot-value ast :id))
                                       (sal-ast->sxml (slot-value ast :type)))
                                 (if (slot-value ast :value)
                                     (list (sal-ast->sxml (slot-value ast :value))) '())) ast)))
    (when (view/temporal-declaration? ast)
      (sxml/set-attribute! node 'BRIDGETEMPORAL "true"))
    node))

(define (view/macro-check-decl provider type value prefix)
  (make-ast-instance <sal-let-decl> provider
                     :id (make-sal-identifier provider (gen-unique-name prefix))
                     :type type :value value))

(define (view/macro-context-checks fun provider walk env depth)
  ;; A macro may never use one of its context parameters. Retain that actual's
  ;; type obligation even when beta expansion removes every qualified name.
  (if (and (or (instance-of? fun <sal-qualified-name-ref>)
               (instance-of? fun <sal-context-name-decl>))
           (not (null? (slot-value fun :actuals))))
      (map
       (lambda (formal actual)
         (if (instance-of? formal <sal-type-param-decl>)
             ;; Identity needs no inhabitant of an actual type, but preserves
             ;; the well-formedness checks inside that type's expression.
             (let* ((type (walk actual env depth))
                    (variable (make-ast-instance <sal-var-decl> provider
                                :id (make-sal-identifier provider (gen-unique-name 'sal_macro_type))
                                :type type))
                    (identity (make-ast-instance <sal-lambda> provider
                                :local-decls (list variable)
                                :expr (make-ast-instance <sal-name-expr> provider :decl variable))))
               (view/macro-check-decl provider (sal-expr/type identity) identity 'sal_macro_type_argument))
             (let* ((reference (make-ast-instance <sal-qualified-name-expr> provider
                                  :decl formal :context-ref (slot-value fun :context-ref)
                                  :actuals (slot-value fun :actuals)))
                    (type (sal-name-expr/type reference)))
               (view/macro-check-decl provider type (walk actual env depth) 'sal_macro_context_argument))))
       (sal-context/params (slot-value fun :context-ref))
       (slot-value fun :actuals))
      '()))

(define (view/literal-argument? node)
  (or (instance-of? node <sal-numeral>)
      (instance-of? node <sal-true>) (instance-of? node <sal-false>)
      (and (instance-of? node <sal-tuple-literal>)
           (every view/literal-argument? (slot-value node :exprs)))))

(define (view/fold-literal-operation node)
  ;; General SAL simplification evaluates named functions and inlines calls,
  ;; erasing source subtype checks. Only total primitive operations on literal
  ;; operands may be folded to terminate a statically bounded temporal macro.
  (if (and (or (instance-of? node <sal-add>) (instance-of? node <sal-sub>)
               (instance-of? node <sal-mul>) (instance-of? node <sal-lt>)
               (instance-of? node <sal-le>) (instance-of? node <sal-gt>)
               (instance-of? node <sal-ge>) (instance-of? node <sal-eq>)
               (instance-of? node <sal-diseq>) (instance-of? node <sal-not>)
               (instance-of? node <sal-implies>) (instance-of? node <sal-iff>)
               (instance-of? node <sal-xor>))
           (view/literal-argument? (slot-value node :arg)))
      (sal-ast/simplify node)
      node))

(define (view/expand-temporal-macros expression)
  ;; Only property-level temporal templates are beta-expanded. All argument
  ;; substitution and simplification is SAL's native AST operation; state
  ;; expressions are never frozen by evaluating them in an arbitrary state.
  (letrec ((walk
            (lambda (node env depth)
              (when (> depth 128)
                (sign-error "Temporal macro expansion exceeded 128 unfoldings; a finite native expansion is required" node))
              (let ((fun (and (instance-of? node <sal-application>)
                              (slot-value node :fun))))
                (cond
                 ((and fun
                         (not (instance-of? node <sal-temporal-application>))
                         (instance-of? fun <sal-name-expr>)
                         (view/temporal-declaration? (slot-value fun :decl)))
                    (let* ((argument (slot-value node :arg))
                           (expanded (sal-expr/apply fun argument))
                           (body (walk expanded env (+ depth 1)))
                           (check (view/macro-check-decl
                                   node (sal-function-type/domain (sal-expr/type fun))
                                   (walk argument env depth) 'sal_macro_argument))
                           (context-checks (view/macro-context-checks fun node walk env depth)))
                      ;; The binding is deliberately unused by BODY. Its type
                      ;; preserves the original call-domain TCC, while BODY
                      ;; retains actual state expressions under each modality.
                      (make-ast-instance <sal-let-expr> node
                                         :local-decls (append context-checks (list check)) :expr body)))
                 ((or (instance-of? node <sal-and>) (instance-of? node <sal-or>))
                  ;; Respect Boolean guards before unfolding a recursive tail.
                  ;; Keep already visited operands and their domain checks.
                  (let loop ((remaining (sal-application/argument-list node)) (done '()))
                    (if (null? remaining)
                        (update-ast-slots node :arg (apply make-application-argument (reverse done)))
                        (let* ((next (walk (car remaining) env depth))
                               (done (cons next done)))
                          (if (or (and (instance-of? node <sal-and>) (sal-expr/false? next))
                                  (and (instance-of? node <sal-or>) (sal-expr/true? next)))
                              (if (null? (cdr done)) next
                                  (update-ast-slots node :arg (apply make-application-argument (reverse done))))
                              (loop (cdr remaining) done))))))
                 ((instance-of? node <sal-conditional>)
                  (let ((condition (walk (slot-value node :cond-expr) env depth)))
                    (cond ((sal-expr/true? condition) (walk (slot-value node :then-expr) env depth))
                          ((sal-expr/false? condition) (walk (slot-value node :else-expr) env depth))
                          (else (update-ast-slots node :cond-expr condition
                                   :then-expr (walk (slot-value node :then-expr) env depth)
                                   :else-expr (walk (slot-value node :else-expr) env depth))))))
                 (else
                  (view/fold-literal-operation
                   (sal-ast/map node env
                                (lambda (child child-env)
                                  (walk child child-env depth))))))))))
    (walk expression (view/empty-env) 0)))

(define (view/referenced-contexts roots excluded)
  (let ((result '()))
    (view/for-each
     (lambda (ast)
       (when (or (instance-of? ast <sal-qualified-name-ref>)
                 (instance-of? ast <sal-context-name-decl>))
         (let ((dependency (slot-value ast :context-ref)))
           (when (and dependency (not (eq? dependency excluded))
                      (view/context-file dependency)
                      (not (memq dependency result)))
             (set! result (cons dependency result)))))) roots)
    (reverse result)))

(define (view/direct-contexts context)
  (view/referenced-contexts
   (append (sal-context/params context) (sal-context/declarations context)) context))

(define (view/context-closure context extra)
  ;; Preserve full generic declarations. Dependency specialization belongs to
  ;; native qualified references/actuals, never textual expansion.
  (let ((done '()) (active '()) (ordered '()))
    (letrec ((visit
              (lambda (ctx)
                (when (and (view/context-file ctx) (not (memq ctx done)))
                  (when (memq ctx active)
                    (sign-error "Cyclic SAL context dependency" (sal-context/name ctx)))
                  (set! active (cons ctx active))
                  (for-each visit (view/direct-contexts ctx))
                  (set! active (cdr active))
                  (set! done (cons ctx done))
                  (set! ordered (cons ctx ordered))))))
      (for-each visit extra)
      (visit context))
    (reverse ordered)))

(define (view/context-source context with-ast?)
  (let ((node (view/node 'CONTEXTSOURCE
                        (if with-ast? (list (sal-ast->sxml context)) '()) context)))
    (sxml/set-attribute! node 'NAME (symbol->string (sal-context/name context)))
    (sxml/set-attribute! node 'FILE (view/context-file context))
    node))

(define (view/module-name module)
  (if (instance-of? module <sal-module-instance>)
      (slot-value module :module-name) module))

(define (view/same-module? left right)
  (or (sal-ast/equivalent? left right)
      ;; The official syntax FALSE is a prelude alias for LSAL's false.
      ;; Normalize module actual expressions with SAL's own simplifier before
      ;; deciding whether a source assertion describes the selected instance.
      (and (instance-of? left <sal-module-instance>)
           (instance-of? right <sal-module-instance>)
           (sal-ast/equivalent? (view/module-name left) (view/module-name right))
           (= (length (slot-value left :actuals)) (length (slot-value right :actuals)))
           (every (lambda (a b)
                    (sal-ast/equivalent? (sal-ast/simplify a) (sal-ast/simplify b)))
                  (slot-value left :actuals) (slot-value right :actuals)))))

(define (view/assertion decl context-actuals)
  (if context-actuals
      (sal-assertion-name/definition
       (make-ast-instance <sal-qualified-assertion-name> decl
                          :decl decl :context-ref (sal-ast/context decl)
                          :actuals context-actuals))
      (slot-value decl :assertion-expr)))

(define (view/selected-property? decl target-decl selected context-actuals generic-params)
  (and (null? generic-params)
       (instance-of? decl <sal-assertion-decl>)
       (let ((assertion (view/assertion decl context-actuals)))
         (and (instance-of? assertion <sal-module-models>)
              (let* ((module (slot-value assertion :module))
                     (name (view/module-name module)))
                (and (instance-of? name <sal-module-name>)
                     (eq? (slot-value name :decl) target-decl)
                     (or (not selected) (view/same-module? module selected))))))))

(define (view/property decl flat context-actuals)
  (let* ((assertion (view/assertion decl context-actuals))
         (module (slot-value assertion :module))
         (original-vars (sal-module/state-variables module))
         (new-vars (sal-module/state-variables flat)))
    (unless (= (length original-vars) (length new-vars))
      (sign-error "Property/module interface disagreement" decl))
    (for-each (lambda (var)
                (unless (sal-module/lookup-var flat (sal-decl/name var))
                  (sign-error "Property variable absent from normalized module" var)))
              original-vars)
    (let* ((expr (sal-ast/rename-variables
                  (view/expand-temporal-macros
                   (sal-module/rebind-expr module (slot-value assertion :expr) flat))))
           (node (view/node 'PROPERTY (list (sal-ast->sxml expr)) decl)))
      (sxml/set-attribute! node 'NAME (symbol->string (sal-decl/name decl)))
      node)))

(define (view/module-call-check module)
  (let* ((instance? (instance-of? module <sal-module-instance>))
         (name (if instance? (slot-value module :module-name) module))
         (parametric (sal-module-name/definition name))
         (formals (slot-value parametric :local-decls))
         (actuals (if instance? (slot-value module :actuals) '()))
         (context-checks
          (view/macro-context-checks name module (lambda (node env depth) node)
                                     (view/empty-env) 0))
         (argument-checks
          (if (null? formals) #f
              (let* ((checks
                      (map (lambda (formal)
                             (view/macro-check-decl
                              module (slot-value formal :type)
                              (make-sal-name-expr formal module) 'sal_module_argument)) formals))
                     (body (make-ast-instance <sal-let-expr> module
                              :local-decls checks :expr (make-sal-true module)))
                     (lambda (make-ast-instance <sal-lambda> module
                                :local-decls formals :expr body)))
                (unless (= (length formals) (length actuals))
                  (sign-error "Module application actual/formal mismatch in domain checks" module))
                ;; Native beta substitution also instantiates dependent formal
                ;; types; looking only at the flattened body would lose them.
                (sal-expr/apply lambda (apply make-application-argument actuals))))))
    (cond ((pair? context-checks)
           (make-ast-instance <sal-let-expr> module :local-decls context-checks
                              :expr (or argument-checks (make-sal-true module))))
          (argument-checks argument-checks)
          (else #f))))

(define (view/module-check-entry expression context scope name source binders)
  (let* ((body
          (fold-left
           (lambda (body binder)
             (make-ast-instance
              (if (instance-of? binder <sal-let-expr>) <sal-let-expr> <sal-for-all-expr>)
              binder :local-decls (slot-value binder :local-decls) :expr body))
           expression binders))
         (entry (view/node 'MODULECHECK
                           (list (sal-ast->sxml (sal-ast/rename-variables body))) source)))
    (sxml/set-attribute! entry 'CONTEXT (symbol->string (sal-context/name context)))
    (sxml/set-attribute! entry 'SCOPE scope)
    (sxml/set-attribute! entry 'NAME (symbol->string name))
    entry))

(define (view/source-module-checks contexts)
  (let ((result '()))
    (for-each
     (lambda (context)
       (for-each
        (lambda (declaration)
          (when (instance-of? declaration <sal-context-name-decl>)
            (let ((checks (view/macro-context-checks
                           declaration declaration (lambda (node env depth) node)
                           (view/empty-env) 0)))
              (when (pair? checks)
                (set! result
                      (cons (view/module-check-entry
                             (make-ast-instance <sal-let-expr> declaration
                                                :local-decls checks :expr (make-sal-true declaration))
                             context "context" (sal-decl/name declaration) declaration '())
                            result)))))
          (when (instance-of? declaration <sal-module-decl>)
            (letrec
                ((walk
                  (lambda (node binders env)
                    (cond
                     ((or (instance-of? node <sal-module-instance>)
                          (instance-of? node <sal-module-name>))
                      (let ((check (view/module-call-check node)))
                        (when check
                          (set! result
                                (cons (view/module-check-entry
                                       check context "context" (sal-decl/name declaration) node binders)
                                      result)))))
                     (else
                      (let ((binders (if (and (instance-of? node <sal-local-binds-ast>)
                                             (pair? (slot-value node :local-decls)))
                                         (cons node binders) binders)))
                        (sal-ast/map node env
                                     (lambda (child child-env)
                                       (walk child binders child-env)))))
                     )
                    node)))
              (walk (slot-value declaration :parametric-module) '() (view/empty-env)))))
        (sal-context/declarations context))) contexts)
    (reverse result)))

(unless (or (= (length *arguments*) 2) (= (length *arguments*) 3))
  (sign-error "Usage: sal-view-export.scm INPUT MODULE [QUALIFIED-SELECTOR], or INPUT --context/--source/--manifest" *arguments*))

(let* ((input (car *arguments*))
       (target (cadr *arguments*))
       (selector (and (= (length *arguments*) 3) (caddr *arguments*)))
       (environment (make-sal-env))
       ;; The selected file's directory takes precedence over ambient paths.
       (_ (sal-env/set-sal-context-path!
           environment (cons (dirname input) (slot-value environment :sal-context-path))))
       (context (sal-env/context-from-file environment input))
       (selected
        (and selector
             (sal-env/with-string-reader
              environment
              (if (substring=? (trim selector) "(" 1)
                  make-lsal-string-reader make-sal-string-reader)
              (lambda () (sal-env/module-string->ast environment selector)))))
       (selected-name (and selected (view/module-name selected)))
       (context-actuals
        (and selected-name (instance-of? selected-name <sal-qualified-module-name>)
             (slot-value selected-name :actuals)))
       ;; Native used-contexts follows definitions; an uninterpreted qualified
       ;; actual has none, so also collect explicit context references.
       (extra (if selected
                  (append (view/referenced-contexts (list selected) #f)
                          (sal-ast/used-contexts selected)) '()))
       (contexts (view/context-closure context extra)))
  (cond
   ((string=? target "--source")
    (sxml->xml (sal/replace-builtin-names-with-official-names (sal-ast->sxml context))))
   ((string=? target "--manifest")
    (let ((node (view/node 'SALMANIFEST
                          (map (lambda (ctx)
                                 (let ((file-node (view/node 'FILE '() ctx)))
                                   (sxml/set-attribute! file-node 'PATH (view/context-file ctx))
                                   (sxml/set-attribute! file-node 'NAME (symbol->string (sal-context/name ctx)))
                                   file-node)) contexts) context)))
      (sxml/set-attribute! node 'VERSION "2")
      (sxml->xml node)))
   (else
    (let* ((library-only? (string=? target "--context"))
           (decl (and (not library-only?)
                      ;; SAL has distinct namespaces: e.g. Needham-Schroeder
                      ;; declares both a Boolean function and module intruder.
                      (sal-context/module-declaration context (string->symbol target)))))
      (unless (or library-only? (and decl (instance-of? decl <sal-module-decl>)))
        (sign-error "No module with this name" target))
      (when (and selected
                 (not (and (instance-of? selected-name <sal-module-name>)
                           (eq? (slot-value selected-name :decl) decl))))
        (sign-error "Selector must instantiate the selected root module declaration" selector))
      ;; Keep nondeterministic choice logical; trace labels stay in SOURCE.
      (sal/set-trace-info-enabled! #f)
      (let* ((parameters (if (and decl (not selected))
                             (slot-value (slot-value decl :parametric-module) :local-decls)
                             '()))
             (body (and decl (or selected
                                  (slot-value (slot-value decl :parametric-module) :module))))
             (flat (and body (view/hygienic-flat body)))
             (properties
              (if decl (filter (lambda (d)
                                 (view/selected-property? d decl selected context-actuals parameters))
                               (sal-context/declarations context)) '()))
             (source (view/node 'SOURCE (list (sal-ast->sxml context)) context))
             (document
              (view/node 'SALVIEW
                         (append
                          (list (view/node 'DEPENDENCIES
                                           (map (lambda (ctx) (view/context-source ctx #t))
                                                (filter (lambda (ctx) (not (eq? ctx context))) contexts)) context)
                                source
                                (view/export-list 'MODULEPARAMETERS parameters context)
                                (view/export-list 'ROOTACTUALS (or context-actuals '()) context)
                                (view/node 'MODULECHECKS
                                 (append
                                  (view/source-module-checks contexts)
                                  (if selected
                                      (let ((check (view/module-call-check selected)))
                                        (if check
                                            (list (view/module-check-entry check context "view"
                                                    (sal-decl/name decl) selected '())) '()))
                                      '())) context))
                          (if flat (list (view/flat-node flat)) '())
                          (list (view/node 'PROPERTIES
                                           (map (lambda (d) (view/property d flat context-actuals)) properties)
                                           context))) context)))
        (sxml/set-attribute! source 'FILE (view/context-file context))
        (sxml/set-attribute! document 'VERSION "2")
        (sxml/set-attribute! document 'MODULE target)
        (sxml/set-attribute! document 'LIBRARY (if library-only? "true" "false"))
        (when selector
          (sxml/set-attribute! document 'SELECTOR selector)
          (sxml/set-attribute! document 'INSTANTIATED "true"))
        (sxml->xml (sal/replace-builtin-names-with-official-names document)))))))
