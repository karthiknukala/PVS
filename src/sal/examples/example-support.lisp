;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; example-support.lisp -- Shared support for the SAL compiler examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defparameter *sal-example-directory*
  (uiop:pathname-directory-pathname
   (or *load-truename* *compile-file-truename*))
  "Directory containing the SAL compiler examples.")

(defun sal-example-path (name)
  (merge-pathnames name *sal-example-directory*))

(defun sal-example-declaration-name (declaration)
  (let ((identifier (and declaration (id declaration))))
    (and identifier
         (etypecase (name identifier)
           (symbol (symbol-name (name identifier)))
           (string (name identifier))))))

(defun sal-example-application-arguments (application)
  "Return APPLICATION's operands without exposing SAL's tuple encoding."
  (let ((argument (arg application)))
    (if (sal-arg-tuple-literal? argument)
        (exprs argument)
        (list argument))))

(defun sal-example-module-body (declaration)
  (module (parametric-module declaration)))

(defun sal-example-load (name)
  "Read an example SAL file and return its CLOS AST."
  (sal-preprocess-file (sal-example-path name)))
