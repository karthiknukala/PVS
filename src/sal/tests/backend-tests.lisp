;;; Load after backend.lisp; loading this file does not run tools or write files.
(in-package :pvs)

(defun sal-test-backend-snapshots ()
  (let* ((directory (sal-backend-work-directory))
         (path (loop for i from 0
                     for candidate = (merge-pathnames
                                      (format nil "snapshot-test-~d-~d.txt"
                                              (get-universal-time) i) directory)
                     unless (probe-file candidate) return candidate)))
    (unwind-protect
         (let ((absent (list (sal-file-snapshot path))))
           (assert (sal-snapshots-current-p absent))
           (with-open-file (stream path :direction :output :if-exists :error)
             (write-string "original model" stream))
           (assert (not (sal-snapshots-current-p absent)))
           (let ((present (list (sal-file-snapshot path))))
             (assert (sal-snapshots-current-p present))
             (with-open-file (stream path :direction :output :if-exists :supersede)
               (write-string "modified model" stream))
             (assert (not (sal-snapshots-current-p present)))))
      (when (probe-file path) (delete-file path))))
  t)

(defun sal-test-backend-malformed-output ()
  (dolist (output (list "" "PROVED" "proved" "The word proved. is not a result."
                        (format nil "proved.~%invalid.~%")
                        (format nil "proved.~%no counterexample between depths: [0, 10].~%")))
    (assert (eq :unknown (sal-classify-check-output :smc output "" 0))))
  (dolist (stderr '("WARNING: subtype information (constraint) will be lost"
                    "Error: incomplete solver response" "Unexpected diagnostic"))
    (assert (not (nth-value 1 (sal-classify-check-output :smc "proved." stderr 0)))))
  (assert (eq :unknown
              (sal-classify-check-output
               :deadlock
               (format nil "ok (module does NOT contain deadlock states).~%Total number of deadlock states: 1~%")
               "" 0)))
  (assert (eq :error (sal-classify-check-output :smc "Counterexample:" "" 2)))
  t)

(defun sal-test-backend-live ()
  "Exercise installed SAL tools; only test files under src/sal/.work are written."
  (let ((source (merge-pathnames "backend_regression.sal" (sal-backend-work-directory))))
    (with-open-file (stream source :direction :output :if-exists :supersede)
      (write-string
       "backend_regression: CONTEXT =
BEGIN
  machine: MODULE =
  BEGIN
    OUTPUT x: [0..3]
    OUTPUT started: BOOLEAN
    INITIALIZATION x = 0; started = FALSE
    TRANSITION
    [ x < 3 --> x' = x + 1; started' = TRUE
    [] ELSE --> x' = x; started' = started ]
  END;
  holds: THEOREM machine |- G(x = 0 OR started);
  bad: THEOREM machine |- G(x < 2);
  stuck: MODULE =
  BEGIN
    OUTPUT x: BOOLEAN
    INITIALIZATION x = FALSE
    TRANSITION [ x --> x' = FALSE ]
  END;
END
" stream))
    (loop for (assertion backend induction module expected)
            in '(("holds" :smc nil nil :proved)
                 ("bad" :smc nil nil :counterexample)
                 ("holds" :bmc nil nil :bounded)
                 ("holds" :bmc t nil :proved)
                 (nil :deadlock nil "stuck" :deadlock)
                 (nil :deadlock nil "machine" :deadlock-free))
          for result = (sal-run-check source assertion :backend backend :depth 2
                                       :induction induction :module module)
          do (assert (eq expected (sal-check-result-outcome result)))
             (when (member expected '(:proved :deadlock-free))
               (assert (sal-check-result-exact-p result)))
          collect result)))

(defun sal-test-backend-instances ()
  "Actuals must select the checked instance, and source extensions stay exact."
  (let* ((directory (sal-backend-work-directory))
         (source (merge-pathnames "backend_parameter.sal" directory))
         (lsal (merge-pathnames "backend_parameter.lsal" directory)))
    (with-open-file (out source :direction :output :if-exists :supersede)
      (write-string
       "backend_parameter{start: BOOLEAN}: CONTEXT =
BEGIN
  machine[flip: BOOLEAN]: MODULE =
  BEGIN
    OUTPUT x: BOOLEAN
    INITIALIZATION x = start
    TRANSITION x' = IF flip THEN NOT x ELSE x ENDIF
  END;
  holds: THEOREM machine[FALSE] |- G(x = FALSE);
END
" out))
    ;; Same context name, distinct source and opposite property. A path search
    ;; that silently loads the .sal sibling would return the wrong outcome.
    (with-open-file (out lsal :direction :output :if-exists :supersede)
      (write-string
       "(context backend_parameter () (start::bool)
  (define-module (machine flip::bool)
    (begin (output x::bool)
      (initialization (= x start))
      (transition (= x' (if flip (not x) x)))))
  (theorem holds (|- (machine false) (G (= x true)))))
" out))
    (loop for (file selector expected)
            in (list (list source "backend_parameter{FALSE}!machine[FALSE]" :proved)
                     (list source "backend_parameter{TRUE}!machine[FALSE]" :counterexample)
                     (list source "backend_parameter{FALSE}!machine[TRUE]" :error)
                     (list lsal "backend_parameter{FALSE}!machine[FALSE]" :counterexample)
                     (list lsal "((@ machine (backend_parameter () (false))) false)"
                           :counterexample))
          for result = (sal-run-check file "holds" :module "machine" :selector selector)
          do (assert (eq expected (sal-check-result-outcome result)))
             (when (eq expected :proved) (assert (sal-check-result-exact-p result)))
          collect result)))

(defun sal-run-backend-tests (&key live)
  (assert (sal-test-backend-result-parser))
  (assert (sal-test-backend-malformed-output))
  (assert (sal-test-backend-snapshots))
  (if live (append (sal-test-backend-live) (sal-test-backend-instances)) t))

(export '(sal-run-backend-tests))
