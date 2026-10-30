;;; Loaded by parameters.lisp after the shared parameter test helpers.
(in-package :pvs)

(defun sal-test-imported-ring-actuals ()
  (let* ((view (sal-parameter-open "parameter_ring_parent" "system" "imported-rings"))
         (theory "Parameter_Ring_Semantics")
         (file (merge-pathnames (concatenate 'string theory ".pvs")
                               (sal-parameter-output "imported-rings")))
         (field (sal-pvs-name "r")))
    (sal-parameter-theory view)
    (sal-test (= 2 (length (sal-transition-view-contexts view)))
              "imported ring context retains its concrete actual")
    (sal-write-file-if-changed
     file
     (format nil "~a: THEORY~%BEGIN~%  IMPORTING ~a~%  last: State = (# ~a := 2 #)~%  first: State = (# ~a := 0 #)~%  wrap_uses_imported_bound: THEOREM step(last, first)~%END ~a~%"
             theory (sal-transition-view-theory-name view) field field
             theory))
    (typecheck-file (pathname-name file) nil nil nil)
    (sal-test-prove theory "wrap_uses_imported_bound" '(grind))
    ;; The formula also checks ring expressions that occur only in properties.
    (sal-test-prove (sal-transition-view-theory-name view)
                    (sal-pvs-name "bounded") '(grind))
    (sal-test (sal-proof-target-p (sal-parameter-register view "parameter-rings"))
              "imported ring property registers against the exact SAL source")))
