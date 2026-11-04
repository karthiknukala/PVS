(in-package :pvs)
;;; Older saved cores can still BREAK when an ordinary CL condition is sent
;;; to SESSION-OUTPUT. A background debugger then waits for a terminal forever.
;;; Publish the diagnostic as a condition instead; preserve proofstate objects.
(defun session-output (output)
  (let ((sess (current-session)))
    (when sess
      (let ((value
              (typecase output
                (string (string-trim '(#\Space #\Tab #\Newline) output))
                (proofstate output)
                (cl:condition
                 (make-condition 'cl:simple-error :format-control "~a"
                                 :format-arguments (list (princ-to-string output))))
                (t (make-condition 'cl:simple-error
                     :format-control "Unexpected native session output: ~s"
                     :format-arguments (list output))))))
        (push value (outputs sess))))))
