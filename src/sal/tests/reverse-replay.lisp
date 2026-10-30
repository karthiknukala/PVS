;;; Fresh process replay of persisted native PVS model-checker proofs and TCCs.
(in-package :pvs)
(load (merge-pathnames "tests/reverse-support.lisp"
                      (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
(handler-case
    (progn
      (sal-reverse-context)
      (dolist (case '(("Reverse_Counter" "safe")
                      ("Reverse_Counter" "safe_alias")
                      ("Reverse_Direct" "safe")
                      ("Reverse_Terminal" "observed_before_finish")
                      ("Reverse_Array" "mark_zero_first")
                      ("Reverse_Phase" "completed_after_active")))
        (destructuring-bind (theory formula) case
          (sal-reverse-typecheck theory)
          (sal-reverse-tccs theory :replay t)
          (sal-reverse-extract theory formula)
          (sal-reverse-saved-proof theory formula)))
      (format t "~&SAL-REVERSE-REPLAY-PASSED~%"))
  (error (condition)
    (format t "~&SAL-REVERSE-REPLAY-FAILED: ~a~%" condition)))
