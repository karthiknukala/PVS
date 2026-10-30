;;; Concrete relation checks catch capture/identity errors that typechecking cannot.
(in-package :pvs)

(defun sal-test-concrete-semantics (view source-name)
  (let ((body
          (cond
            ((string= source-name "integration/builtin_shadow")
             "step((# sal_value := 1 #), (# sal_value := 2 #)) AND NOT step((# sal_value := 1 #), (# sal_value := 1 #))")
            ((string= source-name "integration/binder_shadowing")
             "initial((# sal_value := 2 #)) AND step((# sal_value := 2 #), (# sal_value := 3 #)) AND NOT step((# sal_value := 2 #), (# sal_value := 2 #))")
            ((string= source-name "integration/renaming_capture")
             "NOT step((# sal_y := FALSE, sal_result := FALSE #), (# sal_y := TRUE, sal_result := TRUE #)) AND step((# sal_y := TRUE, sal_result := FALSE #), (# sal_y := FALSE, sal_result := TRUE #))"))))
    (when body
      (sal-write-file-if-changed
       (merge-pathnames "Bridge_Semantics_Check.pvs"
                        (uiop:pathname-directory-pathname (sal-transition-view-pvs-file view)))
       (format nil "Bridge_Semantics_Check: THEORY~%BEGIN~% IMPORTING ~a~% expected_relation: THEOREM ~a~%END Bridge_Semantics_Check~%"
               (sal-transition-view-theory-name view) body))
      (typecheck-file "Bridge_Semantics_Check")
      (sal-test-prove "Bridge_Semantics_Check" "expected_relation"
                      (if (string= source-name "integration/renaming_capture")
                          '(then (grind) (inst 1 "TRUE") (grind))
                          '(grind))))))

(defun sal-test-output-boundary ()
  (dolist (path (list "/outside-the-sal-bridge/"
                      (merge-pathnames ".work/missing/../../../../escape/" *sal-bridge-directory*)
                      (merge-pathnames ".work/*/" *sal-bridge-directory*)))
    (sal-test (handler-case (progn (sal-bridge-output-path path) nil)
                (error () t))
              (format nil "output boundary rejects ~a" path)))
  (let ((view (make-sal-transition-view)))
    (setf (gethash "sal_a" (sal-transition-view-origins view)) :lower
          (gethash "sal_A" (sal-transition-view-origins view)) :upper)
    (sal-test (and (eq :lower (sal-view-origin view "sal_a_TCC1"))
                   (eq :upper (sal-view-origin view "sal_A_TCC1")))
              "source origin mapping respects case")))

(defun sal-test-causal-contract (view source-name)
  (when (sal-transition-view-causality-theory-name view)
    (sal-test-prove
     (sal-transition-view-causality-theory-name view)
     "causality_structural_acyclic_TCC1"
     (if (string= source-name "integration/causality_good")
         '(then (inst 1 "LAMBDA (n: CausalNode): IF n = causal_sal_acknowledged THEN 2 ELSIF n = causal_sal_enabled THEN 1 ELSE 0 ENDIF")
                (grind))
         '(grind))
     :expect-complete (string= source-name "integration/causality_good"))))
