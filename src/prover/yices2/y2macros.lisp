;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2macros.lisp --
;;   Macros for bindings defined in y2bindings.lisp/api.spec
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2026, SRI International.  All Rights Reserved.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the 3-Clause BSD License.
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; 3-Clause BSD License for more details.
;; --------------------------------------------------------------------

(in-package :pvs)

;; Context, manager, and solver-scoping utilities live in y2structures.lisp.

;; --------------------------------------------------------------------
;; Types

(defun y2/bool-type ()
  (%y2/yices_bool_type))

(defun y2/int-type ()
  (%y2/yices_int_type))

(defun y2/real-type ()
  (%y2/yices_real_type))

(defun y2/bv-type (size)
  (%y2/yices_bv_type size))

;; --------------------------------------------------------------------
;; Terms and variables

(defun y2/constant (type index)
  (%y2/yices_constant type index))

(defun y2/var (type &optional name)
  (let ((term (%y2/yices_new_uninterpreted_term type)))
    (when name
      (y2/check-code
       (%y2/yices_set_term_name term name)
       "Could not set Yices2 term name"))
    term))

(defun y2/bool (name)
  (y2/var (y2/bool-type) name))

(defun y2/int (name)
  (y2/var (y2/int-type) name))

(defun y2/real (name)
  (y2/var (y2/real-type) name))

(defun y2/bv (name size)
  (y2/var (y2/bv-type size) name))

(defmacro y2/with-vars (bindings &body body)
  "Bind Lisp variables to fresh Yices variables.

Examples:
  (y2/with-vars ((x real)
                 (y int)
                 (p bool)
                 (b (bv 32)))
    ...)"
  `(let ,(mapcar
          (lambda (binding)
            (destructuring-bind (var sort &optional explicit-name) binding
              (let ((name (or explicit-name
                              (string-downcase (symbol-name var)))))
                `(,var
                  ,(cond
                     ((eq sort 'bool) `(y2/bool ,name))
                     ((eq sort 'int)  `(y2/int ,name))
                     ((eq sort 'real) `(y2/real ,name))
                     ((and (consp sort) (eq (first sort) 'bv))
                      `(y2/bv ,name ,(second sort)))
                     (t
                      (error "Bad Y2/WITH-VARS sort: ~S" sort)))))))
          bindings)
     ,@body))

;; --------------------------------------------------------------------
;; Constants

(defun y2/true ()
  (%y2/yices_true))

(defun y2/false ()
  (%y2/yices_false))

(defun y2/int32 (n)
  (%y2/yices_int32 n))

(defun y2/int64 (n)
  (%y2/yices_int64 n))

(defun y2/rat (n &optional d)
  (if d
      (%y2/yices_rational32 n d)
      (%y2/yices_int32 n)))

(defun y2/parse-rat (string)
  (%y2/yices_parse_rational string))

(defun y2/parse-float (string)
  (%y2/yices_parse_float string))

;; --------------------------------------------------------------------
;; Boolean connectives

(defun y2/not (a)
  (%y2/yices_not a))

(defun y2/=> (a b)
  (%y2/yices_implies a b))

(defun y2/iff (a b)
  (%y2/yices_iff a b))

(defun y2/= (a b)
  (%y2/yices_eq a b))

(defun y2//= (a b)
  (%y2/yices_neq a b))

(defun y2/and (&rest terms)
  (case (length terms)
    (0 (y2/true))
    (1 (first terms))
    (2 (%y2/yices_and2 (first terms) (second terms)))
    (3 (%y2/yices_and3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_and (length terms) arr)))))

(defun y2/or (&rest terms)
  (case (length terms)
    (0 (y2/false))
    (1 (first terms))
    (2 (%y2/yices_or2 (first terms) (second terms)))
    (3 (%y2/yices_or3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_or (length terms) arr)))))

(defun y2/xor (&rest terms)
  (case (length terms)
    (0 (y2/false))
    (1 (first terms))
    (2 (%y2/yices_xor2 (first terms) (second terms)))
    (3 (%y2/yices_xor3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_xor (length terms) arr)))))

(defun y2/ite (c t-branch e-branch)
  (%y2/yices_ite c t-branch e-branch))

(defun y2/distinct (&rest terms)
  (y2/%with-term-array (arr terms)
    (%y2/yices_distinct (length terms) arr)))



;; --------------------------------------------------------------------
;; Helpers for C arrays of terms

(defmacro y2/%with-term-array ((ptr terms-form) &body body)
  `(let* ((terms-list ,terms-form)
          (n (length terms-list)))
     (cffi:with-foreign-object (,ptr 'term_t n)
       (loop for term in terms-list
             for i from 0
             do (setf (cffi:mem-aref ,ptr 'term_t i) term))
       ,@body)))

;; --------------------------------------------------------------------
;; Arithmetic

(defun y2/+ (&rest terms)
  (case (length terms)
    (0 (y2/int32 0))
    (1 (first terms))
    (2 (%y2/yices_add (first terms) (second terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_sum (length terms) arr)))))

(defun y2/- (a &optional b)
  (if b
      (%y2/yices_sub a b)
      (%y2/yices_neg a)))

(defun y2/* (&rest terms)
  (case (length terms)
    (0 (y2/int32 1))
    (1 (first terms))
    (2 (%y2/yices_mul (first terms) (second terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_product (length terms) arr)))))

(defun y2/square (a)
  (%y2/yices_square a))

(defun y2/power (a n)
  (%y2/yices_power a n))

(defun y2// (a b)
  (%y2/yices_division a b))

(defun y2/idiv (a b)
  (%y2/yices_idiv a b))

(defun y2/imod (a b)
  (%y2/yices_imod a b))

(defun y2/abs (a)
  (%y2/yices_abs a))

(defun y2/floor (a)
  (%y2/yices_floor a))

(defun y2/ceil (a)
  (%y2/yices_ceil a))

(defun y2/< (a b)
  (%y2/yices_arith_lt_atom a b))

(defun y2/<= (a b)
  (%y2/yices_arith_leq_atom a b))

(defun y2/> (a b)
  (%y2/yices_arith_gt_atom a b))

(defun y2/>= (a b)
  (%y2/yices_arith_geq_atom a b))

(defun y2/arith= (a b)
  (%y2/yices_arith_eq_atom a b))

(defun y2/arith/= (a b)
  (%y2/yices_arith_neq_atom a b))

(defun y2/zero? (a)
  (%y2/yices_arith_eq0_atom a))

(defun y2/nonzero? (a)
  (%y2/yices_arith_neq0_atom a))

(defun y2/positive? (a)
  (%y2/yices_arith_gt0_atom a))

(defun y2/nonnegative? (a)
  (%y2/yices_arith_geq0_atom a))

(defun y2/negative? (a)
  (%y2/yices_arith_lt0_atom a))

(defun y2/nonpositive? (a)
  (%y2/yices_arith_leq0_atom a))

;; --------------------------------------------------------------------
;; Bitvectors: small starter set

(defun y2/bvconst (size value)
  (%y2/yices_bvconst_uint32 size value))

(defun y2/bvzero (size)
  (%y2/yices_bvconst_zero size))

(defun y2/bvone (size)
  (%y2/yices_bvconst_one size))

(defun y2/bv+ (a b)
  (%y2/yices_bvadd a b))

(defun y2/bv- (a b)
  (%y2/yices_bvsub a b))

(defun y2/bvneg (a)
  (%y2/yices_bvneg a))

(defun y2/bv* (a b)
  (%y2/yices_bvmul a b))

(defun y2/bvnot (a)
  (%y2/yices_bvnot a))

(defun y2/bvand (&rest terms)
  (case (length terms)
    (1 (first terms))
    (2 (%y2/yices_bvand2 (first terms) (second terms)))
    (3 (%y2/yices_bvand3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_bvand (length terms) arr)))))

(defun y2/bvor (&rest terms)
  (case (length terms)
    (1 (first terms))
    (2 (%y2/yices_bvor2 (first terms) (second terms)))
    (3 (%y2/yices_bvor3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_bvor (length terms) arr)))))

(defun y2/bvxor (&rest terms)
  (case (length terms)
    (1 (first terms))
    (2 (%y2/yices_bvxor2 (first terms) (second terms)))
    (3 (%y2/yices_bvxor3 (first terms) (second terms) (third terms)))
    (otherwise
     (y2/%with-term-array (arr terms)
       (%y2/yices_bvxor (length terms) arr)))))

(defun y2/bv= (a b)
  (%y2/yices_bveq_atom a b))

(defun y2/bv/= (a b)
  (%y2/yices_bvneq_atom a b))

(defun y2/bv< (a b)
  (%y2/yices_bvlt_atom a b))

(defun y2/bv<= (a b)
  (%y2/yices_bvle_atom a b))

(defun y2/bv> (a b)
  (%y2/yices_bvgt_atom a b))

(defun y2/bv>= (a b)
  (%y2/yices_bvge_atom a b))

(defun y2/bvs< (a b)
  (%y2/yices_bvslt_atom a b))

(defun y2/bvs<= (a b)
  (%y2/yices_bvsle_atom a b))

(defun y2/bvs> (a b)
  (%y2/yices_bvsgt_atom a b))

(defun y2/bvs>= (a b)
  (%y2/yices_bvsge_atom a b))

;; --------------------------------------------------------------------
;; Model values

(defun y2/value-bool (term)
  (cffi:with-foreign-object (out :int32)
    (y2/check-code
     (%y2/yices_get_bool_value (y2/ensure-model) term out)
     "Could not get Boolean value")
    (not (zerop (cffi:mem-ref out :int32)))))

(defun y2/value-int32 (term)
  (cffi:with-foreign-object (out :int32)
    (y2/check-code
     (%y2/yices_get_int32_value (y2/ensure-model) term out)
     "Could not get int32 value")
    (cffi:mem-ref out :int32)))

(defun y2/value-int64 (term)
  (cffi:with-foreign-object (out :int64)
    (y2/check-code
     (%y2/yices_get_int64_value (y2/ensure-model) term out)
     "Could not get int64 value")
    (cffi:mem-ref out :int64)))

(defun y2/value-double (term)
  (cffi:with-foreign-object (out :double)
    (y2/check-code
     (%y2/yices_get_double_value (y2/ensure-model) term out)
     "Could not get double value")
    (cffi:mem-ref out :double)))

(defun y2/value-rational32 (term)
  "Return two values: numerator and denominator."
  (cffi:with-foreign-objects ((num :int32)
                              (den :uint32))
    (y2/check-code
     (%y2/yices_get_rational32_value (y2/ensure-model) term num den)
     "Could not get rational32 value")
    (values (cffi:mem-ref num :int32)
            (cffi:mem-ref den :uint32))))

(defun y2/value (term &key as)
  "Convenience value reader.

AS may be :BOOL, :INT32, :INT64, :DOUBLE, or :RATIONAL32."
  (ecase as
    (:bool (y2/value-bool term))
    (:int32 (y2/value-int32 term))
    (:int64 (y2/value-int64 term))
    (:double (y2/value-double term))
    (:rational32 (y2/value-rational32 term))))


(defun y2/value-rational (term)
  "Return a Lisp rational if the model value fits rational32."
  (multiple-value-bind (num den)
      (y2/value-rational32 term)
    (/ num den)))

;; --------------------------------------------------------------------
;; Pretty printing / strings

(defun y2/term-string (term &key (width 120) (height 40) (offset 0))
  (let ((s (%y2/yices_term_to_string term width height offset)))
    (unwind-protect
         (cffi:foreign-string-to-lisp s)
      (%y2/yices_free_string s))))

(defun y2/type-string (type &key (width 120) (height 40) (offset 0))
  (let ((s (%y2/yices_type_to_string type width height offset)))
    (unwind-protect
         (cffi:foreign-string-to-lisp s)
      (%y2/yices_free_string s))))

(defun y2/model-string (&key (width 120) (height 80) (offset 0))
  (let ((s (%y2/yices_model_to_string
            (y2/ensure-model)
            width height offset)))
    (unwind-protect
         (cffi:foreign-string-to-lisp s)
      (%y2/yices_free_string s))))
