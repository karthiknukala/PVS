(in-package :pvs)
;;; MAPOBJECT owns its visited table in the core. Isolate substitution here.
(agent-remember-original 'gensubst)
(defun gensubst (obj substfn testfn)
  (let ((*gensubst-cache* (make-hash-table :test #'eq)))
    (funcall (agent-original 'gensubst) obj substfn testfn)))
