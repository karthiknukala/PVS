;;; Explicit extension entry point. Load after ordinary PVS initialization.
(in-package :pvs)
(defvar *agent-loaded* nil)
(defvar *agent-root* nil)
(defvar *agent-source-manifest* nil)
(declaim (ftype (function (t) t) agent-check-sources))

(let* ((root (uiop:pathname-directory-pathname
               (or *load-truename* *compile-file-truename*
                   (error "Load agent/load.lisp from a file"))))
       (loaded (and (boundp '*agent-loaded*) (symbol-value '*agent-loaded*))))
  (unless (eq loaded :ready)
    (when loaded
      (error "An agent extension load failed or is incomplete; restart PVS"))
    (when *all-sessions*
      (error "Load agent patches before creating proof/evaluator sessions"))
    (unless (string= (lisp-implementation-type) "SBCL")
      (error "This agent extension is tested on SBCL only"))
    (load (merge-pathnames "support.lisp" root))
    (setq *agent-root* root *agent-loaded* :loading)
    (handler-case
        (progn
          (load (merge-pathnames "compatibility.lisp" root))
          (agent-check-sources *agent-source-manifest*)
          (dolist (file '("patches/proof-records.lisp"
                          "patches/apply-justification.lisp"
                          "patches/proof-runtime.lisp"
                          "patches/bdd.lisp"
                          "patches/parser.lisp"
                          "patches/traversal.lisp"
                          "patches/session-output.lisp"
                          "patches/sessions.lisp"
                          "patches/evaluator.lisp"
                          "interface.lisp"
                          "interaction.lisp"
                          "lazy-strategies.lisp"
                          "observer.lisp"
                          "buffers.lisp"))
            (load (merge-pathnames file root)))
          (setq *agent-loaded* :ready))
      (error (condition)
        (setq *agent-loaded* :failed)
        (error "Agent extension startup failed: ~a" condition)))))
