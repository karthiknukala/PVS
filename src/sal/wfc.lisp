;;; Native well-formedness is a prerequisite, never a replacement for PVS TCCs.
(in-package :pvs)

(defvar *sal-last-wfc-result* nil)
(defvar *sal-wfc-source* nil)

(defun sal-check-well-formed (source)
  "Run sal-wfc before export. Keep its diagnostics and require native Ok."
  (let* ((file (truename source))
         (snapshot (sal-file-snapshot file))
         (home (or *sal-backend-home* (uiop:getenv "SAL_HOME")
                   (error "Set SAL_HOME to run sal-wfc")))
         (program (merge-pathnames "bin/sal-wfc" (uiop:ensure-directory-pathname home)))
         (work (sal-backend-work-directory))
         (command (list "/usr/bin/env" (format nil "TMPDIR=~a" work)
                        ;; Match the exporter's source-first dependency lookup.
                        (format nil "SALCONTEXTPATH=~a:~a"
                                (uiop:pathname-directory-pathname file)
                                (let ((path (uiop:getenv "SALCONTEXTPATH")))
                                  (if (and path (plusp (length (string-trim '(#\Space) path))))
                                      path ".")))
                        (namestring program) (namestring file))))
    (unless (probe-file program) (error "sal-wfc not found: ~a" program))
    (multiple-value-bind (out err status)
        (uiop:run-program command :directory work :output :string :error-output :string
                          :ignore-error-status t)
      (setf *sal-last-wfc-result*
            (list :source (namestring file) :command command :status status
                  :stdout out :stderr err))
      (unless (and (eql status 0) (member "Ok." (sal-output-lines out) :test #'string=))
        (error "sal-wfc rejected ~a (exit ~a). Translation was not accepted.~%~a~%~a"
               file status out err))
      (unless (equal snapshot (sal-file-snapshot file))
        (error "SAL source changed while sal-wfc was running; typecheck again"))
      *sal-last-wfc-result*)))

(export '(sal-check-well-formed *sal-last-wfc-result*))
