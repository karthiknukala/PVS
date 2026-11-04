;;; Native PVSio repairs. Upstream src/PVSio/pvsio.lisp, baseline e185d56.
;;; Preparation is exclusive; execution of prepared concrete expressions may overlap proofs.
(in-package :pvs)

(defvar *agent-strict-evaluation* nil)
(defvar *agent-evaluation-cache* nil)
(defvar *agent-evaluation-generation* 0)
(defstruct (agent-evaluation (:constructor agent-make-evaluation))
  expression translated type void error generation (tcc-message "") (debug-message ""))

(dolist (name '(pvsio-init pvsio-eval pvsio-in-session evaluate-in-session
                load-pvs-attachments))
  (agent-remember-original name))

(defun load-pvs-attachments (&optional force (verbose t))
  (agent-call-with-setup
   (lambda ()
     ;; Also invalidate on partial-load failure: definitions may already have changed.
     (incf *agent-evaluation-generation*)
     (funcall (agent-original 'load-pvs-attachments) force verbose))))

(defun agent-pvsio-init (theoryref)
  "Agent evaluation generates TCCs and refuses execution when any remain."
  (let ((*agent-strict-evaluation* t))
    (pvsio-init theoryref :tccs? t)))

(defun pvsio-init (theoryref &key input-hook tccs?)
  (agent-call-with-setup
   (lambda ()
     (let* ((theory (get-typechecked-theory theoryref))
            (context (context theory))
            (id (get-new-session-id (id theory)))
            (strict *agent-strict-evaluation*))
       (multiple-value-bind (sess request)
           (agent-make-native-session
            'pvsio-session id
            (lambda ()
              (let ((*agent-strict-evaluation* strict))
                (agent-call-with-proof-runtime
                 (lambda () (pvsio-in-session id context input-hook tccs?)))))
            :context context)
         (unwind-protect
              (progn
                (agent-await-request request)
                `(("id" . ,(string id)) ("promptIn" . ,*pvsio-promptin*)
                  ("version" . ,*pvsio-version*)))
           (setf (agent-session-data-claimed (agent-session-state sess)) nil)))))))

(defun agent-pvsio-quit-p (expression)
  (member expression '("quit" "q" "(quit)" "exit" "(exit)") :test #'string-equal))

(defun agent-pvsio-meta-p (expression)
  (member expression
          '("help" "debug" "nodebug" "timing" "notiming" "tccs" "notccs"
            "pvsio-version" "pvsio_version" "list-pvs-attachments"
            "list_pvs_attachments" "load-pvs-attachments" "load_pvs_attachments")
          :test #'string-equal))

(defun agent-prepare-evaluation (expression)
  "Parse, typecheck, and translate under exclusive setup; execute nothing here."
  (let ((prepared (agent-make-evaluation :expression expression :generation *agent-evaluation-generation*))
        (tcc-stream (make-string-output-stream))
        (debug-stream (make-string-output-stream)))
    (handler-case
        (let* ((*generate-tccs* (if *agent-strict-evaluation* 'all *generate-tccs*))
               (parsed (pc-parse expression 'expr))
               (*tccforms* nil)
               (typed (pc-typecheck parsed)))
          (setf (agent-evaluation-type prepared) (type typed)
                (agent-evaluation-void prepared)
                (and (type-name? (type typed))
                     (string= "void" (format nil "~a" (print-type (type typed))))))
          (when *evaluator-debug*
            (format debug-stream "~%Expression ~a typechecks to:~%" parsed)
            (let ((*standard-output* debug-stream)) (show typed)))
          (when *tccforms*
            (format tcc-stream "~%Typechecking ~a produced the following TCCs:~%" parsed)
            (let ((*standard-output* tcc-stream)) (evaluator-print-tccs *tccforms*))
            (if *agent-strict-evaluation*
                (setf (agent-evaluation-error prepared)
                      "Evaluation stopped before execution: unresolved TCCs")
                (format tcc-stream "~%Warning: proceeding with evaluation despite unproven TCCs~%")))
          (unless (agent-evaluation-error prepared)
            (setf (agent-evaluation-translated prepared) (pvs2cl typed))
            (when *evaluator-debug*
              (format debug-stream "~%Common Lisp translation:~%~s~%"
                      (agent-evaluation-translated prepared)))))
      (error (condition) (setf (agent-evaluation-error prepared) (princ-to-string condition))))
    (setf (agent-evaluation-tcc-message prepared) (get-output-stream-string tcc-stream)
          (agent-evaluation-debug-message prepared) (get-output-stream-string debug-stream))
    prepared))

(defun agent-evaluation-cache-key (expression)
  (list expression *agent-evaluation-generation* *generate-tccs*
        *agent-strict-evaluation* *evaluator-debug*))

(defun agent-cached-evaluation (expression)
  (gethash (agent-evaluation-cache-key expression) *agent-evaluation-cache*))

(defun agent-prepare-and-cache-evaluation (expression)
  (setf (gethash (agent-evaluation-cache-key expression) *agent-evaluation-cache*)
        (agent-prepare-evaluation expression)))

(defun agent-pvsio-base-result (sess expression kind)
  `(("sessionId" . ,(string (id sess)))
    ("inputKind" . ,kind) ("inputExpr" . ,expression)))

(defun agent-evaluate-prepared (sess prepared)
  (let* ((result (agent-pvsio-base-result sess (agent-evaluation-expression prepared) 'pvs))
         (res (make-string-output-stream)) (std (make-string-output-stream))
         (err (make-string-output-stream)) (deb (make-string-output-stream)))
    (write-string (agent-evaluation-debug-message prepared) deb)
    (if (agent-evaluation-error prepared)
        (write-string (agent-evaluation-error prepared) err)
        (handler-case
            (let ((value
                    (let ((*standard-output* std) (*error-output* err) (*trace-output* deb))
                      (if *pvs-eval-do-timing*
                          (time (eval (agent-evaluation-translated prepared)))
                          (eval (agent-evaluation-translated prepared))))))
              (when *evaluator-debug*
                (format deb "~%Common Lisp result: ~s~%" value))
              (when (and *convert-back-to-pvs* (not (agent-evaluation-void prepared)))
                (let ((pvs-value (cl2pvs value (agent-evaluation-type prepared))))
                  (assert (expr? pvs-value))
                  (write-string (unparse pvs-value :string t) res))))
          (error (condition) (format err "~a" condition))))
    (nconc result
           `(("promptOut" . ,(format nil *pvsio-promptout*))
             ("promptIn" . ,(format nil *pvsio-promptin*))
             ("stdOut" . ,(get-output-stream-string std))
             ("pvsResult" . ,(get-output-stream-string res))
             ("debugMsg" . ,(get-output-stream-string deb))
             ("tccMsg" . ,(agent-evaluation-tcc-message prepared))
             ("errOut" . ,(get-output-stream-string err))))))

(defun agent-pvsio-meta-result (sess expression kind)
  (let ((base (agent-pvsio-base-result sess expression kind))
        (debug ""))
    (cond
      ((string-equal expression "help")
       (setf debug (with-output-to-string (*standard-output*) (help-pvsio))))
      ((string-equal expression "debug")
       (setf *evaluator-debug* t debug "Debug output enabled"))
      ((string-equal expression "nodebug")
       (setf *evaluator-debug* nil debug "Debug output disabled"))
      ((string-equal expression "timing")
       (setf *pvs-eval-do-timing* t debug "Timing enabled"))
      ((string-equal expression "notiming")
       (setf *pvs-eval-do-timing* nil debug "Timing disabled"))
      ((string-equal expression "tccs")
       (setf *generate-tccs* 'all debug "TCC generation enabled"))
      ((string-equal expression "notccs")
       (if *agent-strict-evaluation*
           (return-from agent-pvsio-meta-result
             (nconc base '(("errOut" . "Agent evaluation requires TCC generation"))))
           (setf *generate-tccs* 'none debug "TCC generation disabled")))
      ((member expression '("pvsio-version" "pvsio_version") :test #'string-equal)
       (setf debug (format nil "~a" *pvsio-version*)))
      ((member expression '("list-pvs-attachments" "list_pvs_attachments") :test #'string-equal)
       (setf debug (with-output-to-string (*standard-output*) (list-pvs-attachments))))
      ((member expression '("load-pvs-attachments" "load_pvs_attachments") :test #'string-equal)
       (setf debug (with-output-to-string (*standard-output*)
                     (load-pvs-attachments t)))))
    (nconc base `(("debugMsg" . ,debug)))))

(defun agent-evaluate-lisp (sess expression)
  (let ((res (make-string-output-stream)) (std (make-string-output-stream))
        (err (make-string-output-stream)))
    (let ((*standard-output* std) (*error-output* err))
      (handler-case (format res "~s" (eval (read-from-string expression)))
        (error (condition) (format err "~a" condition))))
    (nconc (agent-pvsio-base-result sess expression 'lisp)
           `(("stdOut" . ,(get-output-stream-string std))
             ("errOut" . ,(get-output-stream-string err))
             ("lispResult" . ,(get-output-stream-string res))))))

(defun pvsio-eval (session-id pvs-ex kind)
  (unless (and (stringp pvs-ex) (member kind '("pvs" "lisp") :test #'string-equal))
    (error "Evaluator expects a string expression and kind pvs or lisp"))
  (let* ((state (agent-require-session session-id :evaluator))
         (sess (agent-session-data-session state))
         (kind (if (string-equal kind "lisp") 'lisp 'pvs)))
    (unless (agent-pvsio-quit-p pvs-ex)
      (when (fboundp 'agent-check-prepared-sources) (agent-check-prepared-sources)))
    (agent-call-with-session-claim
     state
     (lambda ()
       (let* ((prepared
                (when (and (eq kind 'pvs) (not (agent-pvsio-quit-p pvs-ex))
                           (not (agent-pvsio-meta-p pvs-ex)))
                  (or (agent-call-with-operation
                       (lambda ()
                         (agent-dispatch state :query
                                         (lambda () (agent-cached-evaluation pvs-ex)))))
                      (agent-call-with-setup
                       (lambda ()
                         (agent-dispatch state :prepare
                                         (lambda () (agent-prepare-and-cache-evaluation pvs-ex))))))))
              (result
                (if (member pvs-ex '("load-pvs-attachments" "load_pvs_attachments")
                            :test #'string-equal)
                    (agent-call-with-setup
                     (lambda () (agent-dispatch state :prepare
                                               (lambda () (agent-pvsio-meta-result sess pvs-ex kind)))))
                    (agent-call-with-operation
                     (lambda ()
                       (when (and prepared
                                  (/= (agent-evaluation-generation prepared)
                                      *agent-evaluation-generation*))
                         (error "Evaluator definitions changed after preparation; retry while idle"))
                       (agent-dispatch state :command (list kind pvs-ex prepared)))))))
         (push (cons pvs-ex result) (history sess))
         result)))))

(defun pvsio-in-session (session-id context input-hook &optional tccs?)
  (let ((*pvsio-input-hooks* (if input-hook (cons input-hook *pvsio-input-hooks*)
                                *pvsio-input-hooks*))
        (*pvs-message-hook* (list #'session-output))
        (sess (get-session session-id)))
    (with-context context
      (let ((*generate-tccs* (if tccs? 'all 'none))
            (*current-context* (or context (context nil))) (*suppress-msg* t)
            (*in-evaluator* t) (*destructive?* nil) (*eval-verbose* nil)
            (*compile-verbose* nil) (*convert-back-to-pvs* t) (*disable-gc-printout* t)
            (*pvstrace-level* 0) (*eval-untranslatable* nil) (*pvs2cl-mappings* nil)
            ;; These options must belong to the evaluator, not the process.
            (*evaluator-debug* nil) (*pvs-eval-do-timing* nil)
            (*agent-evaluation-cache* (make-hash-table :test #'equal)))
        (reset-pseudo-normalize-caches)
        (load-pvs-attachments)
        (agent-call-with-session-timer
         (lambda () (evaluate-in-session sess)))))))

(defun evaluate-in-session (sess)
  (if (not (agent-session-state sess))
      (funcall (agent-original 'evaluate-in-session) sess)
      (loop
        (destructuring-bind (kind expression prepared) (session-read)
          (let* ((state (agent-session-state sess))
                 (quit (agent-pvsio-quit-p expression))
                 (result
                   (restart-case
                       (handler-case
                           (cond (quit "bye!")
                                 ((agent-pvsio-meta-p expression)
                                  (agent-pvsio-meta-result sess expression kind))
                                 ((eq kind 'lisp) (agent-evaluate-lisp sess expression))
                                 (prepared (agent-evaluate-prepared sess prepared))
                                 (t (error "Evaluation was not prepared")))
                         (error (condition)
                           (nconc (agent-pvsio-base-result sess expression kind)
                                  `(("errOut" . ,(princ-to-string condition))))))
                     (agent-evaluator-abort ()
                       (nconc (agent-pvsio-base-result sess expression kind)
                              '(("errOut" . "Evaluation interrupted; external effects are not rolled back")))))))
            (agent-publish state result :terminal (when quit :closed))
            (when quit (return result)))))))
