;;; -*- Mode: LISP; Syntax: Common-lisp; Package: VERSE -*-

;------------------------------------------------------------------------------
; PRMACROS - Macros for the prover subsystem
;------------------------------------------------------------------------------

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

(defmacro newcontext (form)
  `(let ((sigalist sigalist) (findalist findalist) (usealist usealist))
     (catch 'context 
       ,form )))

(defmacro retfalse () `(throw 'context 'false))

; term accessor macros

(defmacro funsym (term) `(car ,term))

(defmacro arg1 (term) `(cadr ,term))

(defmacro arg2 (term) `(caddr ,term))

(defmacro arg3 (term) `(cadddr ,term))

(defmacro argsof (term) `(cdr ,term))

(defmacro lside (term) `(cadr ,term))

(defmacro rside (term) `(caddr ,term))

; getq:
; (getq arg alist) returns the item associated with arg in alist, or nil.

(defmacro getq (arg alist) `(cdr (assq ,arg ,alist)))

(defun prerr (&rest args)
  (apply #'error args))

(alexandria:define-constant +truecons+ '(true) :test #'equal)

(alexandria:define-constant +eqarithrels+ '(greatereqp lesseqp) :test #'equal)

(alexandria:define-constant +ifops+ '(if if*) :test #'equal)

(alexandria:define-constant +boolconstants+ '(false true) :test #'equal)

(alexandria:define-constant +arithrels+ '(lessp lesseqp greaterp greatereqp) :test #'equal)

(alexandria:define-constant +arithops+ '(PLUS TIMES DIFFERENCE MINUS) :test #'equal)

(alexandria:define-constant +boolops+ '(and or implies not ;;if
				    iff) :test #'equal)

(defmacro singleton? (obj)
  `(and (consp ,obj) (null (cdr ,obj))))


(defun add2pot (atoms)
  (let ((atoms (nreverse atoms)))
    (loop for atom in atoms
	  when (not (and (bound-inequality? atom)
			 (subsumed-ineq-list? atom s)))
	  do (push atom s))))

(defmacro addneq2pot (atoms)
  `(add2pot ,atoms))

(defmacro addineq2pot (atoms)
  `(add2pot ,atoms))

(defmacro addprm2pot (atoms)
  `(add2pot ,atoms))

(defmacro arithlist (x)
  `(let ((xx ,x))
     (if (and (consp xx)
	   (qnumberp (car xx)))
      (cdr xx)
      xx)))
