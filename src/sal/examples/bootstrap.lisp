;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bootstrap.lisp -- Load the PVS SAL components and run the examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :cl-user)

(require :asdf)

(let* ((example-directory
         (uiop:pathname-directory-pathname
          (or *load-truename* *compile-file-truename*)))
       (sal-directory
         (uiop:pathname-parent-directory-pathname example-directory))
       (source-directory
         (uiop:pathname-parent-directory-pathname sal-directory))
       (pvs-directory
         (uiop:pathname-parent-directory-pathname source-directory)))
  (asdf:load-asd (merge-pathnames "pvs.asd" pvs-directory))
  (let* ((system (asdf:find-system :pvs))
         (classes (asdf:find-component system "classes"))
         (utilities (asdf:find-component classes "sal/sal-utils")))
    (handler-bind ((warning #'muffle-warning))
      (asdf:operate 'asdf:load-op utilities)))
  (load (merge-pathnames "run-examples.lisp" example-directory)))
