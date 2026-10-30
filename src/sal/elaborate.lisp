;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; elaborate.lisp -- Shallow PVS elaboration of SAL transition-system views
;;
;; Copyright (C) 2026, SRI International. All Rights Reserved.
;; Distributed under the 3-Clause BSD License; see the repository license.

(in-package :pvs)

(export '(sal-elaborate-view sal-elaboration-error
          sal-elaboration-error-message sal-elaboration-error-origin
          sal-pvs-name sal-pvs-expression sal-pvs-type))

(defparameter *sal-elaborator-directory*
  (uiop:pathname-directory-pathname
   (or *load-truename* *compile-file-truename*)))

(define-condition sal-elaboration-error (error)
  ((message :initarg :message :reader sal-elaboration-error-message)
   (origin :initarg :origin :initform nil :reader sal-elaboration-error-origin))
  (:report (lambda (condition stream)
             (write-string (sal-elaboration-error-message condition) stream))))

(defun sal-elaboration-fail (origin control &rest arguments)
  (error 'sal-elaboration-error :origin origin
         :message (apply #'format nil control arguments)))

(defun sal-pvs-name (name)
  "Injectively encode a SAL identifier as a PVS identifier.
The fixed prefix separates source names from bridge declarations. Underscores
are escaped too, so an encoded punctuation character cannot collide with a
literal source spelling. The source display always retains the original name."
  (let ((string (etypecase name
                  (string name)
                  (symbol (symbol-name name))
                  (sal-identifier (sal-identifier-text name))
                  (sal-decl (sal-declaration-name name)))))
    (concatenate
     'string "sal_"
     (with-output-to-string (out)
       (loop for ch across string do
         (if (or (and (char>= ch #\a) (char<= ch #\z))
                 (and (char>= ch #\A) (char<= ch #\Z))
                 (and (char>= ch #\0) (char<= ch #\9)))
             (write-char ch out)
             (format out "_x~X_" (char-code ch))))))))

(defvar *sal-pvs-state* "s")
(defvar *sal-pvs-next-state* "next")
(defvar *sal-pvs-state-declarations* nil)
(defvar *sal-pvs-context* nil)
(defvar *sal-pvs-origin-table* nil)
(defvar *sal-pvs-fresh-counter* 0)
(defvar *sal-pvs-local-names* (make-hash-table :test #'eq))
(defvar *sal-pvs-origin-prefix* nil)
(defvar *sal-pvs-qualify-current-context* nil)
(defvar *sal-pvs-current-context-actuals* nil)
(defvar *sal-pvs-hoist-lets* nil)
(defvar *sal-pvs-lexical-depth* 0)
(defvar *sal-pvs-let-references* nil)
(defvar *sal-pvs-pending-helpers* nil)
(defvar *sal-pvs-helper-call-arguments* "s, next")
(defvar *sal-pvs-temporal-typecheck* nil)
(defvar *sal-pvs-typecheck-bindings* nil)
(defvar *sal-pvs-total-helper-cache* nil)

(defun sal-pvs-context-theory-name (context)
  (concatenate 'string "SALCTX_" (sal-pvs-name (sal-declaration-name context))))

(defun sal-pvs-formal (declaration)
  (if (typep declaration 'sal-type-param-decl)
      (format nil "~A: TYPE" (sal-pvs-name declaration))
      (format nil "~A: ~A" (sal-pvs-name declaration)
              (sal-pvs-type (type declaration)))))

(defun sal-pvs-formal-with-imports (declaration &optional extra-context)
  (let ((dependencies (if (listp extra-context) (copy-list extra-context)
                         (list extra-context))))
    (sal-walk-ast
     (lambda (node)
       (when (and (typep node 'sal-qualified-name-ref) (context-ref node)
                  (not (eq (context-ref node) *sal-pvs-context*))
                  (not (string= (sal-declaration-name (context-ref node)) "prelude")))
         (pushnew (context-ref node) dependencies :test #'eq)))
     declaration)
    (format nil "~A~A"
            (if dependencies
                (format nil "(IMPORTING ~A) "
                        (sal-pvs-join (mapcar #'sal-pvs-context-theory-name
                                              (nreverse dependencies)) ", "))
                "")
            (sal-pvs-formal declaration))))

(defun sal-pvs-formals (declarations)
  (if declarations
      (format nil "[~A]" (sal-pvs-join (mapcar #'sal-pvs-formal-with-imports declarations) ", "))
      ""))

(defun sal-pvs-actual (actual)
  (if (typep actual 'sal-type) (sal-pvs-type actual) (sal-pvs-expression actual)))

(defun sal-pvs-context-instance (context actuals)
  (format nil "~A~A" (sal-pvs-context-theory-name context)
          (if actuals
              (format nil "[~A]" (sal-pvs-join (mapcar #'sal-pvs-actual actuals) ", "))
              (if (params context)
                  (if (eq context *sal-pvs-context*)
                      (format nil "[~A]" (sal-pvs-join (mapcar #'sal-pvs-name (params context)) ", "))
                      (sal-elaboration-fail context "Missing actual parameters for context ~A"
                                            (sal-declaration-name context)))
                  ""))))

(defun sal-pvs-qualified-reference (reference)
  (let* ((owner (context-ref reference))
         (arguments (actuals reference))
         (source-identity-p
           (and owner
                (= (length arguments) (length (params owner)))
                (every (lambda (actual parameter)
                         (and (typep actual '(or sal-name-expr sal-type-name))
                              (eq (decl actual) parameter)))
                       arguments (params owner)))))
    (if (or (null owner)
            (and (eq owner *sal-pvs-context*)
                 (or (member (decl reference) (params owner) :test #'eq)
                     (and (not *sal-pvs-qualify-current-context*)
                          (or (null arguments)
                              (if *sal-pvs-current-context-actuals*
                                  (and (= (length arguments)
                                          (length *sal-pvs-current-context-actuals*))
                                       (every #'sal-ast-structural-equal arguments
                                              *sal-pvs-current-context-actuals*))
                                  source-identity-p)))))
            (string= (sal-declaration-name owner) "prelude"))
        (sal-pvs-name (decl reference))
        (format nil "~A.~A" (sal-pvs-context-instance
                             owner (if (and (eq owner *sal-pvs-context*)
                                            *sal-pvs-qualify-current-context*
                                            source-identity-p
                                            *sal-pvs-current-context-actuals*)
                                       *sal-pvs-current-context-actuals*
                                       arguments))
                (sal-pvs-name (decl reference))))))

(defun sal-pvs-fresh (stem)
  (format nil "bridge_~A_~D" stem (incf *sal-pvs-fresh-counter*)))

(defun sal-pvs-binding-name (declaration)
  "Give every local declaration a name distinct from all source constants.
Identity, not spelling, distinguishes a binder from a qualified reference to
a same-spelled context declaration. Repeated occurrences reuse its name."
  (or (gethash declaration *sal-pvs-local-names*)
      (setf (gethash declaration *sal-pvs-local-names*)
            (format nil "~A_~A" (sal-pvs-fresh "local")
                    (sal-pvs-name declaration)))))

(defun sal-pvs-join (strings separator)
  (format nil "~{~A~}" (loop for text in strings for first = t then nil
                            unless first collect separator collect text)))

(defun sal-pvs-infix (operator arguments &optional (empty "TRUE"))
  (cond ((null arguments) empty)
        ((null (rest arguments)) (first arguments))
        ((and (member operator '("AND" "OR") :test #'string=)
              (> (length arguments) 16))
         ;; PVS parses an unparenthesized chain into a linear-depth AST.
         ;; Native SAL modules can contain thousands of simultaneous clauses.
         ;; Balance only associative Boolean operators, retaining source order
         ;; and hence the same guards available when PVS generates TCCs.
         (let ((items (coerce arguments 'vector)))
           (labels ((emit (start end out)
                      (if (= (1+ start) end)
                          (write-string (aref items start) out)
                          (let ((middle (floor (+ start end) 2)))
                            (write-char #\( out)
                            (emit start middle out)
                            (format out " ~A " operator)
                            (emit middle end out)
                            (write-char #\) out)))))
             (with-output-to-string (out) (emit 0 (length items) out)))))
        (t (format nil "(~A)" (sal-pvs-join arguments
                                             (format nil " ~A " operator))))))

(defun sal-pvs-state-declaration-p (declaration)
  ;; Never infer this from spelling: a local binder may shadow a state field.
  ;; The normalized importer resolves both relation/property references into
  ;; the very same flat scope.
  (typep declaration 'sal-state-var-decl))

(defun sal-pvs-unalias-type (type &optional seen)
  (if (and (typep type 'sal-type-name)
           (typep (decl type) 'sal-type-decl)
           (type (decl type)))
      (if (member (decl type) seen)
          (sal-elaboration-fail type "Recursive type alias ~A"
                                (sal-declaration-name (decl type)))
          (sal-pvs-unalias-type (type (decl type)) (cons (decl type) seen)))
      type))

(defun sal-pvs-expression-type (expression)
  "Infer only the expression types needed for assignment checking.
SAL's XML format does not normally serialize cached expression types."
  (or (and (typep expression 'sal-expr) (type expression))
      (typecase expression
        (sal-name-expr
         (and (typep (decl expression) 'sal-typed-decl) (type (decl expression))))
        (sal-next-operator (sal-pvs-expression-type (name-expr expression)))
        (sal-application
         (let ((ftype (sal-pvs-unalias-type
                       (sal-pvs-expression-type (fun expression)))))
           (and (typep ftype 'sal-function-type) (range ftype))))
        (sal-record-selection
         (let* ((rtype (sal-pvs-unalias-type
                        (sal-pvs-expression-type (target expression))))
                (field (and (typep rtype 'sal-record-type)
                            (find (sal-identifier-text (idx expression))
                                  (fields rtype) :key (lambda (f)
                                                       (sal-identifier-text (id f)))
                                  :test #'string=))))
           (and field (type field))))
        (sal-tuple-selection
         (let ((ttype (sal-pvs-unalias-type
                       (sal-pvs-expression-type (target expression)))))
           (and (typep ttype 'sal-tuple-type)
                (nth (1- (idx expression)) (types ttype)))))
        (t nil))))

(defun sal-pvs-bindings (declarations)
  (sal-pvs-join
   (mapcar (lambda (declaration)
             (format nil "~A: ~A" (sal-pvs-binding-name declaration)
                     (sal-pvs-type (type declaration))))
           declarations)
   ", "))

(defun sal-pvs-predicate-implies-real-p (expression binder)
  "Recognize only explicit real membership of this exact numeric binder.
Native SAL infers unions of numeric subtypes over its broader NUMBER carrier.
Changing that carrier to REAL is exact only when every accepted branch already
requires real membership; no arbitrary numeric predicate is approximated."
  (typecase expression
    (sal-real-pred
     (let ((argument (first (sal-application-arguments expression))))
       (and (typep argument 'sal-name-expr) (eq (decl argument) binder))))
    (sal-and
     (some (lambda (argument) (sal-pvs-predicate-implies-real-p argument binder))
           (sal-application-arguments expression)))
    (sal-or
     (every (lambda (argument) (sal-pvs-predicate-implies-real-p argument binder))
            (sal-application-arguments expression)))
    (sal-false t)
    (t nil)))

(defun sal-pvs-type (type)
  "Render a SAL type directly as a PVS type, rejecting unsupported features."
  (when (and (typep type 'sal-qualified-type-name)
             (context-ref type)
             (not (string= (sal-declaration-name (context-ref type)) "prelude")))
    (return-from sal-pvs-type (sal-pvs-qualified-reference type)))
  ;; XML primitive classification is by spelling. An actual source declaration
  ;; remains authoritative, even when its name resembles a prelude type.
  (when (and (typep type 'sal-type-name) *sal-pvs-context*
             (member (decl type) (declarations *sal-pvs-context*) :test #'eq))
    (return-from sal-pvs-type
      (if *sal-pvs-qualify-current-context*
          (format nil "~A.~A"
                  (sal-pvs-context-instance *sal-pvs-context* *sal-pvs-current-context-actuals*)
                  (sal-pvs-name (decl type)))
          (sal-pvs-name (decl type)))))
  (typecase type
    (sal-bool-type "bool")
    (sal-nat-type "nat")
    (sal-int-type "int")
    (sal-real-type "real")
    (sal-number-type
     (sal-elaboration-fail type
                           "The unconstrained SAL number carrier requires an explicit adapter"))
    (sal-string-type
     ;; SAL STRING is [nat, ARRAY nat OF [0..255]], whereas PVS string is a
     ;; finite sequence of characters. Identifying the carriers loses data.
     (sal-elaboration-fail type "SAL STRING requires an explicit representation adapter"))
    (sal-symmetric-type
     ;; Symmetry reduction requires separate admission; this preserves the
     ;; underlying finite carrier, not a license for extra source operations.
     (format nil "subrange(~A, ~A)" (sal-pvs-expression (lower type))
             (sal-pvs-expression (upper type))))
    (sal-subrange
     (format nil "subrange(~A, ~A)" (sal-pvs-expression (lower type))
             (sal-pvs-expression (upper type))))
    (sal-subtype
     (let ((pred (expr type)))
       (if (and (typep pred 'sal-lambda) (= (length (local-decls pred)) 1))
           (let* ((binder (first (local-decls pred)))
                  (number-type-p
                    (eq (class-name (class-of (sal-pvs-unalias-type (type binder))))
                        'sal-number-type)))
             (format nil "{~A | ~A}"
                     (if (and number-type-p
                              (sal-pvs-predicate-implies-real-p (expr pred) binder))
                         (format nil "~A: real" (sal-pvs-binding-name binder))
                         (sal-pvs-bindings (local-decls pred)))
                     (sal-pvs-expression (expr pred))))
           ;; PVS predicate-as-type notation infers the exact domain from the
           ;; predicate function, including instantiated imported predicates.
           (format nil "(~A)" (sal-pvs-expression pred)))))
    (sal-type-name
     (let ((name (sal-declaration-name (decl type))))
       (cond ((member name '("BOOLEAN" "boolean" "bool") :test #'string=) "bool")
             ((member name '("NATURAL" "natural" "nat") :test #'string=) "nat")
             ((member name '("INTEGER" "integer" "int") :test #'string=) "int")
             ((member name '("REAL" "real" "number") :test #'string=) "real")
             ((member name '("NZINTEGER" "nzinteger") :test #'string=) "nzint")
             ((member name '("NZREAL" "nzreal") :test #'string=) "nzreal")
             ((string= name "nznat") "posnat")
             ((member name '("CHAR" "char" "character") :test #'string=)
              "subrange(0, 255)")
             (t (sal-pvs-name name)))))
    (sal-function-type
     (let ((domain (domain type)))
       (format nil "[~A -> ~A]"
               (if (typep domain 'sal-domain-tuple-type)
                   (sal-pvs-join (mapcar #'sal-pvs-type (types domain)) ", ")
                   (sal-pvs-type domain))
               (sal-pvs-type (range type)))))
    (sal-tuple-type
     (format nil "[~A]" (sal-pvs-join (mapcar #'sal-pvs-type (types type)) ", ")))
    (sal-record-type
     (format nil "[# ~A #]"
             (sal-pvs-join
              (mapcar (lambda (field)
                        (format nil "~A: ~A" (sal-pvs-name (id field))
                                (sal-pvs-type (type field))))
                      (fields type)) ", ")))
    (sal-scalar-type
     (format nil "{~A}"
             (sal-pvs-join
              (mapcar (lambda (element) (sal-pvs-name (decl element)))
                      (scalar-elements type)) ", ")))
    (t (sal-elaboration-fail type "Unsupported SAL type ~A"
                             (and type (class-name (class-of type)))))))

(defun sal-pvs-name-expression (expression)
  (let* ((declaration (decl expression))
         (name (sal-declaration-name declaration))
         (local-name (gethash declaration *sal-pvs-local-names*)))
    (cond ((and *sal-pvs-let-references* (gethash declaration *sal-pvs-let-references*)))
          (local-name local-name)
          ((and *sal-pvs-temporal-typecheck*
                (sal-pvs-temporal-declaration-p declaration))
           (let* ((source-name (sal-pvs-name declaration))
                  (qualified (if (typep expression 'sal-qualified-name-expr)
                                 (sal-pvs-qualified-reference expression) source-name)))
             (concatenate 'string
                          (subseq qualified 0 (- (length qualified) (length source-name)))
                          "bridge_temporal_signature_" source-name)))
          ((sal-pvs-state-declaration-p declaration)
           (format nil "(~A)`~A" *sal-pvs-state* (sal-pvs-name name)))
          ((and (typep declaration 'sal-constant-decl) (null (type declaration))
                (member name '("above" "below" "up-to" "up_to") :test #'string=))
           ;; These native prelude macros return predicates over NATURAL.
           ;; Ordinary source declarations have a declared type and are never
           ;; selected by this fallback for the XML builtin placeholders.
           (let ((bound (sal-pvs-fresh "bound")) (element (sal-pvs-fresh "element")))
             (format nil "(LAMBDA (~A: nat): LAMBDA (~A: nat): ~A ~A ~A)"
                     bound element element
                     (cond ((string= name "above") ">") ((string= name "below") "<")
                           (t "<=")) bound)))
          ((and (typep expression 'sal-qualified-name-expr)
                (context-ref expression)
                (not (string= (sal-declaration-name (context-ref expression)) "prelude")))
           (sal-pvs-qualified-reference expression))
          (t (sal-pvs-name name)))))

(defun sal-pvs-total-helper-value-p (expression)
  (let* ((*sal-pvs-total-helper-cache*
           (or *sal-pvs-total-helper-cache* (make-hash-table :test #'eq)))
         (cached (gethash expression *sal-pvs-total-helper-cache*)))
    (if cached (eq cached :total)
        (progn
          (setf (gethash expression *sal-pvs-total-helper-cache*) :checking)
          (let ((total (sal-pvs-total-helper-value-uncached-p expression)))
            (setf (gethash expression *sal-pvs-total-helper-cache*)
                  (if total :total :partial))
            total)))))

(defun sal-pvs-total-helper-value-uncached-p (expression)
  "A conservative syntactic fragment with no context-dependent domain TCCs.
Relations assume DEFINED states. Only total Boolean/real DAGs may leave that
scope; array access, subtype-valued bindings and arbitrary function calls stay."
  (typecase expression
    ;; Theory actuals themselves can impose subtype obligations even for a
    ;; bare constant reference. Keep them under their source path conditions.
    (sal-qualified-name-expr (null (actuals expression)))
    (sal-name-expr
     (let ((declaration (decl expression)))
       (or (not (typep declaration 'sal-let-decl))
           (sal-pvs-total-helper-binding-p declaration))))
    (sal-numeral t)
    (sal-next-operator (sal-pvs-total-helper-value-p (name-expr expression)))
    ((or sal-record-selection sal-tuple-selection)
     (sal-pvs-total-helper-value-p (target expression)))
    (sal-conditional
     (every #'sal-pvs-total-helper-value-p
            (list (sal-cond-expr expression) (sal-then-expr expression)
                  (sal-else-expr expression))))
    (sal-let-expr
     (and (every #'sal-pvs-total-helper-binding-p (local-decls expression))
          (sal-pvs-total-helper-value-p (expr expression))))
    ((or sal-not sal-and sal-or sal-implies sal-iff sal-xor sal-eq sal-diseq
         sal-lt sal-le sal-gt sal-ge sal-add sal-sub sal-mul sal-min sal-max
         sal-int-pred sal-real-pred)
     (every #'sal-pvs-total-helper-value-p (sal-application-arguments expression)))
    (sal-div
     (let ((arguments (sal-application-arguments expression)))
       (and (typep (second arguments) 'sal-numeral)
            (not (zerop (sal-num (second arguments))))
            (every #'sal-pvs-total-helper-value-p arguments))))
    (t nil)))

(defun sal-pvs-total-helper-binding-p (binding)
  (and (member (sal-pvs-type (type binding)) '("bool" "real") :test #'string=)
       (sal-pvs-total-helper-value-p (value binding))))

(defun sal-pvs-hoisted-let-expression (expression)
  "Keep the native LET DAG in small blocks of ordinary PVS definitions.
A block returns a tuple of its local values. This bounds PVS's LET depth while
avoiding a fresh pair of potentially enormous State binders for every gate."
  (let ((node expression) (entries nil))
    (labels ((flush-block ()
               (when entries
                 (let* ((ordered (nreverse entries))
                        (name (sal-pvs-fresh "let"))
                        (tuple-p (rest ordered))
                        (result (if tuple-p
                                    (format nil "(~A)" (sal-pvs-join (mapcar #'second ordered) ", "))
                                    (second (first ordered))))
                        (type (if tuple-p
                                  (format nil "[~A]" (sal-pvs-join (mapcar #'third ordered) ", "))
                                  (third (first ordered)))))
                   (dolist (entry (reverse ordered))
                     (setf result (format nil "(LET ~A: ~A = ~A IN ~A)"
                                          (second entry) (third entry) (fourth entry) result)))
                   (push (list name (format nil "~A(s, next): ~A = ~A" name type result)
                               (first (first ordered)))
                         *sal-pvs-pending-helpers*)
                   (loop for entry in ordered for index from 1 do
                     (setf (gethash (first entry) *sal-pvs-let-references*)
                           (if tuple-p
                               (format nil "(~A(~A))`~D" name *sal-pvs-helper-call-arguments* index)
                               (format nil "~A(~A)" name *sal-pvs-helper-call-arguments*)))
                     (sal-pvs-note-origin (format nil "~A`~D" name index) (first entry)))
                   (setf entries nil)))))
      (loop while (and (typep node 'sal-let-expr)
                       (every #'sal-pvs-total-helper-binding-p (local-decls node)))
            do (dolist (binding (local-decls node))
                 (let* ((name (sal-pvs-binding-name binding))
                        (body (let ((*sal-pvs-hoist-lets* nil))
                                (sal-pvs-expression (value binding)))))
                   (push (list binding name (sal-pvs-type (type binding)) body) entries)
                   (setf (gethash binding *sal-pvs-let-references*) name)
                   (when (= (length entries) 32) (flush-block))))
               (setf node (expr node)))
      (flush-block)
      (sal-pvs-expression node))))

(defun sal-pvs-temporal-typecheck-result (expression)
  "An arbitrary Boolean result for one temporal occurrence in a typing check.
Its arguments include every lexical binder, so distinct quantified instances
can vary independently. No fixed truth value or temporal law is assumed."
  (let* ((name (sal-pvs-fresh "temporal_result"))
         (bindings *sal-pvs-typecheck-bindings*)
         (signature (if bindings
                        (format nil "~A(~A): bool" name (sal-pvs-bindings bindings))
                        (format nil "~A: bool" name))))
    (push (list name signature expression) *sal-pvs-pending-helpers*)
    (if bindings
        (format nil "~A(~A)" name
                (sal-pvs-join (mapcar #'sal-pvs-binding-name bindings) ", "))
        name)))

(defun sal-pvs-expression (expression)
  "Render a pure SAL expression with explicit current/next state bindings."
  (typecase expression
    (null (sal-elaboration-fail expression "Missing normalized SAL expression"))
    (sal-true "TRUE")
    (sal-false "FALSE")
    (sal-numeral
     (let ((n (sal-num expression)))
       (unless (rationalp n)
         (sal-elaboration-fail expression "Unsupported non-rational literal ~A" n))
       (if (= (denominator n) 1) (format nil "~D" n)
           (format nil "(~D / ~D)" (numerator n) (denominator n)))))
    (sal-name-expr (sal-pvs-name-expression expression))
    (sal-next-operator
     (let ((*sal-pvs-state* *sal-pvs-next-state*))
       (sal-pvs-expression (name-expr expression))))
    (sal-definition-expression
     ;; SAL flattens `x IN f` as f(x) AND domain_f(x). PVS must see the
     ;; domain guard first before typechecking f(x). This conjunction reorder
     ;; preserves the exported relation and does not strengthen IN to set
     ;; inclusion. See SAL src/sal-flat-modules.scm's selection definition.
     (let* ((*sal-pvs-hoist-lets* nil)
            (body (expr expression))
            (parts (and (typep body 'sal-and) (sal-application-arguments body))))
       (if parts
           (sal-pvs-infix "AND"
                          (mapcar #'sal-pvs-expression
                                  (append (rest parts) (list (first parts)))))
           (sal-pvs-expression body))))
    (sal-conditional
     (let ((*sal-pvs-hoist-lets* nil))
       (format nil "(IF ~A THEN ~A ELSE ~A ENDIF)"
             (sal-pvs-expression (sal-cond-expr expression))
             (sal-pvs-expression (sal-then-expr expression))
             (sal-pvs-expression (sal-else-expr expression)))))
    (sal-let-expr
     (if (and *sal-pvs-hoist-lets* (zerop *sal-pvs-lexical-depth*)
              (every #'sal-pvs-total-helper-binding-p (local-decls expression)))
         (sal-pvs-hoisted-let-expression expression)
         (let ((*sal-pvs-hoist-lets* nil))
           (format nil "(LET ~A IN ~A)"
             (sal-pvs-join
              (mapcar (lambda (binding)
                        (format nil "~A: ~A = ~A" (sal-pvs-binding-name binding)
                                (sal-pvs-type (type binding))
                                (sal-pvs-expression (value binding))))
                      (local-decls expression)) ", ")
             (let ((*sal-pvs-typecheck-bindings*
                     (append *sal-pvs-typecheck-bindings* (local-decls expression))))
               (sal-pvs-expression (expr expression)))))))
    (sal-local-binds-expr
     (let ((*sal-pvs-lexical-depth* (1+ *sal-pvs-lexical-depth*))
           (*sal-pvs-typecheck-bindings*
             (append *sal-pvs-typecheck-bindings* (local-decls expression))))
       (format nil "(~A (~A): ~A)"
             (typecase expression (sal-lambda "LAMBDA")
                       (sal-for-all-expr "FORALL")
                       (sal-exists-expr "EXISTS")
                       (t (sal-elaboration-fail expression "Unsupported binder ~A"
                                                (class-name (class-of expression)))))
             (sal-pvs-bindings (local-decls expression))
             (sal-pvs-expression (expr expression)))))
    (sal-record-selection
     (format nil "(~A)`~A" (sal-pvs-expression (target expression))
             (sal-pvs-name (idx expression))))
    (sal-tuple-selection
     (format nil "(~A)`~D" (sal-pvs-expression (target expression)) (idx expression)))
    (sal-tuple-literal
     (format nil "(~A)" (sal-pvs-join (mapcar #'sal-pvs-expression (exprs expression)) ", ")))
    (sal-record-literal
     (format nil "(# ~A #)"
             (sal-pvs-join
              (mapcar (lambda (entry)
                        (format nil "~A := ~A" (sal-pvs-name (id entry))
                                (sal-pvs-expression (expr entry))))
                      (entries expression)) ", ")))
    (sal-update-expr
     (format nil "(~A WITH [~A := ~A])"
             (sal-pvs-expression (target expression))
             (typecase expression
               (sal-record-update (sal-pvs-name (idx expression)))
               (sal-tuple-update (format nil "~D" (idx expression)))
               (t (format nil "(~A)" (sal-pvs-expression (idx expression)))))
             (sal-pvs-expression (new-value expression))))
    (sal-temporal-application
     (if *sal-pvs-temporal-typecheck*
         (format nil "(LET ~A IN ~A)"
                 (sal-pvs-join
                  (mapcar (lambda (argument)
                            (format nil "~A: bool = ~A" (sal-pvs-fresh "temporal_argument")
                                    (sal-pvs-expression argument)))
                          (sal-application-arguments expression)) ", ")
                 (sal-pvs-temporal-typecheck-result expression))
         (sal-elaboration-fail expression "Temporal expression used outside a property")))
    (sal-application (sal-pvs-application expression))
    (t (sal-elaboration-fail expression "Unsupported SAL expression ~A"
                             (class-name (class-of expression))))))

(defun sal-pvs-application (expression)
  (let* ((arguments (sal-application-arguments expression))
         (texts
           (loop with prior-true-p = t with prior-false-p = t
                 for argument in arguments for index from 0
                 collect
                 (let ((*sal-pvs-hoist-lets*
                         (and *sal-pvs-hoist-lets*
                              ;; Preserve PVS's source path assumptions. A
                              ;; LET under a nontrivial boolean guard stays
                              ;; in place instead of acquiring stronger TCCs.
                              (or (zerop index)
                                  (typecase expression
                                    (sal-and prior-true-p)
                                    (sal-or prior-false-p)
                                    (sal-implies (typep (first arguments) 'sal-true))
                                    (t t))))))
                   (sal-pvs-expression argument))
                 do (setf prior-true-p (and prior-true-p (typep argument 'sal-true))
                          prior-false-p (and prior-false-p (typep argument 'sal-false))))))
    (cond
      ((and *sal-pvs-temporal-typecheck* (typep (fun expression) 'sal-name-expr)
            (sal-pvs-temporal-declaration-p (decl (fun expression))))
       ;; The signature application keeps every call-domain obligation. Its
       ;; Boolean result is then independently abstracted at this occurrence;
       ;; identifying two temporal calls by their present Boolean argument
       ;; values could otherwise incorrectly eliminate a later branch TCC.
       (format nil "(LET ~A: bool = (~A)(~A) IN ~A)"
               (sal-pvs-fresh "temporal_call") (sal-pvs-expression (fun expression))
               (sal-pvs-join texts ", ") (sal-pvs-temporal-typecheck-result expression)))
      ((typep expression 'sal-array-selection)
       (format nil "(~A)(~A)" (sal-pvs-expression (fun expression))
               (sal-pvs-join texts ", ")))
      ((typep expression 'sal-not) (format nil "(NOT ~A)" (first texts)))
      ((typep expression 'sal-and) (sal-pvs-infix "AND" texts))
      ((typep expression 'sal-or) (sal-pvs-infix "OR" texts "FALSE"))
      ((typep expression 'sal-implies) (sal-pvs-infix "IMPLIES" texts))
      ((typep expression 'sal-iff) (sal-pvs-infix "IFF" texts))
      ((typep expression 'sal-xor) (sal-pvs-infix "XOR" texts))
      ((typep expression 'sal-eq) (sal-pvs-infix "=" texts))
      ((typep expression 'sal-diseq) (sal-pvs-infix "/=" texts))
      ((typep expression 'sal-lt) (sal-pvs-infix "<" texts))
      ((typep expression 'sal-le) (sal-pvs-infix "<=" texts))
      ((typep expression 'sal-gt) (sal-pvs-infix ">" texts))
      ((typep expression 'sal-ge) (sal-pvs-infix ">=" texts))
      ((typep expression 'sal-add) (sal-pvs-infix "+" texts "0"))
      ((typep expression 'sal-mul) (sal-pvs-infix "*" texts "1"))
      ((typep expression 'sal-sub)
       (if (= (length texts) 1) (format nil "(-~A)" (first texts))
           (sal-pvs-infix "-" texts)))
      ((typep expression 'sal-div) (sal-pvs-infix "/" texts))
      ((typep expression 'sal-idiv)
       ;; Native SAL's GMP evaluator uses mpz_tdiv_q: truncate toward zero.
       ;; Division by zero is a source TCC, not an arbitrary totalization.
       (let ((quotient (sal-pvs-fresh "quotient")))
         (format nil "(LET ~A = (~A / ~A) IN IF ~A >= 0 THEN floor(~A) ELSE ceiling(~A) ENDIF)"
                 quotient (first texts) (second texts) quotient quotient quotient)))
      ((typep expression 'sal-mod)
       ;; mpz_mod returns the nonnegative residue modulo the absolute divisor.
       ;; PVS rem's positive divisor exposes exactly the required nonzero TCC.
       (format nil "rem(abs(~A))(~A)" (second texts) (first texts)))
      ((typep expression 'sal-min) (format nil "min(~A)" (sal-pvs-join texts ", ")))
      ((typep expression 'sal-max) (format nil "max(~A)" (sal-pvs-join texts ", ")))
      ((typep expression 'sal-int-pred) (format nil "integer_pred(~A)" (first texts)))
      ((typep expression 'sal-real-pred)
       ;; Membership is tautological on the admitted real carrier, but its
       ;; argument may itself have a partial-call/domain obligation.
       (format nil "(LET ~A: real = ~A IN TRUE)" (sal-pvs-fresh "real_argument")
               (first texts)))
      ((typep expression 'sal-debug-application) (car (last texts)))
      ((typep expression 'sal-ring-application)
       (let* ((ring (sal-pvs-unalias-type (sal-pvs-expression-type (first arguments))))
              (bound (and (typep ring 'sal-bounded-subtype)
                          (sal-pvs-expression (upper ring))))
              (element (sal-pvs-fresh "ring")))
         (unless bound
           (sal-elaboration-fail expression "Cannot recover RINGSET operand bounds"))
         ;; This is the same expansion as SAL's native local simplifier.
         (format nil "(LET ~A = ~A IN IF ~A = ~A THEN ~A ELSE ~A ~A 1 ENDIF)"
                 element (first texts) element
                 (if (typep expression 'sal-ring-pre) "0" bound)
                 (if (typep expression 'sal-ring-pre) bound "0")
                 element (if (typep expression 'sal-ring-pre) "-" "+"))))
      (t (format nil "(~A)(~A)" (sal-pvs-expression (fun expression))
                 (sal-pvs-join texts ", "))))))

(defun sal-pvs-temporal-p (expression)
  (not (null (sal-find-ast (lambda (node) (typep node 'sal-temporal-application))
                         expression))))

(defun sal-pvs-temporal-declaration-p (declaration &optional seen)
  "A temporal library definition is a source macro over state predicates.
The native exporter expands its uses at PROPERTY boundaries, preserving the
actual expressions under temporal operators. It is not a Boolean constant."
  (and (typep declaration 'sal-constant-decl)
       (not (member declaration seen :test #'eq))
       (value declaration)
       (or (sal-pvs-temporal-p (value declaration))
           (sal-find-ast
            (lambda (node)
              (and (typep node 'sal-name-expr)
                   (sal-pvs-temporal-declaration-p
                    (decl node) (cons declaration seen))))
            (value declaration)))))

(defun sal-pvs-ltl-expression (expression path index)
  "Shallow LTL semantics over an ordinary PVS path and a natural index."
  (let ((*sal-pvs-state* (format nil "~A(~A)" path index)))
    (if (not (sal-pvs-temporal-p expression))
        (sal-pvs-expression expression)
        (let ((arguments (and (typep expression 'sal-application)
                              (sal-application-arguments expression))))
          (labels ((at (e k) (sal-pvs-ltl-expression e path k))
                   (quantified (quantifier body)
                     (let ((j (sal-pvs-fresh "time")))
                       (format nil "(~A (~A: {n: nat | n >= ~A}): ~A)"
                               quantifier j index (at body j)))))
            (typecase expression
              (sal-let-expr
               (format nil "(LET ~A IN ~A)"
                       (sal-pvs-join
                        (mapcar (lambda (binding)
                                  (format nil "~A: ~A = ~A" (sal-pvs-binding-name binding)
                                          (sal-pvs-type (type binding))
                                          (at (value binding) index)))
                                (local-decls expression)) ", ")
                       (at (expr expression) index)))
              (sal-tuple-literal
               (format nil "(~A)" (sal-pvs-join
                                   (mapcar (lambda (e) (at e index)) (exprs expression)) ", ")))
              (sal-local-binds-expr
               (format nil "(~A (~A): ~A)"
                       (typecase expression (sal-for-all-expr "FORALL")
                                 (sal-exists-expr "EXISTS")
                                 (t (sal-elaboration-fail expression "Unsupported temporal binder")))
                       (sal-pvs-bindings (local-decls expression))
                       (at (expr expression) index)))
              (sal-ltl-x (at (first arguments) (format nil "(~A + 1)" index)))
              (sal-ltl-g (quantified "FORALL" (first arguments)))
              (sal-ltl-f (quantified "EXISTS" (first arguments)))
              (sal-ltl-u
               (let ((j (sal-pvs-fresh "time")) (h (sal-pvs-fresh "time")))
                 (format nil "(EXISTS (~A: {n: nat | n >= ~A}): (~A AND (FORALL (~A: {n: nat | ~A <= n AND n < ~A}): ~A)))"
                         j index (at (second arguments) j) h index j
                         (at (first arguments) h))))
              (sal-ltl-w
               (let ((j (sal-pvs-fresh "time")) (h (sal-pvs-fresh "time")))
                 (format nil "((EXISTS (~A: {n: nat | n >= ~A}): (~A AND (FORALL (~A: {n: nat | ~A <= n AND n < ~A}): ~A))) OR ~A)"
                         j index (at (second arguments) j) h index j
                         (at (first arguments) h) (quantified "FORALL" (first arguments)))))
              (sal-ltl-r
               (let ((j (sal-pvs-fresh "time")) (h (sal-pvs-fresh "time")))
                 (format nil "(FORALL (~A: {n: nat | n >= ~A}): (FORALL (~A: {n: nat | ~A <= n AND n < ~A}): NOT (~A)) IMPLIES ~A)"
                         j index h index j (at (first arguments) h)
                         (at (second arguments) j))))
              (sal-ltl-m
               (let ((j (sal-pvs-fresh "time")) (h (sal-pvs-fresh "time")))
                 (format nil "(EXISTS (~A: {n: nat | n >= ~A}): (~A AND (FORALL (~A: {n: nat | ~A <= n AND n <= ~A}): ~A)))"
                         j index (at (first arguments) j) h index j
                         (at (second arguments) h))))
              (sal-conditional
               (format nil "(IF ~A THEN ~A ELSE ~A ENDIF)"
                       (at (sal-cond-expr expression) index)
                       (at (sal-then-expr expression) index)
                       (at (sal-else-expr expression) index)))
              (sal-not (format nil "(NOT ~A)" (at (first arguments) index)))
              (sal-and (sal-pvs-infix "AND" (mapcar (lambda (e) (at e index)) arguments)))
              (sal-or (sal-pvs-infix "OR" (mapcar (lambda (e) (at e index)) arguments) "FALSE"))
              (sal-implies (sal-pvs-infix "IMPLIES" (mapcar (lambda (e) (at e index)) arguments)))
              (sal-iff (sal-pvs-infix "IFF" (mapcar (lambda (e) (at e index)) arguments)))
              (sal-xor (sal-pvs-infix "XOR" (mapcar (lambda (e) (at e index)) arguments)))
              (t (sal-elaboration-fail expression
                                       "Unsupported temporal operator ~A; admitted LTL operators are X, G, F, U"
                                       (class-name (class-of expression))))))))))

(defun sal-pvs-ctl-p (expression)
  (not (null (sal-find-ast (lambda (node) (typep node 'sal-ctl-application)) expression))))

(defun sal-pvs-ctl-expression (expression state)
  (let ((*sal-pvs-state* state))
    (if (not (sal-pvs-temporal-p expression))
        (sal-pvs-expression expression)
        (let ((arguments (and (typep expression 'sal-application)
                              (sal-application-arguments expression))))
          (labels ((at (e) (sal-pvs-ctl-expression e state))
                   (operator (name)
                     (format nil "ctl.~A(~A)(~A)" name
                             (sal-pvs-join
                              (mapcar (lambda (arg)
                                        (let ((s (sal-pvs-fresh "ctlstate")))
                                          (format nil "LAMBDA (~A: State): ~A" s
                                                  (sal-pvs-ctl-expression arg s)))) arguments)
                              ", ") state)))
            (typecase expression
              (sal-let-expr
               (format nil "(LET ~A IN ~A)"
                       (sal-pvs-join
                        (mapcar (lambda (binding)
                                  (format nil "~A: ~A = ~A" (sal-pvs-binding-name binding)
                                          (sal-pvs-type (type binding)) (at (value binding))))
                                (local-decls expression)) ", ")
                       (at (expr expression))))
              (sal-tuple-literal
               (format nil "(~A)" (sal-pvs-join (mapcar #'at (exprs expression)) ", ")))
              (sal-ctl-ex (operator "next_exists"))
              (sal-ctl-ax (operator "next_all"))
              (sal-ctl-ef (operator "eventually_exists"))
              (sal-ctl-af (operator "eventually_all"))
              (sal-ctl-eg (operator "globally_exists"))
              (sal-ctl-ag (operator "globally_all"))
              (sal-ctl-eu (operator "until_exists"))
              (sal-ctl-au (operator "until_all"))
              (sal-ctl-er (operator "release_exists"))
              (sal-ctl-ar (operator "release_all"))
              (sal-local-binds-expr
               (format nil "(~A (~A): ~A)"
                       (typecase expression (sal-for-all-expr "FORALL")
                                 (sal-exists-expr "EXISTS")
                                 (t (sal-elaboration-fail expression "Unsupported CTL binder")))
                       (sal-pvs-bindings (local-decls expression)) (at (expr expression))))
              (sal-not (format nil "(NOT ~A)" (at (first arguments))))
              (sal-and (sal-pvs-infix "AND" (mapcar #'at arguments)))
              (sal-or (sal-pvs-infix "OR" (mapcar #'at arguments) "FALSE"))
              (sal-implies (sal-pvs-infix "IMPLIES" (mapcar #'at arguments)))
              (sal-iff (sal-pvs-infix "IFF" (mapcar #'at arguments)))
              (sal-xor (sal-pvs-infix "XOR" (mapcar #'at arguments)))
              (sal-conditional
               (format nil "(IF ~A THEN ~A ELSE ~A ENDIF)" (at (sal-cond-expr expression))
                       (at (sal-then-expr expression)) (at (sal-else-expr expression))))
              (t (sal-elaboration-fail expression "Mixed or unsupported CTL expression ~A"
                                       (class-name (class-of expression))))))))))

(defun sal-pvs-note-origin (name origin)
  (when *sal-pvs-origin-table*
    (setf (gethash (if *sal-pvs-origin-prefix*
                      (concatenate 'string *sal-pvs-origin-prefix* "::" name)
                      name)
                  *sal-pvs-origin-table*) origin)))

(defun sal-pvs-write-declaration (stream name body origin)
  (let ((helpers (nreverse *sal-pvs-pending-helpers*)))
    (setf *sal-pvs-pending-helpers* nil)
    (dolist (helper helpers)
      (sal-pvs-note-origin (first helper) (third helper))
      (format stream "  ~A~%~%" (second helper))))
  (sal-pvs-note-origin name origin)
  (format stream "  ~A~%~%" body))

(defun sal-pvs-relation-expression (expression &optional two-state-p)
  (let ((*sal-pvs-hoist-lets* t)
        (*sal-pvs-total-helper-cache* (make-hash-table :test #'eq))
        (*sal-pvs-lexical-depth* 0)
        (*sal-pvs-let-references* (make-hash-table :test #'eq))
        (*sal-pvs-helper-call-arguments* (if two-state-p "s, next" "s, s")))
    (sal-pvs-expression expression)))

(defun sal-pvs-recursive-calls (declaration)
  (let ((calls nil))
    (labels ((walk (node)
               (when (and (typep node 'sal-application)
                          (typep (fun node) 'sal-name-expr)
                          (eq (decl (fun node)) declaration))
                 (push node calls))
               (when (typep node 'sal-ast) (sal-map-children #'walk node))))
      (walk (value declaration)))
    (nreverse calls)))

(defun sal-pvs-recursion-measure (declaration parameters calls)
  "Suggest a measure; PVS still generates and checks its termination TCCs.
Structural descent, bounded upward counters and natural downward counters
cover the source libraries. This never asserts that a recursive call decreases."
  (labels ((parameter-p (expression parameter)
             (and (typep expression 'sal-name-expr)
                  (eq (decl expression) parameter)))
           (call-arguments (index)
             (mapcar (lambda (call) (nth index (sal-application-arguments call))) calls))
           (changed-p (parameter index)
             (some (lambda (arg) (not (parameter-p arg parameter))) (call-arguments index))))
    ;; An unguarded self-call with the identical argument tuple has no descent.
    ;; Preserve this source error as an explicitly false termination TCC rather
    ;; than deleting the definition or pretending that it is an LTL template.
    (let* ((value (value declaration))
           (body (and (typep value 'sal-lambda) (expr value))))
      (when (and (= (length calls) 1) (eq body (first calls))
                 (= (length parameters) (length (sal-application-arguments body)))
                 (every #'parameter-p (sal-application-arguments body) parameters))
        (return-from sal-pvs-recursion-measure "0")))
    ;; A native datatype's subterm ordering exposes selector-domain TCCs too.
    (loop for parameter in parameters for index from 0
          when (and (typep (sal-pvs-unalias-type (type parameter)) 'sal-data-type)
                    (changed-p parameter index))
            do (return-from sal-pvs-recursion-measure
                 (format nil "~A BY <<" (sal-pvs-binding-name parameter))))
    ;; Bounded counters frequently count upward (SATS and PCP examples).
    (loop for parameter in parameters for index from 0
          for type = (sal-pvs-unalias-type (type parameter))
          when (and (typep type 'sal-bounded-subtype)
                    (some (lambda (arg)
                            (and (typep arg 'sal-add)
                                 (some (lambda (a) (parameter-p a parameter))
                                       (sal-application-arguments arg))))
                          (call-arguments index)))
            do (return-from sal-pvs-recursion-measure
                 (format nil "(~A - ~A)" (sal-pvs-expression (upper type))
                         (sal-pvs-binding-name parameter))))
    ;; Prefer an explicitly decreasing argument before a changing accumulator.
    (loop for parameter in parameters for index from 0
          when (some (lambda (arg)
                       (and (typep arg 'sal-sub)
                            (parameter-p (first (sal-application-arguments arg)) parameter)))
                     (call-arguments index))
            do (return-from sal-pvs-recursion-measure (sal-pvs-binding-name parameter)))
    ;; Euclid's algorithm uses a let-bound residue in its final natural argument.
    (loop for parameter in (reverse parameters)
          for index downfrom (1- (length parameters))
          when (and (typep (sal-pvs-unalias-type (type parameter)) 'sal-nat-type)
                    (changed-p parameter index))
            do (return-from sal-pvs-recursion-measure (sal-pvs-binding-name parameter)))
    (sal-elaboration-fail declaration "Cannot infer a termination measure for recursive function ~A"
                          (sal-declaration-name declaration))))

(defun sal-pvs-constant-definition (declaration)
  (let ((name (sal-pvs-name declaration))
        (calls (and (value declaration) (sal-pvs-recursive-calls declaration))))
    (if calls
        (let* ((body (value declaration))
               (type (sal-pvs-unalias-type (type declaration))))
          (unless (and (typep body 'sal-lambda) (typep type 'sal-function-type))
            (sal-elaboration-fail declaration "Recursive source definition must be a function"))
          (format nil "~A(~A): RECURSIVE ~A = ~A~%    MEASURE ~A"
                  name (sal-pvs-bindings (local-decls body)) (sal-pvs-type (range type))
                  (sal-pvs-expression (expr body))
                  (sal-pvs-recursion-measure declaration (local-decls body) calls)))
        (format nil "~A: ~A~A" name (sal-pvs-type (type declaration))
                (if (value declaration)
                    (format nil " = ~A" (sal-pvs-expression (value declaration))) "")))))

(defun sal-pvs-write-context-declarations (context stream)
  (dolist (declaration (declarations context))
    (let ((name (sal-pvs-name declaration)))
      (typecase declaration
        (sal-type-decl
         (let ((type (type declaration)))
           (cond
             ((typep type 'sal-data-type)
              (sal-pvs-note-origin name declaration)
              (format stream "  ~A: DATATYPE~%  BEGIN~%" name)
              (dolist (constructor-ref (constructors type))
                (let ((constructor (decl constructor-ref)))
                  (format stream "    ~A~A: ~A~%"
                          (sal-pvs-name constructor)
                          (if (accessors constructor)
                              (format nil "(~A)"
                                      (sal-pvs-join
                                       (mapcar (lambda (ref)
                                                 (format nil "~A: ~A"
                                                         (sal-pvs-name (decl ref))
                                                         (sal-pvs-type (range (type (decl ref))))))
                                               (accessors constructor)) ", "))
                              "")
                          (sal-pvs-name (recognizer-decl constructor)))))
              (format stream "  END ~A~%~%" name))
             (t (sal-pvs-write-declaration
                 stream name
                 (if type (format nil "~A: TYPE = ~A" name (sal-pvs-type type))
                     (format nil "~A: TYPE" name)) declaration)))))
        (sal-constant-decl
         ;; SAL's source XML may also serialize an implicit constructor as an
         ;; ordinary CONSTANTDECLARATION. The reader's resolved value table
         ;; retains its actual implicit declaration, while the source-order
         ;; list retains the original placeholder.
         (unless (or (typep declaration 'sal-implicit-decl)
                     (typep (gethash (sal-declaration-name declaration)
                                     (constant-declarations context))
                            'sal-implicit-decl))
           (if (sal-pvs-temporal-declaration-p declaration)
               (progn
                 (sal-pvs-note-origin name declaration)
                 (format stream "  % SAL temporal macro ~A is expanded at property uses.~%~%"
                         (sal-declaration-name declaration))
                 (sal-pvs-write-declaration
                  stream (concatenate 'string "bridge_temporal_signature_" name)
                  (format nil "bridge_temporal_signature_~A: ~A" name
                          (sal-pvs-type (type declaration))) declaration)
                 (let ((*sal-pvs-temporal-typecheck* t)
                       (*sal-pvs-typecheck-bindings* nil))
                   (sal-pvs-write-declaration
                    stream (concatenate 'string "bridge_temporal_check_" name)
                    (format nil "bridge_temporal_check_~A: ~A = ~A" name
                            (sal-pvs-type (type declaration))
                            (sal-pvs-expression (value declaration))) declaration)))
               (sal-pvs-write-declaration
                stream name (sal-pvs-constant-definition declaration) declaration))))
        (sal-assertion-decl
         ;; Context-level mathematical theorems belong to the library theory.
         ;; Module assertions are emitted only in their selected machine view.
         (let ((formula (assertion-expr declaration)))
           (unless (typep formula 'sal-assertion-expr)
             (sal-pvs-write-declaration
              stream name (format nil "~A: THEOREM ~A" name (sal-pvs-expression formula))
              declaration))))))))

(defun sal-pvs-context-dependencies (context)
  (let ((dependencies nil))
    (sal-walk-ast
     (lambda (node)
       (let ((owner (typecase node
                      (sal-qualified-name-ref (context-ref node))
                      (sal-context-name-decl (context-ref node)))))
         (when (and owner (not (eq owner context))
                    (not (string= (sal-declaration-name owner) "prelude")))
           (pushnew owner dependencies :test #'eq))))
     context)
    (nreverse dependencies)))

(defun sal-pvs-render-context (context view)
  "A SAL context is a native parametric PVS theory, shared by all instances."
  (let* ((*sal-pvs-context* context)
         (*sal-pvs-state-declarations* nil)
         (*sal-pvs-fresh-counter* 0)
         (*sal-pvs-local-names* (make-hash-table :test #'eq))
         (*sal-pvs-origin-table* (sal-transition-view-origins view))
         (*sal-pvs-origin-prefix* (sal-pvs-context-theory-name context)))
    (with-output-to-string (stream)
      (format stream "% SAL context ~A; source ~A.~%~A~A: THEORY~%BEGIN~%~%"
              (sal-declaration-name context) (file-name context)
              *sal-pvs-origin-prefix* (sal-pvs-formals (params context)))
      (dolist (parameter (params context))
        (sal-pvs-note-origin (sal-pvs-name parameter) parameter))
      ;; Generic imports put the dependency's declaration names in scope.
      ;; Each use keeps its own explicit actuals, including locally bound ones.
      (dolist (dependency (sal-pvs-context-dependencies context))
        (format stream "  IMPORTING ~A~%" (sal-pvs-context-theory-name dependency)))
      (terpri stream)
      (sal-pvs-write-context-declarations context stream)
      (sal-pvs-write-module-checks view stream "context" context)
      (format stream "END ~A~%" *sal-pvs-origin-prefix*))))

(defun sal-pvs-write-module-checks (view stream scope context)
  (loop for check in (sal-transition-view-module-checks view)
        for index from 1
        when (and (string= scope (sal-module-check-scope check))
                  (eq context (sal-module-check-context check)))
          do (let* ((name (format nil "check_module_~D" index))
                    (expression (sal-module-check-expression check)))
               (sal-pvs-write-declaration
                stream name (format nil "~A: bool = ~A" name
                                    (sal-pvs-expression expression)) expression))))

(defun sal-pvs-view-formals (view)
  (append (unless (sal-transition-view-instantiated-p view)
            (params (sal-transition-view-context view)))
          (sal-transition-view-module-parameters view)))

(defun sal-pvs-view-formal-text (view)
  ;; Module parameters may use a type declared inside their context. The main
  ;; theory's IMPORTING clause is not yet in scope while its formals are read.
  (let ((*sal-pvs-qualify-current-context* t)
        (*sal-pvs-current-context-actuals* (sal-transition-view-root-actuals view)))
    (let ((formals (sal-pvs-view-formals view))
          (first-module-parameter (first (sal-transition-view-module-parameters view))))
      (if formals
          (format nil "[~A]"
                  (sal-pvs-join
                   (mapcar (lambda (formal)
                             (sal-pvs-formal-with-imports
                              formal (and (eq formal first-module-parameter)
                                          (or (sal-transition-view-contexts view)
                                              (list *sal-pvs-context*))))) formals)
                   ", "))
          ""))))

(defun sal-pvs-view-actuals (view)
  (sal-pvs-join (mapcar #'sal-pvs-name (sal-pvs-view-formals view)) ", "))

(defun sal-pvs-view-instance (view)
  (format nil "~A~A" (sal-transition-view-theory-name view)
          (if (sal-pvs-view-formals view)
              (format nil "[~A]" (sal-pvs-view-actuals view)) "")))

(defun sal-pvs-assignment-containing-p (expression)
  (not (null
        (sal-find-ast (lambda (node)
                        (or (typep node 'sal-assignment)
                            (typep node 'sal-definition-expression)))
                      expression))))

(defun sal-pvs-choice-containing-p (expression)
  (not (null (sal-find-ast (lambda (node) (typep node 'sal-choice)) expression))))

(defun sal-pvs-write-assignment-checks (expression stream phase)
  "Emit independent assignment and nondeterministic-arm typing checks.
The operational relation stays unchanged. Checking expressions are generated
from the same assignment nodes, with the original path guards and binders.
Choices do not acquire priority; ordinary Boolean expressions retain their
native non-strict contexts. Assignments and choices are not assumed guards."
  (let ((counter 0)
        (choice-counter 0)
        (*sal-pvs-total-helper-cache* (make-hash-table :test #'eq)))
    (labels
        ((walk (node guards binders)
           (typecase node
             (sal-assignment
              (let* ((args (sal-application-arguments node))
                     (lhs (first args)) (rhs (second args))
                     (target-type (sal-pvs-expression-type lhs))
                     (name nil))
                (unless target-type
                  (sal-elaboration-fail node "Cannot recover assignment target type"))
                ;; Primitive bool and real cannot widen further within the
                ;; admitted PVS carriers. Omit only total expressions: a
                ;; preceding overlapping disjunct may mask a partial-call
                ;; domain in the relation, so it still needs this independent
                ;; source check. Aliases and all proper subtypes also retain it.
                (unless (and (member (sal-pvs-type target-type) '("bool" "real") :test #'string=)
                             (sal-pvs-total-helper-value-p lhs)
                             (sal-pvs-total-helper-value-p rhs))
                  (setf name (format nil "check_~A_~D" phase (incf counter)))
                  (sal-pvs-write-declaration
                   stream name
                   (format nil "~A(s, next: State~A): bool =~%    ~A IMPLIES (LET bridge_rhs: ~A = ~A IN TRUE)"
                           name
                           (if binders (format nil ", ~A" (sal-pvs-bindings binders)) "")
                           (sal-pvs-infix "AND" (mapcar #'sal-pvs-expression guards))
                           (sal-pvs-type target-type) (sal-pvs-expression rhs)) node))))
             (sal-definition-expression
              ;; IN is relational intersection, not a deterministic assignment
              ;; or a promise that every candidate inhabits the target type.
              (walk (expr node) guards binders))
             (sal-choice
              ;; SAL choice is not PVS's short-circuit Boolean OR: a true arm
              ;; must not hide a domain error in another arm's guard. Check
              ;; each complete arm independently, retaining its internal
              ;; IF/AND/OR and their non-strict typing assumptions. The LET
              ;; checks definedness; it does not assert that the arm is true.
              ;; Assignment target membership is checked separately above.
              ;; Emit those existing checks first so native TCC subsumption
              ;; keeps their assignment-specific names and source locations.
              (dolist (arm (sal-application-arguments node))
                (walk arm guards binders))
              (dolist (arm (sal-application-arguments node))
                ;; Reuse the conservative totality classifier to avoid
                ;; duplicating large, already-total Boolean LET circuits.
                (unless (sal-pvs-total-helper-value-p arm)
                  (let ((name (format nil "check_choice_~A_~D"
                                      phase (incf choice-counter))))
                    (sal-pvs-write-declaration
                     stream name
                     (format nil "~A(s, next: State~A): bool =~%    ~A IMPLIES (LET bridge_choice: bool = ~A IN TRUE)"
                             name
                             (if binders (format nil ", ~A" (sal-pvs-bindings binders)) "")
                             (sal-pvs-infix "AND" (mapcar #'sal-pvs-expression guards))
                             (sal-pvs-expression arm)) arm)))))
             (sal-and
              (let* ((args (sal-application-arguments node))
                     (guard-parts
                       ;; A choice with no assignments still cannot justify
                       ;; its own arm checks by being assumed as a guard.
                       (remove-if (lambda (arg)
                                    (or (sal-pvs-assignment-containing-p arg)
                                        (sal-pvs-choice-containing-p arg)))
                                  args)))
                (dolist (arg args) (walk arg (append guards guard-parts) binders))))
             (sal-or
              (dolist (arg (sal-application-arguments node)) (walk arg guards binders)))
             (sal-implies
              (let ((args (sal-application-arguments node)))
                (walk (first args) guards binders)
                (walk (second args) (append guards (list (first args))) binders)))
             (sal-conditional
              (walk (sal-cond-expr node) guards binders)
              (walk (sal-then-expr node) (append guards (list (sal-cond-expr node))) binders)
              ;; Negation construction uses the existing AST and source place.
              (let ((negative (make-instance 'sal-not :arg (sal-cond-expr node))))
                (walk (sal-else-expr node) (append guards (list negative)) binders)))
             (sal-let-expr
              (when (sal-pvs-assignment-containing-p node)
                (sal-elaboration-fail node "Assignments under normalized LET require binder lifting")))
             (sal-local-binds-expr
              (walk (expr node) guards (append binders (local-decls node))))
             (sal-ast
              (sal-map-children (lambda (child) (walk child guards binders)) node)))))
      (walk expression nil nil))))

(defun sal-pvs-property-body (expression)
  (cond
    ((sal-pvs-ctl-p expression)
     (format nil "FORALL (s: State): initial(s) IMPLIES ~A"
             (sal-pvs-ctl-expression expression "s")))
    ((and (typep expression 'sal-ltl-g)
          (not (sal-pvs-temporal-p (first (sal-application-arguments expression)))))
     (format nil "system.invariant(LAMBDA (s: State): ~A)"
             (sal-pvs-expression (first (sal-application-arguments expression)))))
    ((sal-pvs-temporal-p expression)
     (format nil "system.satisfies(LAMBDA (p: system.path, k: nat): ~A)"
             (sal-pvs-ltl-expression expression "p" "k")))
    (t (sal-elaboration-fail expression
                             "A module property must explicitly select a temporal modality"))))

(defun sal-pvs-render-view (view &key (progress-checks t))
  (declare (ignore progress-checks))
  (let* ((context (sal-transition-view-context view))
         (flat (sal-transition-view-flat-module view))
         (*sal-pvs-context* context)
         (*sal-pvs-current-context-actuals* (sal-transition-view-root-actuals view))
         (*sal-pvs-state-declarations* (state-vars flat))
         (*sal-pvs-state* "s")
         (*sal-pvs-next-state* "next")
         (*sal-pvs-fresh-counter* 0)
         (*sal-pvs-local-names* (make-hash-table :test #'eq))
         (*sal-pvs-origin-table* (sal-transition-view-origins view))
         (*sal-pvs-pending-helpers* nil)
         (*sal-pvs-origin-prefix* nil)
         (theory (or (sal-transition-view-theory-name view)
                     (format nil "SAL_~A_~A"
                             (sal-pvs-name (sal-declaration-name context))
                             (sal-pvs-name (sal-transition-view-module-name view))))))
    (unless (typep flat 'sal-flat-module)
      (sal-elaboration-fail flat "The shared view requires a SAL-normalized flat module"))
    (let ((text
            (with-output-to-string (stream)
              (format stream "% Generated from ~A, module ~A.~%" (sal-transition-view-source view)
                      (sal-transition-view-module-name view))
              (format stream "% The relations below are exported by SAL's module normalizer.~%")
              (format stream "~A~A: THEORY~%BEGIN~%~%" theory
                      (sal-pvs-view-formal-text view))
              ;; Explicit selector actuals can mention a context which the
              ;; generic root source never imported. Their namespace must be
              ;; visible before the specialized root import is typechecked.
              (dolist (dependency (sal-transition-view-contexts view))
                (unless (eq dependency context)
                  (format stream "  IMPORTING ~A~%" (sal-pvs-context-theory-name dependency))))
              (format stream "  IMPORTING ~A~%~%"
                      (sal-pvs-context-instance context (sal-transition-view-root-actuals view)))
              (dolist (parameter (sal-pvs-view-formals view))
                (sal-pvs-note-origin (sal-pvs-name parameter) parameter))
              (sal-pvs-write-declaration
               stream "State"
               (if (state-vars flat)
                   (format nil "State: TYPE = [# ~A #]"
                           (sal-pvs-join
                            (mapcar (lambda (decl)
                                      (format nil "~A: ~A" (sal-pvs-name decl)
                                              (sal-pvs-type (type decl))))
                                    (state-vars flat)) ", "))
                   "State: TYPE = {bridge_unit}") flat)
              ;; Reuse the state variable declarations for the normalized DAG
              ;; helpers; repeatedly redeclaring very wide record binders is
              ;; expensive in PVS. Each helper still has two explicit inputs.
              (format stream "  s, next: VAR State~%~%")
              (sal-pvs-write-declaration
               stream "defined" (format nil "defined(s: State): bool = ~A"
                                         (sal-pvs-relation-expression (definition flat))) flat)
              (sal-pvs-write-declaration
               stream "initial"
               (format nil "initial(s: State): bool = defined(s) AND ~A"
                       (sal-pvs-relation-expression (initialization flat))) flat)
              (sal-pvs-write-declaration
               stream "step"
               (format nil "step(s, next: State): bool = defined(s) AND defined(next) AND ~A"
                       (sal-pvs-relation-expression (transition flat) t)) flat)
              (sal-pvs-write-declaration
               stream "idle"
               (format nil "idle(s, next: State): bool = defined(s) AND defined(next) AND ~A"
                       (sal-pvs-relation-expression (sal-skip flat) t)) flat)
              (format stream "  IMPORTING SAL_Transition_System[State, initial, step] AS system~%~%")
              (when (some (lambda (p) (sal-pvs-ctl-p (cdr p)))
                          (sal-transition-view-properties view))
                (format stream "  IMPORTING SAL_CTL[State, step] AS ctl~%~%"))
              (format stream "  % Separate checks preserve nondeterministic branch typing.~%")
              (sal-pvs-write-module-checks view stream "view" context)
              (sal-pvs-write-assignment-checks (definition flat) stream "definition")
              (sal-pvs-write-assignment-checks (initialization flat) stream "initial")
              (sal-pvs-write-assignment-checks (transition flat) stream "step")
              (dolist (property (sal-transition-view-properties view))
                (let ((name (sal-pvs-name (car property))))
                  (sal-pvs-write-declaration
                   stream name (format nil "~A: THEOREM ~A" name
                                       (sal-pvs-property-body (cdr property)))
                   (or (cdr (assoc (car property)
                                   (sal-transition-view-property-origins view)
                                   :test #'string=))
                       (cdr property)))))
              (format stream "END ~A~%" theory))))
      (setf (sal-transition-view-theory-name view) theory
            (sal-transition-view-origins view) *sal-pvs-origin-table*
            (sal-transition-view-pvs-text view) text)
      text)))

(defun sal-pvs-render-progress-view (view)
  "Keep progress contracts separate from the typing/safety theory.
An open component may block intentionally; its safety development must not
acquire the companion theory's progress assumptions."
  (let* ((context (sal-transition-view-context view))
         (*sal-pvs-context* context)
         (name (format nil "~A_progress" (sal-transition-view-theory-name view))))
    (setf (sal-transition-view-progress-theory-name view) name
          (gethash "progress" (sal-transition-view-origins view))
          (sal-transition-view-flat-module view))
    (format nil "% Optional initialization and deadlock obligations for ~A.~%~A~A: THEORY~%BEGIN~%  IMPORTING ~A~%~%  progress: THEORY = SAL_Progress_Contract{{~%    S := State, initial := initial, step := step }}~%END ~A~%"
            (sal-transition-view-module-name view) name
            (sal-pvs-view-formal-text view)
            (sal-pvs-view-instance view) name)))

(defun sal-elaborate-view (view output-directory &key (progress-checks t))
  "Write a readable shallow theory for VIEW and return VIEW.
No output is written until the complete view has passed elaboration."
  (let* ((directory (uiop:ensure-directory-pathname
                     (sal-bridge-output-path output-directory))))
    (setf (sal-transition-view-origins view) (make-hash-table :test #'equal))
    (let* ((contexts (or (sal-transition-view-contexts view)
                         (list (sal-transition-view-context view))))
           (context-texts
            (mapcar (lambda (context)
                      (cons (merge-pathnames
                             (format nil "~A.pvs" (sal-pvs-context-theory-name context)) directory)
                            (sal-pvs-render-context context view))) contexts))
           (machine-p (not (null (sal-transition-view-flat-module view))))
           (text (and machine-p (sal-pvs-render-view view)))
           (progress-text (and machine-p progress-checks (sal-pvs-render-progress-view view)))
           (file (merge-pathnames
                  (format nil "~A.pvs" (if machine-p (sal-transition-view-theory-name view)
                                           (sal-pvs-context-theory-name
                                            (sal-transition-view-context view)))) directory))
           (progress-file
             (and progress-text
                  (merge-pathnames
                   (format nil "~A.pvs" (sal-transition-view-progress-theory-name view))
                   directory))))
      (sal-prepare-output-directory directory)
      (ensure-directories-exist file)
      (dolist (entry context-texts) (sal-write-file-if-changed (car entry) (cdr entry)))
      (when machine-p (sal-write-file-if-changed file text))
      (when progress-file
        (sal-write-file-if-changed progress-file progress-text))
      (setf (sal-transition-view-pvs-file view) file
            (sal-transition-view-context-pvs-files view) (mapcar #'car context-texts)
            (sal-transition-view-context-pvs-texts view) context-texts
            (sal-transition-view-progress-pvs-file view) progress-file)
      (unless machine-p
        (setf (sal-transition-view-theory-name view)
              (sal-pvs-context-theory-name (sal-transition-view-context view))
              (sal-transition-view-pvs-text view) (cdr (assoc file context-texts :test #'equal))))
      (unless progress-text (setf (sal-transition-view-progress-theory-name view) nil))
      view)))
