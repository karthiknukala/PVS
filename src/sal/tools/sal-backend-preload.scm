;; Run before SAL's unchanged checker frontend in the same salenv process.
;; Contexts are loaded by exact source path, including LSAL/XML variants. The
;; qualified assertion is built from the selected module's native actual ASTs.

(define-method (sal-ast->lsal-doc (ast <sal-qualified-name-ref>)
                                  (info <pp-info++>) (depth <primitive>))
  ;; The legacy LSAL printer omits the separate type/value actual groups.
  ;; Repair only this process's printer, keeping recursive actuals native.
  (if (sal-name-ref/builtin? ast)
      (to-string (sal-name-ref/name ast))
      (let* ((context (sal-qualified-name-ref/context-ref ast))
             (actuals (sal-qualified-name-ref/actuals ast))
             (type-docs '()) (value-docs '()))
        (for-each
         (lambda (formal actual)
           (let ((doc (sal-ast->lsal-doc actual info (+ depth 1))))
             (if (instance-of? formal <sal-type-param-decl>)
                 (set! type-docs (cons doc type-docs))
                 (set! value-docs (cons doc value-docs)))))
         (sal-context/params context) actuals)
        (pp/list-style1 "@" (sal-name-ref/name ast)
                        (if (null? actuals) (sal-context/name context)
                            (pp/list-style1 (sal-context/name context)
                                            (apply pp/list-style6 (reverse type-docs))
                                            (apply pp/list-style6 (reverse value-docs))))))))

(define (bridge/module-name module)
  (if (instance-of? module <sal-module-instance>)
      (slot-value module :module-name) module))

(define (bridge/same-module? left right)
  (or (sal-ast/equivalent? left right)
      (and (instance-of? left <sal-module-instance>)
           (instance-of? right <sal-module-instance>)
           (sal-ast/equivalent? (bridge/module-name left) (bridge/module-name right))
           (= (length (slot-value left :actuals)) (length (slot-value right :actuals)))
           (every (lambda (a b)
                    (sal-ast/equivalent? (sal-ast/simplify a) (sal-ast/simplify b)))
                  (slot-value left :actuals) (slot-value right :actuals)))))

(define (bridge/load-exact path)
  (let ((context (sal-env/context-from-file *sal-env* path)))
    (unless (equal? path (slot-value context :file-name))
      (sign-error "SAL context resolved to a different source file" path))
    context))

(let ((source #f) (dependencies '()) (selector #f)
      (assertion #f) (module #f) (native-arguments '()))
  (let loop ((arguments *arguments*))
    (unless (null? arguments)
      (let ((argument (car arguments)))
        (if (member argument '("--sal-bridge-source" "--sal-bridge-dependency"
                               "--sal-bridge-selector" "--sal-bridge-assertion"
                               "--sal-bridge-module"))
            (begin
              (when (null? (cdr arguments))
                (sign-error "Missing SAL bridge option value" argument))
              (let ((value (cadr arguments)))
                (cond
                 ((equal? argument "--sal-bridge-source") (set! source value))
                 ((equal? argument "--sal-bridge-dependency")
                  (set! dependencies (cons value dependencies)))
                 ((equal? argument "--sal-bridge-selector") (set! selector value))
                 ((equal? argument "--sal-bridge-assertion") (set! assertion value))
                 ((equal? argument "--sal-bridge-module") (set! module value))))
              (loop (cddr arguments)))
            (begin
              (set! native-arguments (cons argument native-arguments))
              (loop (cdr arguments)))))))
  (unless source (sign-error "Missing exact SAL source path" source))
  (sal-env/set-sal-context-path!
   *sal-env* (cons (dirname source) (slot-value *sal-env* :sal-context-path)))
  (for-each bridge/load-exact (reverse dependencies))
  (let ((context (bridge/load-exact source)))
    (if selector
        (let* ((selected
                (sal-env/with-string-reader
                 *sal-env*
                 (if (substring=? (trim selector) "(" 1)
                     make-lsal-string-reader make-sal-string-reader)
                 (lambda () (sal-env/module-string->ast *sal-env* selector))))
               (selected-name (bridge/module-name selected))
               (decl (and module
                          (sal-context/module-declaration context (string->symbol module)))))
          (unless (and decl (instance-of? selected-name <sal-qualified-module-name>)
                       (eq? (slot-value selected-name :decl) decl)
                       (eq? (slot-value selected-name :context-ref) context))
            (sign-error "Selector must instantiate the exact selected source module" selector))
          (if assertion
              (let* ((assertion-decl (sal-context/assertion-declaration
                                      context (string->symbol assertion)))
                     (_ (unless assertion-decl
                          (sign-error "No assertion with this name" assertion)))
                     (assertion-name
                      (make-ast-instance <sal-qualified-assertion-name> assertion-decl
                                         :decl assertion-decl :context-ref context
                                         :actuals (slot-value selected-name :actuals)))
                     (body (sal-assertion-name/definition assertion-name)))
                (unless (and (instance-of? body <sal-module-models>)
                             (bridge/same-module? selected (slot-value body :module)))
                  (sign-error "Assertion does not describe the selected module instance" assertion))
                ;; LSAL's native printer also represents names containing '-'
                ;; that cannot be written as official SAL identifiers.
                (sal/set-sal-pp-proc! sal-ast->lsal-doc)
                (let* ((text (with-output-to-string
                              (lambda () (sal/pp-detailed assertion-name))))
                       (roundtrip
                        (sal-env/with-string-reader
                         *sal-env* make-lsal-string-reader
                         (lambda () (sal-env/assertion-name-string->ast *sal-env* text)))))
                  (sal/set-sal-pp-proc! sal-ast->sal-doc)
                  (unless (sal-ast/equivalent? assertion-name roundtrip)
                    (sign-error "Qualified assertion did not roundtrip through SAL syntax" text))
                  (set! *arguments*
                        (append (reverse native-arguments)
                                (list (string-append "--assertion=" text))))))
              ;; The native deadlock CLI guesses only "(@" as LSAL, so an
              ;; LSAL module application must be printed in official syntax.
              ;; Reparse and compare before allowing that spelling to run.
              (let* ((text (with-output-to-string
                            (lambda () (sal/pp-detailed selected))))
                     (roundtrip
                      (sal-env/with-string-reader
                       *sal-env* make-sal-string-reader
                       (lambda () (sal-env/module-string->ast *sal-env* text)))))
                (unless (bridge/same-module? selected roundtrip)
                  (sign-error "Module instance cannot be represented for the native deadlock CLI" selector))
                (set! *arguments*
                      (append (reverse native-arguments)
                              (list (string-append "--module=" text)))))))
        (set! *arguments*
              (append (reverse native-arguments) (list source (or assertion module)))))))
