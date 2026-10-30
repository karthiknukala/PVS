;;; Replay the parameter semantic proofs in a fresh PVS process.
(in-package :pvs)
(let ((root (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
  (load (merge-pathnames "load.lisp" root))
  (load (merge-pathnames "tests/support.lisp" root)))
(setq *proof-prompt-behavior* :noquestions *proceed-without-asking* t
      *noninteractive* t *noninteractive-timeout* 60)

(defun sal-parameter-replay-formulas (theory names)
  (let ((th (get-typechecked-theory theory)))
    (dolist (name names)
      (let ((decl (find name (append (assuming th) (theory th))
                        :key (lambda (d) (if (formula-decl? d) (string (id d)) "")) :test #'string=)))
        (sal-test (and decl (justification decl))
                  (format nil "saved parameter proof ~a.~a" theory name))
        (sal-test (eq (status-flag (prove-decl decl :strategy '(then (rerun) (quit)))) '!)
                  (format nil "fresh parameter replay ~a.~a" theory name))))))

(handler-case
    (progn
      (dolist (case '(("parameter_instances" "instances" "Parameter_Instance_Semantics"
                       ("two_actuals_step" "instances_not_conflated"))
                      ("parameter_ring_parent" "imported-rings" "Parameter_Ring_Semantics"
                       ("wrap_uses_imported_bound"))
                      ("parameter_temporal_parent" "temporal-macros" "Parameter_Temporal_Semantics"
                       ("macro_equivalence"))))
        (destructuring-bind (source directory theory formulas) case
          (let ((view (sal-open
                       (merge-pathnames (format nil "examples/parameters/~a.sal" source)
                                        *sal-bridge-directory*)
                       "system" :progress-checks nil :register nil
                       :output-directory
                       (merge-pathnames (format nil "~a/" directory)
                                        (uiop:ensure-directory-pathname
                                         (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT"))))))
            (typecheck-file theory)
            (sal-parameter-replay-formulas theory formulas)
            (when (string= source "parameter_ring_parent")
              (sal-parameter-replay-formulas
               (sal-transition-view-theory-name view) (list (sal-pvs-name "bounded")))))))
      (format t "~&SAL-PARAMETER-REPLAY-PASSED~%"))
  (error (condition)
    (format t "~&SAL-PARAMETER-REPLAY-FAILED: ~a~%" condition)))
