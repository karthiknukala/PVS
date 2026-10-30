;;; Loaded by parameters.lisp after the shared parameter test helpers.
(in-package :pvs)

(defun sal-test-imported-temporal-macros ()
  (let* ((view (sal-parameter-open "parameter_temporal_parent" "system" "temporal-macros"))
         (properties (sal-transition-view-properties view))
         (macro (cdr (assoc "imported" properties :test #'string=)))
         (direct (cdr (assoc "direct" properties :test #'string=)))
         (finite (cdr (assoc "finite" properties :test #'string=))))
    (sal-parameter-theory view)
    (sal-test (= 2 (length (sal-transition-view-contexts view)))
              "temporal library remains in the source dependency closure")
    (let* ((theory "Parameter_Temporal_Semantics")
           (file (merge-pathnames (concatenate 'string theory ".pvs")
                                 (sal-parameter-output "temporal-macros")))
           (*sal-pvs-context* (sal-transition-view-context view))
           (*sal-pvs-current-context-actuals* (sal-transition-view-root-actuals view))
           (*sal-pvs-qualify-current-context* t)
           (*sal-pvs-local-names* (make-hash-table :test #'eq))
           (*sal-pvs-fresh-counter* 0))
      (sal-write-file-if-changed
       file
       (format nil "~a: THEORY~%BEGIN~%  IMPORTING ~a~%  macro_value(p: system.path, k: nat): bool = ~a~%  direct_value(p: system.path, k: nat): bool = ~a~%  macro_equivalence: THEOREM FORALL (p: system.path, k: nat): macro_value(p, k) = direct_value(p, k)~%END ~a~%"
               theory (sal-transition-view-theory-name view)
               (sal-pvs-ltl-expression macro "p" "k")
               (sal-pvs-ltl-expression direct "p" "k") theory))
      (typecheck-file (pathname-name file) nil nil nil)
      (sal-test-prove theory "macro_equivalence" '(grind)))
    (sal-test (notany
               (lambda (property)
                 (sal-find-ast
                  (lambda (node)
                    (and (typep node 'sal-name-expr)
                         (member (sal-declaration-name (decl node))
                                 '("recurring" "reaches" "bounded") :test #'string=)))
                  property))
               (list macro finite))
              "temporal aliases and finite recursive macros are expanded in properties")
    (sal-test (typep (expr (cdr (assoc "bounded" properties :test #'string=))) 'sal-ltl-g)
              "native G remains inside its typed call-domain LET")
    (sal-test (not (sal-safety-property-p
                   (cdr (assoc "bounded" properties :test #'string=))))
              "typed macro wrappers are not silently admitted as unguarded safety properties"))
  (loop for source in '("parameter_temporal_bad" "parameter_temporal_bad_context"
                        "parameter_temporal_bad_inner")
        for name in '("bad_domain" "bad_context" "bad_inner")
        do
        (let ((view (sal-parameter-open source "system" source)))
          (sal-parameter-theory view)
          (let ((obligations
            (remove-if-not
             (lambda (obligation)
               (search (sal-pvs-name name) (sal-source-obligation-name obligation)
                       :test #'char-equal))
             (sal-transition-view-tccs view))))
          (sal-test obligations "unused temporal macro formals retain call/context-domain TCCs")
          (sal-test (some (lambda (obligation)
                           (not (proved? (sal-source-obligation-declaration obligation)))) obligations)
                    "invalid temporal macro argument is not silently admitted")
          (sal-test (every (lambda (obligation)
                            (= 4 (sal-source-place-initial-line
                                     (sal-source-obligation-place obligation)))) obligations)
                    "temporal call-domain obligations retain the SAL call site")))))
