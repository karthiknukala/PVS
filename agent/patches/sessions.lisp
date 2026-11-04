;;; Native session repairs. Upstream src/pvs-threads.lisp, baseline e185d56.
;;; No core class layouts change; bookkeeping belongs to this extension.
(in-package :pvs)

(defvar *agent-admission-lock* (bt:make-lock "agent admission"))
(defvar *agent-registry-lock* (bt:make-lock "agent registry"))
(defvar *agent-active-operations* 0)
(defvar *agent-setup-active* nil)
(defvar *agent-in-setup* nil)
(defvar *agent-bound-session* nil)
(defvar *agent-bound-state* nil)
(defvar *agent-session-table* (make-hash-table :test #'equalp))

(defstruct (agent-session-data (:constructor agent-make-session-data))
  session kind (lock (bt:make-lock "agent session"))
  (phase :starting) (sequence 0) claimed request last-proofstate error
  interrupt-requested interrupted timer recovery-note)
(defstruct (agent-request (:constructor agent-make-request))
  sequence kind payload (reply (make-queue)))
(defstruct (agent-reply (:constructor agent-make-reply))
  sequence value error)

(defun agent-call-with-setup (thunk)
  "Run setup only with no admitted operations; never wait for busy workers."
  (if *agent-in-setup*
      (funcall thunk)
      (progn
        (bt:with-lock-held (*agent-admission-lock*)
          (when (or *agent-setup-active* (plusp *agent-active-operations*)
                    (bt:with-lock-held (*agent-registry-lock*)
                      (loop for state being the hash-values of *agent-session-table*
                            thereis (member (agent-session-data-phase state)
                                            '(:starting :queued :running :inspecting)))))
            (error "PVS setup requires all operations to be idle"))
          (setf *agent-setup-active* t))
        (unwind-protect
             (let ((*agent-in-setup* t)) (funcall thunk))
          (bt:with-lock-held (*agent-admission-lock*)
            (setf *agent-setup-active* nil))))))

(defun agent-call-with-operation (thunk)
  "Admit independent native commands concurrently; exclude global setup."
  (bt:with-lock-held (*agent-admission-lock*)
    (when *agent-setup-active*
      (error "PVS setup is in progress; retry after setup completes"))
    (incf *agent-active-operations*))
  (unwind-protect (funcall thunk)
    (bt:with-lock-held (*agent-admission-lock*)
      (decf *agent-active-operations*))))

(defun agent-session-state (session-or-id)
  (when session-or-id
    (bt:with-lock-held (*agent-registry-lock*)
      (gethash (string (if (typep session-or-id 'session)
                          (id session-or-id) session-or-id))
               *agent-session-table*))))

(defun agent-native-proof-status (state)
  "Whole-proof status, independent of a worker's final cleanup interval."
  (let ((phase (agent-session-data-phase state))
        (ps (agent-session-data-last-proofstate state)))
    (cond ((member phase '(:failed :aborted)) "aborted")
          ((eq phase :closed)
           (if (and (typep ps 'top-proofstate) (eq (status-flag ps) '!))
               "proved" "quit"))
          ((session-alive-p (agent-session-data-session state)) "active")
          (t "inactive"))))

(defun agent-session-info (&optional session-id)
  "Return JSON-ready native session state, including retained terminal sessions."
  (let ((states
          (bt:with-lock-held (*agent-registry-lock*)
            (if session-id
                (let ((state (gethash (string session-id) *agent-session-table*)))
                  (when state (list state)))
                (loop for state being the hash-values of *agent-session-table*
                      collect state)))))
    (mapcar
     (lambda (state)
       (bt:with-lock-held ((agent-session-data-lock state))
         (let ((sess (agent-session-data-session state))
               (ps (agent-session-data-last-proofstate state)))
           `(("id" . ,(string (id sess)))
             ("kind" . ,(string-downcase (agent-session-data-kind state)))
             ("state" . ,(string-downcase (agent-session-data-phase state)))
             ("proofStatus" . ,(when (eq (agent-session-data-kind state) :proof)
                                  (agent-native-proof-status state)))
             ("alive" . ,(and (thread sess) (bt:thread-alive-p (thread sess)) t))
             ("busy" . ,(and (agent-session-data-claimed state) t))
             ("sequence" . ,(agent-session-data-sequence state))
             ("proofstateId" . ,(when ps (unique-ps-id ps)))
             ("interruptRequested" . ,(and (agent-session-data-interrupt-requested state) t))
             ("interrupted" . ,(and (agent-session-data-interrupted state) t))
             ("recoveryNote" . ,(agent-session-data-recovery-note state))
             ("error" . ,(agent-session-data-error state))))))
     states)))

(defun agent-current-proofstate (&optional (sess (current-session)))
  (let ((state (agent-session-state sess)))
    (when state (agent-session-data-last-proofstate state))))

(dolist (name '(current-session get-session session-alive-p session-kill
                session-read session-finish prover-init prover-step
                all-proof-sessions prover-status quit-all-proof-sessions
                interrupt-session handle-interrupt prove-formula-in-session
                read-strategies-files))
  (agent-remember-original name))

(defun current-session ()
  (or *agent-bound-session* (funcall (agent-original 'current-session))))

(defun get-session (obj)
  (bt:with-lock-held (*agent-registry-lock*)
    (if (bt:threadp obj)
        (find obj *all-sessions* :key #'thread)
        (find obj *all-sessions* :key #'id :test #'string-equal))))

(defun session-alive-p (&optional (sess (current-session)))
  (and sess (thread sess) (bt:thread-alive-p (thread sess))))

(defun agent-terminal-phase-p (phase)
  (member phase '(:closed :failed :aborted)))

(defun agent-require-session (id kind)
  (let* ((sess (get-session id)) (state (agent-session-state id)))
    (unless (and sess state (eq kind (agent-session-data-kind state)))
      (error "No live ~a session named ~a" kind id))
    (bt:with-lock-held ((agent-session-data-lock state))
      (when (or (agent-terminal-phase-p (agent-session-data-phase state))
                (not (session-alive-p sess)))
        (error "Session ~a has exited" id)))
    state))

(defun agent-call-with-session-claim (state thunk)
  (bt:with-lock-held ((agent-session-data-lock state))
    (when (agent-session-data-claimed state)
      (error "Session ~a already has an operation in flight"
             (id (agent-session-data-session state))))
    (unless (eq (agent-session-data-phase state) :idle)
      (error "Session is not idle: ~a" (agent-session-data-phase state)))
    (setf (agent-session-data-claimed state) t))
  (unwind-protect (funcall thunk)
    (bt:with-lock-held ((agent-session-data-lock state))
      (setf (agent-session-data-claimed state) nil))))

(defun agent-publish (state value &key error terminal)
  "Complete exactly the current request on its dedicated correlated queue."
  (with-interrupts-deferred
   (let (request)
    (bt:with-lock-held ((agent-session-data-lock state))
      ;; Completion and force-close can race. The first terminal result wins.
      (when (agent-terminal-phase-p (agent-session-data-phase state))
        (return-from agent-publish (values value nil)))
      (setf request (agent-session-data-request state)
            (agent-session-data-request state) nil
            (agent-session-data-phase state) (or terminal :idle))
      (when error (setf (agent-session-data-error state) (princ-to-string error)))
      (when (and request (eq (agent-session-data-kind state) :proof)
                 (member (agent-request-kind request) '(:initial :command))
                 (listp value) (typep (car value) 'proofstate))
        (setf (agent-session-data-last-proofstate state) (car value)))
      (setf (agent-session-data-interrupt-requested state) nil))
    (when request
      (push-queue (agent-make-reply :sequence (agent-request-sequence request)
                                    :value value :error error)
                  (agent-request-reply request)))
    (values value t))))

(defun agent-close-state (state &optional error)
  (let ((sess (agent-session-data-session state)))
    (unless (agent-terminal-phase-p (agent-session-data-phase state))
      (agent-publish state nil :error (or error "Session exited without a terminal response")
                     :terminal :failed))
    (bt:with-lock-held (*agent-registry-lock*)
      (setf *all-sessions* (remove sess *all-sessions*))
      (when (eq (agent-session-data-kind state) :proof)
        (let ((status (intern (string-upcase (agent-native-proof-status state)) :pvs)))
          (pushnew (cons (id sess) status) *done-sessions* :key #'car :test #'equal))))))

(defun agent-await-request (request)
  (let ((reply (pop-queue (agent-request-reply request))))
    (unless (= (agent-reply-sequence reply) (agent-request-sequence request))
      (error "Mismatched native session response"))
    (if (agent-reply-error reply)
        (error "~a" (agent-reply-error reply))
        (agent-reply-value reply))))

(defun agent-dispatch (state kind payload)
  "Caller holds the session claim and the appropriate process admission."
  (let ((request
          (bt:with-lock-held ((agent-session-data-lock state))
            (when (agent-terminal-phase-p (agent-session-data-phase state))
              (error "Session has exited"))
            (let ((request (agent-make-request
                            :sequence (incf (agent-session-data-sequence state))
                            :kind kind :payload payload)))
              (setf (agent-session-data-request state) request
                    (agent-session-data-phase state) :queued)
              request))))
    (push-queue request (input-queue (agent-session-data-session state)))
    (agent-await-request request)))

(defun agent-make-native-session (class id worker &rest initargs)
  "Construct the final native class and registry entry before starting its worker."
  (let* ((sess (apply #'make-instance class :id id :input-queue (make-queue)
                      :output-queue (make-queue) initargs))
         (initial (agent-make-request :sequence 0 :kind :initial))
         (state (agent-make-session-data :session sess
                   :kind (if (eq class 'proof-session) :proof :evaluator)
                   :request initial :claimed t))
         (start (make-queue)))
    (bt:with-lock-held (*agent-registry-lock*)
      (push sess *all-sessions*)
      (setf (gethash (string id) *agent-session-table*) state))
    (handler-case
        (setf (thread sess)
              (bt:make-thread
               (lambda ()
                 ;; Latch ensures THREAD is assigned before worker error cleanup.
                 (pop-queue start)
                 (let ((*package* (find-package :pvs))
                       (*agent-bound-session* sess)
                       (*agent-bound-state* state)
                       (*agent-in-setup* t))
                   (unwind-protect
                        (handler-case (funcall worker)
                          (error (condition) (agent-close-state state condition)))
                     (agent-close-state state))))
               :name (string id)))
      (error (condition) (agent-close-state state condition) (error condition)))
    (push-queue t start)
    (values sess initial)))

(defun agent-worker-read (state)
  (loop
    (let ((request (pop-queue (input-queue (agent-session-data-session state)))))
      (unless (agent-request-p request)
        (error "Uncorrelated input on an agent-managed session"))
      (bt:with-lock-held ((agent-session-data-lock state))
        (when (agent-terminal-phase-p (agent-session-data-phase state))
          (error "Session closed before its queued request began"))
        (setf (agent-session-data-request state) request
              (agent-session-data-phase state)
              (if (eq (agent-request-kind request) :command) :running :inspecting)
              (agent-session-data-interrupted state) nil
              (agent-session-data-recovery-note state) nil
              (agent-session-data-error state) nil))
      (case (agent-request-kind request)
        ((:query :prepare)
         (handler-case
             (let ((*ps* (agent-session-data-last-proofstate state))
                   (*agent-in-setup* (eq (agent-request-kind request) :prepare)))
               (agent-publish state (funcall (agent-request-payload request))))
           (error (condition) (agent-publish state nil :error condition))))
        (:command (return (agent-request-payload request)))
        (t (agent-publish state nil :error "Unknown session operation"))))))

(defun session-read ()
  (let* ((sess (current-session)) (state (agent-session-state sess)))
    (if (not state)
        (funcall (agent-original 'session-read))
        (progn
          ;; First read acknowledges readiness after implicit setup loads.
          (setf *agent-in-setup* nil)
          (let ((out (outputs sess)))
            (setf (outputs sess) nil)
            (when out (push out (logs sess)))
            ;; A fast caller may already have queued the next evaluator request.
            ;; It must not receive the previous operation's empty output here.
            (when (and (agent-session-data-request state)
                       (not (eq (agent-session-data-phase state) :queued)))
              (agent-publish state out)))
          (let ((input (agent-worker-read state)))
            (if (typep sess 'proof-session)
                (progn
                  (push input (logs sess))
                  (if (quit-command-p input) '(quit) input))
                input))))))

(defun session-finish (&optional (sess (current-session)))
  (let ((state (agent-session-state sess)))
    (if (not state)
        (funcall (agent-original 'session-finish) sess)
        (let ((out (outputs sess)))
          (setf (outputs sess) nil *agent-in-setup* nil)
          (push out (logs sess))
          (agent-publish state out :terminal :closed)))))

(defun agent-call-in-session (id thunk &optional expected-proofstate-id)
  (let ((state (agent-require-session id :proof)))
    (agent-call-with-session-claim
     state
     (lambda ()
       (agent-call-with-operation
        (lambda ()
          (agent-dispatch
           state :query
           (lambda ()
             (when (and expected-proofstate-id
                        (not (equal expected-proofstate-id
                                    (unique-ps-id (agent-current-proofstate)))))
               (error "Stale proofstate; inspect current state first"))
             (funcall thunk)))))))))

(defun agent-proof-response (sess outputs &optional command)
  (unless (typep (car outputs) 'proofstate)
    (error "Proof ~a produced no proofstate: ~a" (id sess) outputs))
  (let* ((ps (car outputs)) (commentary (reverse (cdr outputs)))
         (error (find-if (lambda (item) (typep item 'error)) commentary))
         (status (cond ((eq (status-flag ps) 'quit) "quit")
                       ((and (typep ps 'top-proofstate) (eq (status-flag ps) '!)) "proved")
                       (command "waiting") (t "init")))
         (previous (get (id sess) :previous-proofstate)))
    (setf (get (id sess) :previous-proofstate) ps)
    `(("id" . ,(string (id sess)))
      ,@(when command `(("command" . ,command)))
      ("proofstate" . ,ps) ("status" . ,status)
      ,@(when command `(("changed" . ,(eq previous ps))))
      ("commentary" . ,(remove error commentary))
      ,@(when error `(("error" . ,(princ-to-string error)))))))

(defun agent-check-proof-backend (decl)
  (unless (string-equal *default-decision-procedure* 'shostak)
    (error "Agent native sessions currently support only the Shostak backend"))
  (let ((selected (default-proof decl)))
    (when (and selected (decision-procedure-used selected)
               (not (string-equal (decision-procedure-used selected) 'shostak)))
      (error "The selected proof uses ~a; agent native sessions support only Shostak"
             (decision-procedure-used selected)))))

(defun prover-init (formref &key rerun? input-hook dont-save?)
  ;; Native DONT-SAVE? was ignored; do not offer a false persistence guarantee.
  (when dont-save? (error "DONT-SAVE? is not supported by the agent native proof path"))
  (agent-call-with-setup
   (lambda ()
     (let* ((fdecl (get-formula-decl formref))
            (id (get-new-session-id (id fdecl))))
       (agent-check-proof-backend fdecl)
       (multiple-value-bind (sess request)
           (agent-make-native-session
            'proof-session id
            (lambda () (prove-formula-in-session id fdecl rerun? input-hook))
            :formula-decl fdecl)
         (unwind-protect
              (agent-proof-response sess (agent-await-request request))
           (setf (agent-session-data-claimed (agent-session-state sess)) nil)))))))

(defun prover-step (id cmd)
  (let* ((state (agent-require-session id :proof))
         (form (let ((*read-eval* nil) (*package* (find-package :pvs)))
                 (read-from-string cmd))))
    (unless form (error "A proof command must be a nonempty Lisp form"))
    (unless (quit-command-p form)
      (when (fboundp 'agent-check-prepared-sources) (agent-check-prepared-sources)))
    (agent-call-with-session-claim
     state
     (lambda ()
       (agent-call-with-operation
        (lambda ()
          (agent-proof-response (agent-session-data-session state)
                                (agent-dispatch state :command form) cmd)))))))

(defun all-proof-sessions ()
  (bt:with-lock-held (*agent-registry-lock*)
    (remove-if-not (lambda (sess) (typep sess 'proof-session)) *all-sessions*)))

(defun prover-status (&optional proof-id)
  (if proof-id
      (let ((state (agent-session-state proof-id)))
        (if (and state (eq (agent-session-data-kind state) :proof))
            (bt:with-lock-held ((agent-session-data-lock state))
              (list `(("proof-id" . ,(string proof-id))
                      ("status" . ,(agent-native-proof-status state)))))
            (funcall (agent-original 'prover-status) proof-id)))
      (mapcar (lambda (sess)
                (car (prover-status (id sess))))
              (all-proof-sessions))))

(defun session-kill (sess)
  (let ((state (agent-session-state sess)))
    (if state
        ;; A completed proof may still be unwinding its output/logging stack.
        ;; Shutdown must not turn its already-published Q.E.D. into an abort.
        (multiple-value-bind (value published)
            (agent-publish state nil :error "Session was terminated" :terminal :aborted)
          (declare (ignore value))
          (when published
            (when (session-alive-p sess) (bt:destroy-thread (thread sess)))
            (agent-close-state state "Session was terminated")))
        (funcall (agent-original 'session-kill) sess))))

(defun quit-all-proof-sessions ()
  (dolist (sess (all-proof-sessions))
    (handler-case (prover-step (string (id sess)) "(quit)")
      (error () (session-kill sess))))
  nil)

(defun interrupt-session (id)
  (let ((state (agent-session-state id)))
    (unless (and state (session-alive-p (agent-session-data-session state)))
      (error "No live session named ~a" id))
    (bt:with-lock-held ((agent-session-data-lock state))
      (unless (eq (agent-session-data-phase state) :running)
        (return-from interrupt-session "Session is idle"))
      (setf (agent-session-data-interrupt-requested state)
            (agent-session-data-sequence state)))
    "Interrupt requested"))

(defun agent-restore-session (state &optional note)
  "Run only on the owning thread, using PVS's existing abort/restore boundary."
  (when (eq (agent-session-data-phase state) :running)
    (setf (agent-session-data-interrupted state) t
          (agent-session-data-interrupt-requested state) nil
          (agent-session-data-recovery-note state) note)
    (if (eq (agent-session-data-kind state) :evaluator)
        (when (find-restart 'agent-evaluator-abort)
          (invoke-restart 'agent-evaluator-abort))
        (restore))))

(defun handle-interrupt ()
  ;; A timer runs asynchronously on the owner. Do not acquire the registry lock
  ;; here: the interrupted thread could already own it. Requests are tied to
  ;; their native sequence and cleared on publication, never applied to a later step.
  (let ((state *agent-bound-state*))
    (if (not state)
        (funcall (agent-original 'handle-interrupt))
        (when (eql (agent-session-data-interrupt-requested state)
                   (agent-session-data-sequence state))
          (agent-restore-session state "Requested interruption")))))

(defun agent-session-debugger (condition previous-hook)
  (declare (ignore previous-hook))
  ;; BREAK bypasses *debugger-hook* on SBCL; the invoke hook covers it as well.
  ;; This is Lisp-level recovery, not recovery from SBCL's fatal C-level LDB.
  (let ((state *agent-bound-state*))
    (when (and state (eq (agent-session-data-phase state) :running))
      (agent-restore-session state
        (format nil "Lisp debugger: ~a" condition)))
    (error "Agent session cannot restore at this boundary: ~a" condition)))

(defun agent-call-with-session-timer (thunk)
  #+sbcl
  (let* ((state *agent-bound-state*)
         (sb-ext:*invoke-debugger-hook* #'agent-session-debugger)
         (timer (sb-ext:make-timer #'handle-interrupt :thread (bt:current-thread))))
    (when state (setf (agent-session-data-timer state) timer))
    (unwind-protect
         (progn (sb-ext:schedule-timer timer 0.1 :repeat-interval 0.1)
                (funcall thunk))
      (sb-ext:unschedule-timer timer)
      (when state (setf (agent-session-data-timer state) nil))))
  #-sbcl (funcall thunk))

(defun prove-formula-in-session (id fdecl rerun? input-hook)
  (let ((*proceed-without-asking* t) (*pvs-emacs-interface* nil)
        (*default-decision-procedure* 'shostak) (*force-dp* t)
        (*prover-input-hooks*
          (let ((hooks
                  (mapcar (lambda (hook)
                            (if (eq hook (agent-original 'session-read))
                                #'session-read hook))
                          *prover-input-hooks*)))
            (if input-hook (cons input-hook hooks) hooks)))
        (*pvs-message-hook* (list #'session-output)))
    (session-output (format nil "~a started at ~a" id (iso8601-date)))
    (agent-call-with-session-timer (lambda () (prove-formula fdecl :rerun? rerun?)))))

(defun read-strategies-files ()
  (agent-call-with-setup (lambda () (funcall (agent-original 'read-strategies-files)))))
