;;; Focused semantic boundaries exercised by the corpus renderer.
(in-package :pvs)

(defun sal-test-elaboration-corners ()
  (flet ((identifier (name) (make-instance 'sal-identifier :name (make-symbol name))))
    (let* ((parameter (make-instance 'sal-var-param-decl :id (identifier "n")
                                     :type (make-instance 'sal-nat-type)))
           (context (make-instance 'sal-context :id (identifier "synthetic")
                                   :params (list parameter)))
           (constant (make-instance 'sal-constant-decl :id (identifier "cap")
                                    :type (make-instance 'sal-nat-type)))
           (identity (make-instance 'sal-name-expr :decl parameter))
           (reference (make-instance 'sal-qualified-name-expr :context-ref context
                                     :decl constant :actuals (list identity)))
           (*sal-pvs-context* context)
           (*sal-pvs-local-names* (make-hash-table :test #'eq)))
      ;; SAL's current loader cannot export a source context importing another
      ;; instance of itself. The renderer still must never erase such actuals
      ;; when a resolved AST is supplied by a future/native alternative loader.
      (sal-test (string= "sal_cap" (sal-pvs-qualified-reference reference))
                "identity context actuals use the local declaration")
      (setf (actuals reference) (list (make-instance 'sal-numeral :num 3)))
      (sal-test (string= "SALCTX_sal_synthetic[3].sal_cap"
                         (sal-pvs-qualified-reference reference))
                "same context with different actuals retains its interpretation")
      (let ((*sal-pvs-qualify-current-context* t)
            (*sal-pvs-current-context-actuals* (list (make-instance 'sal-numeral :num 2))))
        (sal-test (string= "SALCTX_sal_synthetic[3].sal_cap"
                           (sal-pvs-qualified-reference reference))
                  "forced qualification never overwrites explicit changed actuals"))
      (sal-test (not (sal-pvs-total-helper-value-p reference))
                "qualified actual domain obligations stay in their original guard"))
    (let* ((binder (make-instance 'sal-var-decl :id (identifier "x")
                                  :type (make-instance 'sal-number-type)))
           (other (make-instance 'sal-var-decl :id (identifier "x")
                                 :type (make-instance 'sal-number-type)))
           (reference (make-instance 'sal-name-expr :decl binder))
           (real-predicate (make-instance 'sal-real-pred :arg reference))
           (predicate (make-instance 'sal-lambda :local-decls (list binder)
                                     :expr real-predicate))
           (subtype (make-instance 'sal-subtype :expr predicate))
           (*sal-pvs-local-names* (make-hash-table :test #'eq)))
      (sal-test (search ": real |" (sal-pvs-type subtype))
                "explicit real membership narrows exactly the NUMBER subtype")
      (setf (type binder) (make-instance 'sal-nat-type))
      (sal-test (search ": nat |" (sal-pvs-type subtype))
                "existing NATURAL binder is never widened to REAL")
      (setf (type binder) (make-instance 'sal-number-type)
            (decl reference) other)
      (sal-test (handler-case (progn (sal-pvs-type subtype) nil)
                  (sal-elaboration-error () t))
                "real guard on a shadowing binder cannot justify narrowing")
      (setf (decl reference) binder
            (expr predicate)
            (make-instance 'sal-or
                           :arg (make-instance 'sal-arg-tuple-literal
                                               :exprs (list real-predicate
                                                            (make-instance 'sal-true)))))
      (sal-test (handler-case (progn (sal-pvs-type subtype) nil)
                  (sal-elaboration-error () t))
                "every numeric union branch must entail real membership"))))

(defun sal-test-nonterminating-source-tcc ()
  (let* ((view (sal-open-context
                (merge-pathnames "examples/integration/frontend_nonterminating.sal"
                                 *sal-bridge-directory*)
                :output-directory
                (merge-pathnames "frontend-nonterminating/"
                                 (uiop:ensure-directory-pathname
                                  (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT")))))
         (name (sal-transition-view-theory-name view))
         (theory (get-typechecked-theory name))
         (obligations (remove-if-not
                       (lambda (declaration) (search "sal_loop" (string (id declaration))))
                       (collect-tccs theory))))
    (sal-test obligations "unguarded source recursion produces a termination TCC")
    (dolist (tcc obligations)
      (sal-test-prove name (string (id tcc)) '(grind) :expect-complete nil))
    (sal-test (every (lambda (entry) (sal-source-obligation-place entry))
                     (sal-transition-view-tccs view))
              "nontermination is reported at the original SAL declaration")))

(defun sal-test-let-block-semantics ()
  (let* ((view (sal-test-open "integration/frontend_let_blocks" "system"
                              :progress-checks nil :register nil))
         (directory (uiop:pathname-directory-pathname (sal-transition-view-pvs-file view)))
         (theory "Frontend_Let_Block_Check")
         (generated (sal-transition-view-pvs-text view)))
    (sal-test (= 3 (loop for position = (search "(s, next):" generated)
                          then (search "(s, next):" generated :start2 (1+ position))
                        while position count position))
              "65 native LET nodes share three bounded helper blocks")
    (sal-test (not (search "check_choice_" generated))
              "total Boolean LET circuits need no duplicate choice checks")
    (sal-write-file-if-changed
     (merge-pathnames (format nil "~A.pvs" theory) directory)
     (format nil "~A: THEORY~%BEGIN~%  IMPORTING ~A~%  parity: THEOREM FORALL (s,n:State): step(s,n) IFF n`sal_y = (NOT s`sal_x)~%END ~A~%"
             theory (sal-transition-view-theory-name view) theory))
    (typecheck-file theory)
    (sal-test-prove theory "parity" '(grind))))

(defun sal-test-unused-temporal-tccs ()
  (let* ((view (sal-open-context
                (merge-pathnames "examples/integration/frontend_unused_temporal.sal"
                                 *sal-bridge-directory*)
                :output-directory
                (merge-pathnames "frontend-unused-temporal/"
                                 (uiop:ensure-directory-pathname
                                  (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT"))))))
    (dolist (name '("bad" "independent"))
      (let ((obligations
              (remove-if-not
               (lambda (entry)
                 (search (concatenate 'string "bridge_temporal_check_" (sal-pvs-name name))
                         (sal-source-obligation-name entry)))
               (sal-transition-view-tccs view))))
        (sal-test obligations "unused temporal macro retains body-domain TCCs")
        (sal-test (some (lambda (entry) (not (proved? (sal-source-obligation-declaration entry))))
                        obligations)
                  "typing-only temporal checks do not assume their results")
        (sal-test (every #'sal-source-obligation-place obligations)
                  "unused temporal macro TCC maps to its original declaration")))))

(defun sal-test-primitive-partial-assignments ()
  (let* ((view (sal-test-open "integration/frontend_partial_assignments" "system"
                              :progress-checks nil :register nil))
         (checks (remove-if-not
                  (lambda (entry) (search "check_step_" (sal-source-obligation-name entry)))
                  (sal-transition-view-tccs view))))
    (sal-test (>= (length checks) 2)
              "partial BOOL and REAL assignments retain independent domain TCCs")
    (sal-test (every (lambda (entry) (not (proved? (sal-source-obligation-declaration entry)))) checks)
              "overlapping valid branch cannot mask invalid primitive assignments")))

(defun sal-test-nondeterministic-guard-checks ()
  (dolist (module '("bad" "indexed"))
    (let* ((view (sal-test-open "integration/frontend_choice_guards" module
                                :progress-checks nil :register nil))
           (checks (remove-if-not
                    (lambda (entry)
                      (search "check_choice_step_" (sal-source-obligation-name entry)))
                    (sal-transition-view-tccs view))))
      (sal-test checks "a true nondeterministic arm cannot hide another guard's domain TCC")
      (sal-test (every #'sal-source-obligation-place checks)
                "independent guard TCCs retain their SAL source places")
      (dolist (entry checks)
        (sal-test-prove (sal-transition-view-theory-name view)
                        (sal-source-obligation-name entry) '(grind)
                        :expect-complete nil))))
  (let ((view (sal-test-open "integration/frontend_choice_guards" "safe"
                             :progress-checks nil :register nil)))
    ;; Native short-circuit typing of each source guard is retained. Splitting
    ;; their Boolean subexpressions into unconditional checks would reject all
    ;; three guards, although the positive-domain application is protected.
    (sal-test-type-tccs view)
    (sal-test t "IF, AND and OR within guards retain their non-strict typing contexts")))

(defun sal-replay-nondeterministic-guard-checks ()
  (let* ((view (sal-test-open "integration/frontend_choice_guards" "safe"
                              :progress-checks nil :register nil))
         (theory (get-typechecked-theory (sal-transition-view-theory-name view))))
    (dolist (tcc (collect-tccs theory))
      (sal-test (justification tcc) "saved non-strict guard typing proof")
      (sal-test (eq (status-flag (prove-decl tcc :strategy '(then (rerun) (quit)))) '!)
                "fresh replay of non-strict guard typing"))))
