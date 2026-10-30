;;; Semantic regressions for the corpus-driven frontend additions.
;;; These prove native PVS meanings, independently of model-checker admission.
(in-package :pvs)

(defun sal-test-frontend-semantics ()
  (let* ((view (sal-test-open "integration/frontend_semantics" "terminal"))
         (theory (sal-transition-view-theory-name view))
         (context-name (sal-pvs-context-theory-name (sal-transition-view-context view)))
         (directory (uiop:pathname-directory-pathname (sal-transition-view-pvs-file view)))
         (test-theory "Frontend_Semantics_Check"))
    ;; A terminal state is not silently completed with a stuttering edge.
    ;; Native SAL's relational CTL kernel is vacuous at that state, verified by
    ;; native-ctl-terminal.scm. Its command-line simplifier assumes totality.
    (dolist (name '("terminal_next" "terminal_not_exists_next"))
      (sal-test-prove theory (sal-pvs-name name) '(grind)))
    (sal-test-prove theory (sal-pvs-name "terminal_eventually")
                    '(then (grind) (inst -1 "s!1") (grind)))
    (sal-test-prove theory (sal-pvs-name "terminal_no_infinite")
                    '(then (grind) (inst -1 "s!1") (grind)))
    (sal-write-file-if-changed
     (merge-pathnames (format nil "~A.pvs" test-theory) directory)
     (format nil "~A: THEORY~%BEGIN~%  IMPORTING ~A~%~%
  quotient_signs: THEOREM
    sal_quotient(-7, 3) = -2 AND sal_quotient(7, -3) = -2 AND
    sal_quotient(-7, -3) = 2 AND sal_quotient(7, 3) = 2
  residue_signs: THEOREM
    sal_residue(-7, 3) = 2 AND sal_residue(7, -3) = 1 AND
    sal_residue(-7, -3) = 2 AND sal_residue(7, 3) = 1
  ring_wraparound: THEOREM
    sal_successor(2) = 0 AND sal_predecessor(0) = 2 AND
    sal_successor(0) = 1 AND sal_predecessor(2) = 1
  recursive_value: THEOREM sal_countdown(3) = 3
END ~A~%" test-theory theory test-theory))
    (typecheck-file test-theory)
    (sal-test-prove test-theory "quotient_signs" '(grind))
    (sal-test-prove test-theory "residue_signs"
                    '(then (lemma "rem_floor" ("b" "3" "x" "-7"))
                           (lemma "rem_floor" ("b" "3" "x" "7"))
                           (typepred "floor(7/3)")
                           (typepred "floor(-7/3)")
                           (grind)))
    (sal-test-prove test-theory "ring_wraparound" '(grind))
    (sal-test-prove test-theory "recursive_value" '(grind))
    (let* ((context (get-typechecked-theory context-name))
           (termination (remove-if-not
                         (lambda (decl) (search "sal_countdown" (string (id decl))))
                         (collect-tccs context))))
      (sal-test termination "recursive definition has native termination obligations")
      (dolist (tcc termination)
        (sal-test-prove context-name (string (id tcc)) '(grind)))))
  ;; Keep inconsistent arithmetic apart from the semantic proof theory.
  (let* ((view (sal-open-context
                (merge-pathnames "examples/integration/frontend_zero_divisor.sal"
                                 *sal-bridge-directory*)
                :output-directory
                (merge-pathnames "frontend-zero-divisor/"
                                 (uiop:ensure-directory-pathname
                                  (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT")))))
         (theory (get-typechecked-theory (sal-transition-view-theory-name view))))
    (dolist (name '("zero_quotient" "zero_residue"))
      (let ((obligations
              (remove-if-not (lambda (decl) (search (sal-pvs-name name) (string (id decl))))
                             (collect-tccs theory))))
        (sal-test obligations (format nil "~A preserves zero-divisor TCC" name))
        (dolist (tcc obligations)
          (sal-test-prove (string (id theory)) (string (id tcc)) '(grind)
                          :expect-complete nil))))))

(defun sal-replay-frontend-semantics ()
  "Replay the new semantic and termination proofs from saved proof files."
  (let* ((view (sal-test-open "integration/frontend_semantics" "terminal"))
         (main (sal-transition-view-theory-name view))
         (context (sal-pvs-context-theory-name (sal-transition-view-context view))))
    (typecheck-file "Frontend_Semantics_Check")
    (labels ((replay (theory names)
               (let ((th (get-typechecked-theory theory)))
                 (dolist (name names)
                   (let ((decl (find name (append (assuming th) (theory th))
                                     :key (lambda (d) (if (formula-decl? d) (string (id d)) "")) :test #'string=)))
                     (sal-test (and decl (justification decl))
                               (format nil "saved frontend proof ~a.~a" theory name))
                     (sal-test (eq (status-flag (prove-decl decl :strategy '(then (rerun) (quit)))) '!)
                               (format nil "fresh frontend replay ~a.~a" theory name)))))))
      (replay main (mapcar #'sal-pvs-name '("terminal_next" "terminal_not_exists_next"
                                          "terminal_eventually" "terminal_no_infinite")))
      (replay "Frontend_Semantics_Check" '("quotient_signs" "residue_signs"
                                            "ring_wraparound" "recursive_value"))
      (replay context
              (loop for decl in (collect-tccs (get-typechecked-theory context))
                    when (search "sal_countdown" (string (id decl)))
                    collect (string (id decl)))))))
