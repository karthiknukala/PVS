;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sal-pp.lisp -- Pretty-printer for the SAL CLOS abstract syntax tree
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

;;; This is the CLOS counterpart of SAL 3.3's sal-pretty-printer.scm.  It
;;; emits official SAL concrete syntax and uses Common Lisp's pretty-printing
;;; streams for line breaking and indentation.

(in-package :pvs)

(export '(sal-pp sal-pp-to-string write-sal-file))

(defvar *sal-pp-print-qualified-names* t)

(defgeneric sal-pp* (object stream precedence)
  (:documentation
   "Write OBJECT in SAL concrete syntax to STREAM.
PRECEDENCE is the precedence of the surrounding expression."))

(defgeneric sal-infix-precedence (application))

(defmethod sal-infix-precedence ((application sal-infix-application))
  (declare (ignore application))
  50)

(defmethod sal-infix-precedence ((application sal-iff))
  (declare (ignore application))
  10)

(defmethod sal-infix-precedence ((application sal-eq))
  (declare (ignore application))
  10)

(defmethod sal-infix-precedence ((application sal-diseq))
  (declare (ignore application))
  15)

(defmethod sal-infix-precedence ((application sal-xor))
  (declare (ignore application))
  15)

(defmethod sal-infix-precedence ((application sal-implies))
  (declare (ignore application))
  20)

(defmethod sal-infix-precedence ((application sal-or))
  (declare (ignore application))
  30)

(defmethod sal-infix-precedence ((application sal-and))
  (declare (ignore application))
  40)

(defmethod sal-infix-precedence ((application sal-arith-relation))
  (declare (ignore application))
  60)

(defmethod sal-infix-precedence ((application sal-add))
  (declare (ignore application))
  80)

(defmethod sal-infix-precedence ((application sal-sub))
  (declare (ignore application))
  80)

(defmethod sal-infix-precedence ((application sal-mul))
  (declare (ignore application))
  90)

(defmethod sal-infix-precedence ((application sal-div))
  (declare (ignore application))
  90)

(defmethod sal-infix-precedence ((application sal-idiv))
  (declare (ignore application))
  90)

(defmethod sal-infix-precedence ((application sal-mod))
  (declare (ignore application))
  90)

(defun sal-pp-with-options (object stream
                            &key (right-margin 100) (qualified-names t))
  (let ((*print-pretty* t)
        (*print-right-margin* right-margin)
        (*sal-pp-print-qualified-names* qualified-names))
    (pprint-logical-block (stream nil)
      (sal-pp* object stream 0)))
  object)

(defun sal-pp (object &rest arguments)
  "Pretty-print OBJECT in SAL concrete syntax to STREAM and return OBJECT.

RIGHT-MARGIN controls line wrapping.  When QUALIFIED-NAMES is true, external
context qualifiers are retained.  STREAM defaults to *STANDARD-OUTPUT* and may
be omitted when supplying keyword arguments."
  (let ((stream (if (and arguments (not (keywordp (first arguments))))
                    (pop arguments)
                    *standard-output*)))
    (apply #'sal-pp-with-options object stream arguments)))

(defun sal-pp-to-string (object &key (right-margin 100)
                                     (qualified-names t))
  "Return OBJECT pretty-printed in SAL concrete syntax."
  (with-output-to-string (stream)
    (sal-pp object stream
            :right-margin right-margin
            :qualified-names qualified-names)))

(defun write-sal-file (object path &key (right-margin 100)
                                        (qualified-names t)
                                        (if-exists :supersede))
  "Pretty-print OBJECT as SAL concrete syntax into PATH and return PATH."
  (with-open-file (stream path :direction :output
                               :if-does-not-exist :create
                               :if-exists if-exists)
    (sal-pp object stream
            :right-margin right-margin
            :qualified-names qualified-names)
    (terpri stream))
  path)

;;; Basic output utilities

(defun sal-pp-separated (objects stream separator
                         &key (precedence 0) (break-kind :fill))
  (loop for object in objects
        for firstp = t then nil
        unless firstp
          do (write-string separator stream)
             (pprint-newline break-kind stream)
        do (sal-pp* object stream precedence)))

(defun sal-pp-enclosed-list (objects stream open close
                             &key (separator ", ") (precedence 0))
  (write-string open stream)
  (pprint-logical-block (stream nil)
    (pprint-indent :block 1 stream)
    (sal-pp-separated objects stream separator :precedence precedence))
  (write-string close stream))

(defun sal-identifier-text (identifier)
  (let ((value (name identifier)))
    (etypecase value
      (symbol (symbol-name value))
      (string value))))

(defun sal-name-reference-text (reference)
  (sal-identifier-text (id (decl reference))))

(defun sal-context-reference-text (reference)
  (sal-identifier-text (id reference)))

(defun sal-pp-context-reference (context-reference actual-parameters stream)
  (write-string (sal-context-reference-text context-reference) stream)
  (when actual-parameters
    (sal-pp-enclosed-list actual-parameters stream "{" "}")))

(defun sal-application-arguments (application)
  (let ((argument (arg application)))
    (if (typep argument 'sal-arg-tuple-literal)
        (exprs argument)
        (list argument))))

(defun sal-pp-binary (left operator right stream
                      &key (precedence 0) (break-kind :fill))
  (pprint-logical-block (stream nil)
    (sal-pp* left stream precedence)
    (write-char #\Space stream)
    (write-string operator stream)
    (write-char #\Space stream)
    (pprint-indent :current 0 stream)
    (pprint-newline break-kind stream)
    (sal-pp* right stream precedence)))

(defun sal-pp-bindings (bindings stream)
  (sal-pp-enclosed-list bindings stream "(" ")"))

(defun sal-pp-multibind (operator bindings body stream)
  (pprint-logical-block (stream nil)
    (write-string operator stream)
    (write-char #\Space stream)
    (sal-pp-bindings bindings stream)
    (write-string ": " stream)
    (pprint-indent :block 2 stream)
    (pprint-newline :fill stream)
    (sal-pp* body stream 0)))

(defun sal-pp-state-variables (variables stream)
  (dolist (variable variables)
    (pprint-newline :mandatory stream)
    (sal-pp* variable stream 0)))

(defun sal-pp-section (label definitions commands stream)
  (when (or definitions commands)
    (pprint-newline :mandatory stream)
    (pprint-logical-block (stream nil)
      (write-string label stream)
      (pprint-indent :block 2 stream)
      (loop for remaining on definitions
            do (pprint-newline :mandatory stream)
               (sal-pp* (first remaining) stream 0)
               (when (rest remaining)
                 (write-char #\; stream)))
      (when commands
        (when definitions
          (write-char #\; stream))
        (pprint-newline :mandatory stream)
        (sal-pp* commands stream 0)))))

(defun sal-symmetric-type-size (object)
  (let ((upper-bound (upper object)))
    (if (and (typep upper-bound 'sal-sub)
             (= (length (sal-application-arguments upper-bound)) 2)
             (typep (second (sal-application-arguments upper-bound))
                    'sal-numeral)
             (= (sal-num (second (sal-application-arguments upper-bound))) 1))
        (first (sal-application-arguments upper-bound))
        upper-bound)))

(defun sal-set-list-elements (set-expression)
  (labels ((collect-elements (expression)
             (cond ((typep expression 'sal-or)
                    (mapcan #'collect-elements
                            (sal-application-arguments expression)))
                   ((typep expression 'sal-eq)
                    (let ((arguments (sal-application-arguments expression)))
                      (and (= (length arguments) 2)
                           (list (second arguments)))))
                   (t nil))))
    (collect-elements (expr set-expression))))

;;; Primitive values and names

(defmethod sal-pp* ((object null) stream precedence)
  (declare (ignore precedence))
  (write-string "FALSE" stream))

(defmethod sal-pp* ((object symbol) stream precedence)
  (declare (ignore precedence))
  (write-string (symbol-name object) stream))

(defmethod sal-pp* ((object string) stream precedence)
  (declare (ignore precedence))
  (write-string object stream))

(defmethod sal-pp* ((object integer) stream precedence)
  (declare (ignore precedence))
  (princ object stream))

(defmethod sal-pp* ((object ratio) stream precedence)
  (declare (ignore precedence))
  (format stream "~d/~d" (numerator object) (denominator object)))

(defmethod sal-pp* ((object sal-identifier) stream precedence)
  (declare (ignore precedence))
  (write-string (sal-identifier-text object) stream))

(defmethod sal-pp* ((object sal-name-ref) stream precedence)
  (declare (ignore precedence))
  (write-string (sal-name-reference-text object) stream))

(defmethod sal-pp* ((object sal-qualified-name-ref) stream precedence)
  (declare (ignore precedence))
  (let ((context-reference (context-ref object)))
    (when (and *sal-pp-print-qualified-names* context-reference)
      (sal-pp-context-reference context-reference (actuals object) stream)
      (write-char #\! stream))
    (write-string (sal-name-reference-text object) stream)))

(defmethod sal-pp* ((object sal-numeral) stream precedence)
  (declare (ignore precedence))
  (let ((number (sal-num object)))
    (if (rationalp number)
        (if (= (denominator number) 1)
            (princ (numerator number) stream)
            (format stream "~d/~d" (numerator number) (denominator number)))
        (princ number stream))))

(defmethod sal-pp* ((object sal-string-expr) stream precedence)
  (declare (ignore precedence))
  (write (sal-string object) :stream stream :escape t))

;;; Declarations and contexts

(defmethod sal-pp* ((object sal-decl) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (id object) stream 0))

(defmethod sal-pp* ((object sal-type-param-decl) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (id object) stream 0)
  (write-string ": TYPE" stream))

(defmethod sal-pp* ((object sal-var-decl) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (id object) ":" (type object) stream))

(defmethod sal-pp* ((object sal-let-decl) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp-binary (id object) ":" (type object) stream)
    (write-string " = " stream)
    (pprint-newline :fill stream)
    (sal-pp* (value object) stream 0)))

(defmethod sal-pp* ((object sal-constant-decl) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp* (id object) stream 0)
    (write-string ": " stream)
    (sal-pp* (type object) stream 0)
    (when (value object)
      (write-string " = " stream)
      (pprint-indent :block 2 stream)
      (pprint-newline :fill stream)
      (sal-pp* (value object) stream 0))))

(defmethod sal-pp* ((object sal-type-decl) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp* (id object) stream 0)
    (write-string ": TYPE" stream)
    (when (type object)
      (write-string " = " stream)
      (pprint-indent :block 2 stream)
      (pprint-newline :fill stream)
      (sal-pp* (type object) stream 0))))

(defmethod sal-pp* ((object sal-parametric-module) stream precedence)
  (sal-pp* (module object) stream precedence))

(defmethod sal-pp* ((object sal-module-decl) stream precedence)
  (declare (ignore precedence))
  (let ((parameterized-module (parametric-module object)))
    (pprint-logical-block (stream nil)
      (sal-pp* (id object) stream 0)
      (when (local-decls parameterized-module)
        (sal-pp-enclosed-list (local-decls parameterized-module)
                              stream "[" "]"))
      (write-string ": MODULE =" stream)
      (pprint-indent :block 2 stream)
      (pprint-newline :mandatory stream)
      (sal-pp* parameterized-module stream 0))))

(defmethod sal-pp* ((object sal-context-name-decl) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (id object) stream 0)
  (write-string ": CONTEXT = " stream)
  (sal-pp-context-reference (context-ref object) (actuals object) stream))

(defmethod sal-pp* ((object sal-assertion-decl) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp* (id object) stream 0)
    (write-string ": " stream)
    (sal-pp* (kind object) stream 0)
    (write-char #\Space stream)
    (pprint-indent :block 2 stream)
    (pprint-newline :fill stream)
    (sal-pp* (assertion-expr object) stream 0)))

(defmethod sal-pp* ((object sal-context) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp* (id object) stream 0)
    (when (params object)
      (sal-pp-enclosed-list (params object) stream "{" "}"))
    (write-string ": CONTEXT =" stream)
    (pprint-newline :mandatory stream)
    (write-string "BEGIN" stream)
    (pprint-indent :block 2 stream)
    (dolist (declaration (remove-if (lambda (item)
                                      (typep item 'sal-implicit-decl))
                                    (declarations object)))
      (pprint-newline :mandatory stream)
      (sal-pp* declaration stream 0)
      (write-char #\; stream))
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (write-string "END" stream)))

;;; Types

(defmethod sal-pp* ((object sal-function-type) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-char #\[ stream)
    (sal-pp* (domain object) stream 0)
    (write-string " -> " stream)
    (pprint-newline :fill stream)
    (sal-pp* (range object) stream 0)
    (write-char #\] stream)))

(defmethod sal-pp* ((object sal-array-type) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "ARRAY " stream)
    (sal-pp* (domain object) stream 0)
    (write-string " OF " stream)
    (pprint-newline :fill stream)
    (sal-pp* (range object) stream 0)))

(defmethod sal-pp* ((object sal-tuple-type) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (types object) stream "[" "]"))

(defmethod sal-pp* ((object sal-domain-tuple-type) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (types object) stream "[" "]"))

(defmethod sal-pp* ((object sal-record-type) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (fields object) stream "[# " " #]"))

(defmethod sal-pp* ((object sal-field) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (id object) ":" (type object) stream))

(defmethod sal-pp* ((object sal-subtype) stream precedence)
  (sal-pp* (expr object) stream precedence))

(defmethod sal-pp* ((object sal-subrange) stream precedence)
  (declare (ignore precedence))
  (write-char #\[ stream)
  (sal-pp* (lower object) stream 0)
  (write-string ".." stream)
  (sal-pp* (upper object) stream 0)
  (write-char #\] stream))

(defmethod sal-pp* ((object sal-scalar-set-type) stream precedence)
  (declare (ignore precedence))
  (write-string "SCALARSET(" stream)
  (sal-pp* (sal-symmetric-type-size object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-ring-set-type) stream precedence)
  (declare (ignore precedence))
  (write-string "RINGSET(" stream)
  (sal-pp* (sal-symmetric-type-size object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-scalar-type) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (scalar-elements object) stream "{" "}"))

(defun sal-pp-constructor (constructor stream)
  (let* ((declaration (decl constructor))
         (constructor-accessors (accessors declaration)))
    (sal-pp* (id declaration) stream 0)
    (when constructor-accessors
      (write-char #\( stream)
      (loop for accessor in constructor-accessors
            for firstp = t then nil
            unless firstp
              do (write-string ", " stream)
                 (pprint-newline :fill stream)
            do (let* ((accessor-declaration (decl accessor))
                      (accessor-type (type accessor-declaration)))
                 (sal-pp* (id accessor-declaration) stream 0)
                 (write-string ": " stream)
                 (sal-pp* (if (typep accessor-type 'sal-function-type)
                              (range accessor-type)
                              accessor-type)
                          stream 0)))
      (write-char #\) stream))))

(defmethod sal-pp* ((object sal-data-type) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "DATATYPE" stream)
    (pprint-indent :block 2 stream)
    (loop for constructor in (constructors object)
          for firstp = t then nil
          do (if firstp
                 (pprint-newline :mandatory stream)
                 (progn
                   (write-char #\, stream)
                   (pprint-newline :mandatory stream)))
             (sal-pp-constructor constructor stream))
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (write-string "END" stream)))

(defmethod sal-pp* ((object sal-state-type) stream precedence)
  (declare (ignore precedence))
  (write-string "STATE(" stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

;;; Expressions

(defmethod sal-pp* ((object sal-definition-expression) stream precedence)
  (sal-pp* (expr object) stream precedence))

(defmethod sal-pp* ((object sal-application) stream precedence)
  (let ((arguments (sal-application-arguments object)))
    (if (and (typep object 'sal-infix-application)
             (> (length arguments) 1))
        (let* ((own-precedence (sal-infix-precedence object))
               (parenthesize (< own-precedence precedence)))
          (when parenthesize (write-char #\( stream))
          (pprint-logical-block (stream nil)
            (loop for argument in arguments
                  for firstp = t then nil
                  unless firstp
                    do (write-char #\Space stream)
                       (sal-pp* (fun object) stream 0)
                       (write-char #\Space stream)
                       (pprint-newline :fill stream)
                  do (sal-pp* argument stream (1+ own-precedence))))
          (when parenthesize (write-char #\) stream)))
        (progn
          (unless (typep (fun object) 'sal-name-expr)
            (write-char #\( stream))
          (sal-pp* (fun object) stream 100)
          (unless (typep (fun object) 'sal-name-expr)
            (write-char #\) stream))
          (sal-pp-enclosed-list arguments stream "(" ")")))))

(defmethod sal-pp* ((object sal-in) stream precedence)
  (sal-pp-binary (arg object) "IN" (fun object) stream
                 :precedence precedence))

(defmethod sal-pp* ((object sal-lambda) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multibind "LAMBDA" (local-decls object) (expr object) stream))

(defmethod sal-pp* ((object sal-for-all-expr) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multibind "FORALL" (local-decls object) (expr object) stream))

(defmethod sal-pp* ((object sal-exists-expr) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multibind "EXISTS" (local-decls object) (expr object) stream))

(defmethod sal-pp* ((object sal-set-list-expr) stream precedence)
  (declare (ignore precedence))
  (let ((elements (sal-set-list-elements object)))
    (if elements
        (sal-pp-enclosed-list elements stream "{" "}")
        (call-next-method))))

(defmethod sal-pp* ((object sal-set-pred-expr) stream precedence)
  (declare (ignore precedence))
  (write-char #\{ stream)
  (sal-pp* (first (local-decls object)) stream 0)
  (write-string " | " stream)
  (pprint-newline :fill stream)
  (sal-pp* (expr object) stream 0)
  (write-char #\} stream))

(defmethod sal-pp* ((object sal-let-expr) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "(LET " stream)
    (sal-pp-separated (local-decls object) stream ", ")
    (pprint-indent :block 2 stream)
    (pprint-newline :mandatory stream)
    (write-string "IN " stream)
    (sal-pp* (expr object) stream 0)
    (write-char #\) stream)))

(defmethod sal-pp* ((object sal-array-literal) stream precedence)
  (declare (ignore precedence))
  (write-string "[[" stream)
  (sal-pp* (first (local-decls object)) stream 0)
  (write-string "] " stream)
  (pprint-newline :fill stream)
  (sal-pp* (expr object) stream 0)
  (write-string "]" stream))

(defmethod sal-pp* ((object sal-tuple-literal) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (exprs object) stream "(" ")"))

(defmethod sal-pp* ((object sal-record-literal) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (entries object) stream "(# " " #)"))

(defmethod sal-pp* ((object sal-record-entry) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (id object) ":=" (expr object) stream))

(defmethod sal-pp* ((object sal-simple-selection) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (target object) stream 100)
  (write-char #\. stream)
  (sal-pp* (idx object) stream 100))

(defmethod sal-pp* ((object sal-array-selection) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (fun object) stream 100)
  (write-char #\[ stream)
  (sal-pp* (arg object) stream 0)
  (write-char #\] stream))

(defmethod sal-pp* ((object sal-function-update) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (target object) stream 100)
  (write-string " WITH (" stream)
  (sal-pp* (idx object) stream 0)
  (write-string ") := " stream)
  (sal-pp* (new-value object) stream 0))

(defmethod sal-pp* ((object sal-array-update) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (target object) stream 100)
  (write-string " WITH [" stream)
  (sal-pp* (idx object) stream 0)
  (write-string "] := " stream)
  (sal-pp* (new-value object) stream 0))

(defmethod sal-pp* ((object sal-record-update) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (target object) stream 100)
  (write-string " WITH ." stream)
  (sal-pp* (idx object) stream 0)
  (write-string " := " stream)
  (sal-pp* (new-value object) stream 0))

(defmethod sal-pp* ((object sal-tuple-update) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (target object) stream 100)
  (write-string " WITH ." stream)
  (sal-pp* (idx object) stream 0)
  (write-string " := " stream)
  (sal-pp* (new-value object) stream 0))

(defun sal-pp-conditional-tail (object stream)
  (if (typep object 'sal-conditional)
      (progn
        (write-string "ELSIF " stream)
        (sal-pp* (sal-cond-expr object) stream 0)
        (write-string " THEN" stream)
        (pprint-indent :block 2 stream)
        (pprint-newline :mandatory stream)
        (sal-pp* (sal-then-expr object) stream 0)
        (pprint-indent :block 0 stream)
        (pprint-newline :mandatory stream)
        (sal-pp-conditional-tail (sal-else-expr object) stream))
      (progn
        (write-string "ELSE " stream)
        (sal-pp* object stream 0)
        (write-string " ENDIF" stream))))

(defmethod sal-pp* ((object sal-conditional) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "IF " stream)
    (sal-pp* (sal-cond-expr object) stream 0)
    (write-string " THEN" stream)
    (pprint-indent :block 2 stream)
    (pprint-newline :mandatory stream)
    (sal-pp* (sal-then-expr object) stream 0)
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (sal-pp-conditional-tail (sal-else-expr object) stream)))

(defmethod sal-pp* ((object sal-next-operator) stream precedence)
  (sal-pp* (name-expr object) stream precedence)
  (write-char #\' stream))

(defmethod sal-pp* ((object sal-pre-operator) stream precedence)
  (declare (ignore precedence))
  (let ((count 1)
        (operand (expr object)))
    (loop while (typep operand 'sal-pre-operator)
          do (incf count)
             (setf operand (expr operand)))
    (if (= count 1)
        (write-string "PRE(" stream)
        (format stream "PRE^~d(" count))
    (sal-pp* operand stream 0)
    (write-char #\) stream)))

(defmethod sal-pp* ((object sal-mod-init) stream precedence)
  (declare (ignore precedence))
  (write-string "INIT(" stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-mod-trans) stream precedence)
  (declare (ignore precedence))
  (write-string "TRANS(" stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

;;; Definitions, commands, and modules

(defmethod sal-pp* ((object sal-simple-definition) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (lhs object) "=" (rhs object) stream))

(defmethod sal-pp* ((object sal-simple-selection-definition)
                    stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (lhs object) "IN" (rhs object) stream))

(defmethod sal-pp* ((object sal-for-all-definition) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "(FORALL " stream)
    (sal-pp-bindings (local-decls object) stream)
    (write-string ": " stream)
    (sal-pp-separated (definitions object) stream ", ")
    (write-char #\) stream)))

(defmethod sal-pp* ((object sal-command-section) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-char #\[ stream)
    (let ((all-commands (append (commands object)
                                (when (else-command object)
                                  (list (else-command object))))))
      (loop for command in all-commands
            for firstp = t then nil
            unless firstp
              do (pprint-newline :mandatory stream)
                 (write-string "[] " stream)
            do (sal-pp* command stream 0)))
    (write-char #\] stream)))

(defmethod sal-pp* ((object sal-guarded-command) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (sal-pp* (guard object) stream 0)
    (write-string " --> " stream)
    (pprint-indent :block 4 stream)
    (pprint-newline :fill stream)
    (sal-pp-separated (assignments object) stream "; ")))

(defmethod sal-pp* ((object sal-labeled-command) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (label object) stream 0)
  (write-string ": " stream)
  (sal-pp* (command object) stream 0))

(defmethod sal-pp* ((object sal-multi-command) stream precedence)
  (declare (ignore precedence))
  (write-string "([] " stream)
  (sal-pp-bindings (local-decls object) stream)
  (write-string ": " stream)
  (sal-pp* (command object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-else-command) stream precedence)
  (declare (ignore precedence))
  (write-string "ELSE --> " stream)
  (sal-pp-separated (assignments object) stream "; "))

(defmethod sal-pp* ((object sal-input-state-var-decl) stream precedence)
  (write-string "INPUT " stream)
  (call-next-method))

(defmethod sal-pp* ((object sal-output-state-var-decl) stream precedence)
  (write-string "OUTPUT " stream)
  (call-next-method))

(defmethod sal-pp* ((object sal-local-state-var-decl) stream precedence)
  (write-string "LOCAL " stream)
  (call-next-method))

(defmethod sal-pp* ((object sal-global-state-var-decl) stream precedence)
  (write-string "GLOBAL " stream)
  (call-next-method))

(defmethod sal-pp* ((object sal-base-module) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "BEGIN" stream)
    (pprint-indent :block 2 stream)
    (sal-pp-state-variables (state-vars object) stream)
    (sal-pp-section "DEFINITION" (definitions object) nil stream)
    (sal-pp-section "INITIALIZATION"
                    (initialization-definitions object)
                    (initialization-command-section object)
                    stream)
    (sal-pp-section "TRANSITION"
                    (transition-definitions object)
                    (transition-command-section object)
                    stream)
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (write-string "END" stream)))

(defun sal-pp-module-composition (object operator stream)
  (write-char #\( stream)
  (sal-pp* (module1 object) stream 0)
  (write-char #\Space stream)
  (write-string operator stream)
  (write-char #\Space stream)
  (pprint-newline :fill stream)
  (sal-pp* (module2 object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-asynch-composition) stream precedence)
  (declare (ignore precedence))
  (sal-pp-module-composition object "[]" stream))

(defmethod sal-pp* ((object sal-synch-composition) stream precedence)
  (declare (ignore precedence))
  (sal-pp-module-composition object "||" stream))

(defmethod sal-pp* ((object sal-observer) stream precedence)
  (declare (ignore precedence))
  (sal-pp-module-composition object "OBSERVES" stream))

(defun sal-pp-multi-composition (object operator stream)
  (write-char #\( stream)
  (write-string operator stream)
  (write-char #\Space stream)
  (sal-pp-bindings (local-decls object) stream)
  (write-string ": " stream)
  (pprint-newline :fill stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-multi-asynch-composition)
                    stream precedence)
  (declare (ignore precedence))
  (sal-pp-multi-composition object "[]" stream))

(defmethod sal-pp* ((object sal-multi-synch-composition) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multi-composition object "||" stream))

(defun sal-pp-organized-module (object operator stream)
  (write-char #\( stream)
  (write-string operator stream)
  (write-char #\Space stream)
  (sal-pp-separated (identifiers object) stream ", ")
  (pprint-newline :mandatory stream)
  (write-string "IN " stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-hiding) stream precedence)
  (declare (ignore precedence))
  (sal-pp-organized-module object "LOCAL" stream))

(defmethod sal-pp* ((object sal-new-output) stream precedence)
  (declare (ignore precedence))
  (sal-pp-organized-module object "OUTPUT" stream))

(defmethod sal-pp* ((object sal-renaming) stream precedence)
  (declare (ignore precedence))
  (write-string "(RENAME " stream)
  (sal-pp-separated (renames object) stream ", ")
  (pprint-newline :mandatory stream)
  (write-string "IN " stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-rename) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (from-name object) stream 0)
  (write-string " TO " stream)
  (sal-pp* (to-expr object) stream 0))

(defmethod sal-pp* ((object sal-with-module) stream precedence)
  (declare (ignore precedence))
  (write-string "(WITH " stream)
  (sal-pp-separated (new-state-vars object) stream "; ")
  (pprint-newline :mandatory stream)
  (sal-pp* (module object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-module-instance) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (module-name object) stream 0)
  (when (actuals object)
    (sal-pp-enclosed-list (actuals object) stream "[" "]")))

(defun sal-pp-flat-section (label value stream)
  (when value
    (pprint-newline :mandatory stream)
    (pprint-logical-block (stream nil)
      (write-string label stream)
      (pprint-indent :block 2 stream)
      (pprint-newline :mandatory stream)
      (sal-pp* value stream 0))))

(defmethod sal-pp* ((object sal-flat-module) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "BEGIN_FLAT" stream)
    (pprint-indent :block 2 stream)
    (sal-pp-state-variables (state-vars object) stream)
    (sal-pp-flat-section "DEFINITION" (definition object) stream)
    (sal-pp-flat-section "INITIALIZATION" (initialization object) stream)
    (sal-pp-flat-section "TRANSITION" (transition object) stream)
    (sal-pp-flat-section "SKIP" (sal-skip object) stream)
    (sal-pp-flat-section "VALID_INPUT" (valid-input-expr object) stream)
    (sal-pp-flat-section "VALID_STATE" (valid-state-expr object) stream)
    (sal-pp-flat-section "VALID_CONSTANT"
                         (valid-constant-expr object) stream)
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (write-string "END" stream)))

;;; Assertions and explicit-state modules

(defmethod sal-pp* ((object sal-module-models) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (module object) "|-" (expr object) stream))

(defmethod sal-pp* ((object sal-module-implements) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (module1 object) "IMPLEMENTS" (module2 object) stream))

(defmethod sal-pp* ((object sal-assertion-proposition) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (op object) stream 0)
  (sal-pp-enclosed-list (assertion-exprs object) stream "(" ")"))

(defmethod sal-pp* ((object sal-esm-choice) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (statements object) stream "(" ")"
                        :separator " [] "))

(defmethod sal-pp* ((object sal-esm-seq) stream precedence)
  (declare (ignore precedence))
  (sal-pp-enclosed-list (statements object) stream "(" ")"
                        :separator "; "))

(defmethod sal-pp* ((object sal-esm-case) stream precedence)
  (declare (ignore precedence))
  (write-string "CASE " stream)
  (sal-pp* (expr object) stream 0)
  (dolist (entry (case-entries object))
    (pprint-newline :mandatory stream)
    (sal-pp* entry stream 0))
  (pprint-newline :mandatory stream)
  (write-string "ENDCASE" stream))

(defmethod sal-pp* ((object sal-esm-case-entry) stream precedence)
  (declare (ignore precedence))
  (sal-pp* (value object) stream 0)
  (write-string ": " stream)
  (sal-pp* (statement object) stream 0))

(defmethod sal-pp* ((object sal-esm-when-undefined) stream precedence)
  (declare (ignore precedence))
  (write-string "WHEN_UNDEFINED " stream)
  (sal-pp* (lhs object) stream 0)
  (write-string ": " stream)
  (sal-pp* (statement object) stream 0))

(defmethod sal-pp* ((object sal-esm-multi-seq) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multibind "FOR_EACH" (local-decls object)
                    (statement object) stream))

(defmethod sal-pp* ((object sal-esm-multi-choice) stream precedence)
  (declare (ignore precedence))
  (sal-pp-multibind "CHOICE" (local-decls object)
                    (statement object) stream))

(defmethod sal-pp* ((object sal-esm-guard) stream precedence)
  (declare (ignore precedence))
  (write-string "GUARD(" stream)
  (sal-pp* (expr object) stream 0)
  (write-char #\) stream))

(defmethod sal-pp* ((object sal-esm-assignment) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (lhs object) ":=" (rhs object) stream))

(defmethod sal-pp* ((object sal-esm-choice-assignment) stream precedence)
  (declare (ignore precedence))
  (sal-pp-binary (lhs object) "=:=" (rhs object) stream))

(defmethod sal-pp* ((object sal-esm-module) stream precedence)
  (declare (ignore precedence))
  (pprint-logical-block (stream nil)
    (write-string "ESM_MODULE" stream)
    (pprint-indent :block 2 stream)
    (sal-pp-state-variables (state-vars object) stream)
    (sal-pp-flat-section "DEFINITION" (definition object) stream)
    (sal-pp-flat-section "INITIALIZATION" (initialization object) stream)
    (sal-pp-flat-section "TRANSITION" (transition object) stream)
    (pprint-indent :block 0 stream)
    (pprint-newline :mandatory stream)
    (write-string "END" stream)))

(defmethod sal-pp* ((object sal-ast) stream precedence)
  (declare (ignore stream precedence))
  (error "No SAL concrete-syntax printer is defined for ~s"
         (class-name (class-of object))))
