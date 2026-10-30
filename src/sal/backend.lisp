;;; SAL subprocesses and semantic result classification.  This is not an
;;; evidence checker: successful results remain an explicit trust boundary.
(in-package :pvs)

(defvar *sal-backend-directory*
  (uiop:pathname-directory-pathname (or *load-truename* *compile-file-truename*)))
(defvar *sal-backend-home* nil)
(defvar *sal-last-check-result* nil)

(defstruct sal-check-result
  backend source assertion module selector depth induction command version
  source-fingerprint source-snapshots exit-status stdout stderr outcome
  exact-p started-at elapsed-seconds)

(defun sal-file-snapshot (path)
  "Capture exact contents; the fingerprint is only a human-readable identifier."
  (let ((absolute (merge-pathnames path (uiop:getcwd))))
    (cons (namestring absolute)
          (and (probe-file absolute) (uiop:read-file-string absolute)))))

(defun sal-snapshots-current-p (snapshots)
  (every (lambda (entry) (equal entry (sal-file-snapshot (car entry)))) snapshots))

(defun sal-text-fingerprint (text)
  "Stable FNV-1a identifier, never used instead of exact source comparison."
  (let ((hash #xcbf29ce484222325))
    (loop for character across text
          do (setf hash (ldb (byte 64 0)
                             (* (logxor hash (char-code character))
                                #x100000001b3))))
    (format nil "fnv1a64:~16,'0x" hash)))

(defun sal-user-configuration-path ()
  (let ((home (uiop:getenv "HOME")))
    (and home (merge-pathnames ".salrc" (uiop:ensure-directory-pathname home)))))

(defun sal-output-lines (text)
  (with-input-from-string (stream text)
    (loop for line = (read-line stream nil nil) while line
          collect (string-trim '(#\Space #\Tab #\Return) line))))

(defun sal-classify-check-output (backend stdout stderr exit-status
                                 &key induction)
  "Return OUTCOME and EXACT-P, based on SAL's semantic output, not exit status.
Unknown or contradictory output fails closed.  Backend normalization warnings
are retained and disqualify proof closure, even when SAL prints `proved.'."
  (let* ((text (concatenate 'string stdout (string #\Newline) stderr))
         (lines (sal-output-lines stdout))
         (proved (member "proved." lines :test #'string=))
         (invalid (member "invalid." lines :test #'string=))
         (counterexample (search "Counterexample:" text))
         (bounded (search "no counterexample between depths:" text))
         (induction-failed (search "k-induction rule failed" text))
         (deadlock-free
          (member "ok (module does NOT contain deadlock states)." lines
                  :test #'string=))
         (deadlock (search "Total number of deadlock states:" text))
         ;; The admitted frontend is exact; do not silently inherit backend
         ;; approximations or SAL's deadlock caveat for liveness properties.
         (exact-p
          (not (or (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                              stderr)))
                   (search "WARNING" text :test #'char-equal)
                   (search "warning:" text :test #'char-equal)
                   (search "constraint) will be lost" text :test #'char-equal)
                   (search "only true if it is deadlock free" text
                           :test #'char-equal)))))
    (values
     (cond
       ((not (eql exit-status 0)) :error)
       ((and proved (or invalid counterexample bounded induction-failed)) :unknown)
       ((eq backend :deadlock)
        (cond ((and deadlock-free (not deadlock)) :deadlock-free)
              ((and deadlock (not deadlock-free)) :deadlock)
              (t :unknown)))
       (counterexample :counterexample)
       (invalid :invalid)
       (induction-failed :induction-failed)
       (bounded :bounded)
       (proved (if (or (eq backend :smc) induction) :proved :bounded))
       (t :unknown))
     exact-p)))

(defun sal-backend-program (backend)
  (let* ((home (or *sal-backend-home* (uiop:getenv "SAL_HOME")
                   (error "Set SAL_HOME or *sal-backend-home* to the SAL installation.")))
         (name (ecase backend
                 (:smc "sal-smc") (:bmc "sal-bmc")
                 (:inf-bmc "sal-inf-bmc") (:deadlock "sal-deadlock-checker")))
         (program (merge-pathnames (concatenate 'string "bin/" name)
                                   (uiop:ensure-directory-pathname home))))
    (unless (probe-file program) (error "SAL backend not found: ~a" program))
    (namestring program)))

(defun sal-backend-work-directory ()
  (let ((directory (merge-pathnames ".work/backend/" *sal-backend-directory*)))
    (when (fboundp 'sal-bridge-output-path)
      (setf directory (sal-bridge-output-path directory)))
    (ensure-directories-exist (merge-pathnames "placeholder" directory))
    directory))

(defun sal-run-check (source assertion &key (backend :smc) (depth 10)
                                      induction module dependencies selector)
  "Run a SAL tool using an argument vector and retain its complete transcript.

Only fixed options are accepted: unproved lemmas and arbitrary backend flags
cannot enter through this API.  Plain BMC success is :BOUNDED, not :PROVED.
DEPENDENCIES are additional SAL source files whose exact contents are retained.
SELECTOR is the same qualified module expression used by the imported view;
its native context actuals are also used for the selected assertion.
The process runs and creates temporary files only inside src/sal/.work/backend."
  (unless (and (integerp depth) (<= 0 depth))
    (error "SAL depth must be a nonnegative integer: ~s" depth))
  (let* ((source (or (probe-file source) (error "SAL source missing: ~a" source)))
         (subject (if (eq backend :deadlock) module assertion))
         (_ (unless (and (stringp subject) (plusp (length subject))
                         (not (char= (char subject 0) #\-)))
              (error "SAL requires an assertion/module name, got ~s" subject)))
         (program (sal-backend-program backend))
         (work (sal-backend-work-directory))
         (preload (merge-pathnames "tools/sal-backend-preload.scm"
                                   *sal-backend-directory*))
         (dependencies (remove source
                               (remove-duplicates
                                (mapcar (lambda (file)
                                          (or (probe-file file)
                                              (error "SAL dependency missing: ~a" file)))
                                        dependencies)
                                :test #'equal)
                               :test #'equal))
         (environment (list "/usr/bin/env"
                            (concatenate 'string "TMPDIR=" (namestring work))))
         (command (append environment (list program (namestring preload)
                                            "--sal-bridge-source" (namestring source))
                          (loop for file in dependencies
                                append (list "--sal-bridge-dependency" (namestring file)))
                          (when module (list "--sal-bridge-module" module))
                          (unless (eq backend :deadlock)
                            (list "--sal-bridge-assertion" assertion))
                          (when selector (list "--sal-bridge-selector" selector))
                          (when (member backend '(:bmc :inf-bmc))
                            (append (list (format nil "--depth=~d" depth))
                                    (when induction (list "--induction"))))))
         (snapshots (mapcar #'sal-file-snapshot
                           (remove-duplicates
                            (append (list source) dependencies
                                    (let ((rc (sal-user-configuration-path)))
                                      (and rc (list rc))))
                            :test #'equal)))
         (started (get-universal-time))
         (ticks (get-internal-real-time)))
    (declare (ignore _))
    (unless (probe-file preload) (error "SAL backend preloader missing: ~a" preload))
    (when (and selector (or (not (stringp selector)) (null module)))
      (error "A SAL selector requires a qualified module expression and module name."))
    (multiple-value-bind (version version-errors version-status)
        (uiop:run-program (append environment (list program "--version"))
                          :directory work :output :string :error-output :string
                          :ignore-error-status t)
      (declare (ignore version-status))
      (multiple-value-bind (stdout stderr status)
          (uiop:run-program command :directory work :output :string
                            :error-output :string :ignore-error-status t)
        (multiple-value-bind (outcome exact-p)
            (sal-classify-check-output backend stdout stderr status :induction induction)
          (unless (sal-snapshots-current-p snapshots)
            (setf outcome :stale-source exact-p nil))
          (setf *sal-last-check-result*
                (make-sal-check-result
                 :backend backend :source source :assertion assertion :module module
                 :selector selector
                 :depth depth :induction induction :command command
                 :version (string-trim '(#\Space #\Tab #\Newline #\Return)
                                       (concatenate 'string version version-errors))
                 :source-fingerprint
                 (sal-text-fingerprint
                  (cdr (assoc (namestring source) snapshots :test #'equal)))
                 :source-snapshots snapshots :exit-status status
                 :stdout stdout :stderr stderr :outcome outcome :exact-p exact-p
                 :started-at started
                 :elapsed-seconds (/ (- (get-internal-real-time) ticks)
                                     (float internal-time-units-per-second)))))))))

(defun sal-print-check-result (&optional (result *sal-last-check-result*)
                                        (stream *standard-output*))
  (if (null result)
      (format stream "~&No SAL backend result is available.~%")
      (progn
        (format stream "~&SAL ~a: ~a (~a), ~a~%"
                (sal-check-result-backend result) (sal-check-result-source result)
                (or (sal-check-result-assertion result)
                    (sal-check-result-module result))
                (sal-check-result-outcome result))
        (when (sal-check-result-selector result)
          (format stream "Selected instance: ~a~%" (sal-check-result-selector result)))
        (format stream "Source ~a; backend ~a~%"
                (sal-check-result-source-fingerprint result)
                (sal-check-result-version result))
        (unless (sal-check-result-exact-p result)
          (format stream "Backend diagnostics or changed source prevent proof closure.~%"))
        (write-string (sal-check-result-stdout result) stream)
        (write-string (sal-check-result-stderr result) stream)))
  result)

(defun sal-test-backend-result-parser ()
  "Small regression suite for proof-relevant distinctions in SAL output."
  (flet ((expect (outcome backend output &optional induction (status 0))
           (assert (eq outcome (sal-classify-check-output
                                backend output "" status :induction induction)))))
    (expect :proved :smc (format nil "proved.~%"))
    (expect :bounded :bmc (format nil "proved.~%"))
    (expect :proved :bmc (format nil "proved.~%") t)
    (expect :bounded :bmc "no counterexample between depths: [0, 10].")
    (expect :counterexample :smc "Counterexample:")
    (expect :invalid :smc "invalid.")
    (expect :unknown :smc "")
    (expect :unknown :smc (format nil "proved.~%Counterexample:~%"))
    (expect :error :smc "proved." nil 1)
    (expect :induction-failed :bmc "k-induction rule failed, please try to increase the depth." t)
    (expect :deadlock-free :deadlock "ok (module does NOT contain deadlock states).")
    (expect :deadlock :deadlock "Total number of deadlock states: 1")
    (assert (not (nth-value 1 (sal-classify-check-output
                              :smc "proved." "WARNING: possible incompleteness" 0))))
    t))

(export '(sal-run-check sal-check-result sal-check-result-outcome
          sal-check-result-exact-p sal-check-result-stdout sal-check-result-stderr
          sal-check-result-command sal-check-result-source-fingerprint
          sal-check-result-version sal-print-check-result
          sal-test-backend-result-parser *sal-last-check-result* *sal-backend-home*))
