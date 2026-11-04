;;; Immutable per-session *pvs* display snapshots. No proof cursor claims.
(in-package :pvs)
(defvar *agent-worker-id*
  (format nil "~36r-~36r" (get-universal-time)
          (random most-positive-fixnum (make-random-state t))))
(defvar *agent-buffer-lock* (bt:make-lock "agent thread buffers"))
(defvar *agent-buffer-table* (make-hash-table :test #'equal))
(defvar *agent-buffer-revision* 0)
(defvar *agent-buffer-originals* (make-hash-table :test #'eq))

(defun agent-buffer-tail (text limit)
  (subseq text (max 0 (- (length text) limit))))

(defun agent-buffer-write (state &key command output sequent status reset-output)
  ;; Only immutable strings leave the owning thread. Replacing the entire row
  ;; lets RPC readers serialize it after releasing this short lock.
  (when (eq (current-session) (agent-session-data-session state))
    (with-interrupts-deferred
      (bt:with-lock-held (*agent-buffer-lock*)
        (let* ((sid (string (id (agent-session-data-session state))))
               (old (gethash sid *agent-buffer-table*))
               (old-output (if reset-output "" (or (agent-field "output" old) "")))
               (out (concatenate 'string old-output (or output "")))
               (addition (concatenate 'string
                           (if command (format nil "~%Rule? ~a~%" command) "")
                           (or output "") (if sequent (format nil "~%~a~%" sequent) "")))
               (history (concatenate 'string (or (agent-field "transcript" old) "") addition))
               (truncated (or (agent-field "truncated" old)
                              (> (length history) 65536) (> (length out) 32768)
                              (and sequent (> (length sequent) 65536))
                              (and command (> (length command) 8192)))))
          (setf (gethash sid *agent-buffer-table*)
                `(("session_id" . ,sid) ("revision" . ,(incf *agent-buffer-revision*))
                  ("sequence" . ,(agent-session-data-sequence state))
                  ("command_sequence" . ,(if command (agent-session-data-sequence state) (agent-field "command_sequence" old)))
                  ("command" . ,(if command (agent-short command 8192) (or (agent-field "command" old) "")))
                  ("sequent" . ,(if sequent (agent-short sequent 65536) (or (agent-field "sequent" old) "")))
                  ("output" . ,(agent-buffer-tail out 32768))
                  ("transcript" . ,(agent-buffer-tail history 65536))
                  ("status" . ,(or status (agent-field "status" old) "waiting"))
                  ("truncated" . ,truncated)))
          (when (> (hash-table-count *agent-buffer-table*) 128)
            (let ((oldest (loop for key being the hash-keys of *agent-buffer-table*
                               using (hash-value row)
                               minimize (agent-field "revision" row) into minimum
                               finally (return minimum))))
              (maphash (lambda (key row)
                         (when (= oldest (agent-field "revision" row))
                           (remhash key *agent-buffer-table*))) *agent-buffer-table*))))))))

(defun agent-buffer-command (state payload)
  (let ((*print-case* :downcase) (*print-pretty* nil))
    (agent-buffer-write state :command
      (if (eq (agent-session-data-kind state) :proof)
          (prin1-to-string payload) (princ-to-string (second payload)))
      :reset-output t :status "running")))

(defun agent-buffer-finish (state value terminal error)
  (let* ((proof (eq (agent-session-data-kind state) :proof))
         (ps (and proof (listp value) (typep (car value) 'proofstate) (car value)))
         (interrupted (agent-session-data-interrupted state))
         (status (cond (error "error") (interrupted "interrupted")
                       ((eq terminal :closed) (if proof (agent-native-proof-status state) "closed"))
                       (t "waiting")))
         (text (if proof
                   (cond (error (format nil "~a~%" error))
                         ((string= status "proved") "Q.E.D.")
                         (interrupted (format nil "~a~%" (or (agent-session-data-recovery-note state) "Interrupted")))
                         (t ""))
                   (if (listp value)
                       (format nil "~{~a~%~}" (remove nil (mapcar (lambda (key) (agent-field key value))
                                                 '("stdOut" "tccMsg" "errOut" "pvsResult"))))
                       (princ-to-string value)))))
    (agent-buffer-write state :status status :output text
      :sequent (when ps
                 ;; Reuse the native *pvs* proofstate printer on its owner thread.
                 (let ((*print-pretty* t) (*show-parent-rule* nil)) (format nil "~a" ps))))))

;; Observation wrappers are idempotent and preserve the native return values.
;; They can also be installed at an idle boundary without changing proof rules,
;; runtime bindings, or declarations. Never reload the full startup patch set.
(dolist (name '(session-output agent-worker-read agent-publish))
  (unless (gethash name *agent-buffer-originals*)
    (setf (gethash name *agent-buffer-originals*) (symbol-function name))))

(defun session-output (value)
  (prog1 (funcall (gethash 'session-output *agent-buffer-originals*) value)
    (when (and *agent-bound-state* (or (stringp value) (typep value 'cl:condition)))
      (ignore-errors
        (agent-buffer-write *agent-bound-state* :output (format nil "~a~%" value))))))

(defun agent-worker-read (state)
  (let ((payload (funcall (gethash 'agent-worker-read *agent-buffer-originals*) state)))
    (ignore-errors (agent-buffer-command state payload))
    payload))

(defun agent-publish (state value &key error terminal)
  (let ((request (agent-session-data-request state)))
    ;; A worker already waiting inside the old read function when capture is
    ;; installed will miss its first read wrapper. Retain that command too.
    (when (and request (eq (agent-request-kind request) :command))
      (ignore-errors
        (let ((sequence (bt:with-lock-held (*agent-buffer-lock*)
                          (agent-field "command_sequence"
                            (gethash (string (id (agent-session-data-session state))) *agent-buffer-table*)))))
          (unless (eql sequence (agent-request-sequence request))
            (let ((*print-case* :downcase) (*print-pretty* nil))
              (agent-buffer-write state :command
                (if (eq (agent-session-data-kind state) :proof)
                    (prin1-to-string (agent-request-payload request))
                    (princ-to-string (second (agent-request-payload request))))))))))
    ;; Queries must not become proof transcript entries or duplicate sequents.
    (multiple-value-prog1
        (funcall (gethash 'agent-publish *agent-buffer-originals*) state value :error error :terminal terminal)
      (when (and request (member (agent-request-kind request) '(:initial :command)))
        (ignore-errors (agent-buffer-finish state value terminal error))))))

(defun agent-observer-state (since)
  (let ((sessions (agent-session-info)) rows revision)
    (bt:with-lock-held (*agent-buffer-lock*)
      (setf revision *agent-buffer-revision*
            rows (loop for row being the hash-values of *agent-buffer-table*
                       when (> (agent-field "revision" row) since) collect row)))
    `(("worker_id" . ,*agent-worker-id*) ("sessions" . ,(coerce sessions 'vector))
      ("buffers" . ,(coerce rows 'vector)) ("revision" . ,revision))))

(in-package :pvs-jsonrpc)
(defrequest agent-observer-state (since) "Read immutable thread buffers and native session inventory without claiming proof cursors."
  (pvs::agent-observer-state since))
