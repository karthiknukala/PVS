;;; Integration regressions: typechecked native PVS -> exact SAL -> proof rule.
(in-package :pvs)
(load (merge-pathnames "tests/reverse-support.lisp"
                      (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))

(defun sal-reverse-counter-tests ()
  (sal-reverse-typecheck "Reverse_Counter")
  (sal-reverse-tccs "Reverse_Counter")
  (let* ((extraction (sal-reverse-extract "Reverse_Counter" "safe"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test (some (lambda (d) (string= "Reverse_Counter_Library" (string (id (module d)))))
                    (sal-pvs-extraction-declarations extraction))
              "extraction includes definitions from the parameterized library")
    (sal-test-prove "Reverse_Counter" "safe" '(sal-check-pvs "Reverse_Counter.safe"))
    (sal-test (eq :proved (sal-check-result-outcome (sal-proof-target-last-result target)))
              "symbolic checker proved the concrete library instance")
    ;; K-induction is another proof strategy over exactly the same native goal.
    (sal-test-prove "Reverse_Counter" "safe"
                    '(sal-check-pvs "Reverse_Counter.safe" :backend :bmc :depth 4))
    (sal-test (sal-check-result-exact-p (sal-proof-target-last-result target))
              "finite induction result is admitted as exact")
    ;; A changed singleton sequent is outside the registered rule's contract.
    (setf (sal-proof-target-last-result target) nil)
    (sal-test-prove "Reverse_Counter" "safe"
                    '(then (expand "invariant") (sal-check-pvs "Reverse_Counter.safe"))
                    :expect-complete nil)
    (sal-test (null (sal-proof-target-last-result target))
              "changed singleton goal never invokes SAL")
    ;; Restore and persist the original successful strategy after the rejection.
    (sal-test-prove "Reverse_Counter" "safe" '(sal-check-pvs "Reverse_Counter.safe"))
    (dolist (file (list (merge-pathnames "Reverse_Counter_Library.pvs"
                                        (sal-reverse-output "context"))
                        (sal-pvs-extraction-source extraction)))
      (let ((original (uiop:read-file-string file)))
        (unwind-protect
            (progn
              ;; PVS's parsed? predicate compares whole-second write dates.
              ;; Make this probe deterministic even on a very fast machine.
              (when (string= (pathname-type file) "pvs") (sleep 1.1))
              (sal-write-file-if-changed file (concatenate 'string original (format nil "~%% stale source probe~%")))
              (setf (sal-proof-target-last-result target) nil)
              (if (string= (pathname-type file) "pvs")
                  (sal-test (search "changed" (or (sal-target-refusal target nil) ""))
                            "proof admission refuses the changed native dependency")
                  (sal-test-prove "Reverse_Counter" "safe"
                                  '(sal-check-pvs "Reverse_Counter.safe") :expect-complete nil))
              (sal-test (null (sal-proof-target-last-result target))
                        (format nil "source mutation blocks checker invocation: ~a" (file-namestring file)))
              (when (string= (pathname-type file) "pvs")
                (let ((refusal nil))
                  (handler-case
                      (sal-extract-pvs "Reverse_Counter" "safe"
                                       :output-directory (sal-reverse-output "stale-extraction"))
                    (error (condition) (setf refusal (princ-to-string condition))))
                  (sal-test (and refusal (search "typechecked" refusal :test #'char-equal))
                            (format nil "stale typed AST is refused before extraction: ~a" refusal)))))
          (sal-write-file-if-changed file original))
        (when (string= (pathname-type file) "pvs")
          ;; The original contents have returned, but native PVS timestamps
          ;; still require a fresh typecheck and registration.
          (sal-reverse-typecheck "Reverse_Counter")
          (sal-reverse-tccs "Reverse_Counter")
          (setf extraction (sal-reverse-extract "Reverse_Counter" "safe")
                target (sal-pvs-extraction-target extraction)))))
    (sal-test-prove "Reverse_Counter" "safe" '(sal-check-pvs "Reverse_Counter.safe")))
  (sal-reverse-extract "Reverse_Counter" "safe_alias")
  (sal-test-prove "Reverse_Counter" "safe_alias" '(sal-check-pvs "Reverse_Counter.safe_alias"))
  (let* ((extraction (sal-reverse-extract "Reverse_Counter" "stays_zero"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test-prove "Reverse_Counter" "stays_zero"
                    '(sal-check-pvs "Reverse_Counter.stays_zero") :expect-complete nil)
    (sal-test (eq :counterexample (sal-check-result-outcome (sal-proof-target-last-result target)))
              "false library property retains a SAL counterexample and an open PVS goal")))

(defun sal-reverse-direct-tests ()
  (sal-reverse-typecheck "Reverse_Direct")
  (sal-reverse-tccs "Reverse_Direct")
  (sal-reverse-extract "Reverse_Direct" "safe")
  (sal-test-prove "Reverse_Direct" "safe" '(sal-check-pvs "Reverse_Direct.safe")))

(defun sal-reverse-terminal-tests ()
  (sal-reverse-typecheck "Reverse_Terminal")
  (sal-reverse-tccs "Reverse_Terminal")
  (let* ((extraction (sal-reverse-extract "Reverse_Terminal" "observed_before_finish"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test-prove "Reverse_Terminal" "observed_before_finish"
                    '(sal-check-pvs "Reverse_Terminal.observed_before_finish"))
    (let ((result (sal-run-check (sal-pvs-extraction-source extraction) nil
                                 :backend :deadlock :module (sal-proof-target-module target))))
      (sal-test (eq :deadlock (sal-check-result-outcome result))
                "exact relational extraction preserves reachable terminal states")))
  (let* ((extraction (sal-reverse-extract "Reverse_Terminal" "never_finishes"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test-prove "Reverse_Terminal" "never_finishes"
                    '(sal-check-pvs "Reverse_Terminal.never_finishes") :expect-complete nil)
    (sal-test (eq :counterexample (sal-check-result-outcome (sal-proof-target-last-result target)))
              "safety checking includes the reachable terminal state")))

(defun sal-reverse-admission-tests ()
  (sal-reverse-typecheck "Reverse_Admission" "Reverse_Unbounded")
  (dolist (case '(("Reverse_Unbounded" "unbounded integer carrier")
                  ("Reverse_Opaque" "opaque")
                  ("Reverse_Recursive" "recursive")
                  ("Reverse_Fake_Invariant" "canonical")
                  ("Reverse_Not_An_Invariant" "invariant")
                  ("Reverse_Generic" "closed concrete")))
    (destructuring-bind (name expected) case
      (let ((refusal nil))
        (handler-case
            (sal-extract-pvs name "candidate" :output-directory (sal-reverse-output name))
          (error (condition) (setf refusal (princ-to-string condition))))
        (sal-test (and refusal (search expected refusal :test #'char-equal))
                  (format nil "native fragment ~a refused for ~a: ~a" name expected refusal))
        (format t "~&ADMISSION ~a: ~a~%" name refusal))))
  (let* ((extraction (sal-reverse-extract "Reverse_Unproved_TCC" "candidate"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test (sal-target-unfinished-tccs target)
              "ill-typed successor retains its unproved native TCC")
    (sal-test-prove "Reverse_Unproved_TCC" "candidate"
                    '(sal-check-pvs "Reverse_Unproved_TCC.candidate") :expect-complete nil)
    (sal-test (null (sal-proof-target-last-result target))
              "unproved native TCC prevents invoking SAL"))
  (let* ((extraction (sal-reverse-extract "Reverse_Mapped_TCC" "candidate"))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test (some #'mapped-axiom-tcc? (sal-target-unfinished-tccs target))
              "native interpretation retains an unproved mapped-axiom TCC")
    (sal-test-prove "Reverse_Mapped_TCC" "candidate"
                    '(sal-check-pvs "Reverse_Mapped_TCC.candidate") :expect-complete nil)
    (sal-test (null (sal-proof-target-last-result target))
              "mapped-axiom TCC prevents invoking SAL on an otherwise safe machine")))

(defun sal-reverse-array-tests ()
  (sal-reverse-typecheck "Reverse_Array")
  (sal-reverse-tccs "Reverse_Array")
  (sal-reverse-extract "Reverse_Array" "mark_zero_first")
  (sal-test-prove "Reverse_Array" "mark_zero_first"
                  '(sal-check-pvs "Reverse_Array.mark_zero_first")))

(defun sal-reverse-phase-tests ()
  (sal-reverse-typecheck "Reverse_Phase")
  (sal-reverse-tccs "Reverse_Phase")
  (sal-reverse-extract "Reverse_Phase" "completed_after_active")
  (sal-test-prove "Reverse_Phase" "completed_after_active"
                  '(sal-check-pvs "Reverse_Phase.completed_after_active")))

(sal-reverse-context :prepare t)
(let ((failures nil))
  (dolist (test '(sal-reverse-counter-tests sal-reverse-direct-tests sal-reverse-terminal-tests
                  sal-reverse-array-tests sal-reverse-phase-tests sal-reverse-admission-tests))
    (format t "~&SAL-REVERSE-TEST-BEGIN ~a~%" test)
    (force-output)
    (handler-case (funcall test)
      (error (condition)
        (push (cons test (princ-to-string condition)) failures)
        (format t "~&SAL-REVERSE-TEST-FAILED ~a: ~a~%" test condition)))
    (force-output))
  (if failures
      (format t "~&SAL-REVERSE-TESTS-FAILED: ~d groups~%" (length failures))
      (format t "~&SAL-REVERSE-TESTS-PASSED~%")))
