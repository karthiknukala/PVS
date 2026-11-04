;;; Batch helpers for proving and persisting named PVS declarations.
;;; Load with: pvs -raw -L /path/to/pvs-proof-driver.lisp -E '...'

(in-package :pvs)

(setq *proof-prompt-behavior* :noquestions)
(setq *proceed-without-asking* t)
(setq *noninteractive* t)
(setq *noninteractive-timeout* 120)

(defun pvs-skill-prepare (context file)
  (change-context context)
  (typecheck-file file))

(defun pvs-skill-find-formula (theory name)
  (find-if
   (lambda (decl)
     (and (formula-decl? decl)
          (string= (string (id decl)) name)))
   (append (assuming theory) (theory theory))))

(defun pvs-skill-proof-justification (strategy)
  (let ((form
         (if (stringp strategy)
             (multiple-value-bind (value position)
                 (read-from-string strategy)
               (declare (ignore position))
               value)
             strategy)))
    ;; Editable proof scripts start with a string label, for example
    ;; ("" (SKOSIMP*) (GRIND)). A bare strategy such as (GRIND) must be
    ;; wrapped first; REVERT-JUSTIFICATION otherwise interprets GRIND as a
    ;; proof label and silently produces a NIL step.
    (if (and (consp form) (stringp (car form)))
        (or (revert-justification form) form)
        (or (revert-justification (list "" form)) form))))

(defun pvs-skill-prove-one
    (context file theory-name formula-name strategy
     &optional save-complete?)
  "Prove one named declaration. Save only when SAVE-COMPLETE? is true and
the proof status is complete. Return the PVS proof status flag."
  (pvs-skill-prepare context file)
  (let* ((theory (get-typechecked-theory theory-name))
         (decl (and theory
                    (pvs-skill-find-formula theory formula-name))))
    (unless theory
      (error "PVS theory not found after typecheck: ~a" theory-name))
    (unless decl
      (error "PVS formula not found: ~a.~a" theory-name formula-name))
    (read-strategies-files)
    (setf (justification decl)
          (pvs-skill-proof-justification strategy))
    (format t "~%PVS-SKILL PROVING ~a.~a~%" theory-name formula-name)
    (let* ((proof
            (prove-decl decl :strategy '(then (rerun) (quit))))
           (flag (status-flag proof))
           (complete? (eq flag '!)))
      (format t "~%PVS-SKILL RESULT ~a.~a STATUS ~a~%"
              theory-name formula-name flag)
      (when (and save-complete? complete?)
        (save-all-proofs theory t)
        (save-context nil t)
        (format t "PVS-SKILL SAVED ~a.prf~%" file))
      (when (and save-complete? (not complete?))
        (format t "PVS-SKILL NOT SAVED: proof is incomplete~%"))
      flag)))

(defun pvs-skill-replay-theory (context file theory-name)
  "Typecheck FILE, force replay of THEORY-NAME, and save proof status."
  (pvs-skill-prepare context file)
  (prove-theory theory-name t nil nil t)
  (save-context nil t))

(defun pvs-skill-replay-importchain (context file theory-name)
  "Typecheck FILE, force replay of THEORY-NAME's import chain, and save status."
  (pvs-skill-prepare context file)
  (prove-importchain theory-name t nil nil t)
  (save-context nil t))

(defun pvs-skill-status-theory (context file theory-name)
  "Typecheck FILE and print proof status for THEORY-NAME."
  (pvs-skill-prepare context file)
  (status-proof-theory theory-name))

(defun pvs-skill-status-importchain (context file theory-name)
  "Typecheck FILE and print proof status for THEORY-NAME's import chain."
  (pvs-skill-prepare context file)
  (status-proof-importchain theory-name))
