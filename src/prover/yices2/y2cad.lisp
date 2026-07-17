;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2cad.lisp -- Linear/monomial lifting with an exact Yices MCSAT controller.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2026, SRI International. All Rights Reserved.
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the 3-Clause BSD License.
;; --------------------------------------------------------------------

(in-package :pvs)

;; Y2CAD is deliberately not a quantifier-elimination procedure. ASSERT first
;; skolemizes and propositionally decomposes a goal; this decision procedure
;; accepts the resulting conjunction of ground polynomial literals. This is
;; exactly the existential QF_NRA boundary implemented by Yices MCSAT.
;;
;; For every expanded monomial m it creates a real variable z_m. A QF_LRA
;; satellite receives only the lifted linear constraints and z_0 = 1. Its
;; UNSAT answer is conclusive, while SAT is only a relaxation. The exact
;; controller receives the same lifted constraints plus
;;
;;   z_0 = 1,  z_ei = x_i,  z_(a+b) = z_a * z_b.
;;
;; That conjunction is equisatisfiable with the original polynomial problem.
;; MCSAT therefore remains the exact real-algebraic authority; the purpose of
;; this file is orchestration and observability, not an unsupported claim that
;; monomial lifting eliminates real algebraic compatibility.

(defparameter *y2cad-max-expanded-terms* 4096
  "Maximum terms in one expanded polynomial. Larger inputs are left to PVS.")

(defparameter *y2cad-trace-level* nil
  "Y2CAD trace mode: NIL, :SUMMARY, or :FULL.")

(defvar *y2cad-last-status* nil)
(defvar *y2cad-last-error* nil)
(defvar *y2cad-last-model* nil)
(defvar *y2cad-last-summary* nil)

(defstruct (y2cad-constraint
            (:constructor make-y2cad-constraint (source relation polynomial)))
  source
  relation
  polynomial)

(defstruct (y2cad-state
            (:constructor make-y2cad-state
                (&key whiteboard constraints (generation 0)
                      (constraint-generation 0)
                      (linear-generation -1) linear-status
                      (exact-generation -1) exact-status
                      (controller-calls 0))))
  whiteboard
  (constraints nil :type list)
  (generation 0 :type fixnum)
  (constraint-generation 0 :type fixnum)
  (linear-generation -1 :type fixnum)
  linear-status
  (exact-generation -1 :type fixnum)
  exact-status
  (controller-calls 0 :type fixnum))

(defvar *y2cad-force-exact* nil
  "Dynamically true for DPI validity queries, which are closure checkpoints.")

(defvar *y2cad-controller-policy* :demand
  "Exact-controller scheduling policy. :DEMAND is normal Y2CAD behavior;
:DEFER lets a higher-level portfolio own compatibility checkpoints.")

;; --------------------------------------------------------------------
;; Diagnostics

(defun y2cad-trace-rank ()
  (case *y2cad-trace-level*
    ((:full :white-box) 2)
    ((t :summary :compact) 1)
    (otherwise 0)))

(defun y2cad-tracing-p (&optional (level :summary))
  (>= (y2cad-trace-rank) (if (member level '(:full :white-box)) 2 1)))

(defun y2cad-trace (level component control &rest arguments)
  (when (y2cad-tracing-p level)
    (let ((message (format nil "~%[Y2CAD/~a] ~a"
                           component (apply #'format nil control arguments))))
      (or (and (fboundp 'session-output) (session-output message))
          (format t "~a" message)))))

(defun set-y2cad-trace (level)
  (setq *y2cad-trace-level*
        (case level
          ((nil :off) nil)
          ((t :summary :compact) :summary)
          ((:full :white-box) :full)
          (otherwise
           (error "Y2CAD trace level must be NIL, :SUMMARY, or :FULL"))))
  (format-if "~%Y2CAD tracing is ~a" (or *y2cad-trace-level* :off))
  *y2cad-trace-level*)

(defun y2cad-display (object)
  (if (typep object 'expr)
      (y2direct-pvs-string object)
      (princ-to-string object)))

(defun y2cad-monomial-string (monomial)
  (if (null monomial)
      "1"
      (format nil "~{~a~^ * ~}" (mapcar #'y2cad-display monomial))))

(defun y2cad-status-string ()
  (with-output-to-string (stream)
    (format stream "Y2CAD status: ~a" (or *y2cad-last-status* :none))
    (when *y2cad-last-summary*
      (format stream "~%  ~a" *y2cad-last-summary*))
    (when *y2cad-last-error*
      (format stream "~%  last error: ~a" *y2cad-last-error*))))

(defun y2cad-show (text)
  (or (and (fboundp 'session-output) (session-output (format nil "~%~a~%" text)))
      (format t "~%~a~%" text))
  text)

;; --------------------------------------------------------------------
;; Sparse expanded polynomials
;;
;; A polynomial is an alist (MONOMIAL . RATIONAL). A monomial is a sorted
;; list of typed PVS atoms, with repetitions encoding powers. TC-EQ is used
;; instead of printed names, so two scoped terms cannot alias accidentally.

(defun y2cad-monomial-equal-p (left right)
  (and (= (length left) (length right))
       (every #'tc-eq left right)))

(defun y2cad-term-less-p (left right)
  (string< (y2cad-display left) (y2cad-display right)))

(defun y2cad-sort-monomial (factors)
  (stable-sort (copy-list factors) #'y2cad-term-less-p))

(defun y2cad-poly-entry (monomial polynomial)
  (find monomial polynomial :key #'car :test #'y2cad-monomial-equal-p))

(defun y2cad-poly-add-coefficient (polynomial monomial coefficient)
  (let ((entry (y2cad-poly-entry monomial polynomial)))
    (cond (entry
           (incf (cdr entry) coefficient)
           (if (zerop (cdr entry)) (delete entry polynomial :test #'eq)
               polynomial))
          ((zerop coefficient) polynomial)
          (t (acons monomial coefficient polynomial)))))

(defun y2cad-poly-constant (number)
  (if (zerop number) nil (list (cons nil number))))

(defun y2cad-poly-atom (expr)
  (list (cons (list expr) 1)))

(defun y2cad-poly-scale (polynomial factor)
  (loop for (monomial . coefficient) in polynomial
        for scaled = (* coefficient factor)
        unless (zerop scaled) collect (cons monomial scaled)))

(defun y2cad-poly-add (left right)
  (let ((sum (copy-tree left)))
    (dolist (entry right sum)
      (setq sum (y2cad-poly-add-coefficient
                 sum (car entry) (cdr entry))))))

(defun y2cad-poly-subtract (left right)
  (y2cad-poly-add left (y2cad-poly-scale right -1)))

(defun y2cad-check-size (polynomial)
  (when (> (length polynomial) *y2cad-max-expanded-terms*)
    (error "expanded polynomial exceeds ~d terms"
           *y2cad-max-expanded-terms*))
  polynomial)

(defun y2cad-poly-multiply (left right)
  (let ((product nil))
    (dolist (lentry left (y2cad-check-size product))
      (dolist (rentry right)
        (setq product
              (y2cad-poly-add-coefficient
               product
               (y2cad-sort-monomial
                (append (car lentry) (car rentry)))
               (* (cdr lentry) (cdr rentry))))))))

(defun y2cad-poly-power (polynomial exponent)
  (let ((result (y2cad-poly-constant 1))
        (factor polynomial)
        (power exponent))
    (loop while (plusp power)
          do (when (oddp power)
               (setq result (y2cad-poly-multiply result factor)))
             (setq power (ash power -1))
             (when (plusp power)
               (setq factor (y2cad-poly-multiply factor factor))))
    result))

(defun y2cad-number-value (expr)
  (when (and (typep expr 'expr) (rational-expr? expr))
    (let ((value (number expr)))
      (and (rationalp value) value))))

(defun y2cad-arithmetic-atom-p (expr)
  (and (typep expr 'expr)
       (type expr)
       (ignore-errors (y2direct-arithmetic-type-p (type expr)))))

(defun y2cad-polynomial (expr)
  "Return an expanded polynomial and success flag for a ground real term."
  (let ((number (y2cad-number-value expr)))
    (cond (number (values (y2cad-poly-constant number) t))
          ((name-expr? expr) (values (y2cad-poly-atom expr) t))
          ((typep expr 'application)
           (let* ((head (y2direct-application-head expr))
                  (op (and (name-expr? head) (id head)))
                  (args (arguments expr)))
             (case op
               (+
                (let ((sum nil))
                  (dolist (arg args (values sum t))
                    (multiple-value-bind (poly ok) (y2cad-polynomial arg)
                      (unless ok
                        (return-from y2cad-polynomial (values nil nil)))
                      (setq sum (y2cad-poly-add sum poly))))))
               (-
                (cond ((= (length args) 1)
                       (multiple-value-bind (poly ok)
                           (y2cad-polynomial (first args))
                         (values (and ok (y2cad-poly-scale poly -1)) ok)))
                      ((plusp (length args))
                       (multiple-value-bind (result ok)
                           (y2cad-polynomial (first args))
                         (unless ok
                           (return-from y2cad-polynomial (values nil nil)))
                         (dolist (arg (rest args) (values result t))
                           (multiple-value-bind (poly arg-ok)
                               (y2cad-polynomial arg)
                             (unless arg-ok
                               (return-from y2cad-polynomial
                                 (values nil nil)))
                             (setq result
                                   (y2cad-poly-subtract result poly))))))
                      (t (values nil nil))))
               (*
                (let ((product (y2cad-poly-constant 1)))
                  (dolist (arg args (values product t))
                    (multiple-value-bind (poly ok) (y2cad-polynomial arg)
                      (unless ok
                        (return-from y2cad-polynomial (values nil nil)))
                      (setq product (y2cad-poly-multiply product poly))))))
               (/
                (if (= (length args) 2)
                    (let ((denominator (y2cad-number-value (second args))))
                      (if (and denominator (not (zerop denominator)))
                          (multiple-value-bind (numerator ok)
                              (y2cad-polynomial (first args))
                            (values (and ok
                                         (y2cad-poly-scale
                                          numerator (/ denominator)))
                                    ok))
                          (values nil nil)))
                    (values nil nil)))
               (^
                (if (= (length args) 2)
                    (let ((exponent (y2cad-number-value (second args))))
                      (if (and (integerp exponent) (not (minusp exponent)))
                          (multiple-value-bind (base ok)
                              (y2cad-polynomial (first args))
                            (values (and ok (y2cad-poly-power base exponent))
                                    ok))
                          (values nil nil)))
                    (values nil nil)))
               (otherwise
                ;; Ground real applications are purified as algebraic atoms.
                ;; PVS/Shostak, not this NRA controller, owns any UF semantics.
                (if (y2cad-arithmetic-atom-p expr)
                    (values (y2cad-poly-atom expr) t)
                    (values nil nil))))))
          ((y2cad-arithmetic-atom-p expr)
           (values (y2cad-poly-atom expr) t))
          (t (values nil nil)))))

(defun y2cad-invert-relation (relation)
  (ecase relation
    (:equal :distinct) (:distinct :equal)
    (:less :greatereq) (:lesseq :greater)
    (:greater :lesseq) (:greatereq :less)))

(defun y2cad-relation (expr)
  (let ((negated? (and (typep expr 'application) (negation? expr))))
    (when negated? (setq expr (first (arguments expr))))
    (when (typep expr 'application)
      (let* ((head (y2direct-application-head expr))
             (op (and (name-expr? head) (id head)))
             (relation
               (cond ((equation? expr) :equal)
                     ((disequation? expr) :distinct)
                     ((eq op '<) :less)
                     ((eq op '<=) :lesseq)
                     ((eq op '>) :greater)
                     ((eq op '>=) :greatereq))))
        (when (and relation (= (length (arguments expr)) 2))
          (values (if negated? (y2cad-invert-relation relation) relation)
                  (first (arguments expr)) (second (arguments expr)) t))))))

(defun y2cad-parse-constraint (source)
  (when (typep source 'expr)
    (multiple-value-bind (relation left right relation?)
        (y2cad-relation source)
      (when relation?
        (multiple-value-bind (left-poly left-ok) (y2cad-polynomial left)
          (multiple-value-bind (right-poly right-ok) (y2cad-polynomial right)
            (when (and left-ok right-ok)
              (make-y2cad-constraint
               source relation (y2cad-poly-subtract left-poly right-poly)))))))))

;; --------------------------------------------------------------------
;; Lifting and solver contexts

(defun y2cad-add-monomial (monomial monomials)
  (if (find monomial monomials :test #'y2cad-monomial-equal-p)
      monomials
      (cons monomial monomials)))

(defun y2cad-monomial-closure (constraints)
  (let ((closure (list nil)))
    (labels ((add (monomial)
               (unless (find monomial closure :test #'y2cad-monomial-equal-p)
                 (push monomial closure)
                 (when monomial
                   (add (list (first monomial)))
                   (when (rest monomial) (add (rest monomial)))))))
      (dolist (constraint constraints)
        (dolist (entry (y2cad-constraint-polynomial constraint))
          (add (car entry)))))
    (stable-sort closure
                 #'(lambda (left right)
                     (or (< (length left) (length right))
                         (and (= (length left) (length right))
                              (string< (y2cad-monomial-string left)
                                       (y2cad-monomial-string right))))))))

(defun y2cad-find-term (monomial table)
  (cdr (find monomial table :key #'car :test #'y2cad-monomial-equal-p)))

(defun y2cad-make-z-table (monomials)
  (loop for monomial in monomials
        for index from 0
        collect (cons monomial (y2/real (format nil "z_~d" index)))))

(defun y2cad-base-atoms (monomials)
  (let ((atoms nil))
    (dolist (monomial monomials (nreverse atoms))
      (when (= (length monomial) 1)
        (unless (find (first monomial) atoms :test #'tc-eq)
          (push (first monomial) atoms))))))

(defun y2cad-make-x-table (atoms)
  (loop for atom in atoms
        for index from 0
        collect (cons atom (y2/real (format nil "x_~d" index)))))

(defun y2cad-find-x (atom table)
  (cdr (find atom table :key #'car :test #'tc-eq)))

(defun y2cad-rational-term (number)
  (if (integerp number)
      (if (<= (- (expt 2 31)) number (1- (expt 2 31)))
          (y2/int32 number)
          (y2/int64 number))
      (y2/parse-rat (format nil "~a" number))))

(defun y2cad-lifted-polynomial-term (polynomial z-table)
  (apply #'y2/+
         (loop for (monomial . coefficient) in polynomial
               for z = (y2cad-find-term monomial z-table)
               collect (if (= coefficient 1)
                           z
                           (y2/* (y2cad-rational-term coefficient) z)))))

(defun y2cad-lifted-constraint-term (constraint z-table)
  (let ((left (y2cad-lifted-polynomial-term
               (y2cad-constraint-polynomial constraint) z-table))
        (zero (y2/int32 0)))
    (ecase (y2cad-constraint-relation constraint)
      (:equal (y2/= left zero))
      (:distinct (y2//= left zero))
      (:less (y2/< left zero))
      (:lesseq (y2/<= left zero))
      (:greater (y2/> left zero))
      (:greatereq (y2/>= left zero)))))

(defun y2cad-assert-linear-layer (constraints z-table component)
  (let ((z0 (y2cad-find-term nil z-table)))
    (y2cad-trace :full component "bridge: z_0 = 1")
    (y2/assert! (y2/= z0 (y2/int32 1))))
  (dolist (constraint constraints)
    (let ((term (y2cad-lifted-constraint-term constraint z-table)))
      (y2cad-trace :full component "lift: ~a~%    => ~a"
                   (y2cad-display (y2cad-constraint-source constraint))
                   (y2/term-string term :height 16))
      (y2/assert! term))))

(defun y2cad-assert-monomial-layer (monomials z-table x-table)
  (dolist (monomial monomials)
    (cond ((null monomial))
          ((= (length monomial) 1)
           (let ((z (y2cad-find-term monomial z-table))
                 (x (y2cad-find-x (first monomial) x-table)))
             (y2cad-trace :full :monomial "bridge z[~a] = x[~a]"
                          (y2cad-monomial-string monomial)
                          (y2cad-display (first monomial)))
             (y2/assert! (y2/= z x))))
          (t
           (let* ((left (list (first monomial)))
                  (right (rest monomial))
                  (z (y2cad-find-term monomial z-table))
                  (za (y2cad-find-term left z-table))
                  (zb (y2cad-find-term right z-table)))
             (y2cad-trace :full :monomial "bridge z[~a] = z[~a] * z[~a]"
                          (y2cad-monomial-string monomial)
                          (y2cad-monomial-string left)
                          (y2cad-monomial-string right))
             (y2/assert! (y2/= z (y2/* za zb))))))))

(defun y2cad-capture-model (x-table)
  (let ((lines nil))
    (dolist (entry x-table)
      (let* ((atom (car entry))
             (names (collect-subterms atom #'name-expr?))
             (visible? (some #'skolem-constant? names))
             (value (and visible?
                         (ignore-errors (y2/value-double (cdr entry))))))
        (when (and visible? value)
          (push (format nil "   ~a = ~,10g"
                        (y2cad-display atom) value)
                lines))))
    (setq *y2cad-last-model*
          (if lines
              (format nil "Y2CAD exact MCSAT projection:~%~{~a~%~}"
                      (nreverse lines))
              "Y2CAD exact controller returned SAT; no numeric projection was available."))))

(defun y2cad-run-linear-relaxation (constraints monomials)
  (let ((spec (list :name :y2cad-linear :logic "QF_LRA" :mcsat nil
                    :configs '(("solver-type" . "dpllt")
                               ("arith-solver" . "simplex")
                               ("arith-fragment" . "LRA")))))
    (y2cad-trace :summary :linear
                 "check ~d lifted constraint~:p over ~d monomial variable~:p"
                 (length constraints) (length monomials))
    (y2shostak-call-with-solver
     spec
     #'(lambda ()
         (let ((z-table (y2cad-make-z-table monomials)))
           (y2cad-assert-linear-layer constraints z-table :linear)
           (let ((status (y2/check!)))
             (y2cad-trace :summary :linear "relaxation => ~a" status)
             status))))))

(defun y2cad-run-exact-controller (constraints monomials)
  (let ((spec (list :name :y2cad-monomial :logic "QF_NRA"
                    :mcsat t :configs nil)))
    (y2cad-trace :summary :controller
                 "check lifted region against monomial variety (~d bridge term~:p)"
                 (length monomials))
    (y2shostak-call-with-solver
     spec
     #'(lambda ()
         (let* ((z-table (y2cad-make-z-table monomials))
                (atoms (y2cad-base-atoms monomials))
                (x-table (y2cad-make-x-table atoms)))
           (y2cad-assert-linear-layer constraints z-table :controller)
           (y2cad-assert-monomial-layer monomials z-table x-table)
           (let ((status (y2/check!)))
             (y2cad-trace :summary :controller "exact compatibility => ~a"
                          status)
             (when (eq status :sat) (y2cad-capture-model x-table))
             status))))))

;; --------------------------------------------------------------------
;; Persistent state and DPI implementation

(defun y2cad-copy (state &optional bump?)
  (let ((copy (copy-y2cad-state state)))
    (setf (y2cad-state-constraints copy)
          (copy-list (y2cad-state-constraints state))
          (y2cad-state-whiteboard copy)
          (dpi-copy-state* 'shostak (y2cad-state-whiteboard state)))
    (when bump? (incf (y2cad-state-generation copy)))
    copy))

(defun y2cad-constraint-present-p (constraint constraints)
  (find (y2cad-constraint-source constraint) constraints
        :key #'y2cad-constraint-source :test #'tc-eq))

(defun y2cad-add-constraint (state constraint)
  (if (or (null constraint)
          (y2cad-constraint-present-p constraint
                                      (y2cad-state-constraints state)))
      state
      (let ((copy (y2cad-copy state t)))
        (setf (y2cad-state-constraints copy)
              (append (y2cad-state-constraints state) (list constraint)))
        (incf (y2cad-state-constraint-generation copy))
        copy)))

(defun y2cad-update-summary (state &optional monomial-count)
  (setq *y2cad-last-summary*
        (format nil "generation ~d/~d constraints; ~d polynomial literal~:p; ~d lifted monomial~:p; ~d MCSAT invocation~:p"
                (y2cad-state-generation state)
                (y2cad-state-constraint-generation state)
                (length (y2cad-state-constraints state))
                (or monomial-count 0)
                (y2cad-state-controller-calls state))))

(defun y2cad-nonlinear-monomials-p (monomials)
  (some #'(lambda (monomial) (> (length monomial) 1)) monomials))

(defun y2cad-closure-query-p (source)
  "A negated arithmetic literal is ASSERT's usual branch-closure query."
  (and (typep source 'application)
       (negation? source)
       (ignore-errors (y2cad-parse-constraint source))))

(defun y2cad-cache-linear-status (state status)
  (let ((copy (y2cad-copy state)))
    (setf (y2cad-state-linear-generation copy)
          (y2cad-state-constraint-generation state)
          (y2cad-state-linear-status copy) status)
    copy))

(defun y2cad-cache-exact-status (state status)
  (let ((copy (y2cad-copy state)))
    (setf (y2cad-state-exact-generation copy)
          (y2cad-state-constraint-generation state)
          (y2cad-state-exact-status copy) status
          (y2cad-state-controller-calls copy)
          (1+ (y2cad-state-controller-calls state)))
    copy))

(defun y2cad-process (source state)
  (let* ((old-whiteboard (y2cad-state-whiteboard state))
         (constraint
           (handler-case (y2cad-parse-constraint source)
             (error (condition)
               (setq *y2cad-last-error* condition)
               (y2cad-trace :summary :lifting "cannot lift ~a: ~a"
                            (y2cad-display source) condition)
               nil))))
    (multiple-value-bind (base-result new-whiteboard)
        (y2shostak-whiteboard-process source old-whiteboard)
      (when (false-p base-result)
        ;; Preserve attribution to the lifted linear layer when it can certify
        ;; the same conflict. This check is still cheaper than starting MCSAT
        ;; and makes the zero-controller-call path directly observable.
        (when constraint
          (let* ((linear-state (y2cad-add-constraint state constraint))
                 (monomials
                   (y2cad-monomial-closure
                    (y2cad-state-constraints linear-state)))
                 (linear-status
                   (ignore-errors
                     (y2cad-run-linear-relaxation
                      (y2cad-state-constraints linear-state) monomials))))
            (when (eq linear-status :unsat)
              (setq linear-state
                    (y2cad-cache-linear-status linear-state linear-status)
                    *y2cad-last-status* :linear-unsat)
              (y2cad-update-summary linear-state (length monomials))
              (return-from y2cad-process
                (values *false* linear-state)))))
        (setq *y2cad-last-status* :whiteboard-unsat)
        (return-from y2cad-process (values *false* state)))
      (when (true-p base-result)
        (unless (member *y2cad-last-status* '(:sat :unsat :linear-unsat))
          (setq *y2cad-last-status* :whiteboard-entailed))
        (return-from y2cad-process (values *true* state)))
      (let ((current state))
        (when (y2shostak-whiteboard-changed-p old-whiteboard new-whiteboard)
          (setq current (y2cad-copy current t))
          (setf (y2cad-state-whiteboard current) new-whiteboard))
        (when constraint
          (setq current (y2cad-add-constraint current constraint))
          (y2cad-trace :summary :lifting "lifted ~a to ~d linear term~:p"
                       (y2cad-display source)
                       (length (y2cad-constraint-polynomial constraint))))
        (if (null (y2cad-state-constraints current))
            (progn
              (y2cad-update-summary current)
              (values base-result current))
            (let ((monomials
                    (y2cad-monomial-closure
                     (y2cad-state-constraints current))))
              (y2cad-update-summary current (length monomials))
              (handler-case
                  (let ((linear-status
                          (if (= (y2cad-state-linear-generation current)
                                 (y2cad-state-constraint-generation current))
                              (y2cad-state-linear-status current)
                              (y2cad-run-linear-relaxation
                               (y2cad-state-constraints current) monomials))))
                    (unless (= (y2cad-state-linear-generation current)
                               (y2cad-state-constraint-generation current))
                      (setq current
                            (y2cad-cache-linear-status current linear-status)))
                    (when (eq linear-status :unsat)
                      (setq *y2cad-last-status* :linear-unsat)
                      (return-from y2cad-process (values *false* current)))
                    (cond
                      ((not (y2cad-nonlinear-monomials-p monomials))
                       ;; With no product bridges, the lifted LRA problem is
                       ;; already exact. MCSAT would add no information.
                       (setq *y2cad-last-status* :linear-sat)
                       (values base-result current))
                      ((= (y2cad-state-exact-generation current)
                          (y2cad-state-constraint-generation current))
                       ;; Unrelated whiteboard traffic after a checkpoint does
                       ;; not invalidate the exact polynomial result.
                       (setq *y2cad-last-status*
                             (y2cad-state-exact-status current))
                       (values base-result current))
                      ((or (eq *y2cad-controller-policy* :defer)
                           (not (or *y2cad-force-exact*
                                    (y2cad-closure-query-p source))))
                       ;; Premises accumulate in the cheap relaxation. The
                       ;; compatibility controller is intentionally dormant.
                       (setq *y2cad-last-status* :compatibility-deferred)
                       (y2cad-trace :summary :controller
                                    "defer MCSAT until a closure checkpoint")
                       (values base-result current))
                      (t
                       (let ((exact-status
                               (if (= (y2cad-state-exact-generation current)
                                      (y2cad-state-constraint-generation current))
                                   (progn
                                     (y2cad-trace :summary :controller
                                                  "reuse generation-~d compatibility result"
                                                  (y2cad-state-constraint-generation current))
                                     (y2cad-state-exact-status current))
                                   (y2cad-run-exact-controller
                                    (y2cad-state-constraints current)
                                    monomials))))
                         (unless (= (y2cad-state-exact-generation current)
                                    (y2cad-state-constraint-generation current))
                           (setq current
                                 (y2cad-cache-exact-status
                                  current exact-status)))
                         (setq *y2cad-last-status* exact-status)
                         (y2cad-update-summary current (length monomials))
                         (case exact-status
                           (:unsat (values *false* current))
                           (otherwise (values base-result current)))))))
                (error (condition)
                  (setq *y2cad-last-error* condition
                        *y2cad-last-status* :unknown)
                  (y2cad-trace :summary :error "solver failure: ~a" condition)
                  (values base-result current)))))))))

(defun y2cad-valid (state source)
  (multiple-value-bind (result ignored)
      (let ((*y2cad-force-exact* t))
        (y2cad-process source (y2cad-copy state)))
    (declare (ignore ignored))
    (cond ((true-p result) *true*) ((false-p result) *false*) (t nil))))

(defun register-y2cad-decision-procedure ()
  (pushnew 'y2cad *decision-procedures*)
  (let ((entry (assoc 'y2cad *decision-procedure-descriptions*)))
    (if entry
        (setf (cdr entry) "Lifted linear/monomial NRA with exact Yices MCSAT")
        (push (cons 'y2cad
                    "Lifted linear/monomial NRA with exact Yices MCSAT")
              *decision-procedure-descriptions*)))
  'y2cad)

(register-y2cad-decision-procedure)

(defmethod dpi-init* ((dp (eql 'y2cad)))
  (declare (ignore dp)) t)

(defmethod dpi-start* ((dp (eql 'y2cad)) (prove-body function))
  (declare (ignore dp))
  (ensure-y2direct-implementation)
  (setq *y2cad-last-status* nil
        *y2cad-last-error* nil
        *y2cad-last-model* nil
        *y2cad-last-summary* nil)
  (let* ((*translate-id-counter* nil)
         (*translate-id-hash* (init-if-rec *translate-id-hash*))
         (*translate-to-prove-hash* (init-if-rec *translate-to-prove-hash*))
         (typealist primtypealist)
         (*subtype-names* nil)
         (*named-exprs* nil)
         (*rec-type-dummies* nil)
         (*local-typealist* *local-typealist*)
         (applysymlist nil) (sigalist sigalist)
         (usealist usealist) (findalist findalist))
    (initprover)
    (newcounter *translate-id-counter*)
    (funcall prove-body)))

(defmethod dpi-empty-state* ((dp (eql 'y2cad)))
  (declare (ignore dp))
  (make-y2cad-state :whiteboard (y2shostak-empty-whiteboard)))

(defmethod dpi-process* ((dp (eql 'y2cad)) source state)
  (declare (ignore dp)) (y2cad-process source state))

(defmethod dpi-valid?* ((dp (eql 'y2cad)) state source)
  (declare (ignore dp)) (y2cad-valid state source))

(defmethod dpi-push-state* ((dp (eql 'y2cad)) state)
  (declare (ignore dp)) (y2cad-copy state))
(defmethod dpi-pop-state* ((dp (eql 'y2cad)) state)
  (declare (ignore dp)) state)
(defmethod dpi-copy-state* ((dp (eql 'y2cad)) state)
  (declare (ignore dp)) (y2cad-copy state))
(defmethod dpi-restore-state* ((dp (eql 'y2cad)) state)
  (declare (ignore dp)) state)

(defmethod dpi-state-changed?* ((dp (eql 'y2cad)) old-state new-state)
  (declare (ignore dp))
  (/= (y2cad-state-generation old-state) (y2cad-state-generation new-state)))

(defmethod dpi-disjunction?* ((dp (eql 'y2cad)) term)
  (declare (ignore dp)) (and (consp term) (eq (car term) 'or)))
(defmethod dpi-proposition?* ((dp (eql 'y2cad)) term)
  (declare (ignore dp))
  (and (consp term) (memq (car term) '(if if* implies not and iff))))
(defmethod dpi-term-arguments* ((dp (eql 'y2cad)) term)
  (declare (ignore dp)) (when (consp term) (cdr term)))
(defmethod dpi-canon* ((dp (eql 'y2cad)) term state)
  (declare (ignore dp))
  (y2shostak-canonical-form term (y2cad-state-whiteboard state)))

;; --------------------------------------------------------------------
;; Read-only prover commands

(defun y2cad-set-trace-rule (level)
  #'(lambda (proofstate)
      (declare (ignore proofstate))
      (set-y2cad-trace level)
      (values 'X nil nil)))

(addrule 'y2cad-trace nil nil (y2cad-set-trace-rule :summary)
  "Enables compact Y2CAD lifting, relaxation, and exact-controller tracing.")
(addrule 'y2cad-trace$ nil nil (y2cad-set-trace-rule :full)
  "Enables white-box Y2CAD traces including lifted constraints and every monomial bridge.")
(addrule 'y2cad-untrace nil nil (y2cad-set-trace-rule :off)
  "Disables Y2CAD tracing.")

(defun y2cad-report-rule (kind)
  #'(lambda (proofstate)
      (ecase kind
        (:status (y2cad-show (y2cad-status-string)))
        (:model (y2cad-show (or *y2cad-last-model*
                                "No Y2CAD model projection is available.")))
        (:counterexample
         (y2cad-show
          (format nil
                  "Y2CAD did not close this branch. The PVS sequent remains authoritative.~%~%~a~%~%~a"
                  (if proofstate (format nil "~a" proofstate) "<no proof state>")
                  (or *y2cad-last-model* "<no model projection>")))))
      (values 'X nil nil)))

(addrule 'y2cad-status nil nil (y2cad-report-rule :status)
  "Reports the last lifted relaxation and exact-controller status.")
(addrule 'y2cad-model nil nil (y2cad-report-rule :model)
  "Prints the latest exact MCSAT projection for base algebraic variables.")
(addrule 'y2cad-counterexample nil nil (y2cad-report-rule :counterexample)
  "Prints the residual PVS obligation and the latest exact-controller projection.")
