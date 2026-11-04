(in-package :pvs)
(declaim (ftype (function () t) agent-check-prepared-sources))

(defparameter *agent-version* "0.3.2")
(defvar *agent-loaded* nil)
(defvar *agent-root* nil)
(defvar *agent-original-functions* (make-hash-table :test #'equal))
(defvar *agent-metadata-lock* (bt:make-lock "agent metadata"))
(defvar *agent-strategy-files* nil)
(defvar *agent-prepared-files* nil)

(defun agent-remember-original (name)
  "Remember an unpatched function once, including SETF function names."
  (or (gethash name *agent-original-functions*)
      (setf (gethash name *agent-original-functions*) (fdefinition name))))

(defun agent-original (name)
  (or (gethash name *agent-original-functions*)
      (error "No saved original for ~s" name)))

(defun agent-fingerprint-buffer ()
  (make-array 1024 :element-type '(unsigned-byte 8)))

(defun agent-source-fingerprint (file &optional (buffer (agent-fingerprint-buffer)))
  "Portable FNV-1a fingerprint used for exact local patch compatibility."
  (with-open-file (stream file :element-type '(unsigned-byte 8))
    (let ((hash 14695981039346656037))
      (declare (cl:type (simple-array (unsigned-byte 8) (*)) buffer)
               (cl:type (unsigned-byte 64) hash))
      (loop for end = (read-sequence buffer stream) until (zerop end)
            do (dotimes (i end)
                 (setf hash (ldb (byte 64 0)
                                 (* (logxor hash (aref buffer i)) 1099511628211)))))
      (format nil "~16,'0x" hash))))

(defun agent-check-sources (manifest)
  (let ((buffer (agent-fingerprint-buffer)))
    (dolist (entry manifest)
      (let ((path (merge-pathnames (car entry) *pvs-path*)))
        (unless (and (probe-file path)
                     (string-equal (cdr entry) (agent-source-fingerprint path buffer)))
          (error "Agent patches do not match ~a. Review/update agent/compatibility.lisp for this PVS build."
                 path)))))
  t)

(defun agent-capture-output (thunk)
  (let (value)
    (let ((output
            (with-output-to-string (out)
              (let ((*standard-output* out) (*error-output* out)
                    (*trace-output* out)
                    (*pvs-message-hook* nil)
                    (*pvs-warning-hook* nil)
                    (*pvs-buffer-hook*
                      (lambda (name contents &rest options)
                        (declare (ignore options))
                        (format out "~&~a~%~a~%" name contents))))
                (setf value (funcall thunk))))))
      (values value output))))
