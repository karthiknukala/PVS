(in-package :pvs)

;;; Viewer boundaries built from native APPLY, not new proof rules. This file
;;; contains strategy definitions only and can also be loaded at an idle boundary.
(defun agent-mark-lazy-strategy (name)
  "Keep a DEFSTEP's $ spelling inside a native APPLY boundary as well."
  (let* ((expanded (intern (format nil "~a$" name) :pvs))
         (entry (gethash expanded *steps*)))
    (unless (and (gethash name *rules*) entry)
      (error "~a must be an installed DEFSTEP before marking it lazy" name))
    (unless (eq entry (get expanded :agent-lazy-entry))
      ;; Re-register through PVS so keywords, inheritance and source tracking
      ;; follow the same path as ordinary strategy definitions. Re-marking is
      ;; idempotent; redefining a strategy replaces the registry entry.
      (defstrat* expanded (source-formals entry)
        `(apply ,(source-defn entry) :comment ,(string-downcase name))
        (docstring entry) (format-string entry))
      (setf (get expanded :agent-lazy-entry) (gethash expanded *steps*)))
    name))

(defmacro lazy-strategies (&rest names)
  "Mark existing DEFSTEPs as viewer-lazy, including their $ forms."
  `(progn ,@(mapcar (lambda (name) `(agent-mark-lazy-strategy ',name)) names)))

(defmacro defstep/lazy (name args body doc format)
  "Define a checked derived step with a lazy viewer expansion."
  `(progn (defstep ,name ,args ,body ,doc ,format)
          (lazy-strategies ,name)))

(defstrat lazy-step (step &optional comment)
  (apply step :comment comment)
  "Run STEP through native APPLY. The viewer shows the compound step and its
resulting goals; its primitive implementation is revealed only on request.
Execution and proof checking are immediate, and APPLY retains native justification."
  "Checking a compound proof step")
