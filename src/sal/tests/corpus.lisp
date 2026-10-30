;;; Exhaustive, serial PVS corpus checking. Every case has its own output context.
;;; Parse/typecheck failures stay in the report and do not abort later cases.
(in-package :pvs)

(defun sal-corpus-tsv-cell (value)
  (substitute #\Space #\Return
    (substitute #\Space #\Newline
      (substitute #\Space #\Tab (princ-to-string (or value ""))))))

(defun sal-corpus-result (report &rest columns)
  ;; Commit each completed result independently. A long-lived :SUPERSEDE
  ;; stream can delete its output during Lisp's abort cleanup, even after
  ;; FINISH-OUTPUT, losing cases completed before a later process failure.
  (with-open-file (stream report :direction :output :if-exists :append
                                 :if-does-not-exist :error)
    (loop for column in columns for first = t then nil
          unless first do (write-char #\Tab stream)
          do (write-string (sal-corpus-tsv-cell column) stream))
    (terpri stream)))

(defun sal-run-corpus ()
  (let* ((root (uiop:ensure-directory-pathname (uiop:getenv "SAL_CORPUS_ROOT")))
         (output (sal-bridge-output-path
                  (uiop:ensure-directory-pathname (uiop:getenv "SAL_CORPUS_OUTPUT"))))
         (report (sal-bridge-output-path
                  (or (uiop:getenv "SAL_CORPUS_RESULTS_FILE")
                      (merge-pathnames "results.tsv" output))))
         (successes 0) (failures 0))
    (load (or (uiop:getenv "SAL_CORPUS_CASES_FILE")
              (merge-pathnames "cases.lisp" output)))
    (with-open-file (stream report :direction :output :if-exists :supersede
                                  :if-does-not-exist :create)
      (write-line "case_id	source	module	status	main_tccs	import_tccs	generated_file	error" stream))
    (dolist (case *sal-corpus-cases*)
        (destructuring-bind (identity source module &optional input) case
          (format t "~&SAL-CORPUS-BEGIN ~a ~a ~a~%" identity source module)
          (finish-output)
          (handler-case
              (let* ((view (sal-open (or input (merge-pathnames source root)) module
                                     :progress-checks nil :register nil
                                     :output-directory (merge-pathnames
                                                        (concatenate 'string "contexts/" identity "/")
                                                        output)))
                     (theory (get-typechecked-theory (sal-transition-view-theory-name view)))
                     (imports (remove-duplicates (all-importings theory) :test #'eq))
                     (import-tccs (loop for th in imports unless (from-prelude? th)
                                       sum (length (collect-tccs th)))))
                (incf successes)
                (sal-corpus-result report identity source module "typechecked"
                                   (length (collect-tccs theory)) import-tccs
                                   (sal-transition-view-pvs-file view) "")
                (format t "~&SAL-CORPUS-PASS ~a~%" identity))
            (error (condition)
              (incf failures)
              (sal-corpus-result report identity source module "error" "" "" "" condition)
              (format t "~&SAL-CORPUS-FAIL ~a ~a~%" identity condition)))
          (finish-output)))
    (format t "~&SAL-CORPUS-COMPLETE ~d ~d ~d~%"
            (length *sal-corpus-cases*) successes failures)
    (zerop failures)))

(let ((root (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
  (load (merge-pathnames "load.lisp" root)))
(setq *proof-prompt-behavior* :noquestions *proceed-without-asking* t
      *noninteractive* t *noninteractive-timeout* 60)
(sal-run-corpus)
