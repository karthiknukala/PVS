;;; Real native-session regression assertions. All declarations and generated
;;; files live in test_lifecycle.py's disposable context. Queue barriers force
;;; the races; sleeps are not used as evidence of correctness.
(in-package :pvs)

(defun agent-lifecycle-mark (name)
  (format t "~%AGENT-TEST ~a~%" name) (finish-output))
(defun agent-lifecycle-pop (queue)
  (sb-ext:with-timeout 5 (pop-queue queue)))
(defun agent-lifecycle-join (thread)
  (sb-ext:with-timeout 5 (bt:join-thread thread)))
(defun agent-lifecycle-until (predicate)
  (let ((deadline (+ (get-internal-real-time) (* 5 internal-time-units-per-second))))
    (loop until (funcall predicate)
          do (when (> (get-internal-real-time) deadline)
               (error "Lifecycle test condition did not become true"))
             (sleep .005))))
(defun agent-lifecycle-error-p (thunk)
  (handler-case (progn (funcall thunk) nil) (error () t)))
(defun agent-lifecycle-value (key result)
  (cdr (assoc key result :test #'string=)))
(defun agent-lifecycle-spawn (thunk queue)
  (bt:make-thread
   (lambda ()
     (handler-case (push-queue (funcall thunk) queue)
       (error (condition) (push-queue condition queue))))))

(setq *noninteractive* nil *proof-prompt-behavior* :noquestions
      *proceed-without-asking* t)
(change-context (uiop:getenv "PVS_AGENT_TEST_CONTEXT"))
(typecheck-file "lifecycle_probe")
(defparameter *agent-lifecycle-theory* (get-typechecked-theory "lifecycle_probe"))
(defparameter *agent-lifecycle-decl*
  (find "target" (theory *agent-lifecycle-theory*)
        :key (lambda (decl) (string (id decl))) :test #'string=))
(defparameter *agent-lifecycle-proof*
  (agent-lifecycle-value "id" (prover-init *agent-lifecycle-decl*)))
(defparameter *agent-lifecycle-evaluator*
  (agent-lifecycle-value "id" (agent-pvsio-init "lifecycle_probe")))

(assert (agent-call-in-session
         *agent-lifecycle-proof*
         (lambda ()
           (and (typep (current-session) 'proof-session)
                (eq *ps* (agent-current-proofstate))
                (eq (bt:current-thread) (thread (current-session)))))))
(assert (agent-lifecycle-error-p
         (lambda () (pvsio-eval *agent-lifecycle-proof* "1" "pvs"))))
(agent-lifecycle-mark "TYPED-STARTUP-OWNING-THREAD-PASS")

;; Leave the evaluator between publishing a result and calling session-read.
;; A second caller queues its cache query during that exact interval.
(let* ((state (agent-session-state *agent-lifecycle-evaluator*))
       (original (symbol-function 'agent-publish))
       (paused (make-queue)) (resume (make-queue)) (answers (make-queue))
       (pause-once t))
  (assert (string= "3" (agent-lifecycle-value
                       "pvsResult" (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs"))))
  (setf (symbol-function 'agent-publish)
        (lambda (actual value &rest options)
          (multiple-value-prog1 (apply original actual value options)
            (when (and pause-once (eq actual state)
                       (listp value) (assoc "pvsResult" value :test #'equal))
              (setf pause-once nil)
              (push-queue t paused)
              (agent-lifecycle-pop resume)))))
  (unwind-protect
       (let ((first (agent-lifecycle-spawn
                     (lambda () (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs"))
                     answers)))
         (agent-lifecycle-pop paused)
         (assert (string= "3" (agent-lifecycle-value "pvsResult" (agent-lifecycle-pop answers))))
         (agent-lifecycle-join first)
         (let ((second (agent-lifecycle-spawn
                        (lambda () (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs"))
                        answers)))
           (agent-lifecycle-until (lambda () (eq :queued (agent-session-data-phase state))))
           (push-queue t resume)
           (assert (string= "3" (agent-lifecycle-value "pvsResult" (agent-lifecycle-pop answers))))
           (agent-lifecycle-join second)))
    (push-queue t resume)
    (setf (symbol-function 'agent-publish) original)))
(agent-lifecycle-mark "QUEUED-REPLY-CORRELATION-PASS")

;; Abandon a caller while its proof worker is still executing. The admission
;; counter unwinds, but setup and a second command must remain excluded until
;; the native worker actually returns to idle. Its unread result must not block.
(defparameter *agent-lifecycle-entered* (make-queue))
(defparameter *agent-lifecycle-release* (make-queue))
(let* ((state (agent-session-state *agent-lifecycle-proof*))
       (caller
         (bt:make-thread
          (lambda ()
            (catch 'agent-lifecycle-disconnect
              (prover-step
               *agent-lifecycle-proof*
               "(lisp (progn (push-queue t *agent-lifecycle-entered*) (pop-queue *agent-lifecycle-release*)))"))))))
  (agent-lifecycle-pop *agent-lifecycle-entered*)
  (assert (agent-lifecycle-error-p
           (lambda () (prover-step *agent-lifecycle-proof* "(skip)"))))
  (bt:interrupt-thread caller (lambda () (throw 'agent-lifecycle-disconnect t)))
  (agent-lifecycle-join caller)
  (assert (zerop *agent-active-operations*))
  (assert (eq :running (agent-session-data-phase state)))
  (assert (agent-lifecycle-error-p (lambda () (agent-call-with-setup (lambda () t)))))
  (assert (agent-lifecycle-error-p
           (lambda () (prover-step *agent-lifecycle-proof* "(skip)"))))
  ;; A warmed expression still executes on its independent evaluator thread.
  (assert (string= "3" (agent-lifecycle-value
                       "pvsResult" (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs"))))
  (interrupt-session *agent-lifecycle-proof*)
  (agent-lifecycle-until (lambda () (eq :idle (agent-session-data-phase state))))
  (assert (agent-session-data-interrupted state)))
(agent-lifecycle-mark "ABANDONED-CALLER-ADMISSION-RECOVERY-PASS")

;; Hold the worker after publishing Q.E.D. so status cannot rely on thread exit.
(let* ((state (agent-session-state *agent-lifecycle-proof*))
       (original (symbol-function 'agent-publish))
       (paused (make-queue)) (resume (make-queue)) (answers (make-queue)))
  (setf (symbol-function 'agent-publish)
        (lambda (actual value &rest options)
          (multiple-value-bind (result published) (apply original actual value options)
            (when (and published (eq actual state) (getf options :terminal))
              (push-queue t paused)
              (agent-lifecycle-pop resume))
            (values result published))))
  (unwind-protect
       (let ((caller (agent-lifecycle-spawn
                      (lambda () (prover-step *agent-lifecycle-proof* "(grind)")) answers)))
         (agent-lifecycle-pop paused)
         (assert (string= "proved" (agent-lifecycle-value "status" (agent-lifecycle-pop answers))))
         (agent-lifecycle-join caller)
         (assert (session-alive-p (agent-session-data-session state)))
         (session-kill (agent-session-data-session state))
         (assert (string= "proved"
                          (agent-lifecycle-value "status" (car (prover-status *agent-lifecycle-proof*)))))
         (push-queue t resume))
    (push-queue t resume)
    (setf (symbol-function 'agent-publish) original))
  (agent-lifecycle-join (thread (agent-session-data-session state)))
  (assert (null (agent-session-data-timer state))))
(agent-lifecycle-mark "RECOVERY-QED-TERMINAL-STATUS-PASS")

;; A worker error must complete its startup request and unwind its timer.
(multiple-value-bind (sess request)
    (agent-call-with-setup
     (lambda ()
       (agent-make-native-session
        'pvsio-session 'agent-lifecycle-failure
        (lambda () (agent-call-with-session-timer (lambda () (error "worker sentinel")))))))
  (assert (agent-lifecycle-error-p (lambda () (agent-await-request request))))
  (agent-lifecycle-join (thread sess))
  (assert (null (get-session (id sess))))
  (assert (eq :failed (agent-session-data-phase (agent-session-state sess))))
  (assert (null (agent-session-data-timer (agent-session-state sess)))))
(agent-lifecycle-mark "STARTUP-FAILURE-WAKE-TIMER-CLEANUP-PASS")

;; No consumer ever reads this terminal reply.
(multiple-value-bind (sess request)
    (agent-call-with-setup
     (lambda ()
       (agent-make-native-session 'pvsio-session 'agent-lifecycle-undrained
                                 (lambda () (session-finish)))))
  (declare (ignore request))
  (agent-lifecycle-join (thread sess))
  (assert (not (session-alive-p sess))))
(agent-lifecycle-mark "UNDRAINED-TERMINAL-PASS")

(let ((proof (agent-lifecycle-value "id" (prover-init *agent-lifecycle-decl*))))
  (quit-all-proof-sessions)
  (agent-lifecycle-until (lambda () (null (get-session proof))))
  (assert (null (get-session proof)))
  (assert (string= "3" (agent-lifecycle-value
                       "pvsResult" (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs")))))
(assert (string= "bye!" (pvsio-eval *agent-lifecycle-evaluator* "quit" "pvs")))
(assert (agent-lifecycle-error-p
         (lambda () (pvsio-eval *agent-lifecycle-evaluator* "1 + 2" "pvs"))))
(agent-lifecycle-mark "PROOF-ONLY-SHUTDOWN-DEAD-ID-PASS")
(uiop:quit 0)
