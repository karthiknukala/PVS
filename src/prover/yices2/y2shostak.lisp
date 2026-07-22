;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2shostak.lisp --
;;   A Shostak whiteboard orchestrating specialized Yices2 satellites.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2026, SRI International. All Rights Reserved.
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the 3-Clause BSD License.
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; 3-Clause BSD License for more details.
;; --------------------------------------------------------------------

(in-package :pvs)

;; Architecture
;; ------------
;;
;; The ordinary PVS Shostak state is the whiteboard.  Every literal is written
;; there first, so its canonizers, congruence closure, linear arithmetic,
;; datatype rules, tuple rules, update rules, and rewriting remain the primary
;; interface engine.  Yices contexts are satellites: each receives only a
;; purified projection in a fragment it implements well.  A satellite may
;; return UNSAT or an equality/disequality over shared interface terms.  It may
;; never publish a model assignment as a fact.
;;
;; Non-convex combinations require arrangements, not just equality propagation.
;; When enabled below, the orchestrator returns a tautological equality split
;; to ASSERT, whose normal branch-state machinery explores both arrangements.

(defparameter *y2shostak-arrangement-splits* t
  "Generate interface equality splits needed by non-convex combinations.")

(defparameter *y2shostak-max-rounds* 1024
  "Safety bound for equality-exchange rounds. Exhaustion returns UNKNOWN.")

(defparameter *y2shostak-max-typepred-depth* 8
  "Maximum number of demand-driven type-predicate frontiers.

Depth zero contains the immediate terms of the asserted formulas.  Each
subsequent depth contains their immediate subterms.  Exhausting this bound is
an incompleteness boundary, never a proof.")

(defparameter *y2shostak-verbose* nil
  "Compatibility switch. Non-NIL enables compact Y2SHOSTAK tracing.")

(defparameter *y2shostak-trace-level* nil
  "Y2SHOSTAK trace mode: NIL, :SUMMARY, or :FULL.

:SUMMARY is the black-boxish view: whiteboard routing, type-predicate frontier
selection, satellite selection, round results, conflicts, and arrangements.
:FULL additionally prints whiteboard inputs/canonical forms, purified Yices
assertions and interface terms.  Equality and disequality traffic through the
Shostak e-graph is deliberately not traced.")

(defvar *y2shostak-trace-summary-active* t
  "Dynamically false while routine satellite reruns process auxiliary inputs.")

(defvar *y2shostak-generating-typepreds* nil
  "Suppress recursive compound-formula queries while deriving type predicates.")

(defvar *y2shostak-last-status* nil)
(defvar *y2shostak-last-error* nil)
(defvar *y2shostak-last-satellite* nil)
(defvar *y2shostak-last-model* nil
  "Printable projection of the most recent satisfiable satellite model.")
(defvar *y2shostak-last-summary* nil
  "Printable summary of the most recent whiteboard/satellite state.")

(defstruct (y2shostak-entry
            (:constructor make-y2shostak-entry
                (&key source canonical whiteboard family integer? nonlinear?
                      difference?)))
  source
  canonical
  ;; The whiteboard immediately before SOURCE was inserted.  Translating
  ;; against the post-insertion board would let a literal rewrite itself
  ;; (for example, x = y would collapse to x = x).
  whiteboard
  family
  integer?
  nonlinear?
  difference?)

(defstruct (y2shostak-interface
            (:constructor make-y2shostak-interface
                (expr term canonical &optional boundary?)))
  expr
  term
  canonical
  boundary?)

(defstruct (y2shostak-fact
            (:constructor make-y2shostak-fact (relation left right)))
  relation                         ; :equal or :distinct
  left
  right)

(defstruct (y2shostak-pair
            (:constructor make-y2shostak-pair (left right)))
  left
  right)

(defstruct (y2shostak-state
            (:constructor make-y2shostak-state
                (&key whiteboard background arithmetic bitvectors facts pending
                      roots interface-terms deferred-typepreds (generation 0))))
  ;; WHITEBOARD is always an ordinary DPINFO owned by the baseline Shostak DP.
  whiteboard
  (background nil :type list)
  (arithmetic nil :type list)
  (bitvectors nil :type list)
  (facts nil :type list)
  (pending nil :type list)
  ;; ROOTS are the immediate non-Boolean terms of user/base constraints.
  ;; INTERFACE-TERMS is the demand-driven prefix currently visible to Yices.
  ;; DEFERRED-TYPEPREDS records eager predicates supplied by ASSERT/SKEEP; the
  ;; bounded loop regenerates and asserts them only when their frontier opens.
  (roots nil :type list)
  (interface-terms nil :type list)
  (deferred-typepreds nil :type list)
  (generation 0 :type fixnum))

(defun y2shostak-trace-rank ()
  (let ((level (or *y2shostak-trace-level*
                   (and *y2shostak-verbose* :summary))))
    (cond ((or (eq level :full) (eq level :white-box)) 2)
          ((or (eq level :summary) (eq level :compact) (eq level t)) 1)
          ((and (integerp level) (plusp level)) (min level 2))
          (t 0))))

(defun y2shostak-tracing-p (&optional (level :summary))
  (>= (y2shostak-trace-rank)
      (if (member level '(:full :white-box)) 2 1)))

(defun y2shostak-event-trace-level ()
  (if *y2shostak-trace-summary-active* :summary :full))

(defun y2shostak-display (object)
  (if (typep object 'expr)
      (y2direct-pvs-string object)
      (princ-to-string object)))

(defun y2shostak-trace (level component control &rest arguments)
  (when (y2shostak-tracing-p level)
    ;; ASSERT normally binds *SUPPRESS-PRINTING* while it calls the DPI. A
    ;; diagnostic trace must deliberately bypass that binding; otherwise the
    ;; interesting whiteboard/satellite events disappear precisely while the
    ;; decision procedure is running.
    (let ((message
            (format nil "~%[Y2SHOSTAK/~a] ~a"
                    component (apply #'format nil control arguments))))
      (or (and (fboundp 'session-output) (session-output message))
          (format t "~a" message)))))

(defun y2shostak-note (control &rest arguments)
  (apply #'y2shostak-trace :summary :error control arguments))

(defun set-y2shostak-trace (level)
  (setq *y2shostak-trace-level*
        (case level
          ((nil :off) nil)
          ((t :summary :compact) :summary)
          ((:full :white-box) :full)
          (otherwise
           (error "Y2SHOSTAK trace level must be NIL, :SUMMARY, or :FULL"))))
  (when (null *y2shostak-trace-level*)
    (setq *y2shostak-verbose* nil))
  (format-if "~%Y2SHOSTAK tracing is ~a"
             (or *y2shostak-trace-level* :off))
  *y2shostak-trace-level*)

(defun y2shostak-visible-model-interface-p (interface)
  (let* ((expr (y2shostak-interface-expr interface))
         (names (collect-subterms expr #'name-expr?)))
    (and (type expr)
         (not (rational-expr? expr))
         (or (and (name-expr? expr) (skolem-constant? expr))
             (and (y2shostak-interface-boundary? interface)
                  ;; ASSERT also feeds generated Prelude type constraints to
                  ;; the DP. Keep UF terms rooted in the user's skolemized
                  ;; formula and reject constraint-schema terms containing
                  ;; their own bound variables. Accessor/record proxies are
                  ;; omitted because their independent satellite values are
                  ;; especially easy to mistake for whiteboard values.
                  (some #'skolem-constant? names)
                  (not (some #'(lambda (name)
                                 (and (declaration name)
                                      (or (bind-decl? (declaration name))
                                          (accessor? name))))
                             names)))))))

(defun y2shostak-trace-expression-p (expr)
  "Recognize terms rooted in the current user obligation rather than schemas."
  (let ((names (and (typep expr 'expr)
                    (collect-subterms expr #'name-expr?))))
    (or (and (typep expr 'expr) (rational-expr? expr))
        (and (some #'skolem-constant? names)
             (not (some #'(lambda (name)
                            (and (declaration name)
                                 (bind-decl? (declaration name))))
                        names))))))

(defun y2shostak-trace-interface-p (interface)
  "Recognize interface terms worth spelling out in the ordinary full trace.

Generated Prelude subtype constraints can contribute dozens of schematic
arithmetic terms. They remain in the solver, but tracing every pair obscures
the user's problem. User skolems, their compound terms, and numeric constants
remain visible."
  (y2shostak-trace-expression-p (y2shostak-interface-expr interface)))

(defun y2shostak-interface-model-lines (interfaces)
  (loop with seen = nil
        for interface in (reverse interfaces)
        for expr = (y2shostak-interface-expr interface)
        when (and (y2shostak-visible-model-interface-p interface)
                  (not (find expr seen :test #'tc-eq)))
          collect
          (progn
            (push expr seen)
            (let* ((term (y2shostak-interface-term interface))
                   (value (y2direct-model-value-string term (type expr))))
              (when (and (search "y2d_" value :test #'char-equal)
                         (ignore-errors
                           (y2direct-real-type-p (type expr))))
                (setq value
                      (format nil "~,10g (algebraic approximation)"
                              (y2/value-double term))))
              (format nil "~a = ~a"
                      (y2direct-pvs-string expr) value)))))

(defun y2shostak-capture-satellite-model (satellite interfaces)
  "Save a model while its scoped Yices context is still alive.

This is deliberately called a projection: PVS/Shostak-only atoms (notably
datatype and uninterpreted predicates) are not asserted to this context.  The
  saved values are useful diagnostics, but the residual PVS sequent remains the
  authoritative counterexample obligation."
  (handler-case
      (let ((lines (y2shostak-interface-model-lines interfaces)))
        (setq *y2shostak-last-model*
              (if lines
                  (format nil "~a satellite projection:~{~%  ~a~}"
                          satellite lines)
                  (format nil
                          "~a satellite projection:~%  <no user-visible interface terms>"
                          satellite))))
    (error (condition)
      (setq *y2shostak-last-model*
            (format nil
                    "~a satellite returned SAT, but its model could not be rendered: ~a"
                    satellite condition)))))

(defun y2shostak-update-summary (state)
  (setq *y2shostak-last-summary*
        (format nil
                "whiteboard generation ~d; ~d background literal~:p; ~d arithmetic literal~:p; ~d bitvector literal~:p; ~d active interface term~:p; ~d deferred type predicate~:p; ~d pending arrangement~:p"
                (y2shostak-state-generation state)
                (length (y2shostak-state-background state))
                (length (y2shostak-state-arithmetic state))
                (length (y2shostak-state-bitvectors state))
                (length (y2shostak-state-interface-terms state))
                (length (y2shostak-state-deferred-typepreds state))
                (length (y2shostak-state-pending state))))
  state)

(defun y2shostak-status-string ()
  (with-output-to-string (stream)
    (format stream "Y2SHOSTAK status: ~a" (or *y2shostak-last-status* :none))
    (format stream "~%  trace: ~a"
            (or *y2shostak-trace-level*
                (and *y2shostak-verbose* :summary)
                :off))
    (when *y2shostak-last-satellite*
      (format stream "~%  last satellite: ~a" *y2shostak-last-satellite*))
    (when *y2shostak-last-summary*
      (format stream "~%  ~a" *y2shostak-last-summary*))
    (when *y2shostak-last-error*
      (format stream "~%  last error: ~a" *y2shostak-last-error*))))

(defun y2shostak-show-last-status ()
  (let ((text (y2shostak-status-string)))
    (format-if "~%~a" text)
    text))

(defun y2shostak-show-last-model ()
  (let ((text (or *y2shostak-last-model*
                  "No satisfiable Y2SHOSTAK satellite model is available.")))
    (format-if "~%~a" text)
    text))

(defun y2shostak-counterexample-string (&optional proofstate)
  (with-output-to-string (stream)
    (format stream
            "Y2SHOSTAK did not close this branch. The residual PVS sequent is the authoritative, user-readable counterexample obligation.")
    (when proofstate
      (format stream "~%~%~a :~%~a"
              (label proofstate) (current-goal proofstate)))
    (format stream
            "~%~%The following is only a satellite projection; it may omit UF predicates, datatype structure, and other whiteboard-only symbols.~%  ~a"
            (or *y2shostak-last-model* "<no satellite model available>"))))

(defun y2shostak-show-last-counterexample (&optional proofstate)
  (let ((text (y2shostak-counterexample-string proofstate)))
    (format-if "~%~a" text)
    text))

(defun y2shostak-empty-whiteboard ()
  (dpi-empty-state* 'shostak))

(defun y2shostak-state-or-empty (state)
  (if (y2shostak-state-p state)
      state
      (make-y2shostak-state :whiteboard (y2shostak-empty-whiteboard))))

(defun y2shostak-copy (state &optional bump?)
  (let ((copy (copy-y2shostak-state (y2shostak-state-or-empty state))))
    (setf (y2shostak-state-arithmetic copy)
          (copy-list (y2shostak-state-arithmetic copy))
          (y2shostak-state-background copy)
          (copy-list (y2shostak-state-background copy))
          (y2shostak-state-bitvectors copy)
          (copy-list (y2shostak-state-bitvectors copy))
          (y2shostak-state-facts copy)
          (copy-list (y2shostak-state-facts copy))
          (y2shostak-state-pending copy)
          (copy-list (y2shostak-state-pending copy))
          (y2shostak-state-roots copy)
          (copy-list (y2shostak-state-roots copy))
          (y2shostak-state-interface-terms copy)
          (copy-list (y2shostak-state-interface-terms copy))
          (y2shostak-state-deferred-typepreds copy)
          (copy-list (y2shostak-state-deferred-typepreds copy))
          (y2shostak-state-whiteboard copy)
          (dpi-copy-state* 'shostak (y2shostak-state-whiteboard copy)))
    (when bump?
      (incf (y2shostak-state-generation copy)))
    copy))

(defun y2shostak-old-form (source)
  (if (typep source 'expr)
      (top-translate-to-old-prove source)
      source))

(defun y2shostak-canonical-form (source whiteboard)
  (handler-case
      (let ((sigalist (dpinfo-sigalist whiteboard))
            (findalist (dpinfo-findalist whiteboard))
            (usealist (dpinfo-usealist whiteboard)))
        (catch 'context
          (canon (y2shostak-old-form source) 'dont-add-use)))
    (error (condition)
      (y2shostak-note "Y2SHOSTAK could not canonize ~a: ~a"
                      source condition)
      (y2shostak-old-form source))))

(defun y2shostak-whiteboard-process (source whiteboard)
  (dpi-process* 'shostak source whiteboard))

(defun y2shostak-whiteboard-changed-p (old new)
  (dpi-state-changed?* 'shostak old new))

(defun y2shostak-nonboolean-term-p (term)
  (and (typep term 'expr)
       (type term)
       (not (ignore-errors (y2direct-boolean-type-p (type term))))
       (not (ignore-errors (funtype? (find-supertype (type term)))))))

(defun y2shostak-pushnew-exprs (new old)
  (dolist (expr new old)
    (when (and (y2shostak-nonboolean-term-p expr)
               (not (find expr old :test #'tc-eq)))
      (setq old (append old (list expr))))))

(defun y2shostak-formula-root-terms (source)
  "Immediate value terms mentioned by SOURCE, below Boolean structure."
  (labels ((roots (expr)
             (cond ((not (typep expr 'expr)) nil)
                   ((and (type expr)
                         (ignore-errors
                           (y2direct-boolean-type-p (type expr))))
                    (cond ((negation? expr) (roots (args1 expr)))
                          ((or (conjunction? expr) (disjunction? expr)
                               (implication? expr) (iff? expr))
                           ;; Do not MAPCAN PVS argument lists: some accessors
                           ;; expose shared list structure, and NCONC can turn
                           ;; a repeated Boolean operand into a circular list.
                           (loop for argument in (arguments expr)
                                 append (copy-list (roots argument))))
                          ((typep expr 'application)
                           (remove-if-not #'y2shostak-nonboolean-term-p
                                          (copy-list (arguments expr))))
                          (t nil)))
                   ((y2shostak-nonboolean-term-p expr) (list expr))
                   (t nil))))
    (y2shostak-pushnew-exprs (roots source) nil)))

(defun y2shostak-immediate-subterms (term)
  "One structural layer below TERM, excluding operators and Boolean terms."
  (let ((children
          (typecase term
            (application (arguments term))
            (tuple-expr (exprs term))
            (record-expr
             (mapcar #'expression (assignments term)))
            (update-expr
             (cons (expression term)
                   (loop for assignment in (assignments term)
                         append (cons (expression assignment)
                                      (loop for indices in
                                            (arguments assignment)
                                            append (copy-list indices))))))
            (assignment
             (cons (expression term)
                   (loop for indices in (arguments term)
                         append (copy-list indices))))
            (t nil))))
    (y2shostak-pushnew-exprs children nil)))

(defun y2shostak-term-typepreds (term)
  "All explicit type predicates for TERM, flattened but not recursively mined."
  (handler-case
      (let ((*generate-tccs* 'none)
            (*y2shostak-generating-typepreds* t))
        (delete-duplicates
         (loop for predicate in (type-constraints term t)
               nconc (copy-list (and+ predicate)))
         :test #'tc-eq))
    (error (condition)
      (y2shostak-trace :full :typepred
                       "could not obtain type predicates for ~a: ~a"
                       (y2shostak-display term) condition)
      nil)))

(defun y2shostak-derived-typepred-p (source)
  "Recognize eager ASSERT/SKEEP type predicates so they can be deferred."
  (and (typep source 'expr)
       (or (forall-expr? source)
           (let ((terms
                   (collect-subterms source #'y2shostak-nonboolean-term-p)))
             (some #'(lambda (term)
                       (find source (y2shostak-term-typepreds term)
                             :test #'tc-eq))
                   terms)))))

(defun y2shostak-add-deferred-typepred (state source)
  (if (find source (y2shostak-state-deferred-typepreds state) :test #'tc-eq)
      state
      (let ((copy (y2shostak-copy state t)))
        (setf (y2shostak-state-deferred-typepreds copy)
              (append (y2shostak-state-deferred-typepreds state)
                      (list source)))
        copy)))

(defun y2shostak-add-root-terms (state source)
  (let* ((roots (y2shostak-formula-root-terms source))
         (new-roots
           (y2shostak-pushnew-exprs roots (y2shostak-state-roots state)))
         (new-interfaces
           (y2shostak-pushnew-exprs
            roots (y2shostak-state-interface-terms state))))
    (if (and (equal new-roots (y2shostak-state-roots state))
             (equal new-interfaces (y2shostak-state-interface-terms state)))
        state
        (let ((copy (y2shostak-copy state t)))
          (setf (y2shostak-state-roots copy) new-roots
                (y2shostak-state-interface-terms copy) new-interfaces)
          copy))))

(defun y2shostak-add-interface-terms (state terms)
  (let ((new (y2shostak-pushnew-exprs
              terms (y2shostak-state-interface-terms state))))
    (if (equal new (y2shostak-state-interface-terms state))
        state
        (let ((copy (y2shostak-copy state t)))
          (setf (y2shostak-state-interface-terms copy) new)
          copy))))

(defun y2shostak-remove-deferred-typepred (state source)
  (let ((remaining
          (delete source (y2shostak-state-deferred-typepreds state)
                  :test #'tc-eq)))
    (if (= (length remaining)
           (length (y2shostak-state-deferred-typepreds state)))
        state
        (let ((copy (y2shostak-copy state t)))
          (setf (y2shostak-state-deferred-typepreds copy) remaining)
          copy))))

;; --------------------------------------------------------------------
;; Fragment recognition

(defun y2shostak-strip-negation (source)
  (if (and (typep source 'expr) (negation? source))
      (args1 source)
      source))

(defun y2shostak-bitvector-occurs-p (source)
  (and (typep source 'expr)
       (not (null
             (collect-subterms
              source #'(lambda (term)
                         (and (typep term 'expr)
                              (type term)
                              (ignore-errors
                                (y2direct-bitvector-type-p
                                 (type term))))))))))

(defun y2shostak-bitvector-formula-p (source)
  (let ((body (y2shostak-strip-negation source)))
    (and (typep body 'application)
         (if (or (conjunction? body) (disjunction? body)
                 (implication? body) (iff? body))
             (every #'y2shostak-bitvector-formula-p (arguments body))
             (let* ((head (y2direct-application-head body))
                    (op (and (name-expr? head) (id head)))
                    (args (arguments body)))
               (and (or (equation? body)
                        (disequation? body)
                        (member op '(< <= > >=
                                     |bv_slt| |bv_sle| |bv_sgt| |bv_sge|)
                                :test #'eq))
                    (some #'y2shostak-bitvector-occurs-p args)))))))

(defun y2shostak-arithmetic-atom-p (source)
  (let ((body (y2shostak-strip-negation source)))
    (and (typep body 'application)
         (let* ((head (y2direct-application-head body))
                (op (and (name-expr? head) (id head)))
                (args (arguments body)))
           (and (or (equation? body)
                    (disequation? body)
                    (member op '(< <= > >=) :test #'eq))
                args
                (every #'(lambda (arg)
                           (and (type arg)
                                (ignore-errors
                                  (y2direct-arithmetic-type-p (type arg)))))
                       args))))))

(defun y2shostak-arithmetic-formula-p (source)
  "Whether SOURCE is a Boolean combination of arithmetic atoms."
  (let ((body (y2shostak-strip-negation source)))
    (cond ((or (and (name-expr? body) (tc-eq body *true*))
               (and (name-expr? body) (tc-eq body *false*)))
           t)
          ((y2shostak-arithmetic-atom-p body) t)
          ((and (typep body 'application)
                (or (conjunction? body) (disjunction? body)
                    (implication? body) (iff? body)))
           (every #'y2shostak-arithmetic-formula-p (arguments body)))
          (t nil))))

(defun y2shostak-integer-formula-p (source)
  (let ((body (y2shostak-strip-negation source)))
    (and (typep body 'expr)
         (let ((terms
                 (collect-subterms
                  body #'(lambda (term)
                           (and (typep term 'expr)
                                (type term)
                                (ignore-errors
                                  (y2direct-arithmetic-type-p
                                   (type term))))))))
           (and terms
                (every #'(lambda (term)
                           (ignore-errors
                             (y2direct-integer-type-p (type term))))
                       terms))))))

(defun y2shostak-qvalue (term)
  (cond ((integerp term) (values term t))
        ((and (consp term)
              (eq (car term) 'DIVIDE)
              (integerp (second term))
              (integerp (third term))
              (not (zerop (third term))))
         (values (/ (second term) (third term)) t))
        (t (values nil nil))))

(defun y2shostak-coeff-add (coeffs term value)
  (let ((entry (assoc term coeffs :test #'equal)))
    (cond (entry
           (incf (cdr entry) value)
           (if (zerop (cdr entry))
               (delete entry coeffs :test #'eq)
               coeffs))
          ((zerop value) coeffs)
          (t (acons term value coeffs)))))

(defun y2shostak-poly-scale (coeffs factor)
  (loop for (term . coefficient) in coeffs
        for scaled = (* factor coefficient)
        unless (zerop scaled)
          collect (cons term scaled)))

(defun y2shostak-poly-add (left right)
  (let ((sum (copy-tree left)))
    (dolist (entry right sum)
      (setq sum (y2shostak-coeff-add sum (car entry) (cdr entry))))))

(defun y2shostak-linear-polynomial (term)
  "Return COEFFICIENTS, CONSTANT, SUCCESS for an old-prover term."
  (multiple-value-bind (number number?) (y2shostak-qvalue term)
    (cond (number? (values nil number t))
          ((atom term) (values (list (cons term 1)) 0 t))
          ((eq (car term) 'PLUS)
           (let ((coeffs nil) (constant 0))
             (dolist (arg (cdr term) (values coeffs constant t))
               (multiple-value-bind (ac av ok)
                   (y2shostak-linear-polynomial arg)
                 (unless ok
                   (return-from y2shostak-linear-polynomial
                     (values nil nil nil)))
                 (setq coeffs (y2shostak-poly-add coeffs ac))
                 (incf constant av)))))
          ((and (eq (car term) 'MINUS) (= (length term) 2))
           (multiple-value-bind (coeffs constant ok)
               (y2shostak-linear-polynomial (second term))
             (values (and ok (y2shostak-poly-scale coeffs -1))
                     (and ok (- constant)) ok)))
          ((and (eq (car term) 'DIFFERENCE) (= (length term) 3))
           (multiple-value-bind (lc lv lok)
               (y2shostak-linear-polynomial (second term))
             (multiple-value-bind (rc rv rok)
                 (y2shostak-linear-polynomial (third term))
               (if (and lok rok)
                   (values (y2shostak-poly-add
                            lc (y2shostak-poly-scale rc -1))
                           (- lv rv) t)
                   (values nil nil nil)))))
          ((and (eq (car term) 'TIMES) (= (length term) 3))
           (multiple-value-bind (factor factor?)
               (y2shostak-qvalue (second term))
             (unless factor?
               (multiple-value-setq (factor factor?)
                 (y2shostak-qvalue (third term))))
             (if factor?
                 (let ((other (if (multiple-value-bind (n ok)
                                      (y2shostak-qvalue (second term))
                                    (declare (ignore n)) ok)
                                  (third term)
                                  (second term))))
                   (multiple-value-bind (coeffs constant ok)
                       (y2shostak-linear-polynomial other)
                     (if ok
                         (values (y2shostak-poly-scale coeffs factor)
                                 (* constant factor) t)
                         (values nil nil nil))))
                 (values nil nil nil))))
          ((and (eq (car term) 'DIVIDE) (= (length term) 3))
           (multiple-value-bind (denominator denominator?)
               (y2shostak-qvalue (third term))
             (if (and denominator? (not (zerop denominator)))
                 (multiple-value-bind (coeffs constant ok)
                     (y2shostak-linear-polynomial (second term))
                   (if ok
                       (values (y2shostak-poly-scale
                                coeffs (/ denominator))
                               (/ constant denominator) t)
                       (values nil nil nil)))
                 (values nil nil nil))))
          ;; An application from another theory is one arithmetic atom after
          ;; purification (for example, f(x) in f(x)^2 = 2).
          ((not (member (car term) '(PLUS MINUS DIFFERENCE TIMES DIVIDE)
                        :test #'eq))
           (values (list (cons term 1)) 0 t))
          (t (values nil nil nil)))))

(defun y2shostak-old-boolean-node-p (term)
  "Recognize old-prover Boolean syntax without relying on its type alist."
  (and (consp term)
       (member (car term)
               '(not and or implies iff if if*
                 equal nequal lessp lesseqp greaterp greatereqp)
               :test #'eq)))

(defun y2shostak-old-relation-sides (canonical)
  (let ((body (if (and (consp canonical) (eq (car canonical) 'not))
                  (second canonical)
                  canonical)))
    (when (and (consp body)
               (member (car body)
                       '(equal nequal lessp lesseqp greaterp greatereqp)
                       :test #'eq)
               (= (length body) 3)
               ;; IFF is translated by the old prover as equality between
               ;; Boolean terms.  It is connective structure, not a linear
               ;; arithmetic atom.
               (not (and (member (car body) '(equal nequal) :test #'eq)
                         (or (boolp (second body))
                             (boolp (third body))
                             (y2shostak-old-boolean-node-p (second body))
                             (y2shostak-old-boolean-node-p (third body))))))
      (values (second body) (third body) t))))

(defun y2shostak-canonical-relations (canonical)
  "Collect arithmetic relation nodes below a canonical Boolean formula."
  (multiple-value-bind (left right relation?)
      (y2shostak-old-relation-sides canonical)
    (declare (ignore left right))
    (cond (relation? (list canonical))
          ((and (consp canonical)
                (or (member (car canonical)
                            '(not and or implies iff if if*) :test #'eq)
                    (and (= (length canonical) 3)
                         (member (car canonical) '(equal nequal) :test #'eq)
                         (or (boolp (second canonical))
                             (boolp (third canonical))
                             (y2shostak-old-boolean-node-p
                              (second canonical))
                             (y2shostak-old-boolean-node-p
                              (third canonical))))))
           (mapcan #'y2shostak-canonical-relations (cdr canonical)))
          (t nil))))

(defun y2shostak-linear-constraint-p (canonical)
  (multiple-value-bind (left right relation?)
      (y2shostak-old-relation-sides canonical)
    (and relation?
         (multiple-value-bind (lc lv lok)
             (y2shostak-linear-polynomial left)
           (declare (ignore lc lv))
           (and lok
                (multiple-value-bind (rc rv rok)
                    (y2shostak-linear-polynomial right)
                  (declare (ignore rc rv))
                  rok))))))

(defun y2shostak-integer-constraint-p (canonical)
  (multiple-value-bind (left right relation?)
      (y2shostak-old-relation-sides canonical)
    (and relation?
         (eq (prtype left) 'integer)
         (eq (prtype right) 'integer))))

(defun y2shostak-difference-constraint-p (canonical)
  (multiple-value-bind (left right relation?)
      (y2shostak-old-relation-sides canonical)
    (and relation?
         (multiple-value-bind (lc lv lok)
             (y2shostak-linear-polynomial left)
           (declare (ignore lv))
           (multiple-value-bind (rc rv rok)
               (y2shostak-linear-polynomial right)
             (declare (ignore rv))
             (when (and lok rok)
               (let ((coeffs
                       (y2shostak-poly-add
                        lc (y2shostak-poly-scale rc -1))))
                 (and (<= (length coeffs) 2)
                      (every #'(lambda (entry)
                                 (member (cdr entry) '(1 -1) :test #'=))
                             coeffs)
                      (or (< (length coeffs) 2)
                          (zerop (reduce #'+ coeffs
                                        :key #'cdr)))))))))))

(defun y2shostak-classify-entry (source canonical &optional whiteboard)
  (cond ((y2shostak-bitvector-formula-p source)
         (make-y2shostak-entry :source source :canonical canonical
                               :whiteboard whiteboard
                               :family :bitvector))
        ((y2shostak-arithmetic-formula-p source)
         (let* ((relations (y2shostak-canonical-relations canonical))
                (linear? (and relations
                              (every #'y2shostak-linear-constraint-p
                                     relations))))
           (make-y2shostak-entry
            :source source :canonical canonical :family :arithmetic
            :whiteboard whiteboard
            :integer? (or (y2shostak-integer-constraint-p canonical)
                          (y2shostak-integer-formula-p source))
            :nonlinear? (not linear?)
            :difference? (and linear?
                              (every #'y2shostak-difference-constraint-p
                                     relations)))))
        (t nil)))

(defun y2shostak-entry-description (entry)
  (if (null entry)
      "baseline whiteboard only"
      (case (y2shostak-entry-family entry)
        (:bitvector "bitvector satellite")
        (:arithmetic
         (format nil "~:[real~;integer~] ~:[linear~;nonlinear~]~:[~; difference~] arithmetic satellite"
                 (y2shostak-entry-integer? entry)
                 (y2shostak-entry-nonlinear? entry)
                 (y2shostak-entry-difference? entry)))
        (otherwise (princ-to-string (y2shostak-entry-family entry))))))

;; --------------------------------------------------------------------
;; Persistent state updates

(defun y2shostak-entry-present-p (entry entries)
  (find (y2shostak-entry-canonical entry) entries
        :key #'y2shostak-entry-canonical :test #'equal))

(defun y2shostak-add-background (state source)
  (if (find source (y2shostak-state-background state) :test #'tc-eq)
      state
      (let ((copy (y2shostak-copy state t)))
        (setf (y2shostak-state-background copy)
              (append (y2shostak-state-background state) (list source)))
        copy)))

(defun y2shostak-add-entry (state entry)
  (let* ((slot (ecase (y2shostak-entry-family entry)
                 (:arithmetic #'y2shostak-state-arithmetic)
                 (:bitvector #'y2shostak-state-bitvectors)))
         (entries (funcall slot state)))
    (if (y2shostak-entry-present-p entry entries)
        state
        (let ((copy (y2shostak-copy state t)))
          (ecase (y2shostak-entry-family entry)
            (:arithmetic
             (setf (y2shostak-state-arithmetic copy)
                   (append entries (list entry))))
            (:bitvector
             (setf (y2shostak-state-bitvectors copy)
                   (append entries (list entry)))))
          copy))))

(defun y2shostak-same-pair-p (left right fact)
  (or (and (tc-eq left (y2shostak-fact-left fact))
           (tc-eq right (y2shostak-fact-right fact)))
      (and (tc-eq left (y2shostak-fact-right fact))
           (tc-eq right (y2shostak-fact-left fact)))))

(defun y2shostak-find-fact (state left right)
  (find-if #'(lambda (fact) (y2shostak-same-pair-p left right fact))
           (y2shostak-state-facts state)))

(defun y2shostak-fact-old-form (fact)
  (let ((equality
          `(equal ,(y2shostak-old-form (y2shostak-fact-left fact))
                  ,(y2shostak-old-form (y2shostak-fact-right fact)))))
    (if (eq (y2shostak-fact-relation fact) :equal)
        equality
        `(not ,equality))))

(defun y2shostak-fact-string (fact)
  (format nil "~a ~a ~a"
          (y2shostak-display (y2shostak-fact-left fact))
          (if (eq (y2shostak-fact-relation fact) :equal) "=" "/=")
          (y2shostak-display (y2shostak-fact-right fact))))

(defun y2shostak-add-fact (state fact)
  (let ((old (y2shostak-find-fact
              state (y2shostak-fact-left fact)
              (y2shostak-fact-right fact))))
    (cond ((and old (eq (y2shostak-fact-relation old)
                        (y2shostak-fact-relation fact)))
           (values state nil nil))
          ((and old (not (eq (y2shostak-fact-relation old)
                             (y2shostak-fact-relation fact))))
           (y2shostak-trace :summary :whiteboard
                            "conflicting exchanged fact: ~a"
                            (y2shostak-fact-string fact))
           (values state nil t))
          (t
           (let ((copy (y2shostak-copy state t)))
             (setf (y2shostak-state-facts copy)
                   (cons fact (y2shostak-state-facts copy)))
             (multiple-value-bind (result whiteboard)
                 (y2shostak-whiteboard-process
                  (y2shostak-fact-old-form fact)
                  (y2shostak-state-whiteboard copy))
               (if (false-p result)
                   (progn
                     (y2shostak-trace :summary :whiteboard
                                      "rejected exchanged fact as conflicting: ~a"
                                      (y2shostak-fact-string fact))
                     (values state nil t))
                   (progn
                     (setf (y2shostak-state-whiteboard copy) whiteboard)
                     (values copy t nil)))))))))

(defun y2shostak-add-pending (state pair)
  (if (find-if #'(lambda (old)
                   (or (and (tc-eq (y2shostak-pair-left pair)
                                   (y2shostak-pair-left old))
                            (tc-eq (y2shostak-pair-right pair)
                                   (y2shostak-pair-right old)))
                       (and (tc-eq (y2shostak-pair-left pair)
                                   (y2shostak-pair-right old))
                            (tc-eq (y2shostak-pair-right pair)
                                   (y2shostak-pair-left old)))))
                 (y2shostak-state-pending state))
      state
      (let ((copy (y2shostak-copy state t)))
        (push pair (y2shostak-state-pending copy))
        copy)))

(defun y2shostak-pair-split-form (pair)
  (let ((equality
          `(equal ,(y2shostak-old-form (y2shostak-pair-left pair))
                  ,(y2shostak-old-form (y2shostak-pair-right pair)))))
    `(or ,equality (not ,equality))))

(defun y2shostak-source-relation (source pair)
  (let* ((left (y2shostak-old-form (y2shostak-pair-left pair)))
         (right (y2shostak-old-form (y2shostak-pair-right pair)))
         (eq1 `(equal ,left ,right))
         (eq2 `(equal ,right ,left)))
    (cond ((or (equal source eq1) (equal source eq2)) :equal)
          ((or (equal source `(not ,eq1))
               (equal source `(not ,eq2))
               (equal source `(nequal ,left ,right))
               (equal source `(nequal ,right ,left)))
           :distinct)
          (t nil))))

(defun y2shostak-pending-fact (state source)
  (loop for pair in (y2shostak-state-pending state)
        for relation = (y2shostak-source-relation source pair)
        when relation
          return (make-y2shostak-fact
                  relation (y2shostak-pair-left pair)
                  (y2shostak-pair-right pair))))

;; --------------------------------------------------------------------
;; Interface equality operations

(defvar *y2shostak-canonical-whiteboard* nil)
(defvar *y2shostak-arithmetic-term-cache* nil)
(defvar *y2shostak-bitvector-term-cache* nil)

(defun y2shostak-canonize-interface-expr (expr)
  (if *y2shostak-canonical-whiteboard*
      (y2shostak-canonical-form expr *y2shostak-canonical-whiteboard*)
      (y2shostak-old-form expr)))

(defun y2shostak-whiteboard-relation (whiteboard left right)
  (let ((equality `(equal ,(y2shostak-old-form left)
                          ,(y2shostak-old-form right))))
    (multiple-value-bind (result ignored)
        (y2shostak-whiteboard-process equality whiteboard)
      (declare (ignore ignored))
      (cond ((true-p result) :equal)
            ((false-p result) :distinct)
            (t
             (multiple-value-bind (negative-result ignored-negative)
                 (y2shostak-whiteboard-process `(not ,equality) whiteboard)
               (declare (ignore ignored-negative))
               (cond ((true-p negative-result) :distinct)
                     ((false-p negative-result) :equal)
                     (t nil))))))))

(defun y2shostak-note-interface (expr term boundary? interfaces)
  (let* ((canonical (y2shostak-canonize-interface-expr expr))
         (old (find canonical interfaces
                    :key #'y2shostak-interface-canonical :test #'equal)))
    (cond (old
           (when boundary?
             (setf (y2shostak-interface-boundary? old) t))
           interfaces)
          (t (cons (make-y2shostak-interface
                    expr term canonical boundary?)
                   interfaces)))))

(defun y2shostak-compatible-interface-p (left right)
  (and (not (equal (y2shostak-interface-canonical left)
                   (y2shostak-interface-canonical right)))
       (not (zerop
             (%y2/yices_compatible_types
              (%y2/yices_type_of_term (y2shostak-interface-term left))
              (%y2/yices_type_of_term (y2shostak-interface-term right)))))))

(defun y2shostak-interface-pairs (interfaces)
  (loop for tail on interfaces
        for left = (car tail)
        nconc (loop for right in (cdr tail)
                    when (y2shostak-compatible-interface-p left right)
                      collect (cons left right))))

(defun y2shostak-interface-fact-term (fact translate)
  (let ((left (funcall translate (y2shostak-fact-left fact)))
        (right (funcall translate (y2shostak-fact-right fact))))
    (when (and left right)
      (if (eq (y2shostak-fact-relation fact) :equal)
          (y2/= left right)
          (y2//= left right)))))

;; --------------------------------------------------------------------
;; Arithmetic purification and translation

(defvar *y2shostak-arithmetic-interfaces*)
(defvar *y2shostak-active-arithmetic-spec* nil)

(defun y2shostak-number-term (expr)
  (let ((value (number expr)))
    (cond ((integerp value)
           (if (<= (- (expt 2 31)) value (1- (expt 2 31)))
               (y2/int32 value)
               (y2/int64 value)))
          (t (y2/parse-rat (princ-to-string value))))))

(defun y2shostak-arithmetic-proxy (expr)
  (let ((term (y2direct-global-term expr)))
    (setq *y2shostak-arithmetic-interfaces*
          (y2shostak-note-interface
           expr term t *y2shostak-arithmetic-interfaces*))
    term))

(defun y2shostak-record-arithmetic-term (expr term &optional boundary?)
  (setq *y2shostak-arithmetic-interfaces*
        (y2shostak-note-interface
         expr term boundary? *y2shostak-arithmetic-interfaces*))
  term)

(defun y2shostak-arithmetic-term-raw (expr)
  (cond ((rational-expr? expr)
         (y2shostak-record-arithmetic-term
          expr (y2shostak-number-term expr)))
        ((and (name-expr? expr)
              (tc-eq expr *true*))
         (y2/true))
        ((and (name-expr? expr)
              (tc-eq expr *false*))
         (y2/false))
        ((name-expr? expr)
         (if (and (type expr)
                  (y2direct-arithmetic-type-p (type expr)))
             (y2shostak-record-arithmetic-term
              expr (y2direct-global-term expr))
             (y2shostak-arithmetic-proxy expr)))
        ((typep expr 'application)
         (let* ((head (y2direct-application-head expr))
                (op (and (name-expr? head) (id head)))
                (args (arguments expr)))
           (cond ((negation? expr)
                  (y2/not (y2shostak-arithmetic-term (first args))))
                 ((conjunction? expr)
                  (apply #'y2/and
                         (mapcar #'y2shostak-arithmetic-term args)))
                 ((disjunction? expr)
                  (apply #'y2/or
                         (mapcar #'y2shostak-arithmetic-term args)))
                 ((implication? expr)
                  (y2/=> (y2shostak-arithmetic-term (first args))
                         (y2shostak-arithmetic-term (second args))))
                 ((iff? expr)
                  (y2/iff (y2shostak-arithmetic-term (first args))
                          (y2shostak-arithmetic-term (second args))))
                 ((equation? expr)
                  (y2/= (y2shostak-arithmetic-term (first args))
                        (y2shostak-arithmetic-term (second args))))
                 ((disequation? expr)
                  (y2//= (y2shostak-arithmetic-term (first args))
                         (y2shostak-arithmetic-term (second args))))
                 ((member op '(< <= > >=) :test #'eq)
                  (let ((terms (mapcar #'y2shostak-arithmetic-term args)))
                    (ecase op
                      (< (y2/< (first terms) (second terms)))
                      (<= (y2/<= (first terms) (second terms)))
                      (> (y2/> (first terms) (second terms)))
                      (>= (y2/>= (first terms) (second terms))))))
                 ((and (member op '(+ - * /) :test #'eq)
                       (type expr)
                       (y2direct-arithmetic-type-p (type expr)))
                  (let* ((terms (mapcar #'y2shostak-arithmetic-term args))
                         (term
                           (case op
                             (+ (apply #'y2/+ terms))
                             (- (if (= (length terms) 1)
                                    (y2/- (first terms))
                                    (reduce #'y2/- (cdr terms)
                                            :initial-value (car terms))))
                             (* (apply #'y2/* terms))
                             (/ (reduce #'y2// (cdr terms)
                                        :initial-value (car terms))))))
                    (y2shostak-record-arithmetic-term expr term)))
                 ((and (type expr)
                       (y2direct-arithmetic-type-p (type expr)))
                  (y2shostak-arithmetic-proxy expr))
                 (t
                  (y2api-err
                   "Non-arithmetic formula in arithmetic satellite: ~a"
                   expr)))))
        ((and (type expr) (y2direct-arithmetic-type-p (type expr)))
         (y2shostak-arithmetic-proxy expr))
        (t (y2api-err "Cannot purify arithmetic expression ~a" expr))))

(defun y2shostak-arithmetic-boundary-p (expr)
  (and (typep expr 'application)
       (let* ((head (y2direct-application-head expr))
              (op (and (name-expr? head) (id head))))
         (not (member op '(+ - * /) :test #'eq)))))

(defun y2shostak-arithmetic-native-term-p (expr canonical)
  (cond ((or (rational-expr? expr) (name-expr? expr)) t)
        ((getf *y2shostak-active-arithmetic-spec* :mcsat) t)
        (t
         (multiple-value-bind (coefficients constant linear?)
             (y2shostak-linear-polynomial canonical)
           (declare (ignore constant))
           (and linear?
                (or (not (member
                          (getf *y2shostak-active-arithmetic-spec* :name)
                          '(:real-difference :integer-difference)))
                    (and (<= (length coefficients) 2)
                         (every #'(lambda (entry)
                                    (member (cdr entry) '(1 -1) :test #'=))
                                coefficients)
                         (or (< (length coefficients) 2)
                             (zerop (reduce #'+ coefficients
                                           :key #'cdr))))))))))

(defun y2shostak-arithmetic-term (expr)
  "Translate EXPR after Shostak-canonical deduplication of value terms."
  (if (and (typep expr 'expr) (type expr)
           (ignore-errors (y2direct-arithmetic-type-p (type expr))))
      (let* ((canonical (y2shostak-canonize-interface-expr expr))
             (cached (assoc canonical *y2shostak-arithmetic-term-cache*
                            :test #'equal)))
        (if cached
            (y2shostak-record-arithmetic-term
             expr (cdr cached) (y2shostak-arithmetic-boundary-p expr))
            (let ((term
                    (if (y2shostak-arithmetic-native-term-p expr canonical)
                        (y2shostak-arithmetic-term-raw expr)
                        (y2shostak-arithmetic-proxy expr))))
              (push (cons canonical term) *y2shostak-arithmetic-term-cache*)
              term)))
      (y2shostak-arithmetic-term-raw expr)))

(defun y2shostak-distinct-entries (entries)
  (remove-duplicates entries :key #'y2shostak-entry-canonical
                             :test #'equal :from-end t))

(defun y2shostak-arithmetic-spec (entries)
  (let ((integer? (every #'y2shostak-entry-integer? entries))
        (nonlinear? (some #'y2shostak-entry-nonlinear? entries))
        (difference? (every #'y2shostak-entry-difference? entries)))
    (cond ((and nonlinear? integer?)
           ;; QF_NIA is undecidable in general. Yices may decide an instance,
           ;; but UNKNOWN must be preserved as an incompleteness boundary.
           (list :name :nonlinear-integer :logic "QF_NIA"
                 :mcsat nil
                 :configs '(("solver-type" . "dpllt"))))
          (nonlinear?
           (list :name :nonlinear-real :logic "QF_NRA"
                 :mcsat t :configs nil))
          ((and difference? integer?)
           (list :name :integer-difference :logic "QF_IDL"
                 :mcsat nil
                 :configs '(("solver-type" . "dpllt")
                            ("arith-solver" . "ifw")
                            ("arith-fragment" . "IDL"))))
          (difference?
           (list :name :real-difference :logic "QF_RDL"
                 :mcsat nil
                 :configs '(("solver-type" . "dpllt")
                            ("arith-solver" . "rfw")
                            ("arith-fragment" . "RDL"))))
          (integer?
           (list :name :linear-integer :logic "QF_LIA"
                 :mcsat nil
                 :configs '(("solver-type" . "dpllt")
                            ("arith-solver" . "simplex")
                            ("arith-fragment" . "LIA"))))
          (t
           (list :name :linear-real :logic "QF_LRA"
                 :mcsat nil
                 :configs '(("solver-type" . "dpllt")
                            ("arith-solver" . "simplex")
                            ("arith-fragment" . "LRA")))))))

;; --------------------------------------------------------------------
;; Satellite execution

(defun y2shostak-trace-satellite-assertion (satellite source term
                                             &optional (kind "assert"))
  (y2shostak-trace :full satellite "~a: ~a~%    => ~a"
                   kind
                   (if source (y2shostak-display source) "<interface fact>")
                   (y2/term-string term :height 20)))

(defun y2shostak-trace-interfaces (satellite interfaces pairs)
  (let ((shown (remove-if-not #'y2shostak-trace-interface-p interfaces)))
    (y2shostak-trace
     :full satellite
     "interface vocabulary: ~d term~:p (~d generated term~:p elided), ~d candidate pair~:p"
     (length shown) (- (length interfaces) (length shown)) (length pairs))
  (dolist (interface (reverse shown))
    (y2shostak-trace :full satellite "interface~:[~; (boundary)~]: ~a~%    => ~a"
                     (y2shostak-interface-boundary? interface)
                     (y2shostak-display
                      (y2shostak-interface-expr interface))
                     (y2/term-string
                      (y2shostak-interface-term interface) :height 12)))))

(defun y2shostak-call-with-solver (spec thunk)
  (let ((manager nil) (initialized? nil))
    (unwind-protect
         (progn
           (y2/init)
           (setq initialized? t
                 manager
                 (y2/make-manager
                  :default-stack (getf spec :name)
                  :logic (getf spec :logic)
                  :mode "multi-checks"
                  :mcsat (getf spec :mcsat)
                  :configs (getf spec :configs)))
           (y2/%call-with-manager manager thunk))
      (when (and manager (not (y2-manager-closed? manager)))
        (y2/free-manager! manager))
      (when initialized?
        (y2/%release-yices)))))

(defun y2shostak-assert-known-relations (state pairs)
  (dolist (pair pairs)
    (let* ((left (car pair))
           (right (cdr pair))
           (left-expr (y2shostak-interface-expr left))
           (right-expr (y2shostak-interface-expr right))
           (known (or (y2shostak-find-fact state left-expr right-expr)
                      (let ((relation
                              (y2shostak-whiteboard-relation
                               (y2shostak-state-whiteboard state)
                               left-expr right-expr)))
                        (and relation
                             (make-y2shostak-fact
                              relation left-expr right-expr))))))
      (when known
        (let ((term
                (if (eq (y2shostak-fact-relation known) :equal)
                    (y2/= (y2shostak-interface-term left)
                          (y2shostak-interface-term right))
                    (y2//= (y2shostak-interface-term left)
                           (y2shostak-interface-term right)))))
          (y2/assert! term))))))

(defun y2shostak-satellite-consequences (state pairs)
  (let ((facts nil) (split nil))
    (dolist (pair pairs)
      (let* ((left (car pair))
             (right (cdr pair))
             (left-expr (y2shostak-interface-expr left))
             (right-expr (y2shostak-interface-expr right)))
        (unless (or (y2shostak-find-fact state left-expr right-expr)
                    (y2shostak-whiteboard-relation
                     (y2shostak-state-whiteboard state)
                     left-expr right-expr))
          (let ((equality (y2/= (y2shostak-interface-term left)
                                (y2shostak-interface-term right))))
            (let ((not-equal-status
                    (y2/check! :assumptions (list (y2/not equality)))))
              (if (eq not-equal-status :unsat)
                  (push (make-y2shostak-fact
                         :equal left-expr right-expr)
                        facts)
                  (let ((equal-status
                          (y2/check! :assumptions (list equality))))
                    (cond
                      ((eq equal-status :unsat)
                       (push (make-y2shostak-fact
                              :distinct left-expr right-expr)
                             facts))
                      ((and *y2shostak-arrangement-splits*
                            (null split)
                            (or (y2shostak-interface-boundary? left)
                                (y2shostak-interface-boundary? right)))
                       (setq split
                             (make-y2shostak-pair left-expr right-expr))
                       (y2shostak-trace
                        (if *y2shostak-trace-summary-active*
                            :summary :full)
                        :arrangement
                        "undecided boundary pair; propose PVS split: ~a = ~a"
                        (y2shostak-display left-expr)
                        (y2shostak-display right-expr)))
                      (t nil)))))))))
    (values facts split)))

(defun y2shostak-run-arithmetic (state)
  (let* ((entries
           (y2shostak-distinct-entries
            (y2shostak-state-arithmetic state)))
         (spec (y2shostak-arithmetic-spec entries)))
    (setq *y2shostak-last-satellite* (getf spec :name))
    (y2shostak-trace (y2shostak-event-trace-level) (getf spec :name)
                     "start ~a with ~d asserted arithmetic literal~:p and ~d whiteboard literal~:p"
                     (getf spec :logic)
                     (length entries)
                     (length (y2shostak-state-background state)))
    (handler-case
        (y2shostak-call-with-solver
         spec
         #'(lambda ()
             (clear-y2direct)
             (let ((*y2shostak-arithmetic-interfaces* nil)
                   (*y2shostak-canonical-whiteboard*
                     (y2shostak-state-whiteboard state))
                   (*y2shostak-arithmetic-term-cache* nil)
                   (*y2shostak-active-arithmetic-spec* spec))
               (let ((terms
                       (mapcar #'(lambda (entry)
                                   (let ((*y2shostak-canonical-whiteboard*
                                           (or (y2shostak-entry-whiteboard
                                                entry)
                                               *y2shostak-canonical-whiteboard*)))
                                     (y2shostak-arithmetic-term
                                      (y2shostak-entry-source entry))))
                               entries)))
                 (loop for entry in entries
                       for term in terms
                       do (y2shostak-trace-satellite-assertion
                           (getf spec :name)
                           (y2shostak-entry-source entry) term)
                          (y2/assert! term))
                 ;; Only the currently opened frontier is visible here.  This
                 ;; replaces the old recursive mining of every background
                 ;; literal, which eagerly polluted weak arithmetic contexts.
                 (dolist (expr (y2shostak-state-interface-terms state))
                   (when (and (type expr)
                              (ignore-errors
                                (y2direct-arithmetic-type-p (type expr))))
                     (ignore-errors (y2shostak-arithmetic-term expr))))
                 ;; Translate persistent facts before building pairs, so their
                 ;; endpoints join this satellite's interface vocabulary.
                 (dolist (fact (y2shostak-state-facts state))
                   (let ((term
                           (ignore-errors
                             (y2shostak-interface-fact-term
                              fact #'y2shostak-arithmetic-term))))
                     (when term
                       (y2/assert! term))))
                 (let ((pairs
                         (y2shostak-interface-pairs
                          *y2shostak-arithmetic-interfaces*)))
                   (y2shostak-trace-interfaces
                    (getf spec :name)
                    *y2shostak-arithmetic-interfaces* pairs)
                   (y2shostak-assert-known-relations state pairs)
                   (let ((check-status (y2/check!)))
                     (y2shostak-trace (y2shostak-event-trace-level)
                                      (getf spec :name)
                                      "base check => ~a" check-status)
                     (case check-status
                     (:unsat (values :unsat nil nil))
                     (:sat
                     (y2shostak-capture-satellite-model
                       (getf spec :name)
                       *y2shostak-arithmetic-interfaces*)
                      (multiple-value-bind (facts split)
                          (y2shostak-satellite-consequences state pairs)
                        (values :sat facts split)))
                     (otherwise (values :unknown nil nil)))))))))
      (error (condition)
        (setq *y2shostak-last-error* condition)
        (y2shostak-note "Arithmetic satellite ~a failed: ~a"
                        (getf spec :name) condition)
        (values :unknown nil nil)))))

(defvar *y2shostak-bitvector-interfaces*)

(defun y2shostak-record-bitvector-term (expr term &optional boundary?)
  (setq *y2shostak-bitvector-interfaces*
        (y2shostak-note-interface
         expr term boundary? *y2shostak-bitvector-interfaces*))
  term)

(defun y2shostak-bitvector-proxy (expr)
  (y2shostak-record-bitvector-term
   expr (y2direct-global-term expr) t))

(defun y2shostak-bitvector-term-raw (expr)
  (cond ((and (name-expr? expr) (tc-eq expr *true*)) (y2/true))
        ((and (name-expr? expr) (tc-eq expr *false*)) (y2/false))
        ((name-expr? expr)
         (if (and (type expr)
                  (y2direct-bitvector-type-p (type expr)))
             (y2shostak-record-bitvector-term
              expr (y2direct-global-term expr))
             (y2direct-global-term expr)))
        ((typep expr 'application)
         (let* ((head (y2direct-application-head expr))
                (op (and (name-expr? head) (id head)))
                (args (arguments expr)))
           (cond ((negation? expr)
                  (y2/not (y2shostak-bitvector-term (first args))))
                 ((conjunction? expr)
                  (apply #'y2/and
                         (mapcar #'y2shostak-bitvector-term args)))
                 ((disjunction? expr)
                  (apply #'y2/or
                         (mapcar #'y2shostak-bitvector-term args)))
                 ((implication? expr)
                  (y2/=> (y2shostak-bitvector-term (first args))
                         (y2shostak-bitvector-term (second args))))
                 ((iff? expr)
                  (y2/iff (y2shostak-bitvector-term (first args))
                          (y2shostak-bitvector-term (second args))))
                 ((equation? expr)
                  (y2/= (y2shostak-bitvector-term (first args))
                        (y2shostak-bitvector-term (second args))))
                 ((disequation? expr)
                  (y2//= (y2shostak-bitvector-term (first args))
                         (y2shostak-bitvector-term (second args))))
                 ((and (eq op '|nat2bv|)
                       (y2direct-nat2bv-term expr nil)))
                 ((and (eq op '^)
                       (eq (y2direct-module-id head) '|bv_caret|)
                       (y2direct-bv-extract-term expr nil)))
                 ((and (eq op 'sign_extend)
                       (eq (y2direct-module-id head) '|bv_extend|))
                  (let ((terms (mapcar #'y2shostak-bitvector-term args)))
                    (or (y2direct-bv-sign-extend-term expr terms args)
                        (y2shostak-bitvector-proxy expr))))
                 ((or (and (type expr)
                           (y2direct-bitvector-type-p (type expr)))
                      (and args (type (first args))
                           (y2direct-bitvector-type-p
                            (type (first args)))))
                  (let* ((terms (mapcar #'y2shostak-bitvector-term args))
                         (term (y2direct-bitvector-application
                                op terms expr)))
                    (if term
                        (y2shostak-record-bitvector-term expr term)
                        (y2shostak-bitvector-proxy expr))))
                 (t (y2api-err
                     "Non-bitvector formula in bitvector satellite: ~a"
                     expr)))))
        ((and (type expr) (y2direct-bitvector-type-p (type expr)))
         (y2shostak-bitvector-proxy expr))
        (t (y2api-err "Cannot purify bitvector expression ~a" expr))))

(defun y2shostak-bitvector-term (expr)
  "Translate EXPR after Shostak-canonical deduplication of BV value terms."
  (if (and (typep expr 'expr) (type expr)
           (ignore-errors (y2direct-bitvector-type-p (type expr))))
      (let* ((canonical (y2shostak-canonize-interface-expr expr))
             (cached (assoc canonical *y2shostak-bitvector-term-cache*
                            :test #'equal)))
        (if cached
            (y2shostak-record-bitvector-term expr (cdr cached))
            (let ((term (y2shostak-bitvector-term-raw expr)))
              (push (cons canonical term) *y2shostak-bitvector-term-cache*)
              term)))
      (y2shostak-bitvector-term-raw expr)))

(defun y2shostak-run-bitvectors (state)
  (let ((spec (list :name :bitvector-cdclt :logic "QF_UFBV"
                    :mcsat nil
                    :configs '(("solver-type" . "dpllt")))))
    (setq *y2shostak-last-satellite* :bitvector-cdclt)
    (y2shostak-trace (y2shostak-event-trace-level) :bitvector-cdclt
                     "start QF_UFBV with ~d asserted bitvector literal~:p and ~d whiteboard literal~:p"
                     (length (y2shostak-state-bitvectors state))
                     (length (y2shostak-state-background state)))
    (handler-case
        (y2shostak-call-with-solver
         spec
         #'(lambda ()
             (clear-y2direct)
             (let ((*y2shostak-bitvector-interfaces* nil)
                   (*y2shostak-canonical-whiteboard*
                     (y2shostak-state-whiteboard state))
                   (*y2shostak-bitvector-term-cache* nil))
               (let* ((entries
                        (y2shostak-distinct-entries
                         (y2shostak-state-bitvectors state)))
                      (terms
                       (mapcar #'(lambda (entry)
                                   (let ((*y2shostak-canonical-whiteboard*
                                           (or (y2shostak-entry-whiteboard
                                                entry)
                                               *y2shostak-canonical-whiteboard*)))
                                     (y2shostak-bitvector-term
                                      (y2shostak-entry-source entry))))
                               entries)))
                 (dolist (expr (y2shostak-state-interface-terms state))
                   (when (and (type expr)
                              (ignore-errors
                                (y2direct-bitvector-type-p (type expr))))
                     (ignore-errors (y2shostak-bitvector-term expr))))
                 (dolist (fact (y2shostak-state-facts state))
                   (let ((term
                           (ignore-errors
                             (y2shostak-interface-fact-term
                              fact #'y2shostak-bitvector-term))))
                     (when term
                       (y2/assert! term))))
                 (loop for entry in entries
                       for term in terms
                       do (y2shostak-trace-satellite-assertion
                           :bitvector-cdclt
                           (y2shostak-entry-source entry) term)
                          (y2/assert! term))
                 (let ((pairs
                         (y2shostak-interface-pairs
                          *y2shostak-bitvector-interfaces*)))
                   (y2shostak-trace-interfaces
                    :bitvector-cdclt
                    *y2shostak-bitvector-interfaces* pairs)
                   (y2shostak-assert-known-relations state pairs)
                   (let ((check-status (y2/check!)))
                     (y2shostak-trace (y2shostak-event-trace-level)
                                      :bitvector-cdclt
                                      "base check => ~a" check-status)
                     (case check-status
                     (:unsat (values :unsat nil nil))
                     (:sat
                      (y2shostak-capture-satellite-model
                       :bitvector-cdclt
                       *y2shostak-bitvector-interfaces*)
                      (multiple-value-bind (facts split)
                          (y2shostak-satellite-consequences state pairs)
                        (values :sat facts split)))
                     (otherwise (values :unknown nil nil)))))))))
      (error (condition)
        (setq *y2shostak-last-error* condition)
        (y2shostak-note "Bitvector satellite failed: ~a" condition)
        (values :unknown nil nil)))))

(defun y2shostak-run-satellites-once (state)
  (let ((all-facts nil) (split nil) (unknown? nil))
    (flet ((run (function)
             (multiple-value-bind (status facts candidate)
                 (funcall function state)
               (case status
                 (:unsat (return-from y2shostak-run-satellites-once
                           (values :unsat nil nil)))
                 (:unknown (setq unknown? t)))
               (setq all-facts (nconc facts all-facts))
               (unless split (setq split candidate)))))
      (when (y2shostak-state-arithmetic state)
        (run #'y2shostak-run-arithmetic))
      (when (or (y2shostak-state-bitvectors state)
                (some #'(lambda (term)
                          (and (type term)
                               (ignore-errors
                                 (y2direct-bitvector-type-p (type term)))))
                      (y2shostak-state-interface-terms state)))
        (run #'y2shostak-run-bitvectors)))
    (values (if unknown? :unknown :sat) all-facts split)))

(defun y2shostak-orchestrate (state)
  (loop with current = state
        for round from 0 below *y2shostak-max-rounds*
        do (y2shostak-trace (y2shostak-event-trace-level) :orchestrator
                            "round ~d at whiteboard generation ~d"
                            round (y2shostak-state-generation current))
           (multiple-value-bind (status facts split)
               (y2shostak-run-satellites-once current)
             (y2shostak-trace (y2shostak-event-trace-level) :orchestrator
                              "round ~d => ~a" round status)
             (when (eq status :unsat)
               (y2shostak-trace :summary :orchestrator
                                "satellite conflict closes the branch")
               (return (values :unsat current nil)))
             (let ((changed? nil))
               (dolist (fact facts)
                 (multiple-value-bind (next added? conflict?)
                     (y2shostak-add-fact current fact)
                   (when conflict?
                     (return-from y2shostak-orchestrate
                       (values :unsat current nil)))
                   (setq current next
                         changed? (or changed? added?))))
               (unless changed?
                 (y2shostak-trace (y2shostak-event-trace-level) :orchestrator
                                  "fixed point after round ~d" round)
                 (return
                   (values status current
                           (and (eq status :sat) split))))))
        finally
           (y2shostak-trace (y2shostak-event-trace-level) :orchestrator
                            "round limit ~d reached; returning UNKNOWN"
                            *y2shostak-max-rounds*)
           (return (values :unknown current nil))))

(defun y2shostak-satellite-needed-p (state)
  (or (y2shostak-state-arithmetic state)
      (y2shostak-state-bitvectors state)
      (some #'(lambda (term)
                (and (type term)
                     (ignore-errors
                       (y2direct-bitvector-type-p (type term)))))
            (y2shostak-state-interface-terms state))))

(defun y2shostak-orchestrate-if-needed (state)
  (if (y2shostak-satellite-needed-p state)
      (y2shostak-orchestrate state)
      (values :sat state nil)))

(defun y2shostak-ingest-constraint (state source)
  "Canonize SOURCE, then add it to the whiteboard and routed constraints.

This is the only insertion path used by the demand-driven type-predicate
loop.  In particular, a constraint that canonizes to TRUE never reaches a
Yices context, and canonically duplicate routed constraints share one entry."
  (let* ((old-whiteboard (y2shostak-state-whiteboard state))
         (canonical (y2shostak-canonical-form source old-whiteboard)))
    (multiple-value-bind (result new-whiteboard)
        (y2shostak-whiteboard-process source old-whiteboard)
      (cond ((false-p result)
             (values :unsat state))
            ((true-p result)
             (values :entailed
                     (y2shostak-remove-deferred-typepred state source)))
            (t
             (let ((current state))
               (when (y2shostak-whiteboard-changed-p
                      old-whiteboard new-whiteboard)
                 (setq current (y2shostak-copy current t))
                 (setf (y2shostak-state-whiteboard current) new-whiteboard))
               (setq current (y2shostak-add-background current source))
               (let ((entry (y2shostak-classify-entry
                             source canonical old-whiteboard)))
                 (when entry
                   (y2shostak-trace
                    :full :router "canonized demand constraint -> ~a"
                    (y2shostak-entry-description entry))
                   (setq current (y2shostak-add-entry current entry))))
               (setq current
                     (y2shostak-remove-deferred-typepred current source))
               (values :added current)))))))

(defun y2shostak-frontier-typepreds (frontier)
  (delete-duplicates
   (loop for term in frontier
         nconc (copy-list (y2shostak-term-typepreds term)))
   :test #'tc-eq))

(defun y2shostak-next-frontier (frontier seen)
  (let ((next nil))
    (dolist (term frontier)
      (dolist (subterm (y2shostak-immediate-subterms term))
        (unless (or (find subterm seen :test #'tc-eq)
                    (find subterm frontier :test #'tc-eq)
                    (find subterm next :test #'tc-eq))
          (setq next (append next (list subterm))))))
    next))

(defun y2shostak-bounded-orchestrate (state)
  "Try the base constraints, then open type-predicate frontiers on demand."
  (multiple-value-bind (base-status base-state base-split)
      (y2shostak-orchestrate-if-needed state)
    (when (eq base-status :unsat)
      (return-from y2shostak-bounded-orchestrate
        (values :unsat base-state nil)))
    (let ((current base-state)
          (status base-status)
          (split base-split)
          (frontier (copy-list (y2shostak-state-roots base-state)))
          (seen nil))
      (loop for depth from 0 below *y2shostak-max-typepred-depth*
            while frontier
            do (setq current
                     (y2shostak-add-interface-terms current frontier))
               (let ((predicates (y2shostak-frontier-typepreds frontier)))
                 (y2shostak-trace
                  (y2shostak-event-trace-level) :typepred
                  "frontier ~d: ~d term~:p, ~d type predicate~:p"
                  depth (length frontier) (length predicates))
                 (dolist (predicate predicates)
                   (multiple-value-bind (ingest-status next)
                       (y2shostak-ingest-constraint current predicate)
                     (setq current next)
                     (when (eq ingest-status :unsat)
                       (y2shostak-trace
                        :summary :typepred
                        "frontier ~d contradicts the whiteboard" depth)
                       (return-from y2shostak-bounded-orchestrate
                         (values :unsat current nil))))))
               (multiple-value-bind (next-status next next-split)
                   (y2shostak-orchestrate-if-needed current)
                 (setq current next
                       status next-status
                       split (or split next-split))
                 (when (eq status :unsat)
                   (y2shostak-trace
                    :summary :typepred
                    "frontier ~d closes the branch" depth)
                   (return-from y2shostak-bounded-orchestrate
                     (values :unsat current nil))))
               (setq seen (y2shostak-pushnew-exprs frontier seen)
                     frontier (y2shostak-next-frontier frontier seen))
            finally
               (when frontier
                 (y2shostak-trace
                  (y2shostak-event-trace-level) :typepred
                  "frontier bound ~d reached with deeper subterms deferred"
                  *y2shostak-max-typepred-depth*)))
      (values status current (and (eq status :sat) split)))))

(defun y2shostak-compound-satellite-formula-p (source)
  (let ((body (y2shostak-strip-negation source)))
    (and (typep body 'application)
         (or (conjunction? body) (disjunction? body)
             (implication? body) (iff? body))
         (or (y2shostak-arithmetic-formula-p source)
             (y2shostak-bitvector-formula-p source)))))

(defun y2shostak-query-entailed-p (state source)
  "Test a compound formula in a disposable, canonized satellite state."
  (when (y2shostak-compound-satellite-formula-p source)
    (let ((probe (y2shostak-add-root-terms
                  (y2shostak-copy state) source)))
      (multiple-value-bind (ingest-status next)
          (y2shostak-ingest-constraint probe (negate source))
        (cond ((eq ingest-status :unsat) t)
              ((eq ingest-status :entailed) nil)
              (t
               (multiple-value-bind (status ignored split)
                   (y2shostak-bounded-orchestrate next)
                 (declare (ignore ignored split))
                 (eq status :unsat))))))))

;; --------------------------------------------------------------------
;; DPI processing

(defun y2shostak-process (source state)
  (let* ((state (y2shostak-state-or-empty state))
         (old-whiteboard (y2shostak-state-whiteboard state))
         ;; Classify the literal before writing it on the whiteboard. After
         ;; insertion, contextual canonization quite correctly reduces it to
         ;; TRUE, which no longer exposes its arithmetic fragment.
         (input-canonical
           (y2shostak-canonical-form source old-whiteboard)))
    (y2shostak-update-summary state)
    ;; ASSERT eagerly submits type predicates after each formula.  Remember
    ;; them, but let the bounded loop decide when their term frontier opens.
    (when (y2shostak-derived-typepred-p source)
      (let ((next (y2shostak-add-deferred-typepred state source)))
        (y2shostak-trace :full :typepred "defer eager predicate: ~a"
                         (y2shostak-display source))
        (y2shostak-update-summary next)
        (return-from y2shostak-process (values nil next))))
    ;; ASSERT normally tests an expression for truth before deciding whether
    ;; to retain it.  Compound arithmetic formulas need an explicit
    ;; refutation query because the whiteboard alone only absorbs them.
    (when (y2shostak-query-entailed-p state source)
      (setq *y2shostak-last-status* :satellite-entailed)
      (y2shostak-trace :summary :orchestrator
                       "canonized refutation closes the compound formula")
      (return-from y2shostak-process (values *true* state)))
    (y2shostak-trace :full :whiteboard
                     "process input at generation ~d: ~a"
                     (y2shostak-state-generation state)
                     (y2shostak-display source))
    (y2shostak-trace :full :whiteboard "canonical input: ~a"
                     (y2shostak-display input-canonical))
    (multiple-value-bind (base-result new-whiteboard)
        (y2shostak-whiteboard-process source old-whiteboard)
      (y2shostak-trace :full :whiteboard
                       "baseline result: ~a; state changed: ~:[no~;yes~]"
                       (y2shostak-display base-result)
                       (y2shostak-whiteboard-changed-p
                        old-whiteboard new-whiteboard))
      (when (false-p base-result)
        (setq *y2shostak-last-status* :whiteboard-unsat)
        (y2shostak-trace :summary :whiteboard
                         "baseline contradiction closes the branch")
        (return-from y2shostak-process (values *false* state)))
      (when (true-p base-result)
        (setq *y2shostak-last-status* :whiteboard-entailed)
        (y2shostak-trace :full :whiteboard
                         "input already entailed by the baseline whiteboard")
        (return-from y2shostak-process (values *true* state)))
      (let ((current state))
        (when (y2shostak-whiteboard-changed-p
               old-whiteboard new-whiteboard)
          (setq current (y2shostak-copy current t))
          (setf (y2shostak-state-whiteboard current) new-whiteboard))
        (when (typep source 'expr)
          (setq current (y2shostak-add-background current source)
                current (y2shostak-add-root-terms current source)))
        ;; Equality branches generated by this orchestrator are old-prover
        ;; terms. Recover their typed interface endpoints here.
        (let ((pending (and (not (typep source 'expr))
                            (y2shostak-pending-fact current source))))
          (when pending
            (y2shostak-trace :summary :arrangement
                             "consume PVS arrangement branch: ~a"
                             (y2shostak-fact-string pending))
            (multiple-value-bind (next added? conflict?)
                (y2shostak-add-fact current pending)
              (declare (ignore added?))
              (when conflict?
                (return-from y2shostak-process
                  (values *false* current)))
              (setq current next))))
        (let* ((entry (and (typep source 'expr)
                           (y2shostak-classify-entry
                            source input-canonical old-whiteboard)))
               ;; Skolemized user obligations retain PVS's ! suffix. The
               ;; auxiliary arithmetic constraints generated from Prelude
               ;; schemas generally do not. This affects compact trace noise
               ;; only; full tracing and solver semantics are unchanged.
               (interesting? (and entry
                                  (search "!" (y2shostak-display source)))))
          (if entry
              (y2shostak-trace (if interesting? :summary :full)
                               :router "route ~a -> ~a"
                               (y2shostak-display source)
                               (y2shostak-entry-description entry))
              (y2shostak-trace :full :router "route: ~a"
                               (y2shostak-entry-description entry)))
          (when entry
            (setq current (y2shostak-add-entry current entry)))
          (if (y2shostak-satellite-needed-p current)
              (multiple-value-bind (status next split)
                  (let ((*y2shostak-trace-summary-active* interesting?))
                    (y2shostak-bounded-orchestrate current))
                (setq *y2shostak-last-status* status
                      current next)
                (y2shostak-update-summary current)
                (y2shostak-trace (if interesting? :summary :full)
                                 :orchestrator
                                 "return ~a at generation ~d"
                                 status
                                 (y2shostak-state-generation current))
                (case status
                  (:unsat (values *false* current))
                  (:sat
                   (cond (split
                         (setq current
                                (y2shostak-add-pending current split))
                          (y2shostak-trace
                           (if (and interesting?
                                    (y2shostak-trace-expression-p
                                     (y2shostak-pair-left split))
                                    (y2shostak-trace-expression-p
                                     (y2shostak-pair-right split)))
                               :summary :full)
                           :arrangement
                           "emit PVS equality split: ~a = ~a"
                           (y2shostak-display (y2shostak-pair-left split))
                           (y2shostak-display (y2shostak-pair-right split)))
                          (values (list (y2shostak-pair-split-form split))
                                  current))
                         (entry (values nil current))
                         (t (values base-result current))))
                  (otherwise
                   ;; UNKNOWN is never converted to success. Baseline Shostak
                   ;; retains the literal or absorbs what it can prove.
                   (values base-result current))))
              (progn
                (y2shostak-update-summary current)
                (y2shostak-trace :full :router
                                 "no specialized satellite required")
                (values base-result current))))))))

(defun y2shostak-valid (state source)
  (multiple-value-bind (result ignored)
      (y2shostak-process source (y2shostak-copy state))
    (declare (ignore ignored))
    (cond ((true-p result) *true*)
          ((false-p result) *false*)
          (t nil))))

;; --------------------------------------------------------------------
;; Registration and decision-procedure-interface methods

(defun register-y2shostak-decision-procedure ()
  (pushnew 'y2shostak *decision-procedures*)
  (let ((entry (assoc 'y2shostak *decision-procedure-descriptions*)))
    (if entry
        (setf (cdr entry) "Shostak whiteboard with Yices2 satellites")
        (push (cons 'y2shostak
                    "Shostak whiteboard with Yices2 satellites")
              *decision-procedure-descriptions*)))
  'y2shostak)

(register-y2shostak-decision-procedure)

(defmethod dpi-init* ((dp (eql 'y2shostak)))
  (declare (ignore dp))
  ;; Keep Yices lazy: loading PVS must not require a local Yices installation.
  t)

(defmethod dpi-start* ((dp (eql 'y2shostak)) (prove-body function))
  (declare (ignore dp))
  (ensure-y2direct-implementation)
  (setq *y2shostak-last-status* nil
        *y2shostak-last-error* nil
        *y2shostak-last-satellite* nil
        *y2shostak-last-model* nil
        *y2shostak-last-summary* nil)
  (let* ((*translate-id-counter* nil)
         (*translate-id-hash* (init-if-rec *translate-id-hash*))
         (*translate-to-prove-hash* (init-if-rec *translate-to-prove-hash*))
         (typealist primtypealist)
         (*subtype-names* nil)
         (*named-exprs* nil)
         (*rec-type-dummies* nil)
         (*local-typealist* *local-typealist*)
         (applysymlist nil)
         (sigalist sigalist)
         (usealist usealist)
         (findalist findalist))
    (initprover)
    (newcounter *translate-id-counter*)
    (funcall prove-body)))

(defmethod dpi-end* ((dp (eql 'y2shostak)) proofstate)
  (declare (ignore dp proofstate)))

(defmethod dpi-handles-connectives?* ((dp (eql 'y2shostak)))
  (declare (ignore dp))
  (not *y2shostak-generating-typepreds*))

(defmethod dpi-empty-state* ((dp (eql 'y2shostak)))
  (declare (ignore dp))
  (make-y2shostak-state :whiteboard (y2shostak-empty-whiteboard)))

(defmethod dpi-process* ((dp (eql 'y2shostak)) source state)
  (declare (ignore dp))
  (y2shostak-process source state))

(defmethod dpi-valid?* ((dp (eql 'y2shostak)) state source)
  (declare (ignore dp))
  (y2shostak-valid state source))

(defmethod dpi-push-state* ((dp (eql 'y2shostak)) state)
  (declare (ignore dp))
  (y2shostak-copy state))

(defmethod dpi-pop-state* ((dp (eql 'y2shostak)) state)
  (declare (ignore dp)) state)

(defmethod dpi-copy-state* ((dp (eql 'y2shostak)) state)
  (declare (ignore dp))
  (y2shostak-copy state))

(defmethod dpi-restore-state* ((dp (eql 'y2shostak)) state)
  (declare (ignore dp)) state)

(defmethod dpi-state-changed?* ((dp (eql 'y2shostak)) old-state new-state)
  (declare (ignore dp))
  (/= (y2shostak-state-generation (y2shostak-state-or-empty old-state))
      (y2shostak-state-generation (y2shostak-state-or-empty new-state))))

(defmethod dpi-disjunction?* ((dp (eql 'y2shostak)) term)
  (declare (ignore dp))
  (and (consp term) (eq (car term) 'or)))

(defmethod dpi-proposition?* ((dp (eql 'y2shostak)) term)
  (declare (ignore dp))
  (and (consp term)
       (memq (car term) '(if if* implies not and iff))))

(defmethod dpi-term-arguments* ((dp (eql 'y2shostak)) term)
  (declare (ignore dp))
  (when (consp term) (cdr term)))

(defmethod dpi-canon* ((dp (eql 'y2shostak)) term state)
  (declare (ignore dp))
  (y2shostak-canonical-form
   term (y2shostak-state-whiteboard (y2shostak-state-or-empty state))))

;; --------------------------------------------------------------------
;; Read-only prover diagnostics

(defun y2shostak-dump-state-value (&optional state)
  "Resolve STATE for a diagnostic dump without creating or changing one."
  (cond ((y2shostak-state-p state) state)
        ((typep state 'proofstate)
         (let ((dp-state (dp-state state)))
           (if (y2shostak-state-p dp-state)
               dp-state
               (error "The proof state does not contain a Y2SHOSTAK state."))))
        ((and (null state)
              (boundp '*dp-state*)
              (y2shostak-state-p *dp-state*))
         *dp-state*)
        (t
         (error "No current Y2SHOSTAK state. Pass a state explicitly or use (y2shostak-dump) inside the prover."))))

(defun y2shostak-dump-count (object)
  (handler-case
      (length object)
    (error () :unknown)))

(defun y2shostak-dump-bound-value (symbol &optional (otherwise :unavailable))
  (if (boundp symbol) (symbol-value symbol) otherwise))

(defun y2shostak-state-dump-string (&optional state)
  "Return a complete, read-only textual dump of a Y2SHOSTAK STATE.

When STATE is omitted, use the dynamically current `*DP-STATE*'.  STATE may
also be a PROOFSTATE.  The dump includes asserted constraints, routed entries,
exchanged facts, demand frontiers, the raw Shostak DPINFO alists, and current
and last-used solver information.  No Yices context is created by this
function."
  (let* ((state (y2shostak-dump-state-value state))
         (whiteboard (y2shostak-state-whiteboard state))
         (arithmetic
           (y2shostak-distinct-entries
            (y2shostak-state-arithmetic state)))
         (bitvectors
           (y2shostak-distinct-entries
            (y2shostak-state-bitvectors state))))
    (with-output-to-string (stream)
      (let ((*print-circle* t)
            (*print-pretty* t)
            (*print-level* nil)
            (*print-length* nil)
            (*print-right-margin* 100))
        (labels
            ((dump-expressions (title expressions)
               (format stream "~%~a (~d)~%" title (length expressions))
               (if expressions
                   (loop for expression in expressions
                         for index from 0
                         do (format stream "  [~d] ~a~%" index
                                    (y2shostak-display expression)))
                   (format stream "  <none>~%")))
             (dump-entries (title entries)
               (format stream "~%~a (~d)~%" title (length entries))
               (if entries
                   (loop for entry in entries
                         for index from 0
                         do (format stream "  [~d] ~a~%      source: ~a~%      canonical: ~s~%"
                                    index
                                    (y2shostak-entry-description entry)
                                    (y2shostak-display
                                     (y2shostak-entry-source entry))
                                    (y2shostak-entry-canonical entry)))
                   (format stream "  <none>~%")))
             (dump-facts (facts)
               (format stream "~%EXCHANGED SHOSTAK FACTS (~d)~%"
                       (length facts))
               (if facts
                   (loop for fact in facts
                         for index from 0
                         do (format stream "  [~d] ~a~%" index
                                    (y2shostak-fact-string fact)))
                   (format stream "  <none>~%")))
             (dump-pending (pairs)
               (format stream "~%PENDING ARRANGEMENTS (~d)~%"
                       (length pairs))
               (if pairs
                   (loop for pair in pairs
                         for index from 0
                         do (format stream "  [~d] ~a = ~a~%" index
                                    (y2shostak-display
                                     (y2shostak-pair-left pair))
                                    (y2shostak-display
                                     (y2shostak-pair-right pair))))
                   (format stream "  <none>~%")))
             (dump-raw (title object)
               (format stream "~%  ~a (~a)~%"
                       title (y2shostak-dump-count object))
               (if object
                   (progn (write object :stream stream :pretty t :escape t)
                          (terpri stream))
                   (format stream "    <none>~%")))
             (dump-spec (title spec)
               (format stream "  ~a: ~a; logic ~a; MCSAT ~:[no~;yes~]"
                       title (getf spec :name) (getf spec :logic)
                       (getf spec :mcsat))
               (when (getf spec :configs)
                 (format stream "; configuration ~s" (getf spec :configs)))
               (terpri stream)))
          (format stream "Y2SHOSTAK STATE DUMP~%====================~%")
          (format stream "generation: ~d~%" (y2shostak-state-generation state))
          (format stream "decision procedure: ~a~%"
                  (y2shostak-dump-bound-value
                   '*current-decision-procedure*))
          (format stream "limits: ~d type-predicate frontiers; ~d exchange rounds~%"
                  *y2shostak-max-typepred-depth* *y2shostak-max-rounds*)
          (format stream "arrangement splitting: ~:[disabled~;enabled~]~%"
                  *y2shostak-arrangement-splits*)

          (format stream "~%SOLVER INFORMATION~%")
          (format stream "  Yices version: ~a; architecture: ~a; mode: ~a; MCSAT available: ~a~%"
                  (y2shostak-dump-bound-value '+y2api/version-string+)
                  (y2shostak-dump-bound-value '+y2api/build-arch+)
                  (y2shostak-dump-bound-value '+y2api/build-mode+)
                  (y2shostak-dump-bound-value '+y2api/mcsat-enabled?+))
          (format stream "  persistent Yices context: none (contexts are rebuilt per query)~%")
          (format stream "  last status: ~a~%"
                  (or *y2shostak-last-status* :none))
          (format stream "  last satellite: ~a~%"
                  (or *y2shostak-last-satellite* :none))
          (when arithmetic
            (dump-spec "current arithmetic route"
                       (y2shostak-arithmetic-spec arithmetic)))
          (when bitvectors
            (dump-spec "current bitvector route"
                       (list :name :bitvector-cdclt :logic "QF_UFBV"
                             :mcsat nil
                             :configs '(("solver-type" . "dpllt")))))
          (format stream "  last error: ~a~%"
                  (or *y2shostak-last-error* :none))
          (format stream "  last model projection:~%    ~a~%"
                  (or *y2shostak-last-model* :none))

          (dump-expressions "ASSERTED BACKGROUND CONSTRAINTS"
                            (y2shostak-state-background state))
          (dump-entries "ROUTED ARITHMETIC CONSTRAINTS" arithmetic)
          (dump-entries "ROUTED BITVECTOR CONSTRAINTS" bitvectors)
          (dump-facts (y2shostak-state-facts state))
          (dump-pending (y2shostak-state-pending state))
          (dump-expressions "ROOT TERMS"
                            (y2shostak-state-roots state))
          (dump-expressions "ACTIVE INTERFACE TERMS"
                            (y2shostak-state-interface-terms state))
          (dump-expressions "DEFERRED TYPE PREDICATES"
                            (y2shostak-state-deferred-typepreds state))

          (format stream "~%SHOSTAK WHITEBOARD (DPINFO)~%")
          (dump-raw "SIGALIST" (dpinfo-sigalist whiteboard))
          (dump-raw "FINDALIST" (dpinfo-findalist whiteboard))
          (dump-raw "USEALIST" (dpinfo-usealist whiteboard)))))))

(defun y2shostak-dump-state (&optional state (stream *standard-output*))
  "Print a complete read-only dump of the current Y2SHOSTAK state.

STATE and STREAM are optional.  With no STATE, this uses `*DP-STATE*'.  The
function returns no values, which keeps an interactive Lisp invocation from
printing the dump a second time."
  (write-string (y2shostak-state-dump-string state) stream)
  (terpri stream)
  (finish-output stream)
  (values))

(defun y2shostak-set-trace-rule (level)
  #'(lambda (proofstate)
      (declare (ignore proofstate))
      (set-y2shostak-trace level)
      (values 'X nil nil)))

(addrule 'y2shostak-trace nil nil
  (y2shostak-set-trace-rule :summary)
  "Enables compact Y2SHOSTAK tracing: routing, satellite selection, type-predicate frontiers, round results, conflicts, and arrangements. The proof state is unchanged.")

(addrule 'y2shostak-trace$ nil nil
  (y2shostak-set-trace-rule :full)
  "Enables white-box Y2SHOSTAK tracing. In addition to compact events, prints whiteboard inputs and canonical forms, purified satellite assertions, and interface vocabularies. The proof state is unchanged.")

(addrule 'y2shostak-untrace nil nil
  (y2shostak-set-trace-rule :off)
  "Disables Y2SHOSTAK tracing without changing the proof state.")

(defun y2shostak-report-rule (kind)
  #'(lambda (proofstate)
      (ecase kind
        (:status (y2shostak-show-last-status))
        (:model (y2shostak-show-last-model))
        (:dump
         (format-if "~%~a"
                    (y2shostak-state-dump-string
                     (dp-state proofstate))))
        (:counterexample
         (y2shostak-show-last-counterexample proofstate)))
      ;; The report is observational: preserve the current proof state just as
      ;; SKIP does, so the user can continue simplifying or proving it.
      (values 'X nil nil)))

(addrule 'y2shostak-status nil nil
  (y2shostak-report-rule :status)
  "Reports the last Y2SHOSTAK whiteboard/satellite status without changing the proof state.")

(addrule 'y2shostak-model nil nil
  (y2shostak-report-rule :model)
  "Prints the most recent satisfiable satellite model projection. This is diagnostic, not a complete model of whiteboard-only atoms.")

(addrule 'y2shostak-dump nil nil
  (y2shostak-report-rule :dump)
  "Prints the complete current Y2SHOSTAK state, including asserted constraints, routed entries, exchanged facts, demand frontiers, solver diagnostics, and raw Shostak whiteboard alists. The proof state is unchanged.")

(addrule 'y2shostak-counterexample nil nil
  (y2shostak-report-rule :counterexample)
  "Prints the residual PVS sequent as the authoritative counterexample obligation, followed by the most recent satellite model projection.")
