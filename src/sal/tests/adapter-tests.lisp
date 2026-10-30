;;; Load after tests/support.lisp; the caller chooses when to run PVS proofs.
(in-package :pvs)

(defun sal-test-library-adapter (&key (directory (merge-pathnames ".work/adapter/"
                                                                *sal-bridge-directory*)))
  (let* ((view (sal-open (merge-pathnames "examples/integration/library_counter.sal"
                                         *sal-bridge-directory*)
                        "machine" :output-directory directory :progress-checks nil))
         (theory (sal-transition-view-theory-name view)))
    (sal-test-type-tccs view)
    (sal-test-prove theory "sal_safe" `(sal-check ,(format nil "~a.safe" theory)))
    (sal-write-file-if-changed
     (merge-pathnames "PVS_Library_Adapter.pvs" directory)
     (uiop:read-file-string
      (merge-pathnames "examples/integration/PVS_Library_Adapter.pvs"
                       *sal-bridge-directory*)))
    (typecheck-file "PVS_Library_Adapter")
    (dolist (name '("PVS_Transition_View" "PVS_Counter_Library" "PVS_Library_Adapter"))
      (dolist (tcc (collect-tccs (get-typechecked-theory name)))
        (sal-test-prove name (string (id tcc)) '(grind))))
    (dolist (name '("decode_encode" "encode_decode"))
      (sal-test-prove "PVS_Library_Adapter" name '(then (grind) (apply-extensionality) (grind))))
    (sal-test-prove "PVS_Library_Adapter" "initial_commutes" '(grind))
    (sal-test-prove "PVS_Library_Adapter" "step_commutes"
                    '(then (grind) (apply-extensionality) (grind)))
    (sal-test-prove "PVS_Library_Adapter" "sal_proof_reused"
                    '(then (lemma "translated.sal_safe") (grind)))
    (save-context nil t)
    view))

(export '(sal-test-library-adapter))
