;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; run-examples.lisp -- Run all SAL compiler examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defparameter *sal-example-runner-directory*
  (uiop:pathname-directory-pathname
   (or *load-truename* *compile-file-truename*)))

(dolist (file '("example-support.lisp"
                "walk-and-analyze.lisp"
                "rewrite-and-intern.lisp"
                "compiler-pipeline.lisp"))
  (load (merge-pathnames file *sal-example-runner-directory*)))

(defun run-sal-compiler-examples (&key external-tools)
  "Run both examples.  EXTERNAL-TOOLS also invokes SAL simplify/flatten."
  (let ((jobs '(("bounded_counter.sal" . "counter")
                ("arbiter.sal" . "system"))))
    (dolist (job jobs)
      (let* ((source (sal-example-path (car job)))
             (output
               (merge-pathnames
                (format nil "~A-optimized.sal" (pathname-name source))
                (uiop:temporary-directory)))
             (compilation
               (sal-example-compile-file source :output output)))
        (sal-example-print-compilation compilation)
        (when external-tools
          (sal-example-run-external-passes source (cdr job))))))
  (values))

(run-sal-compiler-examples
 :external-tools (not (null (uiop:getenv "SAL_EXAMPLES_EXTERNAL"))))
