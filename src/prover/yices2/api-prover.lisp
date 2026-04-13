;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; api-prover.lisp --
;;   Standalone Yices2 prover integration via the CFFI API bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2006, SRI International.  All Rights Reserved.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
;; --------------------------------------------------------------------

(in-package :pvs)

(defconstant +yices-status-idle+ 0)
(defconstant +yices-status-searching+ 1)
(defconstant +yices-status-unknown+ 2)
(defconstant +yices-status-sat+ 3)
(defconstant +yices-status-unsat+ 4)
(defconstant +yices-status-interrupted+ 5)
(defconstant +yices-status-error+ 6)

(defparameter *yices2-api-logic* "QF_UFLIRA")

(defvar *yices2-api-name-counter* nil)
(defvar *yices2-api-library-loaded* nil)
(defvar *yices2-api-type-cache* nil)
(defvar *yices2-api-symbol-cache* nil)
(defvar *yices2-api-name-cache* nil)

(declaim (ftype function yices2-api-type yices2-api-term))

(defun reset-yices2-api-state ()
  (setq *yices2-api-type-cache* (make-pvs-hash-table)
        *yices2-api-symbol-cache* (make-pvs-hash-table)
        *yices2-api-name-cache* (make-pvs-hash-table))
  (newcounter *yices2-api-name-counter*))

(defun ensure-yices2-api-library ()
  (unless *yices2-api-library-loaded*
    (cffi:load-foreign-library 'yices2)
    (yices_init)
    (setq *yices2-api-library-loaded* t)))

(defun yices2-api-error-string ()
  (let ((ptr (yices_error_string)))
    (if (cffi:null-pointer-p ptr)
        "unknown Yices2 error"
        (unwind-protect
            (cffi:foreign-string-to-lisp ptr)
          (yices_free_string ptr)))))

(defun yices2-api-error (control &rest args)
  (error "~a~%Yices2 error: ~a"
         (apply #'format nil control args)
         (yices2-api-error-string)))

(defun yices2-api-check-code (code control &rest args)
  (if (= code -1)
      (apply #'yices2-api-error control args)
      code))

(defun yices2-api-check-term (term control &rest args)
  (if (= term +yices-null-term+)
      (apply #'yices2-api-error control args)
      term))

(defun yices2-api-check-type (tau control &rest args)
  (if (= tau +yices-null-type+)
      (apply #'yices2-api-error control args)
      tau))

(defun yices2-api-check-pointer (ptr control &rest args)
  (if (cffi:null-pointer-p ptr)
      (apply #'yices2-api-error control args)
      ptr))

(defun yices2-api-name-root (obj)
  (cond ((stringp obj) obj)
        ((symbolp obj) (symbol-name obj))
        ((typep obj 'name) (symbol-name (id obj)))
        ((typep obj 'simple-decl) (symbol-name (id obj)))
        ((typep obj 'type-name) (symbol-name (id obj)))
        (t "y2api")))

(defun yices2-api-sanitize-name (name)
  (let* ((raw (string-downcase name))
         (body
          (with-output-to-string (out)
            (loop for ch across raw
                  do (write-char
                      (if (or (alphanumericp ch)
                              (char= ch #\_))
                          ch
                          #\_)
                      out)))))
    (cond ((zerop (length body)) "y2api")
          ((digit-char-p (char body 0))
           (format nil "n_~a" body))
          (t body))))

(defun yices2-api-fresh-name (obj &optional (fallback "y2api"))
  (or (gethash obj *yices2-api-name-cache*)
      (setf (gethash obj *yices2-api-name-cache*)
            (format nil "~a_~d"
                    (yices2-api-sanitize-name
                     (or (ignore-errors (yices2-api-name-root obj))
                         fallback))
                    (funcall *yices2-api-name-counter*)))))

(defun yices2-api-boolean-type-p (ptype)
  (tc-eq (find-supertype ptype) *boolean*))

(defun yices2-api-integer-type-p (ptype)
  (tc-eq (find-supertype ptype) *integer*))

(defun yices2-api-real-type-p (ptype)
  (let ((stype (find-supertype ptype)))
    (or (tc-eq stype *real*)
        (tc-eq stype *number*))))

(defun yices2-api-arithmetic-type-p (ptype)
  (let ((stype (find-supertype ptype)))
    (or (tc-eq stype *integer*)
        (tc-eq stype *real*)
        (tc-eq stype *number*))))

(defun yices2-api-function-type (fty)
  (let* ((domain (domain fty))
         (range-type (yices2-api-type (range fty))))
    (if (tupletype? domain)
        (let* ((dom-types (mapcar #'yices2-api-type (types domain)))
               (arity (length dom-types)))
          (case arity
            (1 (yices2-api-check-type
                (yices_function_type1 (car dom-types) range-type)
                "Failed to build unary function type for ~a" fty))
            (2 (yices2-api-check-type
                (yices_function_type2 (first dom-types) (second dom-types) range-type)
                "Failed to build binary function type for ~a" fty))
            (3 (yices2-api-check-type
                (yices_function_type3 (first dom-types) (second dom-types)
                                      (third dom-types) range-type)
                "Failed to build ternary function type for ~a" fty))
            (otherwise
             (cffi:with-foreign-object (array 'type_t arity)
               (loop for tau in dom-types
                     for i from 0
                     do (setf (cffi:mem-aref array 'type_t i) tau))
               (yices2-api-check-type
                (yices_function_type arity array range-type)
                "Failed to build function type for ~a" fty)))))
        (yices2-api-check-type
         (yices_function_type1 (yices2-api-type domain) range-type)
         "Failed to build function type for ~a" fty))))

(defun yices2-api-tuple-type (tty)
  (let* ((elt-types (mapcar #'yices2-api-type (types tty)))
         (arity (length elt-types)))
    (case arity
      (1 (yices2-api-check-type
          (yices_tuple_type1 (car elt-types))
          "Failed to build tuple type for ~a" tty))
      (2 (yices2-api-check-type
          (yices_tuple_type2 (first elt-types) (second elt-types))
          "Failed to build tuple type for ~a" tty))
      (3 (yices2-api-check-type
          (yices_tuple_type3 (first elt-types) (second elt-types) (third elt-types))
          "Failed to build tuple type for ~a" tty))
      (otherwise
       (cffi:with-foreign-object (array 'type_t arity)
         (loop for tau in elt-types
               for i from 0
               do (setf (cffi:mem-aref array 'type_t i) tau))
         (yices2-api-check-type
          (yices_tuple_type arity array)
          "Failed to build tuple type for ~a" tty))))))

(defun yices2-api-uninterpreted-type (ptype)
  (let ((tau (yices2-api-check-type
              (yices_new_uninterpreted_type)
              "Failed to build uninterpreted type for ~a" ptype)))
    (yices2-api-check-code
     (yices_set_type_name tau (yices2-api-fresh-name ptype "type"))
     "Failed to name Yices2 type for ~a" ptype)
    tau))

(defun yices2-api-type (ptype)
  (let ((key (find-supertype ptype)))
    (or (gethash key *yices2-api-type-cache*)
        (setf (gethash key *yices2-api-type-cache*)
              (cond ((yices2-api-boolean-type-p key)
                     (yices_bool_type))
                    ((yices2-api-integer-type-p key)
                     (yices_int_type))
                    ((yices2-api-real-type-p key)
                     (yices_real_type))
                    ((funtype? key)
                     (yices2-api-function-type key))
                    ((tupletype? key)
                     (yices2-api-tuple-type key))
                    ((recordtype? key)
                     (error "Yices2 API prover does not yet support record type ~a" key))
                    (t
                     (yices2-api-uninterpreted-type key)))))))

(defun yices2-api-global-term-key (expr)
  (or (ignore-errors (declaration expr))
      expr))

(defun yices2-api-bound-term (expr env)
  (cdr (assoc expr env :test #'same-declaration)))

(defun yices2-api-global-term (expr)
  (let ((key (yices2-api-global-term-key expr)))
    (or (gethash key *yices2-api-symbol-cache*)
        (let ((term (yices2-api-check-term
                     (yices_new_uninterpreted_term (yices2-api-type (type expr)))
                     "Failed to create Yices2 symbol for ~a" expr)))
          (yices2-api-check-code
           (yices_set_term_name term (yices2-api-fresh-name key "sym"))
           "Failed to name Yices2 symbol for ~a" expr)
          (setf (gethash key *yices2-api-symbol-cache*) term)))))

(defun yices2-api-rational-term (value)
  (yices2-api-check-term
   (yices_parse_rational (princ-to-string value))
   "Failed to translate rational constant ~a" value))

(defun yices2-api-reduce-terms (builder args description)
  (cond ((null args)
         (error "No arguments available for ~a" description))
        ((null (cdr args))
         (car args))
        (t
         (reduce #'(lambda (left right)
                     (yices2-api-check-term
                      (funcall builder left right)
                      "Failed to translate ~a" description))
                 (cdr args)
                 :initial-value (car args)))))

(defun yices2-api-boolean-reduce (builder args description identity)
  (if (null args)
      identity
      (yices2-api-reduce-terms builder args description)))

(defun yices2-api-application-arg-terms (expr env)
  (if (tuple-expr? (argument expr))
        (mapcar #'(lambda (arg) (yices2-api-term arg env)) (arguments expr))
        (list (yices2-api-term (argument expr) env))))

(defun yices2-api-apply (fun args expr)
  (case (length args)
    (1 (yices2-api-check-term
        (yices_application1 fun (first args))
        "Failed to translate unary application ~a" expr))
    (2 (yices2-api-check-term
        (yices_application2 fun (first args) (second args))
        "Failed to translate binary application ~a" expr))
    (3 (yices2-api-check-term
        (yices_application3 fun (first args) (second args) (third args))
        "Failed to translate ternary application ~a" expr))
    (otherwise
     (let ((arity (length args)))
       (cffi:with-foreign-object (array 'term_t arity)
         (loop for arg in args
               for i from 0
               do (setf (cffi:mem-aref array 'term_t i) arg))
         (yices2-api-check-term
         (yices_application fun arity array)
          "Failed to translate application ~a" expr))))))

(defun yices2-api-tuple-term (expr env)
  (let* ((args (mapcar #'(lambda (arg) (yices2-api-term arg env)) (exprs expr)))
         (arity (length args)))
    (case arity
      (2 (yices2-api-check-term
          (yices_pair (first args) (second args))
          "Failed to translate tuple term ~a" expr))
      (otherwise
       (cffi:with-foreign-object (array 'term_t arity)
         (loop for arg in args
               for i from 0
               do (setf (cffi:mem-aref array 'term_t i) arg))
         (yices2-api-check-term
          (yices_tuple arity array)
          "Failed to translate tuple term ~a" expr))))))

(defun yices2-api-term (expr &optional env)
  (cond ((tc-eq expr *true*)
         (yices_true))
        ((tc-eq expr *false*)
         (yices_false))
        ((rational-expr? expr)
         (yices2-api-rational-term (number expr)))
        ((name-expr? expr)
         (or (yices2-api-bound-term expr env)
             (yices2-api-global-term expr)))
        ((negation? expr)
         (yices2-api-check-term
          (yices_not (yices2-api-term (args1 expr) env))
          "Failed to translate negation ~a" expr))
        ((conjunction? expr)
         (yices2-api-boolean-reduce #'yices_and2
                                    (mapcar #'(lambda (arg) (yices2-api-term arg env))
                                            (arguments expr))
                                    expr
                                    (yices_true)))
        ((disjunction? expr)
         (yices2-api-boolean-reduce #'yices_or2
                                    (mapcar #'(lambda (arg) (yices2-api-term arg env))
                                            (arguments expr))
                                    expr
                                    (yices_false)))
        ((implication? expr)
         (yices2-api-check-term
          (yices_implies (yices2-api-term (args1 expr) env)
                         (yices2-api-term (args2 expr) env))
          "Failed to translate implication ~a" expr))
        ((iff? expr)
         (yices2-api-check-term
          (yices_iff (yices2-api-term (args1 expr) env)
                     (yices2-api-term (args2 expr) env))
          "Failed to translate iff ~a" expr))
        ((equation? expr)
         (let* ((lhs-expr (args1 expr))
                (rhs-expr (args2 expr))
                (lhs (yices2-api-term lhs-expr env))
                (rhs (yices2-api-term rhs-expr env)))
           (if (yices2-api-boolean-type-p (type lhs-expr))
               (yices2-api-check-term
                (yices_iff lhs rhs)
                "Failed to translate boolean equality ~a" expr)
               (yices2-api-check-term
                (yices_eq lhs rhs)
                "Failed to translate equality ~a" expr))))
        ((disequation? expr)
         (let* ((lhs-expr (args1 expr))
                (rhs-expr (args2 expr))
                (lhs (yices2-api-term lhs-expr env))
                (rhs (yices2-api-term rhs-expr env)))
           (if (yices2-api-boolean-type-p (type lhs-expr))
               (yices2-api-check-term
                (yices_not (yices_iff lhs rhs))
                "Failed to translate boolean disequality ~a" expr)
               (yices2-api-check-term
                (yices_neq lhs rhs)
                "Failed to translate disequality ~a" expr))))
        ((branch? expr)
         (yices2-api-check-term
          (yices_ite (yices2-api-term (condition expr) env)
                     (yices2-api-term (then-part expr) env)
                     (yices2-api-term (else-part expr) env))
          "Failed to translate branch ~a" expr))
        ((application? expr)
         (let* ((op (operator* expr))
                (op-id (and (name-expr? op) (id op)))
                (args (yices2-api-application-arg-terms expr env)))
           (cond ((and (eq op-id '-)
                       (unary-application? expr)
                       (yices2-api-arithmetic-type-p (type expr)))
                  (yices2-api-check-term
                   (yices_neg (first args))
                   "Failed to translate unary minus ~a" expr))
                 ((and (eq op-id '+)
                       (yices2-api-arithmetic-type-p (type expr)))
                  (yices2-api-reduce-terms #'yices_add args expr))
                 ((and (eq op-id '-)
                       (yices2-api-arithmetic-type-p (type expr)))
                  (yices2-api-reduce-terms #'yices_sub args expr))
                 ((and (eq op-id '*)
                       (yices2-api-arithmetic-type-p (type expr)))
                  (yices2-api-reduce-terms #'yices_mul args expr))
                 ((and (eq op-id '/)
                       (yices2-api-arithmetic-type-p (type expr)))
                  (yices2-api-reduce-terms #'yices_division args expr))
                 ((and (eq op-id '<)
                       (yices2-api-boolean-type-p (type expr)))
                  (yices2-api-check-term
                   (yices_arith_lt_atom (first args) (second args))
                   "Failed to translate < formula ~a" expr))
                 ((and (eq op-id '<=)
                       (yices2-api-boolean-type-p (type expr)))
                  (yices2-api-check-term
                   (yices_arith_leq_atom (first args) (second args))
                   "Failed to translate <= formula ~a" expr))
                 ((and (eq op-id '>)
                       (yices2-api-boolean-type-p (type expr)))
                  (yices2-api-check-term
                   (yices_arith_gt_atom (first args) (second args))
                   "Failed to translate > formula ~a" expr))
                 ((and (eq op-id '>=)
                       (yices2-api-boolean-type-p (type expr)))
                  (yices2-api-check-term
                   (yices_arith_geq_atom (first args) (second args))
                   "Failed to translate >= formula ~a" expr))
                 (t
                  (yices2-api-apply (yices2-api-term op env) args expr)))))
        ((binding-expr? expr)
         (error "Yices2 API prover only handles quantifier-free formulas directly; use y2api-simp for ~a" expr))
        ((tuple-expr? expr)
         (yices2-api-tuple-term expr env))
        ((record-expr? expr)
         (error "Yices2 API prover does not yet translate record terms directly: ~a" expr))
        (t
         (error "Unsupported expression for Yices2 API prover: ~a" expr))))

(defun yices2-api-assertion-term (sform)
  (let ((fmla (formula sform)))
    (if (negation? fmla)
        (yices2-api-term (args1 fmla))
        (yices2-api-check-term
         (yices_not (yices2-api-term fmla))
         "Failed to negate succedent formula ~a" fmla))))

(defun yices2-api-run (ps sformnums)
  (let* ((goalsequent (current-goal ps))
         (sforms (select-seq (s-forms goalsequent) sformnums)))
    (if (null sforms)
        (values 'X nil nil)
        (handler-case
            (let ((config nil)
                  (context nil))
              (ensure-yices2-api-library)
              (yices_reset)
              (reset-yices2-api-state)
              (unwind-protect
                  (progn
                    (setq config
                          (yices2-api-check-pointer
                           (yices_new_config)
                           "Failed to allocate a Yices2 context configuration"))
                    (yices2-api-check-code
                     (yices_default_config_for_logic config *yices2-api-logic*)
                     "Failed to initialize Yices2 for logic ~a"
                     *yices2-api-logic*)
                    (yices2-api-check-code
                     (yices_set_config config "mode" "one-shot")
                     "Failed to configure Yices2 one-shot mode")
                    (setq context
                          (yices2-api-check-pointer
                           (yices_new_context config)
                           "Failed to allocate a Yices2 context"))
                    (dolist (sf sforms)
                      (yices2-api-check-code
                       (yices_assert_formula context (yices2-api-assertion-term sf))
                       "Failed to assert translated formula ~a"
                       (formula sf)))
                    (let ((status (yices_check_context context (cffi:null-pointer))))
                      (cond ((= status +yices-status-unsat+)
                             (values '! nil nil))
                            ((= status +yices-status-sat+)
                             (values 'X nil nil))
                            ((= status +yices-status-unknown+)
                             (format t "~%Yices2 API translation returned unknown.")
                             (values 'X nil nil))
                            ((= status +yices-status-interrupted+)
                             (format t "~%Yices2 API proof attempt was interrupted.")
                             (values 'X nil nil))
                            ((= status +yices-status-error+)
                             (yices2-api-error "Yices2 returned an error status")
                             (values 'X nil nil))
                            (t
                             (format t "~%Yices2 API returned unexpected status ~a." status)
                             (values 'X nil nil)))))
                (when context
                  (yices_free_context context))
                (when config
                  (yices_free_config config))
                (yices_reset)))
          (error (condition)
            (format t "~%Yices2 API prover failed: ~a" condition)
            (values 'X nil nil))))))

(defun yices2-api (sformnums)
  #'(lambda (ps)
      (yices2-api-run ps sformnums)))

(addrule 'yices2-api () ((fnums *))
  (yices2-api fnums)
  "Invokes Yices2 through the CFFI API as an endgame solver over the selected formulas."
  "~%Calling Yices2 through the CFFI API,")

(defstep y2api-simp (&optional (fnums *))
  (then (skosimp*) (yices2-api :fnums fnums))
  "Repeatedly skolemizes and flattens, then invokes the standalone Yices2 CFFI API prover."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 CFFI API prover")
