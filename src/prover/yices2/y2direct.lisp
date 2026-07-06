;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2direct.lisp --
;;   Direct PVS-to-Yices2 translation using the CFFI bindings.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;; This file mirrors the text-level encoding in translate-to-yices2.lisp, but
;; builds Yices2 terms directly.  Scalars use Yices scalar types.  Datatypes are
;; encoded as ground free constructors over QF_UF: constructors, tags, and
;; accessors are uninterpreted, while the initial-algebra laws needed by the
;; ground sequent are asserted as quantifier-free formulas.

(defparameter *y2direct-quant-expand-limit* 256)
(defparameter *y2direct-default-logic* "QF_UF")
(defparameter *y2direct-linear-logic* "QF_UFLIRA")
(defparameter *y2direct-nonlinear-logic* "QF_UFNIRA")
(defparameter *y2direct-bitvector-logic* "QF_UFBV")
(defparameter *y2direct-mixed-logic* "ALL")
(defparameter *y2direct-model-depth* 6)

(defvar *y2direct-id-counter*)
(newcounter *y2direct-id-counter*)

(defvar *y2direct-type-cache* nil)
(defvar *y2direct-symbol-cache* nil)
(defvar *y2direct-name-cache* nil)
(defvar *y2direct-term-cache* nil)
(defvar *y2direct-scalar-cache* nil)
(defvar *y2direct-datatype-cache* nil)
(defvar *y2direct-assertions* nil)
(defvar *y2direct-assertion-seen* nil)
(defvar *y2direct-conditions* nil)
(defvar *y2direct-constructor-apps* nil)
(defvar *y2direct-constructor-app-seen* nil)
(defvar *y2direct-datatype-terms* nil)
(defvar *y2direct-datatype-term-seen* nil)
(defvar *y2direct-model-entries* nil)
(defvar *y2direct-model-entry-seen* nil)
(defvar *y2direct-last-countermodel* nil)
(defvar *y2direct-last-unsat-core* nil)
(defvar *y2direct-last-unsat-core-hide* nil)
(defvar *y2direct-has-arithmetic?* nil)
(defvar *y2direct-has-bitvectors?* nil)
(defvar *y2direct-has-datatypes?* nil)

(defstruct y2direct-scalar-info
  type
  constructors
  constants)

(defstruct y2direct-datatype-info
  pvs-type
  yices-type
  constructors
  tag-type
  tag-function
  tag-constants)

(defstruct y2direct-constructor-app
  constructor
  term
  args
  arg-exprs
  type)

(defstruct y2direct-model-entry
  expr
  term
  type)

(defstruct y2direct-sform-assumption
  fnum
  sform
  term)

(defun clear-y2direct ()
  (setq *y2direct-type-cache* (make-pvs-hash-table)
        *y2direct-symbol-cache* (make-pvs-hash-table)
        *y2direct-name-cache* (make-pvs-hash-table)
        *y2direct-term-cache* (make-pvs-hash-table)
        *y2direct-scalar-cache* (make-pvs-hash-table)
        *y2direct-datatype-cache* (make-pvs-hash-table)
        *y2direct-assertions* nil
        *y2direct-assertion-seen* (make-hash-table :test #'eql)
        *y2direct-conditions* nil
        *y2direct-constructor-apps* nil
        *y2direct-constructor-app-seen* (make-hash-table :test #'eql)
        *y2direct-datatype-terms* nil
        *y2direct-datatype-term-seen* (make-hash-table :test #'equal)
        *y2direct-model-entries* nil
        *y2direct-model-entry-seen* (make-hash-table :test #'eql)
        *y2direct-has-arithmetic?* nil
        *y2direct-has-bitvectors?* nil
        *y2direct-has-datatypes?* nil)
  (newcounter *y2direct-id-counter*))

(defun y2direct-null-term-p (term)
  (= term +y2/null-term+))

(defun y2direct-null-type-p (type)
  (= type +y2/null-type+))

(defun y2direct-check-term (term control &rest args)
  (if (y2direct-null-term-p term)
      (apply #'y2api-err control args)
      term))

(defun y2direct-check-type (type control &rest args)
  (if (y2direct-null-type-p type)
      (apply #'y2api-err control args)
      type))

(defun y2direct-note-assertion (term)
  (unless (gethash term *y2direct-assertion-seen*)
    (setf (gethash term *y2direct-assertion-seen*) t)
    (push term *y2direct-assertions*))
  term)

(defun y2direct-note-guarded-assertion (term)
  (y2direct-note-assertion
   (if *y2direct-conditions*
       (y2/=>
        (apply #'y2/and (reverse *y2direct-conditions*))
        term)
       term)))

(defun y2direct-sanitize-name (name)
  (let* ((raw (string-downcase (string name)))
         (body
          (with-output-to-string (out)
            (loop for ch across raw
                  do (write-char
                      (if (or (alphanumericp ch) (char= ch #\_))
                          ch
                          #\_)
                      out)))))
    (cond ((zerop (length body)) "y2d")
          ((digit-char-p (char body 0)) (format nil "n_~a" body))
          (t body))))

(defun y2direct-name-root (obj)
  (cond ((stringp obj) obj)
        ((symbolp obj) (symbol-name obj))
        ((typep obj 'name) (symbol-name (id obj)))
        ((typep obj 'simple-decl) (symbol-name (id obj)))
        ((typep obj 'type-name) (symbol-name (id obj)))
        (t "y2d")))

(defun y2direct-fresh-name (obj &optional (fallback "y2d"))
  (or (gethash obj *y2direct-name-cache*)
      (setf (gethash obj *y2direct-name-cache*)
            (format nil "~a_~d"
                    (y2direct-sanitize-name
                     (or (ignore-errors (y2direct-name-root obj))
                         fallback))
                    (funcall *y2direct-id-counter*)))))

(defun y2direct-pvs-string (obj)
  (or (ignore-errors (unpindent obj 0 :string t :comment? t))
      (ignore-errors (unparse obj :string t))
      (format nil "~a" obj)))

(defun y2direct-internal-model-symbol-p (expr)
  (and (typep expr 'expr)
       (or (constructor? expr)
           (accessor? expr)
           (recognizer? expr))))

(defun y2direct-register-model-entry (expr term)
  (unless (or (y2direct-internal-model-symbol-p expr)
              (gethash term *y2direct-model-entry-seen*))
    (setf (gethash term *y2direct-model-entry-seen*) t)
    (push (make-y2direct-model-entry
           :expr expr
           :term term
           :type (type expr))
          *y2direct-model-entries*))
  term)

(defmacro y2direct-with-type-array ((ptr types-form) &body body)
  `(let* ((types-list ,types-form)
          (n (length types-list)))
     (cffi:with-foreign-object (,ptr 'type_t n)
       (loop for type in types-list
             for i from 0
             do (setf (cffi:mem-aref ,ptr 'type_t i) type))
       ,@body)))

(defun y2direct-set-type-name (type name)
  (y2/check-code
   (%y2/yices_set_type_name type name)
   "Could not name Yices2 type")
  type)

(defun y2direct-set-term-name (term name)
  (y2/check-code
   (%y2/yices_set_term_name term name)
   "Could not name Yices2 term")
  term)

(defun y2direct-new-uninterpreted-type (source &optional (fallback "type"))
  (let ((type
         (y2direct-check-type
          (%y2/yices_new_uninterpreted_type)
          "Failed to create Yices2 uninterpreted type for ~a" source)))
    (y2direct-set-type-name type (y2direct-fresh-name source fallback))))

(defun y2direct-new-scalar-type (cardinality source &optional (fallback "scalar"))
  (let ((type
         (y2direct-check-type
          (%y2/yices_new_scalar_type cardinality)
          "Failed to create Yices2 scalar type for ~a" source)))
    (y2direct-set-type-name type (y2direct-fresh-name source fallback))))

(defun y2direct-new-uninterpreted-term (type source &optional (fallback "sym"))
  (let ((term
         (y2direct-check-term
          (%y2/yices_new_uninterpreted_term type)
          "Failed to create Yices2 symbol for ~a" source)))
    (y2direct-set-term-name term (y2direct-fresh-name source fallback))))

(defun y2direct-tuple-type (types source)
  (let ((arity (length types)))
    (case arity
      (0 (y2api-err "Cannot build an empty Yices2 tuple type for ~a" source))
      (1 (y2direct-check-type
          (%y2/yices_tuple_type1 (first types))
          "Failed to build unary tuple type for ~a" source))
      (2 (y2direct-check-type
          (%y2/yices_tuple_type2 (first types) (second types))
          "Failed to build binary tuple type for ~a" source))
      (3 (y2direct-check-type
          (%y2/yices_tuple_type3 (first types) (second types) (third types))
          "Failed to build ternary tuple type for ~a" source))
      (otherwise
       (y2direct-with-type-array (array types)
         (y2direct-check-type
          (%y2/yices_tuple_type arity array)
          "Failed to build tuple type for ~a" source))))))

(defun y2direct-function-type* (domain-types range-type source)
  (let ((arity (length domain-types)))
    (case arity
      (0 range-type)
      (1 (y2direct-check-type
          (%y2/yices_function_type1 (first domain-types) range-type)
          "Failed to build unary function type for ~a" source))
      (2 (y2direct-check-type
          (%y2/yices_function_type2 (first domain-types) (second domain-types)
                                    range-type)
          "Failed to build binary function type for ~a" source))
      (3 (y2direct-check-type
          (%y2/yices_function_type3 (first domain-types) (second domain-types)
                                    (third domain-types) range-type)
          "Failed to build ternary function type for ~a" source))
      (otherwise
       (y2direct-with-type-array (array domain-types)
         (y2direct-check-type
          (%y2/yices_function_type arity array range-type)
          "Failed to build function type for ~a" source))))))

(defun y2direct-apply (fun args source)
  (case (length args)
    (0 fun)
    (1 (y2direct-check-term
        (%y2/yices_application1 fun (first args))
        "Failed to build unary application for ~a" source))
    (2 (y2direct-check-term
        (%y2/yices_application2 fun (first args) (second args))
        "Failed to build binary application for ~a" source))
    (3 (y2direct-check-term
        (%y2/yices_application3 fun (first args) (second args) (third args))
        "Failed to build ternary application for ~a" source))
    (otherwise
     (y2/%with-term-array (array args)
       (y2direct-check-term
        (%y2/yices_application fun (length args) array)
        "Failed to build application for ~a" source)))))

(defun y2direct-tuple (args source)
  (case (length args)
    (0 (y2api-err "Cannot build an empty Yices2 tuple for ~a" source))
    (1 (first args))
    (2 (y2direct-check-term
        (%y2/yices_pair (first args) (second args))
        "Failed to build pair for ~a" source))
    (3 (y2direct-check-term
        (%y2/yices_triple (first args) (second args) (third args))
        "Failed to build triple for ~a" source))
    (otherwise
     (y2/%with-term-array (array args)
       (y2direct-check-term
        (%y2/yices_tuple (length args) array)
        "Failed to build tuple for ~a" source)))))

(defun y2direct-select (tuple index source)
  (y2direct-check-term
   (%y2/yices_select index tuple)
   "Failed to build tuple selection for ~a" source))

(defun y2direct-tuple-update (tuple index value source)
  (y2direct-check-term
   (%y2/yices_tuple_update tuple index value)
   "Failed to build tuple update for ~a" source))

(defun y2direct-function-update (fun args value source)
  (case (length args)
    (1 (y2direct-check-term
        (%y2/yices_update1 fun (first args) value)
        "Failed to build unary function update for ~a" source))
    (2 (y2direct-check-term
        (%y2/yices_update2 fun (first args) (second args) value)
        "Failed to build binary function update for ~a" source))
    (3 (y2direct-check-term
        (%y2/yices_update3 fun (first args) (second args) (third args) value)
        "Failed to build ternary function update for ~a" source))
    (otherwise
     (y2/%with-term-array (array args)
       (y2direct-check-term
        (%y2/yices_update fun (length args) array value)
        "Failed to build function update for ~a" source)))))

(defun y2direct-bind (builder vars body source)
  (if (null vars)
      body
      (y2/%with-term-array (array vars)
        (y2direct-check-term
         (funcall builder (length vars) array body)
         "Failed to build binding term for ~a" source))))

(defun y2direct-record-fields (rtype)
  (sort-fields (fields rtype) (dependent? rtype)))

(defun y2direct-record-field-decl (field-id rtype)
  (let* ((needle (or (ignore-errors (id field-id)) field-id))
         (field (find needle
                      (y2direct-record-fields rtype)
                      :key #'id
                      :test #'eq)))
    (or field
        (y2api-err "Unsupported record field ~a for Yices2 type ~a"
                   field-id rtype))))

(defun y2direct-record-field-index (field-id rtype)
  (let* ((field (y2direct-record-field-decl field-id rtype))
         (pos (position field (y2direct-record-fields rtype))))
    (or (and pos (1+ pos))
        (y2api-err "Could not locate field ~a in record type ~a"
                   field-id rtype))))

(defun y2direct-component-type (ptype)
  (if (dep-binding? ptype)
      (type ptype)
      ptype))

(defun y2direct-boolean-type-p (ptype)
  (tc-eq (find-supertype ptype) *boolean*))

(defun y2direct-integer-type-p (ptype)
  (tc-eq (find-supertype ptype) *integer*))

(defun y2direct-real-type-p (ptype)
  (let ((stype (find-supertype ptype)))
    (or (tc-eq stype *real*)
        (tc-eq stype *number*))))

(defun y2direct-arithmetic-type-p (ptype)
  (let ((stype (find-supertype ptype)))
    (or (tc-eq stype *integer*)
        (tc-eq stype *real*)
        (tc-eq stype *number*))))

(defun y2direct-static-integer (expr &optional source)
  (let ((value (ignore-errors (pvseval-integer expr))))
    (if (integerp value)
        value
        (y2api-err "Yices2 direct translation needs a ground integer for ~a"
                   (or source expr)))))

(defun y2direct-bitvector-width (ptype)
  (let ((stype (find-supertype ptype)))
    (cond ((and (funtype? stype)
                (simple-below? (domain stype))
                (number-expr? (simple-below? (domain stype)))
                (tc-eq (find-supertype (range stype)) *boolean*))
           (number (simple-below? (domain stype))))
          ((and (type-name? stype)
                (eq (id stype) 'bvec)
                (actuals (module-instance stype)))
           (ignore-errors
             (y2direct-static-integer
              (expr (car (actuals (module-instance stype))))
              stype)))
          (t nil))))

(defun y2direct-bitvector-type-p (ptype)
  (not (null (y2direct-bitvector-width ptype))))

(defun y2direct-datatype-type-p (ptype)
  (let ((stype (find-supertype ptype)))
    (and (adt? stype)
         (not (enum-adt? stype)))))

(defun y2direct-datatype-key (ptype)
  (find-supertype ptype))

(defun y2direct-constructor-result-type (constructor)
  (let ((ctype (find-supertype (type constructor))))
    (if (funtype? ctype)
        (range ctype)
        ctype)))

(defun y2direct-same-constructor-p (left right)
  (or (same-declaration left right)
      (same-id left right)))

(defun y2direct-constructor-list (ptype)
  (constructors (find-supertype ptype)))

(defun y2direct-constructor-position (constructor ptype)
  (let* ((constructors (y2direct-constructor-list ptype))
         (pos (position constructor constructors
                        :test #'y2direct-same-constructor-p)))
    (or pos
        (position (id constructor) constructors :key #'id :test #'eq)
        (y2api-err "Could not find constructor ~a in datatype ~a"
                   constructor ptype))))

(defun y2direct-tag-name (ptype)
  (format nil "~a_tag" (y2direct-fresh-name ptype "datatype")))

(defun y2direct-tag-function-name (ptype)
  (format nil "~a_tag_of" (y2direct-fresh-name ptype "datatype")))

(defun y2direct-scalar-info (ptype)
  (let ((key (find-supertype ptype)))
    (or (gethash key *y2direct-scalar-cache*)
        (let* ((constructors (y2direct-constructor-list key))
               (type (y2direct-new-scalar-type
                      (length constructors)
                      key
                      "scalar"))
               (constants
                (loop for constructor in constructors
                      for index from 0
                      for term = (y2direct-check-term
                                  (%y2/yices_constant type index)
                                  "Failed to create scalar constant ~a"
                                  constructor)
                      do (y2direct-set-term-name
                          term
                          (y2direct-fresh-name constructor "scalar_value"))
                      collect term)))
          (setf (gethash key *y2direct-scalar-cache*)
                (make-y2direct-scalar-info
                 :type type
                 :constructors constructors
                 :constants constants))))))

(defun y2direct-scalar-constant (constructor)
  (let* ((ptype (y2direct-constructor-result-type constructor))
         (info (y2direct-scalar-info ptype))
         (pos (y2direct-constructor-position constructor ptype)))
    (nth pos (y2direct-scalar-info-constants info))))

(defun y2direct-datatype-info (ptype)
  (let ((key (y2direct-datatype-key ptype)))
    (or (gethash key *y2direct-datatype-cache*)
        (let* ((constructors (y2direct-constructor-list key))
               (type (y2direct-new-uninterpreted-type key "datatype"))
               (tag-type (y2direct-new-scalar-type
                          (length constructors)
                          (cons :tag key)
                          "datatype_tag"))
               (tag-function
                (y2direct-new-uninterpreted-term
                 (y2direct-function-type* (list type) tag-type key)
                 (cons :tag-function key)
                 "datatype_tag"))
               (tag-constants
                (loop for constructor in constructors
                      for index from 0
                      for term = (y2direct-check-term
                                  (%y2/yices_constant tag-type index)
                                  "Failed to create datatype tag constant ~a"
                                  constructor)
                      do (y2direct-set-term-name
                          term
                          (format nil "~a_tag"
                                  (y2direct-fresh-name constructor
                                                       "constructor")))
                      collect term)))
          (setq *y2direct-has-datatypes?* t)
          (setf (gethash key *y2direct-datatype-cache*)
                (make-y2direct-datatype-info
                 :pvs-type key
                 :yices-type type
                 :constructors constructors
                 :tag-type tag-type
                 :tag-function tag-function
                 :tag-constants tag-constants))))))

(defun y2direct-datatype-tag (ptype term)
  (let ((info (y2direct-datatype-info ptype)))
    (y2direct-apply (y2direct-datatype-info-tag-function info)
                    (list term)
                    ptype)))

(defun y2direct-constructor-tag (constructor)
  (let* ((ptype (y2direct-constructor-result-type constructor))
         (info (y2direct-datatype-info ptype))
         (pos (y2direct-constructor-position constructor ptype)))
    (nth pos (y2direct-datatype-info-tag-constants info))))

(defun y2direct-register-datatype-term (term ptype)
  (when (and ptype (y2direct-datatype-type-p ptype))
    (let ((key (cons term (y2direct-datatype-key ptype))))
      (unless (gethash key *y2direct-datatype-term-seen*)
        (setf (gethash key *y2direct-datatype-term-seen*) t)
        (push (cons term (y2direct-datatype-key ptype))
              *y2direct-datatype-terms*)))))

(defun y2direct-accessor-term (accessor arg source)
  (y2direct-apply (y2direct-term accessor nil) (list arg) source))

(defun y2direct-register-constructor-app (constructor term args arg-exprs)
  (let ((rtype (y2direct-constructor-result-type constructor)))
    (when (y2direct-datatype-type-p rtype)
      (y2direct-register-datatype-term term rtype)
      (unless (gethash term *y2direct-constructor-app-seen*)
        (setf (gethash term *y2direct-constructor-app-seen*) t)
        (push (make-y2direct-constructor-app
               :constructor constructor
               :term term
               :args args
               :arg-exprs arg-exprs
               :type rtype)
              *y2direct-constructor-apps*))
      (y2direct-note-assertion
       (y2/= (y2direct-datatype-tag rtype term)
             (y2direct-constructor-tag constructor)))
      (loop for accessor in (accessors constructor)
            for arg in args
            do (y2direct-note-assertion
                (y2/= (y2direct-accessor-term accessor term constructor)
                      arg)))
      (loop for arg in args
            for arg-expr in arg-exprs
            when (and (typep arg-expr 'expr)
                      (y2direct-datatype-type-p (type arg-expr))
                      (tc-eq (y2direct-datatype-key (type arg-expr))
                             (y2direct-datatype-key rtype)))
              do (y2direct-note-assertion (y2//=
                                           term
                                           arg)))))
  term)

(defun y2direct-datatype-constructor-term (constructor)
  (let ((entry (gethash constructor *y2direct-symbol-cache*)))
    (or entry
        (let* ((ctype (find-supertype (type constructor)))
               (term-type (y2direct-type ctype nil))
               (term (y2direct-new-uninterpreted-term
                      term-type constructor "constructor")))
          (setf (gethash constructor *y2direct-symbol-cache*) term)
          (unless (funtype? ctype)
            (y2direct-register-constructor-app constructor term nil nil))
          term))))

(defun y2direct-constructor-term (constructor)
  (let ((rtype (y2direct-constructor-result-type constructor)))
    (cond ((enum-adt? (find-supertype rtype))
           (y2direct-scalar-constant constructor))
          ((y2direct-datatype-type-p rtype)
           (y2direct-datatype-constructor-term constructor))
          (t
           (y2direct-global-term constructor)))))

(defun y2direct-recognizer-term (recognizer arg arg-expr source)
  (declare (ignore arg-expr))
  (let* ((constructor (constructor recognizer))
         (rtype (and constructor
                     (y2direct-constructor-result-type constructor))))
    (cond ((and rtype (enum-adt? (find-supertype rtype)))
          (y2/= arg (y2direct-scalar-constant constructor)))
          ((and rtype (y2direct-datatype-type-p rtype))
           (y2direct-register-datatype-term arg rtype)
           (y2/= (y2direct-datatype-tag rtype arg)
                 (y2direct-constructor-tag constructor)))
          (t
           (y2direct-apply (y2direct-term recognizer nil)
                           (list arg)
                           source)))))

(defun y2direct-emit-datatype-decomposition-axioms ()
  (dolist (entry *y2direct-datatype-terms*)
    (let* ((term (car entry))
           (ptype (cdr entry))
           (info (y2direct-datatype-info ptype))
           (tag (y2direct-datatype-tag ptype term)))
      (loop for constructor in (y2direct-datatype-info-constructors info)
            for tag-constant in (y2direct-datatype-info-tag-constants info)
            do (let* ((accessor-args
                       (mapcar #'(lambda (accessor)
                                   (y2direct-accessor-term accessor
                                                           term
                                                           constructor))
                               (accessors constructor)))
                      (constructor-symbol
                       (y2direct-datatype-constructor-term constructor))
                      (constructor-term
                       (y2direct-apply constructor-symbol
                                       accessor-args
                                       constructor)))
                 (y2direct-note-assertion
                  (y2/=>
                   (y2/= tag tag-constant)
                   (y2/= term constructor-term))))))))

(defun y2direct-emit-datatype-axioms ()
  ;; Constructor-tag and accessor axioms are emitted as constructor applications
  ;; are seen.  Decomposition closes observed datatype terms under the current
  ;; finite set of constructors, without quantified datatype axioms.
  (y2direct-emit-datatype-decomposition-axioms))

(defgeneric y2direct-type (type bindings))
(defgeneric y2direct-term (expr bindings))

(defmethod y2direct-type :around ((obj type-expr) bindings)
  (if bindings
      (call-next-method)
      (or (gethash obj *y2direct-type-cache*)
          (setf (gethash obj *y2direct-type-cache*)
                (call-next-method)))))

(defmethod y2direct-type ((ty type-name) bindings)
  (declare (ignore bindings))
  (let ((stype (find-supertype ty)))
    (cond ((y2direct-bitvector-type-p stype)
           (setq *y2direct-has-bitvectors?* t)
           (y2/bv-type (y2direct-bitvector-width stype)))
          ((enum-adt? stype)
           (y2direct-scalar-info-type (y2direct-scalar-info stype)))
          ((y2direct-datatype-type-p stype)
           (y2direct-datatype-info-yices-type
            (y2direct-datatype-info stype)))
          ((y2direct-boolean-type-p stype)
           (y2/bool-type))
          ((tc-eq stype *number*)
           (setq *y2direct-has-arithmetic?* t)
           (y2/real-type))
          ((adt? stype)
           (y2direct-datatype-info-yices-type
            (y2direct-datatype-info stype)))
          (t
           (or (gethash stype *y2direct-type-cache*)
               (setf (gethash stype *y2direct-type-cache*)
                     (y2direct-new-uninterpreted-type stype)))))))

(defmethod y2direct-type ((ty datatype-subtype) bindings)
  (declare (ignore bindings))
  (let ((stype (find-supertype ty)))
    (cond ((enum-adt? stype)
           (y2direct-scalar-info-type (y2direct-scalar-info stype)))
          ((y2direct-datatype-type-p stype)
           (y2direct-datatype-info-yices-type
            (y2direct-datatype-info stype)))
          (t
           (y2direct-type stype nil)))))

(defmethod y2direct-type ((ty subtype) bindings)
  (with-slots (supertype) ty
    (cond ((tc-eq ty *integer*)
           (setq *y2direct-has-arithmetic?* t)
           (y2/int-type))
          ((tc-eq ty *real*)
           (setq *y2direct-has-arithmetic?* t)
           (y2/real-type))
          (t
           (y2direct-type supertype bindings)))))

(defmethod y2direct-type ((ty tuple-or-struct-subtype) bindings)
  (y2direct-tuple-type
   (mapcar #'(lambda (type) (y2direct-type type bindings))
           (types ty))
   ty))

(defmethod y2direct-type ((ty record-or-struct-subtype) bindings)
  (y2direct-tuple-type
   (mapcar #'(lambda (field)
               (y2direct-type (y2direct-component-type (type field))
                              bindings))
           (y2direct-record-fields ty))
   ty))

(defmethod y2direct-type ((ty field-decl) bindings)
  (y2direct-type (type ty) bindings))

(defmethod y2direct-type ((ty dep-binding) bindings)
  (y2direct-type (type ty) bindings))

(defun y2direct-domain-types (domain bindings)
  (let* ((sdom (if (dep-binding? domain)
                   (find-supertype (type domain))
                   (find-supertype domain))))
    (if (typep sdom 'tuple-or-struct-subtype)
        (mapcar #'(lambda (type) (y2direct-type type bindings))
                (types sdom))
        (list (y2direct-type sdom bindings)))))

(defmethod y2direct-type ((ty funtype) bindings)
  (with-slots (domain range) ty
    (y2direct-function-type*
     (y2direct-domain-types domain bindings)
     (y2direct-type range bindings)
     ty)))

(defmethod y2direct-term :around ((obj expr) bindings)
  (if bindings
      (call-next-method)
      (or (gethash obj *y2direct-term-cache*)
          (let* ((result (call-next-method))
                 (type-constraints (type-constraints obj t))
                 (constraints
                  (loop for formula in type-constraints
                        when (not (forall-expr? formula))
                          nconc (and+ formula))))
            (setf (gethash obj *y2direct-term-cache*) result)
            (dolist (constraint constraints)
              (y2direct-note-guarded-assertion
               (y2direct-term constraint nil)))
            (when (type obj)
              (y2direct-register-datatype-term result (type obj)))
            result))))

(defun y2direct-bound-term (expr bindings)
  (cdr (assoc expr bindings :test #'same-declaration)))

(defun y2direct-global-key (expr)
  (or (ignore-errors (declaration expr))
      expr))

(defun y2direct-global-term (expr)
  (let ((key (y2direct-global-key expr)))
    (or (gethash key *y2direct-symbol-cache*)
        (let ((term (y2direct-new-uninterpreted-term
                     (y2direct-type (type expr) nil)
                     key
                     "sym")))
          (setf (gethash key *y2direct-symbol-cache*) term)
          (y2direct-register-model-entry expr term)
          term))))

(defmethod y2direct-term ((expr name-expr) bindings)
  (or (y2direct-bound-term expr bindings)
      (cond ((tc-eq expr *true*) (y2/true))
            ((tc-eq expr *false*) (y2/false))
            ((constructor? expr)
             (y2direct-constructor-term expr))
            (t
             (y2direct-global-term expr)))))

(defmethod y2direct-term ((expr rational-expr) bindings)
  (declare (ignore bindings))
  (let ((value (number expr)))
    (if (integerp value)
        (if (<= (- (expt 2 31)) value (1- (expt 2 31)))
            (y2/int32 value)
            (y2/int64 value))
        (y2/parse-rat (princ-to-string value)))))

(defmethod y2direct-term ((expr string-expr) bindings)
  (declare (ignore bindings))
  (y2/int32 (string->int (string-value expr))))

(defun y2direct-record-assignment (field expr)
  (let ((assignment
         (find (id field)
               (assignments expr)
               :key #'(lambda (assignment)
                        (id (caar (arguments assignment))))
               :test #'eq)))
    (or assignment
        (y2api-err "Missing record assignment for field ~a in ~a"
                   (id field) expr))))

(defmethod y2direct-term ((expr record-expr) bindings)
  (let* ((rtype (find-supertype (type expr)))
         (args
          (mapcar #'(lambda (field)
                      (y2direct-term
                       (expression (y2direct-record-assignment field expr))
                       bindings))
                  (y2direct-record-fields rtype))))
    (y2direct-tuple args expr)))

(defmethod y2direct-term ((expr tuple-expr) bindings)
  (y2direct-tuple
   (mapcar #'(lambda (arg) (y2direct-term arg bindings))
           (exprs expr))
   expr))

(defmethod y2direct-term ((expr branch) bindings)
  (let ((condition (y2direct-term (condition expr) bindings)))
    (y2/ite condition
            (let ((*y2direct-conditions*
                   (cons condition *y2direct-conditions*)))
              (y2direct-term (then-part expr) bindings))
            (let ((*y2direct-conditions*
                   (cons (y2/not condition) *y2direct-conditions*)))
              (y2direct-term (else-part expr) bindings)))))

(defmethod y2direct-term ((expr cases-expr) bindings)
  (y2direct-term (translate-cases-to-if expr) bindings))

(defmethod y2direct-term ((expr projection-expr) bindings)
  (let* ((id (make-new-variable '|x| expr))
         (yid (y2direct-new-uninterpreted-term
               (y2direct-type (domain (find-supertype (type expr))) bindings)
               id
               "projection_arg")))
    (y2direct-select yid (1+ (index expr)) expr)))

(defmethod y2direct-term ((expr projection-application) bindings)
  (with-slots (argument index) expr
    (let ((binding (and (variable? argument)
                        (assoc argument bindings :test #'same-declaration))))
      (if (and binding (consp (cdr binding)))
          (nth (1- index) (cdr binding))
          (y2direct-select
           (y2direct-term argument bindings)
           (1+ (index expr))
           expr)))))

(defmethod y2direct-term ((expr field-application) bindings)
  (with-slots (id argument) expr
    (let* ((rtype (find-supertype (type argument)))
           (index (y2direct-record-field-index id rtype)))
      (y2direct-select (y2direct-term argument bindings) index expr))))

(defun y2direct-direct-application-args (expr)
  (if (tuple-expr? (argument expr))
      (arguments expr)
      (list (argument expr))))

(defun y2direct-application-head-and-args (expr)
  (labels ((walk (term)
             (if (application? term)
                 (multiple-value-bind (head args)
                     (walk (operator term))
                   (values head
                           (append args
                                   (y2direct-direct-application-args term))))
                 (values term nil))))
    (walk expr)))

(defun y2direct-application-head (expr)
  (multiple-value-bind (head args)
      (y2direct-application-head-and-args expr)
    (declare (ignore args))
    head))

(defun y2direct-application-args (expr)
  (multiple-value-bind (head args)
      (y2direct-application-head-and-args expr)
    (declare (ignore head))
    args))

(defun y2direct-effective-application-args (expr)
  (loop for arg in (y2direct-application-args expr)
        append
        (let ((stype (find-supertype (type arg))))
          (if (typep stype 'tuple-or-struct-subtype)
              (loop for index from 1 to (length (types stype))
                    collect (make-projection-application index arg))
              (list arg)))))

(defun y2direct-application-arg-terms (expr bindings)
  (mapcar #'(lambda (arg) (y2direct-term arg bindings))
          (y2direct-effective-application-args expr)))

(defun y2direct-module-id (name)
  (and (name-expr? name)
       (ignore-errors
         (id (module-instance (resolution name))))))

(defun y2direct-bv-constant (width value source)
  (y2direct-check-term
   (%y2/yices_bvconst_uint32 width value)
   "Failed to build bitvector constant for ~a" source))

(defun y2direct-nat2bv-term (expr bindings)
  (let* ((operator (operator* expr))
         (actual (and (actuals (module-instance operator))
                      (expr (car (actuals (module-instance operator))))))
         (arg (args1 expr)))
    (when (and actual
               (number-expr? actual)
               (number-expr? arg))
      (y2direct-bv-constant
       (number actual)
       (number arg)
       expr))))

(defun y2direct-bv-extract-term (expr bindings)
  (let ((argument (argument expr)))
    (when (and (tuple-expr? argument)
               (tuple-expr? (cadr (exprs argument)))
               (number-expr? (car (exprs (cadr (exprs argument)))))
               (number-expr? (cadr (exprs (cadr (exprs argument))))))
      (y2direct-check-term
       (%y2/yices_bvextract
        (y2direct-term (car (exprs argument)) bindings)
        (number (car (exprs (cadr (exprs argument)))))
        (number (cadr (exprs (cadr (exprs argument))))))
       "Failed to build bitvector extraction for ~a" expr))))

(defun y2direct-bv-sign-extend-term (expr args arg-exprs)
  (let* ((bv (car (last args)))
         (bv-expr (car (last arg-exprs)))
         (source-width (and bv-expr
                            (y2direct-bitvector-width (type bv-expr))))
         (target-width (y2direct-bitvector-width (type expr))))
    (when (and source-width target-width (<= source-width target-width))
      (y2direct-check-term
       (%y2/yices_sign_extend bv (- target-width source-width))
       "Failed to build bitvector sign extension for ~a" expr))))

(defun y2direct-arithmetic-application (op-id args expr)
  (case op-id
    (+ (apply #'y2/+ args))
    (- (if (unary-application? expr)
           (y2/- (first args))
           (reduce #'y2/- (cdr args) :initial-value (car args))))
    (* (apply #'y2/* args))
    (/ (reduce #'y2// (cdr args) :initial-value (car args)))
    (< (y2/< (first args) (second args)))
    (<= (y2/<= (first args) (second args)))
    (> (y2/> (first args) (second args)))
    (>= (y2/>= (first args) (second args)))
    (otherwise nil)))

(defun y2direct-bitvector-application (op-id args expr)
  (case op-id
    (AND (apply #'y2/bvand args))
    (& (apply #'y2/bvand args))
    (OR (apply #'y2/bvor args))
    (NOT (y2/bvnot (first args)))
    (XOR (apply #'y2/bvxor args))
    (+ (reduce #'y2/bv+ (cdr args) :initial-value (car args)))
    (- (if (unary-application? expr)
           (y2/bvneg (first args))
           (reduce #'y2/bv- (cdr args) :initial-value (car args))))
    (* (reduce #'y2/bv* (cdr args) :initial-value (car args)))
    (< (y2/bv< (first args) (second args)))
    (<= (y2/bv<= (first args) (second args)))
    (> (y2/bv> (first args) (second args)))
    (>= (y2/bv>= (first args) (second args)))
    (|bv_slt| (y2/bvs< (first args) (second args)))
    (|bv_sle| (y2/bvs<= (first args) (second args)))
    (|bv_sgt| (y2/bvs> (first args) (second args)))
    (|bv_sge| (y2/bvs>= (first args) (second args)))
    (|bv_splus| (reduce #'y2/bv+ (cdr args) :initial-value (car args)))
    (|bv_stimes| (reduce #'y2/bv* (cdr args) :initial-value (car args)))
    (O (reduce #'(lambda (left right)
                   (y2direct-check-term
                    (%y2/yices_bvconcat2 left right)
                    "Failed to build bitvector concat for ~a" expr))
               (cdr args)
               :initial-value (car args)))
    (otherwise nil)))

(defmethod y2direct-term ((expr application) bindings)
  (let* ((operator (y2direct-application-head expr))
         (op-id (and (name-expr? operator) (id operator)))
         (module-id (y2direct-module-id operator))
         (raw-arg-exprs (y2direct-application-args expr))
         (raw-args (mapcar #'(lambda (arg) (y2direct-term arg bindings))
                           raw-arg-exprs))
         (flat-arg-exprs nil)
         (flat-args nil))
    (labels ((flat-arg-exprs ()
               (or flat-arg-exprs
                   (setf flat-arg-exprs
                         (y2direct-effective-application-args expr))))
             (flat-args ()
               (or flat-args
                   (setf flat-args
                         (mapcar #'(lambda (arg)
                                     (y2direct-term arg bindings))
                                 (flat-arg-exprs))))))
      (cond ((negation? expr)
             (y2/not (first raw-args)))
            ((conjunction? expr)
             (apply #'y2/and raw-args))
            ((disjunction? expr)
             (apply #'y2/or raw-args))
            ((implication? expr)
             (y2/=> (first raw-args) (second raw-args)))
            ((iff? expr)
             (y2/iff (first raw-args) (second raw-args)))
            ((equation? expr)
             (y2/= (first raw-args) (second raw-args)))
            ((disequation? expr)
             (y2//= (first raw-args) (second raw-args)))
            ((and (eq op-id '|rem|)
                  (eq module-id 'modulo_arithmetic))
             (y2/imod (second raw-args) (first raw-args)))
            ((and (eq op-id '|nat2bv|)
                  (y2direct-nat2bv-term expr bindings)))
            ((and (eq op-id '^)
                  (eq module-id '|bv_caret|)
                  (y2direct-bv-extract-term expr bindings)))
            ((and (eq op-id 'sign_extend)
                  (eq module-id '|bv_extend|)
                  (y2direct-bv-sign-extend-term expr raw-args raw-arg-exprs)))
            ((and (recognizer? operator) raw-args)
             (y2direct-recognizer-term operator
                                       (first raw-args)
                                       (first raw-arg-exprs)
                                       expr))
            ((constructor? operator)
             (let* ((arg-exprs (flat-arg-exprs))
                    (args (flat-args))
                    (constructor-term (y2direct-constructor-term operator))
                    (term (y2direct-apply constructor-term args expr)))
               (y2direct-register-constructor-app operator term args arg-exprs)))
            ((accessor? operator)
             (let ((term (y2direct-apply
                          (y2direct-term operator nil)
                          raw-args
                          expr)))
               (when (and raw-args raw-arg-exprs)
                 (y2direct-register-datatype-term (first raw-args)
                                                  (type (first raw-arg-exprs))))
               term))
            ((and (or (y2direct-bitvector-type-p (type expr))
                      (and raw-arg-exprs
                           (y2direct-bitvector-type-p
                            (type (first raw-arg-exprs)))))
                  (y2direct-bitvector-application op-id raw-args expr)))
            ((and (y2direct-arithmetic-type-p (type expr))
                  (y2direct-arithmetic-application op-id raw-args expr)))
            ((and (member op-id '(< <= > >=) :test #'eq)
                  raw-args)
             (or (y2direct-arithmetic-application op-id raw-args expr)
                 (y2direct-bitvector-application op-id raw-args expr)))
            (t
             (y2direct-apply (y2direct-term operator bindings)
                             (flat-args)
                             expr))))))

(defun y2direct-binding-variable (binding)
  (let ((var
         (y2direct-check-term
          (%y2/yices_new_variable (y2direct-type (type binding) nil))
          "Failed to create Yices2 bound variable for ~a" binding)))
    (y2direct-set-term-name var (y2direct-fresh-name binding "bound"))))

(defun y2direct-binding-setup (bindings env)
  (labels ((walk (remaining current-env vars)
             (if (null remaining)
                 (values (nreverse vars) current-env)
                 (let ((var (y2direct-binding-variable (car remaining))))
                   (walk (cdr remaining)
                         (acons (car remaining) var current-env)
                         (cons var vars))))))
    (walk bindings env nil)))

(defun y2direct-lambda-term (expr bindings)
  (multiple-value-bind (vars env)
      (y2direct-binding-setup (bindings expr) bindings)
    (y2direct-bind #'%y2/yices_lambda
                   vars
                   (y2direct-term (expression expr) env)
                   expr)))

(defun y2direct-forall-expanded (expr-bindings expression bindings)
  (cond (expr-bindings
         (let* ((binding (car expr-bindings))
                (btype (type binding))
                (below (simple-below? btype))
                (belowval (when below (pvseval-integer below)))
                (upto (simple-upto? btype))
                (uptoval (when upto (pvseval-integer upto)))
                (bound (or (and belowval (1- belowval)) uptoval))
                (rest-bindings (cdr expr-bindings)))
           (and bound
                (< bound *y2direct-quant-expand-limit*)
                (apply #'y2/and
                       (loop for i from 0 to bound
                             collect
                             (y2direct-forall-expanded
                              rest-bindings
                              expression
                              (acons binding (y2/int32 i) bindings)))))))
        (t
         (y2direct-term expression bindings))))

(defun y2direct-exists-expanded (expr-bindings expression bindings)
  (cond (expr-bindings
         (let* ((binding (car expr-bindings))
                (btype (type binding))
                (below (simple-below? btype))
                (belowval (when below (pvseval-integer below)))
                (upto (simple-upto? btype))
                (uptoval (when upto (pvseval-integer upto)))
                (bound (or (and belowval (1- belowval)) uptoval))
                (rest-bindings (cdr expr-bindings)))
           (and bound
                (< bound *y2direct-quant-expand-limit*)
                (apply #'y2/or
                       (loop for i from 0 to bound
                             collect
                             (y2direct-exists-expanded
                              rest-bindings
                              expression
                              (acons binding (y2/int32 i) bindings)))))))
        (t
         (y2direct-term expression bindings))))

(defmethod y2direct-term ((expr binding-expr) bindings)
  (cond ((lambda-expr? expr)
         (y2direct-lambda-term expr bindings))
        ((forall-expr? expr)
         (or (y2direct-forall-expanded (bindings expr)
                                       (expression expr)
                                       bindings)
             (y2api-err
              "Y2DIRECT is quantifier-free; cannot translate unbounded forall ~a"
              expr)))
        ((exists-expr? expr)
         (or (y2direct-exists-expanded (bindings expr)
                                       (expression expr)
                                       bindings)
             (y2api-err
              "Y2DIRECT is quantifier-free; cannot translate unbounded exists ~a"
              expr)))
        (t
         (y2api-err "Unsupported Yices2 direct binding expression ~a" expr))))

(defmethod y2direct-term ((expr forall-expr) bindings)
  (or (y2direct-forall-expanded (bindings expr)
                                (expression expr)
                                bindings)
      (call-next-method)))

(defmethod y2direct-term ((expr exists-expr) bindings)
  (or (y2direct-exists-expanded (bindings expr)
                                (expression expr)
                                bindings)
      (call-next-method)))

(defun y2direct-update-path (path value basis basis-type bindings source)
  (if (null path)
      (y2direct-term value bindings)
      (let ((stype (find-supertype basis-type)))
        (cond ((typep stype 'record-or-struct-subtype)
               (let* ((field (y2direct-record-field-decl (caar path) stype))
                      (index (y2direct-record-field-index field stype))
                      (selected (y2direct-select basis index source))
                      (updated (y2direct-update-path
                                (cdr path)
                                value
                                selected
                                (y2direct-component-type (type field))
                                bindings
                                source)))
                 (y2direct-tuple-update basis index updated source)))
              ((typep stype 'tuple-or-struct-subtype)
               (let* ((index (number (caar path)))
                      (selected (y2direct-select basis index source))
                      (updated (y2direct-update-path
                                (cdr path)
                                value
                                selected
                                (y2direct-component-type
                                 (nth (1- index) (types stype)))
                                bindings
                                source)))
                 (y2direct-tuple-update basis index updated source)))
              ((funtype? stype)
               (let* ((arg-terms
                       (mapcar #'(lambda (arg)
                                   (y2direct-term arg bindings))
                               (car path)))
                      (selected (y2direct-apply basis arg-terms source))
                      (updated (y2direct-update-path
                                (cdr path)
                                value
                                selected
                                (range stype)
                                bindings
                                source)))
                 (y2direct-function-update basis arg-terms updated source)))
              (t
               (y2api-err "Unsupported Yices2 direct update path ~a over ~a"
                          path stype))))))

(defmethod y2direct-term ((expr update-expr) bindings)
  (let ((basis (y2direct-term (expression expr) bindings))
        (basis-type (type (expression expr))))
    (dolist (assignment (assignments expr) basis)
      (setf basis
            (y2direct-update-path (arguments assignment)
                                  (expression assignment)
                                  basis
                                  basis-type
                                  bindings
                                  expr)))))

(defmethod y2direct-term ((expr t) bindings)
  (declare (ignore bindings))
  (y2api-err "Unsupported expression for Y2DIRECT: ~a" expr))

(defun y2direct-yices-value-term-string (term)
  (handler-case
      (let ((value-term (%y2/yices_get_value_as_term (y2/ensure-model) term)))
        (if (or (null value-term)
                (y2direct-null-term-p value-term))
            (y2/term-string term)
            (y2/term-string value-term)))
    (error ()
      (handler-case (y2/term-string term)
        (error () "<unavailable>")))))

(defun y2direct-model-scalar-index (term)
  (cffi:with-foreign-object (out :int32)
    (y2/check-code
     (%y2/yices_get_scalar_value (y2/ensure-model) term out)
     "Could not get scalar model value")
    (cffi:mem-ref out :int32)))

(defun y2direct-model-rational-string (term)
  (multiple-value-bind (num den)
      (y2/value-rational32 term)
    (if (= den 1)
        (princ-to-string num)
        (format nil "~d/~d" num den))))

(defun y2direct-model-bv-string (term width)
  (cffi:with-foreign-object (bits :int32 width)
    (y2/check-code
     (%y2/yices_get_bv_value (y2/ensure-model) term bits)
     "Could not get bitvector model value")
    (let ((value 0))
      (loop for i from 0 below width
            unless (zerop (cffi:mem-aref bits :int32 i))
              do (incf value (ash 1 i)))
      (format nil "nat2bv[~d](~d)" width value))))

(defun y2direct-constructor-pvs-name (constructor)
  (y2direct-pvs-string constructor))

(defun y2direct-model-scalar-string (term ptype)
  (let* ((constructors (y2direct-constructor-list ptype))
         (index (y2direct-model-scalar-index term))
         (constructor (and (<= 0 index)
                           (< index (length constructors))
                           (nth index constructors))))
    (if constructor
        (y2direct-constructor-pvs-name constructor)
        (format nil "<scalar:~d>" index))))

(defun y2direct-model-tuple-string (term types depth)
  (format nil "(~{~a~^, ~})"
          (loop for ptype in types
                for index from 1
                collect
                (y2direct-model-value-string
                 (y2direct-select term index ptype)
                 ptype
                 (1- depth)))))

(defun y2direct-model-record-string (term rtype depth)
  (format nil "(# ~{~a~^, ~} #)"
          (loop for field in (y2direct-record-fields rtype)
                for index from 1
                collect
                (format nil "~a := ~a"
                        (string-downcase (string (id field)))
                        (y2direct-model-value-string
                         (y2direct-select term index field)
                         (y2direct-component-type (type field))
                         (1- depth))))))

(defun y2direct-model-datatype-string (term ptype depth)
  (let* ((info (y2direct-datatype-info ptype))
         (tag-term (y2direct-datatype-tag ptype term))
         (tag-index (y2direct-model-scalar-index tag-term))
         (constructors (y2direct-datatype-info-constructors info))
         (constructor (and (<= 0 tag-index)
                           (< tag-index (length constructors))
                           (nth tag-index constructors))))
    (if constructor
        (let ((args
               (loop for accessor in (accessors constructor)
                     for atype = (range (find-supertype (type accessor)))
                     collect
                     (y2direct-model-value-string
                      (y2direct-accessor-term accessor term constructor)
                      atype
                      (1- depth)))))
          (if args
              (format nil "~a(~{~a~^, ~})"
                      (y2direct-constructor-pvs-name constructor)
                      args)
              (y2direct-constructor-pvs-name constructor)))
        (format nil "<datatype-tag:~d>" tag-index))))

(defun y2direct-model-value-string (term ptype &optional
                                         (depth *y2direct-model-depth*))
  (if (<= depth 0)
      (y2direct-yices-value-term-string term)
      (let ((stype (ignore-errors (find-supertype ptype))))
        (handler-case
            (cond ((and stype (y2direct-bitvector-type-p stype))
                   (y2direct-model-bv-string
                    term
                    (y2direct-bitvector-width stype)))
                  ((and stype (enum-adt? stype))
                   (y2direct-model-scalar-string term stype))
                  ((and stype (y2direct-datatype-type-p stype))
                   (y2direct-model-datatype-string term stype depth))
                  ((and stype (typep stype 'record-or-struct-subtype))
                   (y2direct-model-record-string term stype depth))
                  ((and stype (typep stype 'tuple-or-struct-subtype))
                   (y2direct-model-tuple-string term (types stype) depth))
                  ((and stype (y2direct-boolean-type-p stype))
                   (if (y2/value-bool term) "TRUE" "FALSE"))
                  ((and stype (y2direct-integer-type-p stype))
                   (princ-to-string (y2/value-int64 term)))
                  ((and stype (y2direct-real-type-p stype))
                   (y2direct-model-rational-string term))
                  (t
                   (y2direct-yices-value-term-string term)))
          (error ()
            (y2direct-yices-value-term-string term))))))

(defun y2direct-countermodel-lines ()
  (loop for entry in (reverse *y2direct-model-entries*)
        for expr = (y2direct-model-entry-expr entry)
        for term = (y2direct-model-entry-term entry)
        for ptype = (y2direct-model-entry-type entry)
        collect
        (format nil "~a = ~a"
                (y2direct-pvs-string expr)
                (y2direct-model-value-string term ptype))))

(defun y2direct-countermodel-string ()
  (let ((lines (y2direct-countermodel-lines)))
    (if lines
        (format nil "~{~%  ~a~}" lines)
        (format nil "~%  <no user-visible ground symbols>~%~a"
                (y2/model-string :height 200)))))

(defun y2direct-report-countermodel ()
  (let ((model (y2direct-countermodel-string)))
    (setf *y2direct-last-countermodel* model)
    (format-if "~%Y2DIRECT countermodel:~a" model)
    model))

(defun y2direct-assertion-term (sform)
  (let ((formula (formula sform)))
    (if (negation? formula)
        (y2direct-term (args1 formula) nil)
        (y2/not (y2direct-term formula nil)))))

(defun y2direct-numbered-sforms (sforms sformnums)
  (let ((nums (cleanup-fnums sformnums)))
    (loop with pos = 1
          with neg = -1
          for sform in sforms
          for negative? = (negation? (formula sform))
          for fnum = (if negative? neg pos)
          when (in-sformnums? sform pos neg nums)
            collect (cons fnum sform)
          do (if negative? (decf neg) (incf pos)))))

(defun y2direct-build-numbered-query (numbered-sforms)
  (let ((sform-assumptions
         (loop for (fnum . sform) in numbered-sforms
               collect
               (make-y2direct-sform-assumption
                :fnum fnum
                :sform sform
                :term (y2direct-assertion-term sform)))))
    (y2direct-emit-datatype-axioms)
    (values (nreverse *y2direct-assertions*) sform-assumptions)))

(defun y2direct-sform-assumption-terms (assumptions)
  (mapcar #'y2direct-sform-assumption-term assumptions))

(defun y2direct-sform-assumption-fnums (assumptions)
  (mapcar #'y2direct-sform-assumption-fnum assumptions))

(defun y2direct-term-vector-list (vector)
  (let ((size (cffi:foreign-slot-value vector '(:struct term_vector_t) 'size))
        (data (cffi:foreign-slot-value vector '(:struct term_vector_t) 'data)))
    (loop for i from 0 below size
          collect (cffi:mem-aref data 'term_t i))))

(defun y2direct-unsat-core-terms ()
  (cffi:with-foreign-object (vector '(:struct term_vector_t))
    (%y2/yices_init_term_vector vector)
    (unwind-protect
         (progn
           (y2/check-code
            (%y2/yices_get_unsat_core (y2/ensure-context) vector)
            "Could not get Yices2 unsat core")
           (y2direct-term-vector-list vector))
      (%y2/yices_delete_term_vector vector))))

(defun y2direct-unsat-core-fnums (sform-assumptions)
  (let ((table (make-hash-table :test #'eql)))
    (dolist (assumption sform-assumptions)
      (setf (gethash (y2direct-sform-assumption-term assumption) table)
            (y2direct-sform-assumption-fnum assumption)))
    (remove-duplicates
     (loop for term in (y2direct-unsat-core-terms)
           for fnum = (gethash term table)
           when fnum collect fnum)
     :test #'eql)))

(defun y2direct-format-fnums (fnums)
  (format nil "~{~a~^ ~}" fnums))

(defun y2direct-format-core-replay (hide-fnums)
  (if hide-fnums
      (format nil "(then (hide ~a) (y2direct))"
              (y2direct-format-fnums hide-fnums))
      "(y2direct)"))

(defun y2direct-effective-logic (nonlinear? requested-logic)
  (or requested-logic
      (cond (nonlinear? *y2direct-nonlinear-logic*)
            ((and *y2direct-has-bitvectors?*
                  *y2direct-has-arithmetic?*)
             *y2direct-mixed-logic*)
            (*y2direct-has-bitvectors?* *y2direct-bitvector-logic*)
            (*y2direct-has-arithmetic?* *y2direct-linear-logic*)
            (t *y2direct-default-logic*))))

(defun y2direct-selected-fnums (sform-assumptions)
  (remove-duplicates
   (y2direct-sform-assumption-fnums sform-assumptions)
   :test #'eql))

(defun y2direct-noncore-fnums (selected-fnums core-fnums)
  (loop for fnum in selected-fnums
        unless (member fnum core-fnums :test #'eql)
          collect fnum))

(defun y2direct (sformnums nonlinear? &optional logic (model? t))
  #'(lambda (ps)
      (let* ((goalsequent (current-goal ps))
             (numbered-sforms
              (y2direct-numbered-sforms (s-forms goalsequent) sformnums)))
        (clear-y2direct)
        (setf *y2direct-last-countermodel* nil)
        (multiple-value-bind (auxiliary-assumptions sform-assumptions)
            (y2direct-build-numbered-query numbered-sforms)
          (let ((effective-logic (y2direct-effective-logic nonlinear? logic)))
            (y2/with-solver (:logic effective-logic :mode "one-shot")
              (dolist (assumption auxiliary-assumptions)
                (y2/assert! assumption))
              (case (y2/check!
                     :assumptions
                     (y2direct-sform-assumption-terms sform-assumptions))
                (:unsat
                 (format-if "~%Y2DIRECT translation of negation is unsatisfiable")
                 (values '! nil nil))
                (:sat
                 (format-if "~%Y2DIRECT translation of negation is satisfiable")
                 (when model?
                   (y2direct-report-countermodel))
                 (values 'X nil nil))
                (otherwise
                 (format-if "~%Y2DIRECT result is unknown")
                 (values 'X nil nil)))))))))

(defun y2direct-hide-unsat-core (sformnums nonlinear? &optional logic)
  #'(lambda (ps)
      (let* ((goalsequent (current-goal ps))
             (numbered-sforms
              (y2direct-numbered-sforms (s-forms goalsequent) sformnums)))
        (clear-y2direct)
        (setf *y2direct-last-countermodel* nil
              *y2direct-last-unsat-core* nil
              *y2direct-last-unsat-core-hide* nil)
        (multiple-value-bind (auxiliary-assumptions sform-assumptions)
            (y2direct-build-numbered-query numbered-sforms)
          (let ((effective-logic (y2direct-effective-logic nonlinear? logic)))
            (y2/with-solver (:logic effective-logic :mode "push-pop")
              (dolist (assumption auxiliary-assumptions)
                (y2/assert! assumption))
              (case (y2/check!
                     :assumptions
                     (y2direct-sform-assumption-terms sform-assumptions))
                (:unsat
                 (let* ((selected-fnums
                         (y2direct-selected-fnums sform-assumptions))
                        (core-fnums
                         (or (y2direct-unsat-core-fnums sform-assumptions)
                             selected-fnums))
                        (hide-fnums
                         (y2direct-noncore-fnums selected-fnums core-fnums)))
                   (setf *y2direct-last-unsat-core* core-fnums
                         *y2direct-last-unsat-core-hide* hide-fnums)
	                   (format-if
	                    "~%Y2DIRECT unsat core: ~a"
	                    (y2direct-format-fnums core-fnums))
	                   (format-if
	                    "~%Y2DIRECT core replay: ~a"
	                    (y2direct-format-core-replay hide-fnums))
                   (if hide-fnums
                       (funcall (hide-step hide-fnums) ps)
                       (values '? (list goalsequent)))))
                (:sat
                 (format-if "~%Y2DIRECT core query is satisfiable")
                 (y2direct-report-countermodel)
                 (values 'X nil nil))
                (otherwise
                 (format-if "~%Y2DIRECT core query result is unknown")
                 (values 'X nil nil)))))))))

(addrule 'y2direct () ((fnums *) nonlinear? logic (model? t))
  (y2direct fnums nonlinear? logic model?)
  "Invokes the Yices2 C API as a direct, quantifier-free endgame solver."
  "~%Simplifying with direct Yices2,")

(addrule 'y2direct-core () ((fnums *) nonlinear? logic)
  (y2direct-hide-unsat-core fnums nonlinear? logic)
  "Computes a Yices2 unsat core for FNUMS and hides selected formulas outside the core."
  "~%Computing a direct Yices2 unsat core,")

(defstep y2direct-simp (&optional (fnums *) nonlinear? logic (model? t))
  (then (skosimp*) (y2direct :fnums fnums
                             :nonlinear? nonlinear?
                             :logic logic
                             :model? model?))
  "Repeatedly skolemizes and flattens, then invokes direct Yices2."
  "Repeatedly skolemizing and flattening, and invoking direct Yices2")

(defstep y2direct-core-simp (&optional (fnums *) nonlinear? logic)
  (then (skosimp*) (y2direct-core :fnums fnums
                                  :nonlinear? nonlinear?
                                  :logic logic)
        (y2direct :fnums * :nonlinear? nonlinear?
                  :logic logic
                  :model? nil))
  "Repeatedly skolemizes, computes a Yices2 unsat core, hides non-core formulas, then invokes direct Yices2."
  "Repeatedly skolemizing, hiding formulas outside the direct Yices2 core, and invoking direct Yices2")
