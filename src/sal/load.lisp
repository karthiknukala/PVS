;;; Load this optional extension into an existing PVS image.
;;; No ASDF/PVS build-system or editor changes are required.
(in-package :pvs)

(defparameter *sal-bridge-directory*
  (uiop:pathname-directory-pathname (or *load-truename* *compile-file-truename*)))

(unless (find-package :xmls)
  (let ((source (uiop:getenv "SAL_XMLS_SOURCE")))
    (if source
        (progn
          (pushnew :xmls-nodes-are-structs *features*)
          (load source))
        (error "Load XMLS first, or set SAL_XMLS_SOURCE to its existing xmls.lisp source. The bridge does not install dependencies or write external ASDF caches."))))

(unless (find-class 'sal-context nil)
  (load (merge-pathnames "classes.lisp" *sal-bridge-directory*)))
(dolist (file '("xml-reader.lisp" "sal-pp.lisp" "sal-utils.lisp"
                "view.lisp" "view-import.lisp" "elaborate.lisp" "causality.lisp"
                "backend.lisp" "wfc.lisp" "strategies.lisp" "integration.lisp"
                "pvs-to-sal.lisp" "pvs-origin-view.lisp" "pvs-origin.lisp"
                "sal-display.lisp" "editor.lisp"))
  (load (merge-pathnames file *sal-bridge-directory*)))

(setf *sal-to-xml-program* (merge-pathnames "tools/sal-to-xml.sh" *sal-bridge-directory*)
      *sal-transform-program* (merge-pathnames "tools/sal-transform.sh" *sal-bridge-directory*))
(format t "~&SAL bridge loaded from ~a~%" *sal-bridge-directory*)
