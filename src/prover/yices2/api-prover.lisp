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
(defparameter *yices2-api-nonlinear-logic* "QF_UFNIRA")

(defvar *yices2-api-name-counter* nil)
(defvar *yices2-api-library-loaded* nil)
(defvar *yices2-api-type-cache* nil)
(defvar *yices2-api-symbol-cache* nil)
(defvar *yices2-api-name-cache* nil)
(defvar *yices2-api-last-status* nil)
(defvar *yices2-api-last-model* nil)
(defvar *yices2-api-last-counterexample* nil)
(defvar *yices2-api-last-unsat-core* nil)

(defstruct yices2-api-assumption
  term
  kind
  source
  label)

(declaim (ftype function
		yices2-api-type
		yices2-api-term
		yices2-api-assertion-term
		yices2-api-boolean-type-p
		yices2-api-integer-type-p
		yices2-api-real-type-p
		yices2-api-global-term-key))

(defun clear-yices2-api-last-results ()
  (setq *yices2-api-last-status* nil
	*yices2-api-last-model* nil
	*yices2-api-last-counterexample* nil
	*yices2-api-last-unsat-core* nil))

(defun reset-yices2-api-state ()
  (setq *yices2-api-type-cache* (make-pvs-hash-table)
        *yices2-api-symbol-cache* (make-pvs-hash-table)
        *yices2-api-name-cache* (make-pvs-hash-table))
  (newcounter *yices2-api-name-counter*))

(defun yices2-api-current-library-selection ()
  (or *yices2-foreign-library-selection* :default))

(defun yices2-api-current-library-path ()
  (let ((pathname (ignore-errors (cffi:foreign-library-pathname 'yices2))))
    (when pathname
      (namestring pathname))))

(defun yices2-api-unload-library ()
  (when *yices2-api-library-loaded*
    (ignore-errors (yices_exit)))
  (ignore-errors (cffi:close-foreign-library 'yices2))
  (setq *yices2-api-library-loaded* nil)
  (clear-yices2-api-last-results)
  t)

(defun ensure-yices2-api-library ()
  (unless (and *yices2-api-library-loaded*
               (ignore-errors (cffi:foreign-library-loaded-p 'yices2)))
    (cffi:load-foreign-library 'yices2)
    (yices_init)
    (setq *yices2-api-library-loaded* t)))

(defun yices2-api-library-summary-string ()
  (ensure-yices2-api-library)
  (format nil
          "Yices2 library selection: ~a~%Resolved library: ~a~%Version: ~a~%Build arch: ~a~%Build mode: ~a~%MCSAT support: ~:[disabled~;enabled~]"
          (if (eq (yices2-api-current-library-selection) :default)
              "default search (libyices)"
              (yices2-api-current-library-selection))
          (or (yices2-api-current-library-path) "unknown")
          (or yices_version "unknown")
          (or yices_build_arch "unknown")
          (or yices_build_mode "unknown")
          (> (yices_has_mcsat) 0)))

(defun yices2-api-show-library ()
  (format t "~%~a" (yices2-api-library-summary-string)))

(defun yices2-api-set-library (library)
  (yices2-api-unload-library)
  (configure-yices2-foreign-library library)
  (format t "~%Switched Yices2 API library.~%~a"
          (yices2-api-library-summary-string)))

(defun yices2-api-use-default-library ()
  (yices2-api-unload-library)
  (configure-yices2-foreign-library nil)
  (format t "~%Restored default Yices2 API library search.~%~a"
          (yices2-api-library-summary-string)))

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

(defun yices2-api-owned-string (ptr)
  (when (and ptr (not (cffi:null-pointer-p ptr)))
    (unwind-protect
	(cffi:foreign-string-to-lisp ptr)
      (yices_free_string ptr))))

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

(defun yices2-api-term-string (term &optional (width 120) (height 2000) (offset 2))
  (yices2-api-owned-string
   (yices2-api-check-pointer
    (yices_term_to_string term width height offset)
    "Failed to format Yices2 term ~a" term)))

(defun yices2-api-model-string (model &optional (width 120) (height 2000) (offset 2))
  (yices2-api-owned-string
   (yices2-api-check-pointer
    (yices_model_to_string model width height offset)
    "Failed to format Yices2 model")))

(defun yices2-api-term-vector-terms (vector-ptr)
  (let* ((size (cffi:foreign-slot-value vector-ptr '(:struct term_vector_t) 'size))
	 (data (cffi:foreign-slot-value vector-ptr '(:struct term_vector_t) 'data)))
    (loop for i from 0 below size
	  collect (cffi:mem-aref data 'term_t i))))

(defun yices2-api-pvs-string (obj)
  (cond ((typep obj 's-formula)
	 (unparse-sform obj))
	((typep obj 'syntax)
	 (unparse obj :string t :char-width most-positive-fixnum))
	(t
	 (format nil "~a" obj))))

(defun yices2-api-sort-by-pvs-string (objects)
  (sort objects #'string<
	:key #'yices2-api-pvs-string))

(defun yices2-api-assumption-description (assumption)
  (format nil "[~a] ~a"
	  (ecase (yices2-api-assumption-kind assumption)
	    (:goal "goal")
	    (:subtype "subtype"))
	  (or (yices2-api-assumption-label assumption)
	      (format nil "~a" (yices2-api-assumption-source assumption)))))

(defun yices2-api-assumption-expr (assumption)
  (let ((source (yices2-api-assumption-source assumption)))
    (if (typep source 's-formula)
	(formula source)
	source)))

(defun yices2-api-subtype-constraint-formulas (expr)
  (loop for fmla in (type-constraints expr t)
	when (not (forall-expr? fmla))
	  nconc (and+ fmla)))

(defun yices2-api-collect-subtype-constraint-formulas (objects)
  (let ((exprs nil)
	(constraints nil))
    (mapobject #'(lambda (obj)
		   (when (and (expr? obj)
			      (null (freevars obj)))
		     (unless (member obj exprs :test #'tc-eq)
		       (push obj exprs)
		       (dolist (constraint
				   (yices2-api-subtype-constraint-formulas obj))
			 (when (and (expr? constraint)
				    (null (freevars constraint))
				    (not (binding-expr? constraint)))
			   (pushnew constraint constraints :test #'tc-eq)))))
		   (binding-expr? obj))
	       objects)
    (nreverse constraints)))

(defun yices2-api-build-assumptions (sforms)
  (let ((seen-terms (make-hash-table :test #'eql))
	(assumptions nil))
    (labels ((register-assumption (term kind source)
	       (unless (gethash term seen-terms)
		 (setf (gethash term seen-terms) t)
		 (push (make-yices2-api-assumption
			:term term
			:kind kind
			:source source
			:label (yices2-api-pvs-string source))
		       assumptions))))
      (dolist (sf sforms)
	(register-assumption (yices2-api-assertion-term sf)
			     :goal
			     sf))
      (dolist (constraint
	       (yices2-api-collect-subtype-constraint-formulas sforms))
	(register-assumption (yices2-api-term constraint)
			     :subtype
			     constraint))
      (nreverse assumptions))))

(defun yices2-api-normalize-value-string (string)
  (cond ((null string) nil)
	((string= string "true") "TRUE")
	((string= string "false") "FALSE")
	(t string)))

(defun yices2-api-rational-string (num den)
  (if (= den 1)
      (format nil "~d" num)
      (format nil "~d/~d" num den)))

(defun yices2-api-double-string (value)
  (yices2-api-normalize-value-string
   (format nil "~,16g" value)))

(defun yices2-api-render-value-term (term)
  (cond ((= (yices_term_is_tuple term) 1)
	 (let ((arity (yices_term_num_children term)))
	   (format nil "(~{~a~^, ~})"
		   (loop for i from 0 below arity
			 collect
			 (yices2-api-render-value-term
			  (yices_term_child term i))))))
	((= (yices_term_is_bool term) 1)
	 (cffi:with-foreign-object (value :int32)
	   (if (>= (yices_bool_const_value term value) 0)
	       (if (zerop (cffi:mem-ref value :int32))
		   "FALSE"
		   "TRUE")
	       (yices2-api-normalize-value-string
		(yices2-api-term-string term)))))
	(t
	 (yices2-api-normalize-value-string
	  (yices2-api-term-string term)))))

(defun yices2-api-term-value-string (model term ptype)
  (cond ((yices2-api-boolean-type-p ptype)
	 (cffi:with-foreign-object (value :int32)
	   (if (>= (yices_get_bool_value model term value) 0)
	       (if (zerop (cffi:mem-ref value :int32))
		   "FALSE"
		   "TRUE")
	       (let ((value-term (yices_get_value_as_term model term)))
		 (and (/= value-term +yices-null-term+)
		      (yices2-api-render-value-term value-term))))))
	((yices2-api-integer-type-p ptype)
	 (cffi:with-foreign-object (value :int64)
	   (if (>= (yices_get_int64_value model term value) 0)
	       (format nil "~d" (cffi:mem-ref value :int64))
	       (let ((value-term (yices_get_value_as_term model term)))
		 (and (/= value-term +yices-null-term+)
		      (yices2-api-render-value-term value-term))))))
	((yices2-api-real-type-p ptype)
	 (or (cffi:with-foreign-object (num :int64)
	       (cffi:with-foreign-object (den :uint64)
		 (when (>= (yices_get_rational64_value model term num den) 0)
		   (yices2-api-rational-string
		    (cffi:mem-ref num :int64)
		    (cffi:mem-ref den :uint64)))))
	     (cffi:with-foreign-object (value :double)
	       (when (>= (yices_get_double_value model term value) 0)
		 (yices2-api-double-string
		  (cffi:mem-ref value :double))))
	     (let ((value-term (yices_get_value_as_term model term)))
	       (and (/= value-term +yices-null-term+)
		    (yices2-api-render-value-term value-term)))))
	(t
	 (let ((value-term (yices_get_value_as_term model term)))
	   (and (/= value-term +yices-null-term+)
		(yices2-api-render-value-term value-term))))))

(defun yices2-api-translated-global-name-expr-p (obj)
  (and (name-expr? obj)
       (null (freevars obj))
       (gethash (yices2-api-global-term-key obj) *yices2-api-symbol-cache*)))

(defun yices2-api-user-symbol-p (obj)
  (let ((decl (ignore-errors (declaration obj))))
    (and decl
	 (not (from-prelude? decl))
	 (not (from-prelude-library? decl)))))

(defun yices2-api-collect-model-vars (assumptions)
  (let ((vars nil))
    (dolist (assumption assumptions)
      (mapobject #'(lambda (obj)
		     (when (yices2-api-translated-global-name-expr-p obj)
		       (pushnew obj vars :test #'same-declaration))
		     (binding-expr? obj))
		 (yices2-api-assumption-expr assumption)))
    (yices2-api-sort-by-pvs-string vars)))

(defun yices2-api-collect-observed-applications (assumptions function-vars)
  (let ((applications nil))
    (when function-vars
      (dolist (assumption assumptions)
	(mapobject #'(lambda (obj)
		       (when (and (application? obj)
				  (let ((op (operator* obj)))
				    (and (name-expr? op)
					 (member op function-vars
						 :test #'same-declaration))))
			 (pushnew obj applications :test #'tc-eq))
		       (binding-expr? obj))
		   (yices2-api-assumption-expr assumption))))
    (yices2-api-sort-by-pvs-string applications)))

(defun yices2-api-format-model (assumptions model)
  (let* ((vars (remove-if-not #'yices2-api-user-symbol-p
			      (yices2-api-collect-model-vars assumptions)))
	 (function-vars
	  (remove-if-not #'(lambda (var)
			     (funtype? (find-supertype (type var))))
			 vars))
	 (plain-vars
	  (remove-if #'(lambda (var)
			 (funtype? (find-supertype (type var))))
		     vars))
	 (observed-applications
	  (yices2-api-collect-observed-applications assumptions function-vars)))
    (with-output-to-string (out)
      (cond ((and (null plain-vars)
		  (null function-vars)
		  (null observed-applications))
	     (format out "Model in PVS terms is unavailable.~%Raw Yices2 model:~%~a"
		     (yices2-api-model-string model)))
	    (t
	     (format out "Model in PVS terms:~%")
	     (dolist (var plain-vars)
	       (format out "  ~a = ~a~%"
		       (yices2-api-pvs-string var)
		       (or (yices2-api-term-value-string
			    model (yices2-api-term var) (type var))
			   "<unavailable>")))
	     (when (and function-vars (null observed-applications))
	       (dolist (var function-vars)
		 (format out "  ~a = ~a~%"
			 (yices2-api-pvs-string var)
			 (or (yices2-api-term-value-string
			      model (yices2-api-term var) (type var))
			     "<unavailable>"))))
	     (when observed-applications
	       (format out "Observed applications:~%")
	       (dolist (expr observed-applications)
		 (format out "  ~a = ~a~%"
			 (yices2-api-pvs-string expr)
			 (or (yices2-api-term-value-string
			      model (yices2-api-term expr) (type expr))
			     "<unavailable>")))))))))

(defun yices2-api-format-counterexample (assumptions model-string)
  (let ((goal-assumptions
	 (remove-if-not #'(lambda (assumption)
			    (eq (yices2-api-assumption-kind assumption) :goal))
			assumptions))
	(subtype-count
	 (count :subtype assumptions :key #'yices2-api-assumption-kind)))
    (with-output-to-string (out)
      (format out "Counterexample to the selected formulas:~%")
      (dolist (assumption goal-assumptions)
	(format out "  ~a~%" (yices2-api-assumption-description assumption)))
      (when (> subtype-count 0)
	(format out "Subtype constraints asserted: ~d~%" subtype-count))
      (when model-string
	(format out "~a" model-string)))))

(defun yices2-api-format-unsat-core (core-terms assumptions)
  (let ((assumption-table (make-hash-table :test #'eql)))
    (dolist (assumption assumptions)
      (setf (gethash (yices2-api-assumption-term assumption) assumption-table)
	    assumption))
    (with-output-to-string (out)
      (if core-terms
	  (progn
	    (format out "UNSAT core:~%")
	    (dolist (term core-terms)
	      (let ((assumption (gethash term assumption-table)))
		(format out "  ~a~%"
			(if assumption
			    (yices2-api-assumption-description assumption)
			    (yices2-api-term-string term))))))
	  (format out "UNSAT core is empty.")))))

(defun yices2-api-show-last-model ()
  (if *yices2-api-last-model*
      (format t "~%~a" *yices2-api-last-model*)
      (format t "~%No Yices2 API model is available."))
  nil)

(defun yices2-api-show-last-counterexample ()
  (if *yices2-api-last-counterexample*
      (format t "~%~a" *yices2-api-last-counterexample*)
      (format t "~%No Yices2 API counterexample is available."))
  nil)

(defun yices2-api-show-last-unsat-core ()
  (if *yices2-api-last-unsat-core*
      (format t "~%~a" *yices2-api-last-unsat-core*)
      (format t "~%No Yices2 API UNSAT core is available."))
  nil)

(defun yices2-api-context-settings (nonlinear?)
  (if nonlinear?
      (progn
	(unless (> (yices_has_mcsat) 0)
	  (error "Current Yices2 library does not provide the MCSAT solver.~%~a"
		 (yices2-api-library-summary-string)))
	(values *yices2-api-nonlinear-logic* "mcsat"))
      (values *yices2-api-logic* nil)))

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

(defun yices2-api-run (ps sformnums &optional nonlinear?)
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
              (clear-yices2-api-last-results)
              (unwind-protect
                  (progn
                    (setq config
                          (yices2-api-check-pointer
                           (yices_new_config)
                           "Failed to allocate a Yices2 context configuration"))
		    (multiple-value-bind (logic solver-type)
			(yices2-api-context-settings nonlinear?)
		      (yices2-api-check-code
		       (yices_default_config_for_logic config logic)
		       "Failed to initialize Yices2 for logic ~a"
		       logic)
		      (yices2-api-check-code
		       (yices_set_config config "mode" "one-shot")
		       "Failed to configure Yices2 one-shot mode")
		      (when solver-type
			(yices2-api-check-code
			 (yices_set_config config "solver-type" solver-type)
			 "Failed to configure the Yices2 solver type ~a"
			 solver-type)))
                    (setq context
                          (yices2-api-check-pointer
                           (yices_new_context config)
                           "Failed to allocate a Yices2 context"))
                    (let ((assumptions (yices2-api-build-assumptions sforms)))
		      (cffi:with-foreign-object
			  (array 'term_t (length assumptions))
			(loop for assumption in assumptions
			      for i from 0
			      do (setf (cffi:mem-aref array 'term_t i)
				       (yices2-api-assumption-term assumption)))
			(let ((status
			       (yices_check_context_with_assumptions
				context (cffi:null-pointer)
				(length assumptions) array)))
                      (cond ((= status +yices-status-unsat+)
			     (setq *yices2-api-last-status* :unsat)
			     (cffi:with-foreign-object
				 (core '(:struct term_vector_t))
			       (yices_init_term_vector core)
			       (unwind-protect
				   (let* ((code
					   (yices_get_unsat_core context core))
					  (core-terms
					   (progn
					     (yices2-api-check-code
					      code
					      "Failed to get the Yices2 UNSAT core")
					     (yices2-api-term-vector-terms core)))
					  (core-string
					   (yices2-api-format-unsat-core
					    core-terms assumptions)))
				     (setq *yices2-api-last-unsat-core*
					   core-string)
				     (format t "~%~a" core-string))
				 (yices_delete_term_vector core)))
                             (values '! nil nil))
                            ((= status +yices-status-sat+)
			     (let ((model
				    (yices2-api-check-pointer
				     (yices_get_model context 1)
				     "Failed to get the Yices2 model"))
				   model-string
				   counterexample-string)
			       (unwind-protect
				   (progn
				     (setq model-string
					   (yices2-api-format-model
					    assumptions model))
				     (setq counterexample-string
					   (yices2-api-format-counterexample
					    assumptions model-string)))
				 (when model
				   (yices_free_model model)))
			       (setq *yices2-api-last-status* :sat
				     *yices2-api-last-model* model-string
				     *yices2-api-last-counterexample*
				     counterexample-string)
			       (format t "~%~a" counterexample-string))
                             (values 'X nil nil))
                            ((= status +yices-status-unknown+)
			     (setq *yices2-api-last-status* :unknown)
                             (format t "~%Yices2 API translation returned unknown.")
                             (values 'X nil nil))
                            ((= status +yices-status-interrupted+)
			     (setq *yices2-api-last-status* :interrupted)
                             (format t "~%Yices2 API proof attempt was interrupted.")
                             (values 'X nil nil))
                            ((= status +yices-status-error+)
			     (setq *yices2-api-last-status* :error)
                             (yices2-api-error "Yices2 returned an error status")
                             (values 'X nil nil))
                            (t
			     (setq *yices2-api-last-status* :error)
                             (format t "~%Yices2 API returned unexpected status ~a." status)
                             (values 'X nil nil)))))))
                (when context
                  (yices_free_context context))
                (when config
                  (yices_free_config config))
                (yices_reset)))
          (error (condition)
            (format t "~%Yices2 API prover failed: ~a" condition)
            (values 'X nil nil))))))

(defun yices2-api-dispatch (sformnums &optional nonlinear?)
  #'(lambda (ps)
      (yices2-api-run ps sformnums nonlinear?)))
