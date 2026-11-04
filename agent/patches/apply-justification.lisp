(in-package :pvs)

;;; Native RULE-APPLY's immediate-success path creates JUSTIFICATION before
;;; MAKE-UPDATES installs CURRENT-XRULE. COLLECT-JUSTIFICATION then returns that
;;; cached object, losing APPLY's already-checked primitive derivation. Preserve
;;; the native expansion when its update arrives; never synthesize a proof.
(agent-remember-original 'make-update)
(defun make-update (field value ps)
  (prog1 (funcall (agent-original 'make-update) field value ps)
    (when (and (eq field 'current-xrule) value
               (eq (status-flag ps) '!)
               (justification ps) (null (xrule (justification ps))))
      (setf (xrule (justification ps)) value))))

;;; Native PRF serialization omits XRULE. Agent-owned proof records must carry
;;; the checked expansion, not require the planner that originally found it.
;;; Reuse the native serializer with a copied justification; the live tree and
;;; ordinary non-agent saves keep their original command and structure.
(defmethod extract-justification-sexp :around ((justif justification))
  (if (and *agent-saving-proof-record* (xrule justif))
      (call-next-method (copy justif 'rule (xrule justif) 'xrule nil))
      (call-next-method)))
