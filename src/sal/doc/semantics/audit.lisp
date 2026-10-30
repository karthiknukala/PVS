;;; Diagnostic source-typing audit. No proof, no checker admission.
(in-package :pvs)
(handler-case
  (with-open-file (report (merge-pathnames "semantics/audit-results.txt" *sal-doc-directory*)
                          :direction :output :if-exists :supersede)
    (format report "Source typing audit; intentionally false obligations remain open.~%~%")
    (dolist (name '("audit_guard" "audit_index"))
      (format t "~&AUDIT ~a~%" name)
      (let ((view (sal-open
                   (merge-pathnames (format nil "semantics/~a.sal" name) *sal-doc-directory*)
                   "machine" :progress-checks nil :register nil
                   :output-directory
                   (merge-pathnames (format nil ".demo/semantics/~a/" name)
                                    *sal-doc-directory*))))
        (sal-show-obligations view)
        (format report "~a~%" name)
        (sal-show-obligations view report)
        (unless (sal-transition-view-tccs view)
          (error "Expected an exposed source typing obligation for ~a" name))
        (format report "Source obligation count: ~d~%~%"
                (length (sal-transition-view-tccs view)))
        (format t "~&AUDIT-SOURCE-TCC-COUNT ~a ~d~%" name
                (length (sal-transition-view-tccs view)))))
    (format t "~&SAL-SEMANTICS-AUDIT-COMPLETE~%"))
  (error (e) (format t "~&SAL-SEMANTICS-AUDIT-FAILED: ~a~%" e)))
