;;; Convenience paths for the slide tutorial. No proof automation is hidden here.
;;; Load into a working PVS image with SAL_HOME and SAL_XMLS_SOURCE set.
(in-package :pvs)
(defparameter *sal-doc-directory*
  (uiop:pathname-directory-pathname (or *load-truename* *compile-file-truename*)))
(load (merge-pathnames "../load.lisp" *sal-doc-directory*))

(defun sal-doc-open (file module tag &rest options)
  "Import an existing example into a separate tutorial context."
  (apply #'sal-open (merge-pathnames (concatenate 'string "../examples/" file)
                                    *sal-doc-directory*)
         module :output-directory (merge-pathnames (format nil ".demo/~a/" tag)
                                                    *sal-doc-directory*)
         options))

(defun sal-doc-native (file)
  "Copy native examples into an extension-local context and typecheck FILE.
The native TCCs are deliberately not proved by this helper."
  (let ((directory (sal-prepare-output-directory
                    (merge-pathnames ".demo/native/" *sal-doc-directory*))))
    (dolist (source (directory (merge-pathnames "../examples/reverse/*.pvs"
                                               *sal-doc-directory*)))
      (sal-write-file-if-changed (merge-pathnames (file-namestring source) directory)
                                (uiop:read-file-string source)))
    (change-context (namestring directory))
    (typecheck-file file)
    (format t "~&Native examples are in ~a; inspect and prove the TCCs in PVS.~%"
            directory)))

(defun sal-doc-nary (&key n (module "sync") tag output-directory)
  "Open the worked indexed-composition example, generically or at positive N.
Typing obligations are retained; optional progress contracts are omitted here."
  (when n (assert (and (integerp n) (plusp n))))
  (sal-open (merge-pathnames "nary/nary.sal" *sal-doc-directory*) module
            :output-directory
            (or output-directory
                (merge-pathnames
                 (format nil ".demo/~a/"
                         (or tag (format nil "nary-~a-~a" module (or n "generic"))))
                 *sal-doc-directory*))
            :progress-checks nil
            :context-actuals (and n (list (write-to-string n)))))
