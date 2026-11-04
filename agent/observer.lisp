(in-package :pvs)

;;; Observation only. Never retain live proof objects in the cross-thread queue.
(defvar *agent-observer-enabled* nil)
(defvar *agent-observer-lock* (bt:make-lock "agent observer snapshots"))
(defvar *agent-observer-events* nil)
(defvar *agent-observer-count* 0)
(defvar *agent-observer-dropped* 0)
(defvar *agent-observer-error* nil)
(defvar *agent-observer-cache* nil)

(defvar *agent-observer-ids* (make-hash-table :test #'eq :weakness :key))
(defvar *agent-observer-next-id* 0)
(defun agent-observer-id (ps)
  ;; Native unique-ps-id is label/depth based: strategy reparenting and undo reuse
  ;; it. This observer-only weak map never changes native navigation identities.
  (when (and *agent-observer-enabled* ps)
    (bt:with-lock-held (*agent-observer-lock*)
      (or (gethash ps *agent-observer-ids*)
          (setf (gethash ps *agent-observer-ids*)
                (format nil "node-~d" (incf *agent-observer-next-id*)))))))

(defun agent-observer-text (value &optional (limit 4000))
  (let ((*print-pretty* nil) (*print-case* :downcase))
    (agent-short (if (stringp value) value (princ-to-string value)) limit)))

(defun agent-observer-sequent (ps)
  (let ((seq (current-goal ps)) (budget 16000) (truncated nil))
    (labels ((render (ex)
               (let* ((raw (let ((*print-pretty* nil)) (princ-to-string ex)))
                      (limit (max 0 (min 2000 budget))))
                 (when (> (length raw) limit) (setf truncated t))
                 (decf budget (min limit (length raw)))
                 (agent-short raw limit)))
             (rows (forms negative)
               (when (> (length forms) 40) (setf truncated t))
               (coerce (loop for sf in forms for i below 40
                             for ex = (formula sf)
                             collect (render (if (and negative (negation? ex))
                                                 (args1 ex) ex))) 'vector)))
      (let ((neg (rows (neg-s-forms seq) t)) (pos (rows (pos-s-forms seq) nil)))
        `(("antecedents" . ,neg) ("succedents" . ,pos)
          ("hidden" . ,(length (hidden-s-forms seq))) ("truncated" . ,truncated))))))

(defun agent-observer-enqueue (row)
  (bt:with-lock-held (*agent-observer-lock*)
    (if (< *agent-observer-count* 2048)
        (progn (push row *agent-observer-events*) (incf *agent-observer-count*))
        (incf *agent-observer-dropped*))))

(defun agent-observe-proofstate (ps)
  ;; A display failure must not alter proof control flow or proof status.
  (when (and *agent-observer-enabled* (typep (current-session) 'proof-session)
             (typep ps 'proofstate) (current-goal ps))
    (handler-case
        (let* ((sid (string (id (current-session))))
               (key (agent-observer-id ps))
               (kids (remove-duplicates (children ps) :test #'eq))
               (command (agent-observer-text (or (current-rule ps) (current-input ps) "") 2000))
               (signature (list (current-goal ps) command (status-flag ps)
                                (mapcar #'agent-observer-id kids)))
               (old (and *agent-observer-cache* (gethash ps *agent-observer-cache*))))
          (unless (equal signature (car old))
            (let* ((sequent (if (and old (eq (caar old) (current-goal ps)))
                                (cdr old) (agent-observer-sequent ps)))
                   (row `(("session_id" . ,sid) ("id" . ,key)
                          ("parent" . ,(agent-observer-id
                             (or (parent-proofstate ps)
                                 (when (typep ps 'apply-proofstate) (apply-parent-proofstate ps)))))
                          ("expansion" . ,(and (null (parent-proofstate ps)) (typep ps 'apply-proofstate)))
                          ("label" . ,(label ps)) ("command" . ,command)
                          ("command_label" . ,(when (stringp (comment ps)) (comment ps)))
                          ("status" . ,(princ-to-string (or (status-flag ps) 'open)))
                          ("children" . ,(coerce (mapcar #'agent-observer-id kids) 'vector))
                          ("sequent" . ,sequent))))
              (when *agent-observer-cache*
                (when (> (hash-table-count *agent-observer-cache*) 1024)
                  (clrhash *agent-observer-cache*))
                (setf (gethash ps *agent-observer-cache*) (cons signature sequent)))
              (agent-observer-enqueue row))))
      (error (e) (bt:with-lock-held (*agent-observer-lock*)
                  (setf *agent-observer-error* (princ-to-string e))
                  (incf *agent-observer-dropped*))))))

;;; Reuse the native primitive-step boundary. No parser, proof rule, or DP changes.
(agent-remember-original 'rule-apply)
(defun rule-apply (step ps)
  (agent-observe-proofstate ps)
  (when (and *agent-observer-enabled* (typep (current-session) 'proof-session))
    (agent-observer-enqueue
     `(("kind" . "cursor") ("session_id" . ,(string (id (current-session))))
       ("id" . ,(agent-observer-id ps)))))
  (let ((result (funcall (agent-original 'rule-apply) step ps)))
    (agent-observe-proofstate ps)
    (when (typep result 'proofstate)
      (agent-observe-proofstate result)
      (dolist (child (children result)) (agent-observe-proofstate child)))
    result))

(defun agent-observer-drain ()
  (bt:with-lock-held (*agent-observer-lock*)
    (prog1 `(("nodes" . ,(coerce (nreverse *agent-observer-events*) 'vector))
             ("dropped" . ,*agent-observer-dropped*)
             ("error" . ,*agent-observer-error*))
      (setf *agent-observer-events* nil *agent-observer-count* 0 *agent-observer-dropped* 0 *agent-observer-error* nil))))

(defun agent-observer-strategies ()
  (let ((seen (make-hash-table :test #'equal)) (rows nil))
    (dolist (table (list *steps* *rules* *rulebase*))
      (maphash
       (lambda (name entry)
         (unless (gethash (string-downcase name) seen)
           (setf (gethash (string-downcase name) seen) t)
           (push `(("name" . ,(string-downcase name))
                   ("doc" . ,(or (ignore-errors (docstring entry)) ""))
                   ("signature" . ,(agent-observer-text
                      (or (ignore-errors (formals entry))
                          (ignore-errors (append (required-args entry) (optional-args entry)))))))
                 rows))) table))
    (coerce (sort rows #'string-lessp :key (lambda (r) (agent-field "name" r))) 'vector)))

(in-package :pvs-jsonrpc)
(defrequest agent-observer-enable (enabled) "Enable bounded native proof snapshots."
  (setf pvs::*agent-observer-enabled* enabled)
  `(("enabled" . ,enabled)))
(defrequest agent-observer-drain () "Drain immutable snapshots; never claim a proof cursor."
  (pvs::agent-observer-drain))
(defrequest agent-observer-strategies () "Read native strategy documentation at an idle boundary."
  (pvs::agent-observer-strategies))
