;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; xml-reader.lisp -- Read SAL source files through SAL's XML exporter
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

(export '(read-sal-file
          sal-xml-to-ast
          *sal-to-xml-program*
          sal-source-place
          sal-source-place-initial-line
          sal-source-place-initial-column
          sal-source-place-final-line
          sal-source-place-final-column))

(defparameter *sal-to-xml-program* nil
  "The SAL-to-XML executable used by READ-SAL-FILE.

When NIL, the reader checks SAL_TO_XML, SAL_HOME/tools/sal-to-xml.sh, PATH,
and the conventional ~/projects/misc/sal/sal-3.3 checkout, in that order.")

(defstruct (sal-source-place
             (:constructor make-sal-source-place
                 (initial-line initial-column final-line final-column)))
  initial-line
  initial-column
  final-line
  final-column)

(define-condition sal-xml-error (error)
  ((message :initarg :message :reader sal-xml-error-message)
   (node :initarg :node :initform nil :reader sal-xml-error-node))
  (:report
   (lambda (condition stream)
     (format stream "~a" (sal-xml-error-message condition))
     (when (sal-xml-error-node condition)
       (format stream " (XML element ~a)"
               (xmls:node-name (sal-xml-error-node condition)))))))

(defstruct (sal-xml-state (:constructor %make-sal-xml-state))
  context
  (scopes nil)
  (top-declarations (make-hash-table :test #'equal))
  (external-declarations (make-hash-table :test #'equal))
  (external-contexts (make-hash-table :test #'equal)))

(declaim (ftype (function (sal-xml-state t) t)
                sal-convert-expression sal-convert-module
                sal-convert-assertion-expression sal-convert-actual)
         (ftype (function (sal-xml-state t &optional t) t)
                sal-convert-type))

(defparameter *sal-builtin-application-classes*
  '(("=" . sal-eq)
    ("/=" . sal-diseq)
    ("AND" . sal-and)
    ("OR" . sal-or)
    ("XOR" . sal-xor)
    ("NOT" . sal-not)
    ("=>" . sal-implies)
    ("<=>" . sal-iff)
    ("+" . sal-add)
    ("-" . sal-sub)
    ("*" . sal-mul)
    ("/" . sal-div)
    ("DIV" . sal-idiv)
    ("MOD" . sal-mod)
    ("MAX" . sal-max)
    ("MIN" . sal-min)
    ("<" . sal-lt)
    (">" . sal-gt)
    ("<=" . sal-le)
    (">=" . sal-ge)
    ("REAL?" . sal-real-pred)
    ("REAL-PRED?" . sal-real-pred)
    ("REAL_PRED?" . sal-real-pred)
    ("INTEGER?" . sal-int-pred)
    ("INT-PRED?" . sal-int-pred)
    ("INT_PRED?" . sal-int-pred)
    ("X" . sal-ltl-x)
    ("G" . sal-ltl-g)
    ("F" . sal-ltl-f)
    ("U" . sal-ltl-u)
    ("R" . sal-ltl-r)
    ("W" . sal-ltl-w)
    ("M" . sal-ltl-m)
    ("AX" . sal-ctl-ax)
    ("EX" . sal-ctl-ex)
    ("AG" . sal-ctl-ag)
    ("EG" . sal-ctl-eg)
    ("AF" . sal-ctl-af)
    ("EF" . sal-ctl-ef)
    ("AU" . sal-ctl-au)
    ("EU" . sal-ctl-eu)
    ("AR" . sal-ctl-ar)
    ("ER" . sal-ctl-er)
    ("ACCEPTING" . sal-accepting)
    ("WEAK-ACCEPTING" . sal-weak-accepting)
    ("WEAK_ACCEPTING" . sal-weak-accepting)
    ("RPRED" . sal-ring-pre)
    ("RSUCC" . sal-ring-succ)
    ("DBG_PRINT" . sal-debug-print)
    ("DBG_EXPR" . sal-debug-expr)))

(defparameter *sal-builtin-type-classes*
  '(("any" . sal-any-type)
    ("boolean" . sal-bool-type)
    ("number" . sal-number-type)
    ("real" . sal-real-type)
    ("integer" . sal-int-type)
    ("natural" . sal-nat-type)
    ("nat" . sal-nat-type)
    ("string" . sal-string-type)))

(defun sal-xml-fail (node control &rest arguments)
  (error 'sal-xml-error
         :node node
         :message (apply #'format nil control arguments)))

(defun sal-xml-elements (node)
  (remove-if-not #'xmls:node-p (xmls:node-children node)))

(defun sal-xml-text (node)
  (string-trim '(#\Space #\Tab #\Newline #\Return)
               (with-output-to-string (stream)
                 (dolist (child (xmls:node-children node))
                   (when (stringp child)
                     (write-string child stream))))))

(defun sal-xml-attribute (node attribute)
  (second (assoc attribute (xmls:node-attrs node) :test #'string-equal)))

(defun sal-xml-child (node tag &optional requiredp)
  (or (find tag (sal-xml-elements node)
            :key #'xmls:node-name :test #'string-equal)
      (when requiredp
        (sal-xml-fail node "Expected a ~a child" tag))))

(defun sal-source-place-from-xml (node)
  (let ((place (sal-xml-attribute node "PLACE")))
    (when place
      (let ((numbers (mapcar #'parse-integer
                             (uiop:split-string place
                                                :separator '(#\Space #\Tab)))))
        (unless (= (length numbers) 4)
          (sal-xml-fail node "Invalid PLACE attribute ~s" place))
        (apply #'make-sal-source-place numbers)))))

(defun sal-node (class state xml &rest initargs)
  (apply #'make-instance class
         :place (sal-source-place-from-xml xml)
         :context (sal-xml-state-context state)
         initargs))

(defun sal-identifier-from-xml (state node)
  (unless (string-equal (xmls:node-name node) "IDENTIFIER")
    (sal-xml-fail node "Expected an IDENTIFIER"))
  (sal-node 'sal-identifier state node
            :name (make-symbol (sal-xml-text node))))

(defun sal-identifier-string (identifier)
  (symbol-name (name identifier)))

(defun sal-declaration-name (declaration)
  (sal-identifier-string (id declaration)))

(defun sal-namespace-key (namespace name)
  (list namespace name))

(defun sal-scope-bind (scope namespace declaration)
  (setf (gethash (sal-namespace-key namespace
                                    (sal-declaration-name declaration))
                 scope)
        declaration)
  declaration)

(defun sal-state-bind-top (state namespace declaration)
  (setf (gethash (sal-namespace-key namespace
                                    (sal-declaration-name declaration))
                 (sal-xml-state-top-declarations state))
        declaration)
  declaration)

(defun sal-state-lookup (state namespace name)
  (or (loop for scope in (sal-xml-state-scopes state)
            for declaration = (gethash (sal-namespace-key namespace name)
                                       scope)
            when declaration return declaration)
      (gethash (sal-namespace-key namespace name)
               (sal-xml-state-top-declarations state))))

(defun sal-call-with-scope (state scope thunk)
  (let ((old-scopes (sal-xml-state-scopes state)))
    (unwind-protect
         (progn
           (setf (sal-xml-state-scopes state) (cons scope old-scopes))
           (funcall thunk))
      (setf (sal-xml-state-scopes state) old-scopes))))

(defun sal-declaration-class-for-namespace (namespace)
  (ecase namespace
    (:value 'sal-constant-decl)
    (:type 'sal-type-decl)
    (:module 'sal-module-decl)
    (:assertion 'sal-assertion-decl)
    (:context 'sal-context-name-decl)))

(defun sal-external-declaration (state namespace name xml
                                 &optional declaration-class)
  (or (sal-state-lookup state namespace name)
      (let* ((key (sal-namespace-key namespace name))
             (table (sal-xml-state-external-declarations state)))
        (or (gethash key table)
            (setf (gethash key table)
                  (sal-node (or declaration-class
                                (sal-declaration-class-for-namespace namespace))
                            state xml
                            :id (sal-node 'sal-identifier state xml
                                          :name (make-symbol name))))))))

(defun sal-qualified-declaration (state context-ref namespace name xml)
  (let ((table
          (ecase namespace
            (:value (constant-declarations context-ref))
            (:type (type-declarations context-ref))
            (:module (module-declarations context-ref))
            (:assertion (assertion-declarations context-ref)))))
    (or (gethash name table)
        (let ((declaration
                (sal-node (sal-declaration-class-for-namespace namespace)
                          state xml
                          :id (sal-node 'sal-identifier state xml
                                        :name (make-symbol name)))))
          (setf (context declaration) context-ref
                (context (id declaration)) context-ref
                (gethash name table) declaration)
          declaration))))

(defun sal-empty-context (state name xml)
  (or (and (string= name
                    (sal-declaration-name (sal-xml-state-context state)))
           (sal-xml-state-context state))
      (gethash name (sal-xml-state-external-contexts state))
      (setf (gethash name (sal-xml-state-external-contexts state))
            (let ((context
                    (sal-node 'sal-context state xml
                              :id (sal-node 'sal-identifier state xml
                                            :name (make-symbol name))
                              :params nil
                              :declarations nil
                              :constant-declarations
                              (make-hash-table :test #'equal)
                              :type-declarations
                              (make-hash-table :test #'equal)
                              :module-declarations
                              (make-hash-table :test #'equal)
                              :assertion-declarations
                              (make-hash-table :test #'equal)
                              :context-name-declarations
                              (make-hash-table :test #'equal))))
              (setf (context context) context)
              context))))

(defun sal-read-number (node)
  (let* ((text (sal-xml-text node))
         (slash (position #\/ text)))
    (handler-case
        (if slash
            (/ (parse-integer text :end slash)
               (parse-integer text :start (1+ slash)))
            (parse-integer text))
      (error ()
        (sal-xml-fail node "Invalid SAL numeral ~s" text)))))

(defun sal-builtin-application-class (name)
  (cdr (assoc name *sal-builtin-application-classes* :test #'string-equal)))

(defun sal-builtin-type-class (name)
  (cdr (assoc name *sal-builtin-type-classes* :test #'string-equal)))

(defun sal-name-expression-class (name declaration qualifiedp)
  (cond ((string-equal name "TRUE") 'sal-true)
        ((string-equal name "FALSE") 'sal-false)
        ((typep declaration 'sal-var-param-decl)
         'sal-var-param-name-expr)
        ((typep declaration 'sal-scalar-element-decl) 'sal-scalar)
        ((typep declaration 'sal-constructor-decl) 'sal-constructor)
        ((typep declaration 'sal-accessor-decl) 'sal-accessor)
        ((typep declaration 'sal-recognizer-decl) 'sal-recognizer)
        (qualifiedp 'sal-qualified-name-expr)
        (t 'sal-name-expr)))

(defun sal-qualified-parts (state node)
  (let* ((elements (sal-xml-elements node))
         (identifier (first elements))
         (context-node (second elements)))
    (unless (and identifier context-node
                 (string-equal (xmls:node-name identifier) "IDENTIFIER")
                 (string-equal (xmls:node-name context-node) "CONTEXTNAME"))
      (sal-xml-fail node "Malformed qualified SAL name"))
    (let* ((context-elements (sal-xml-elements context-node))
           (context-name (sal-xml-text (first context-elements)))
           (actual-node (find "ACTUALPARAMETERS" context-elements
                              :key #'xmls:node-name :test #'string-equal))
           (context-declaration
             (sal-state-lookup state :context context-name))
           (context-ref
             (or (and context-declaration
                      (context-ref context-declaration))
                 (sal-empty-context state context-name context-node)))
           (actuals
             (if actual-node
                 (mapcar (lambda (child) (sal-convert-actual state child))
                         (sal-xml-elements actual-node))
                 (and context-declaration (actuals context-declaration)))))
      (values (sal-xml-text identifier)
              context-ref
              actuals))))

(defun sal-type-xml-tag-p (tag)
  (member tag '("TYPENAME" "QUALIFIEDTYPENAME" "FUNCTIONTYPE" "ARRAYTYPE"
                "TUPLETYPE" "RECORDTYPE" "STATETYPE" "SUBTYPE" "SUBRANGE"
                "SCALARTYPE" "SCALARSET" "RINGSET" "DATATYPE")
          :test #'string-equal))

(defun sal-convert-actual (state node)
  (if (sal-type-xml-tag-p (xmls:node-name node))
      (sal-convert-type state node)
      (sal-convert-expression state node)))

(defun sal-convert-name-expression (state node)
  (let* ((name (sal-xml-text node))
         (declaration
           (sal-external-declaration
            state :value name node
            (when (or (string-equal name "TRUE")
                      (string-equal name "FALSE"))
              'sal-scalar-element-decl))))
    (sal-node (sal-name-expression-class name declaration nil)
              state node :decl declaration)))

(defun sal-convert-qualified-name-expression (state node)
  (multiple-value-bind (name context-ref actuals)
      (sal-qualified-parts state node)
    (let ((declaration
            (sal-qualified-declaration state context-ref :value name node)))
      (sal-node (sal-name-expression-class name declaration t)
                state node
                :decl declaration :context-ref context-ref :actuals actuals))))

(defun sal-convert-type-name (state node &optional qualifiedp)
  (if qualifiedp
      (multiple-value-bind (name context-ref actuals)
          (sal-qualified-parts state node)
        (let ((declaration
                (sal-qualified-declaration state context-ref :type name node)))
          (sal-node (or (sal-builtin-type-class name)
                        'sal-qualified-type-name)
                    state node :decl declaration
                    :context-ref context-ref :actuals actuals)))
      (let* ((name (sal-xml-text node))
             (declaration (sal-external-declaration state :type name node)))
        (sal-node (cond ((typep declaration 'sal-type-param-decl)
                         'sal-type-param-name)
                        ((sal-builtin-type-class name))
                        (t 'sal-type-name))
                  state node :decl declaration))))

(defun sal-convert-module-name (state node &optional qualifiedp)
  (if qualifiedp
      (multiple-value-bind (name context-ref actuals)
          (sal-qualified-parts state node)
        (sal-node 'sal-qualified-module-name state node
                  :decl (sal-qualified-declaration state context-ref
                                                   :module name node)
                  :context-ref context-ref :actuals actuals))
      (let ((name (sal-xml-text node)))
        (sal-node 'sal-module-name state node
                  :decl (sal-external-declaration state :module name node)))))

(defun sal-convert-context-name-node (state node)
  (unless (string-equal (xmls:node-name node) "CONTEXTNAME")
    (sal-xml-fail node "Expected a CONTEXTNAME"))
  (let* ((elements (sal-xml-elements node))
         (name (sal-xml-text (first elements)))
         (actual-node (find "ACTUALPARAMETERS" elements
                            :key #'xmls:node-name :test #'string-equal))
         (alias (sal-state-lookup state :context name)))
    (values (or (and alias (context-ref alias))
                (sal-empty-context state name node))
            (if actual-node
                (mapcar (lambda (child) (sal-convert-actual state child))
                        (sal-xml-elements actual-node))
                (and alias (actuals alias))))))

(defun sal-make-local-declaration (state node class)
  (let ((elements (sal-xml-elements node)))
    (unless (>= (length elements) 2)
      (sal-xml-fail node "Malformed local declaration"))
    (sal-node class state node
              :id (sal-identifier-from-xml state (first elements))
              :type (sal-convert-type state (second elements)))))

(defun sal-predeclare-locals (state nodes class)
  (let ((scope (make-hash-table :test #'equal))
        (declarations nil))
    (dolist (node nodes)
      (let* ((elements (sal-xml-elements node))
             (declaration
               (sal-node class state node
                         :id (sal-identifier-from-xml state (first elements)))))
        (sal-scope-bind scope :value declaration)
        (push declaration declarations)))
    (values (nreverse declarations) scope)))

(defun sal-populate-local-types (state nodes declarations)
  (loop for node in nodes
        for declaration in declarations
        for elements = (sal-xml-elements node)
        do (unless (second elements)
             (sal-xml-fail node "A variable declaration needs a type"))
           (setf (type declaration)
                 (sal-convert-type state (second elements))))
  declarations)

(defun sal-convert-binder (state node class declaration-class body-index)
  (let* ((elements (sal-xml-elements node))
         (decl-container (first elements))
         (decl-nodes (sal-xml-elements decl-container)))
    (multiple-value-bind (declarations scope)
        (sal-predeclare-locals state decl-nodes declaration-class)
      (sal-populate-local-types state decl-nodes declarations)
      (sal-call-with-scope
       state scope
       (lambda ()
         (sal-node class state node
                   :local-decls declarations
                   :expr (sal-convert-expression state
                                                 (nth body-index elements))))))))

(defun sal-convert-application-argument (state node)
  (if (string-equal (xmls:node-name node) "TUPLELITERAL")
      (sal-node 'sal-arg-tuple-literal state node
                :exprs (mapcar (lambda (child)
                                 (sal-convert-expression state child))
                               (sal-xml-elements node)))
      (sal-convert-expression state node)))

(defun sal-convert-application (state node)
  (let* ((elements (sal-xml-elements node))
         (fun (sal-convert-expression state (first elements)))
         (arg (sal-convert-application-argument state (second elements)))
         (name (when (typep fun 'sal-name-expr)
                 (sal-declaration-name (decl fun))))
         (class (or (and name (sal-builtin-application-class name))
                    'sal-application)))
    (sal-node class state node :fun fun :arg arg)))

(defun sal-make-builtin-application (state node name arguments)
  (let* ((declaration (sal-external-declaration state :value name node))
         (fun (sal-node 'sal-name-expr state node :decl declaration))
         (arg (sal-node 'sal-arg-tuple-literal state node :exprs arguments)))
    (sal-node (or (sal-builtin-application-class name) 'sal-application)
              state node :fun fun :arg arg)))

(defun sal-convert-set-list (state node)
  ;; The XML syntax contains the elements, whereas the semantic SAL class is
  ;; represented as a predicate. Rebuild that predicate without requiring the
  ;; Bigloo type checker; the generated variable's type is deliberately NIL.
  (let ((elements (mapcar (lambda (child)
                            (sal-convert-expression state child))
                          (sal-xml-elements node))))
    (unless elements
      (sal-xml-fail node "A set-list expression cannot be empty"))
    (let* ((declaration
             (sal-node 'sal-var-decl state node
                       :id (sal-node 'sal-identifier state node
                                     :name (gensym "SET-ELEMENT-"))))
           (variable (sal-node 'sal-name-expr state node :decl declaration))
           (equalities
             (mapcar (lambda (element)
                       (sal-make-builtin-application state node "="
                                                     (list variable element)))
                     elements))
           (predicate (if (rest equalities)
                          (sal-make-builtin-application state node "OR" equalities)
                          (first equalities))))
      (sal-node 'sal-set-list-expr state node
                :local-decls (list declaration) :expr predicate))))

(defun sal-convert-update (state node)
  (let* ((elements (sal-xml-elements node))
         (target (sal-convert-expression state (first elements)))
         (selection-node (second elements))
         (selection-elements (sal-xml-elements selection-node))
         (index-node (second selection-elements))
         (new-value (sal-convert-expression state (third elements)))
         (tag (xmls:node-name selection-node)))
    (cond ((string-equal tag "ARRAYSELECTION")
           (sal-node 'sal-array-update state node :target target
                     :idx (sal-convert-expression state index-node)
                     :new-value new-value))
          ((string-equal tag "RECORDSELECTION")
           (sal-node 'sal-record-update state node :target target
                     :idx (sal-identifier-from-xml state index-node)
                     :new-value new-value))
          ((string-equal tag "TUPLESELECTION")
           (sal-node 'sal-tuple-update state node :target target
                     :idx (sal-read-number index-node)
                     :new-value new-value))
          (t (sal-xml-fail selection-node "Invalid update selection")))))

(defun sal-convert-expression (state node)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "NUMERAL")
       (sal-node 'sal-numeral state node :num (sal-read-number node)))
      ((string-equal tag "STRINGEXPR")
       (sal-node 'sal-string-expr state node :string (sal-xml-text node)))
      ((string-equal tag "NAMEEXPR")
       (sal-convert-name-expression state node))
      ((string-equal tag "QUALIFIEDNAMEEXPR")
       (sal-convert-qualified-name-expression state node))
      ((string-equal tag "APPLICATION")
       (sal-convert-application state node))
      ((string-equal tag "ARRAYSELECTION")
       (sal-node 'sal-array-selection state node
                 :fun (sal-convert-expression state (first elements))
                 :arg (sal-convert-expression state (second elements))))
      ((string-equal tag "RECORDSELECTION")
       (sal-node 'sal-record-selection state node
                 :target (sal-convert-expression state (first elements))
                 :idx (sal-identifier-from-xml state (second elements))))
      ((string-equal tag "TUPLESELECTION")
       (sal-node 'sal-tuple-selection state node
                 :target (sal-convert-expression state (first elements))
                 :idx (sal-read-number (second elements))))
      ((string-equal tag "NEXTOPERATOR")
       (sal-node 'sal-next-operator state node
                 :name-expr (sal-convert-expression state (first elements))))
      ((string-equal tag "TUPLELITERAL")
       (sal-node 'sal-tuple-literal state node
                 :exprs (mapcar (lambda (child)
                                  (sal-convert-expression state child))
                                elements)))
      ((string-equal tag "RECORDLITERAL")
       (sal-node 'sal-record-literal state node
                 :entries (mapcar (lambda (child)
                                    (sal-convert-expression state child))
                                  elements)))
      ((string-equal tag "RECORDENTRY")
       (sal-node 'sal-record-entry state node
                 :id (sal-identifier-from-xml state (first elements))
                 :expr (sal-convert-expression state (second elements))))
      ((string-equal tag "ARRAYLITERAL")
       (let* ((decl-node (first elements))
              (declaration
                (sal-make-local-declaration state decl-node 'sal-idx-var-decl))
              (scope (make-hash-table :test #'equal)))
         (sal-scope-bind scope :value declaration)
         (sal-call-with-scope
          state scope
          (lambda ()
            (sal-node 'sal-array-literal state node
                      :local-decls (list declaration)
                      :expr (sal-convert-expression state (second elements)))))))
      ((string-equal tag "LAMBDAABSTRACTION")
       (sal-convert-binder state node 'sal-lambda 'sal-var-decl 1))
      ((or (string-equal tag "QUANTIFIEDEXPRESSION")
           (string-equal tag "FORALLEXPRESSION")
           (string-equal tag "EXISTSEXPRESSION"))
       (let* ((quantifier-node
                (and (string-equal tag "QUANTIFIEDEXPRESSION")
                     (first elements)))
              (quantifier (if quantifier-node
                              (sal-xml-text quantifier-node)
                              tag))
              (class (if (or (string-equal quantifier "FORALL")
                             (string-equal quantifier "FORALLEXPRESSION"))
                         'sal-for-all-expr
                         'sal-exists-expr))
              (offset (if quantifier-node 1 0))
              (synthetic
                (xmls:make-node :name tag :attrs (xmls:node-attrs node)
                                :children (subseq elements offset))))
         (sal-convert-binder state synthetic class 'sal-var-decl 1)))
      ((string-equal tag "SETPREDEXPRESSION")
       (let* ((id-node (first elements))
              (type-node (second elements))
              (declaration
                (sal-node 'sal-var-decl state id-node
                          :id (if (string-equal (xmls:node-name id-node)
                                               "IDENTIFIER")
                                  (sal-identifier-from-xml state id-node)
                                  (sal-identifier-from-xml
                                   state (first (sal-xml-elements id-node))))
                          :type (sal-convert-type state type-node)))
              (scope (make-hash-table :test #'equal)))
         (sal-scope-bind scope :value declaration)
         (sal-call-with-scope
          state scope
          (lambda ()
            (sal-node 'sal-set-pred-expr state node
                      :local-decls (list declaration)
                      :expr (sal-convert-expression state (third elements)))))))
      ((string-equal tag "SETLISTEXPRESSION")
       (sal-convert-set-list state node))
      ((string-equal tag "LETEXPRESSION")
       (let* ((decl-nodes (sal-xml-elements (first elements))))
         (multiple-value-bind (declarations scope)
             (sal-predeclare-locals state decl-nodes 'sal-let-decl)
           (sal-populate-local-types state decl-nodes declarations)
           ;; SAL LET declarations are simultaneous: initializers see the
           ;; surrounding scope, and only the body sees the new declarations.
           (loop for declaration in declarations
                 for decl-node in decl-nodes
                 do (setf (value declaration)
                          (sal-convert-expression
                           state (third (sal-xml-elements decl-node)))))
           (sal-call-with-scope
            state scope
            (lambda ()
              (sal-node 'sal-let-expr state node
                        :local-decls declarations
                        :expr (sal-convert-expression state
                                                      (second elements))))))))
      ((string-equal tag "CONDITIONAL")
       (sal-node 'sal-conditional state node
                 :cond-expr (sal-convert-expression state (first elements))
                 :then-expr (sal-convert-expression state (second elements))
                 :else-expr (sal-convert-expression state (third elements))))
      ((string-equal tag "UPDATEEXPRESSION")
       (sal-convert-update state node))
      ((string-equal tag "MODINIT")
       (sal-node 'sal-mod-init state node
                 :module (sal-convert-module state (first elements))))
      ((string-equal tag "MODTRANS")
       (sal-node 'sal-mod-trans state node
                 :module (sal-convert-module state (first elements))))
      ((member tag '("MODULEMODELS" "MODULEIMPLEMENTS"
                     "ASSERTIONPROPOSITION" "QUALIFIEDASSERTIONNAME")
               :test #'string-equal)
       (sal-convert-assertion-expression state node))
      (t (sal-xml-fail node "Unsupported SAL expression")))))

(defun sal-convert-field (state node)
  (let ((elements (sal-xml-elements node)))
    (sal-node 'sal-field state node
              :id (sal-identifier-from-xml state (first elements))
              :type (sal-convert-type state (second elements)))))

(defun sal-register-implicit-value (state declaration)
  (sal-state-bind-top state :value declaration)
  (setf (gethash (sal-declaration-name declaration)
                 (constant-declarations (sal-xml-state-context state)))
        declaration)
  declaration)

(defun sal-convert-scalar-type (state node owner)
  (let ((scalar-names nil)
        (scalar-type-name
          (and owner (sal-node 'sal-type-name state node :decl owner))))
    (dolist (element-node (sal-xml-elements node))
      (let* ((name (sal-xml-text element-node))
             (declaration
               (sal-node 'sal-scalar-element-decl state element-node
                         :id (sal-node 'sal-identifier state element-node
                                       :name (make-symbol name))
                         :type scalar-type-name
                         :scalar-type-decl owner)))
        (sal-register-implicit-value state declaration)
        (push (sal-node (cond ((string-equal name "TRUE") 'sal-true)
                              ((string-equal name "FALSE") 'sal-false)
                              (t 'sal-scalar))
                        state element-node :decl declaration)
              scalar-names)))
    (sal-node 'sal-scalar-type state node
              :scalar-elements (nreverse scalar-names))))

(defun sal-convert-data-type (state node owner)
  (let ((constructors nil)
        (data-type-name
          (and owner (sal-node 'sal-type-name state node :decl owner))))
    (dolist (constructor-node (sal-xml-elements node))
      (let* ((children (sal-xml-elements constructor-node))
             (identifier (sal-identifier-from-xml state (first children)))
             (constructor-name (sal-identifier-string identifier))
             (constructor
               (sal-node 'sal-constructor-decl state constructor-node
                         :id identifier :data-type-decl owner))
             (accessor-names nil)
             (accessor-ranges nil))
        (dolist (accessor-node (rest children))
          (let* ((parts (sal-xml-elements accessor-node))
                 (range (sal-convert-type state (second parts)))
                 (accessor
                   (sal-node 'sal-accessor-decl state accessor-node
                             :id (sal-identifier-from-xml state (first parts))
                             :type (sal-node 'sal-function-type state accessor-node
                                             :domain data-type-name :range range)
                             :constructor-decl constructor)))
            (sal-register-implicit-value state accessor)
            (push (sal-node 'sal-accessor state accessor-node :decl accessor)
                  accessor-names)
            (push range accessor-ranges)))
        (setf accessor-names (nreverse accessor-names)
              accessor-ranges (nreverse accessor-ranges)
              (accessors constructor) accessor-names
              (type constructor)
              (if accessor-ranges
                  (sal-node 'sal-function-type state constructor-node
                            :domain
                            (if (rest accessor-ranges)
                                (sal-node 'sal-domain-tuple-type
                                          state constructor-node
                                          :types accessor-ranges)
                                (first accessor-ranges))
                            :range data-type-name)
                  data-type-name))
        (let* ((recognizer-name (concatenate 'string constructor-name "?"))
               (recognizer
                 (sal-node 'sal-recognizer-decl state constructor-node
                           :id (sal-node 'sal-identifier state constructor-node
                                         :name (make-symbol recognizer-name))
                           :type
                           (sal-node 'sal-function-type state constructor-node
                                     :domain data-type-name
                                     :range
                                     (sal-node 'sal-bool-type state
                                               constructor-node
                                               :decl
                                               (sal-external-declaration
                                                state :type "boolean"
                                                constructor-node)))
                           :constructor-decl constructor)))
          (setf (recognizer-decl constructor) recognizer)
          (sal-register-implicit-value state recognizer))
        (sal-register-implicit-value state constructor)
        (push (sal-node 'sal-constructor state constructor-node
                        :decl constructor)
              constructors)))
    (sal-node 'sal-data-type state node :constructors (nreverse constructors))))

(defun sal-make-subrange-type (state node lower upper
                               &optional (class 'sal-subrange))
  (let* ((integer-declaration
           (sal-external-declaration state :type "integer" node))
         (integer-type
           (sal-node 'sal-int-type state node :decl integer-declaration))
         (variable-declaration
           (sal-node 'sal-var-decl state node
                     :id (sal-node 'sal-identifier state node
                                   :name (gensym "SUBRANGE-ELEMENT-"))
                     :type integer-type))
         (variable
           (sal-node 'sal-name-expr state node :decl variable-declaration))
         (lower-bound
           (sal-make-builtin-application state node ">="
                                         (list variable lower)))
         (upper-bound
           (sal-make-builtin-application state node "<="
                                         (list variable upper)))
         (predicate
           (sal-node 'sal-lambda state node
                     :local-decls (list variable-declaration)
                     :expr (sal-make-builtin-application
                            state node "AND" (list lower-bound upper-bound)))))
    (sal-node class state node :expr predicate :lower lower :upper upper)))

(defun sal-convert-symmetric-type (state node class)
  (let* ((size (sal-convert-expression state
                                       (first (sal-xml-elements node))))
         (zero (sal-node 'sal-numeral state node :num 0))
         (one (sal-node 'sal-numeral state node :num 1))
         (upper (sal-make-builtin-application state node "-"
                                              (list size one))))
    (sal-make-subrange-type state node zero upper class)))

(defun sal-convert-type (state node &optional owner)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "TYPENAME")
       (sal-convert-type-name state node))
      ((string-equal tag "QUALIFIEDTYPENAME")
       (sal-convert-type-name state node t))
      ((string-equal tag "FUNCTIONTYPE")
       (let ((domain-node (first elements)))
         (sal-node 'sal-function-type state node
                   :domain
                   (if (string-equal (xmls:node-name domain-node) "TUPLETYPE")
                       (sal-node 'sal-domain-tuple-type state domain-node
                                 :types
                                 (mapcar
                                  (lambda (child)
                                    (sal-convert-type state child))
                                  (sal-xml-elements domain-node)))
                       (sal-convert-type state domain-node))
                   :range (sal-convert-type state (second elements)))))
      ((string-equal tag "ARRAYTYPE")
       (sal-node 'sal-array-type state node
                 :domain (sal-convert-type state (first elements))
                 :range (sal-convert-type state (second elements))))
      ((string-equal tag "TUPLETYPE")
       (sal-node 'sal-tuple-type state node
                 :types (mapcar (lambda (child) (sal-convert-type state child))
                                elements)))
      ((string-equal tag "RECORDTYPE")
       (sal-node 'sal-record-type state node
                 :fields (mapcar (lambda (child) (sal-convert-field state child))
                                 elements)))
      ((string-equal tag "STATETYPE")
       (sal-node 'sal-state-type state node
                 :module (sal-convert-module state (first elements))))
      ((string-equal tag "SUBTYPE")
       (sal-node 'sal-subtype state node
                 :expr (sal-convert-expression state (first elements))))
      ((string-equal tag "SUBRANGE")
       (sal-make-subrange-type
        state node
        (sal-convert-expression state (first elements))
        (sal-convert-expression state (second elements))))
      ((string-equal tag "SCALARTYPE")
       (sal-convert-scalar-type state node owner))
      ((string-equal tag "SCALARSET")
       (sal-convert-symmetric-type state node 'sal-scalar-set-type))
      ((string-equal tag "RINGSET")
       (sal-convert-symmetric-type state node 'sal-ring-set-type))
      ((string-equal tag "DATATYPE")
       (sal-convert-data-type state node owner))
      (t (sal-xml-fail node "Unsupported SAL type")))))

(defun sal-make-state-var (state wrapper-node)
  (let* ((tag (xmls:node-name wrapper-node))
         (node (first (sal-xml-elements wrapper-node)))
         (class (cond ((string-equal tag "INPUTDECL")
                       'sal-input-state-var-decl)
                      ((string-equal tag "OUTPUTDECL")
                       'sal-output-state-var-decl)
                      ((string-equal tag "LOCALDECL")
                       'sal-local-state-var-decl)
                      ((string-equal tag "GLOBALDECL")
                       'sal-global-state-var-decl)
                      (t (sal-xml-fail wrapper-node
                                       "Invalid state-variable declaration")))))
    (sal-node class state wrapper-node
              :id (sal-identifier-from-xml state
                                           (first (sal-xml-elements node))))))

(defun sal-populate-state-var (state wrapper-node declaration)
  (let* ((node (first (sal-xml-elements wrapper-node)))
         (elements (sal-xml-elements node)))
    (setf (type declaration) (sal-convert-type state (second elements)))
    declaration))

(defun sal-state-vars-table (declarations)
  (let ((table (make-hash-table :test #'equal)))
    (dolist (declaration declarations table)
      (setf (gethash (sal-declaration-name declaration) table) declaration))))

(defun sal-set-module-interface (module state-vars)
  (setf (state-vars module) state-vars
        (state-vars-table module) (sal-state-vars-table state-vars))
  module)

(defun sal-convert-definition (state node)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "SIMPLEDEFINITION")
       (let* ((lhs (sal-convert-expression state (first elements)))
              (rhs-wrapper (second elements))
              (selectionp (string-equal (xmls:node-name rhs-wrapper)
                                        "RHSSELECTION"))
              (rhs-node (if (sal-xml-elements rhs-wrapper)
                            (first (sal-xml-elements rhs-wrapper))
                            (third elements))))
         (sal-node (if selectionp
                       'sal-simple-selection-definition
                       'sal-simple-definition)
                   state node :lhs lhs
                   :rhs (sal-convert-expression state rhs-node))))
      ((string-equal tag "FORALLDEFINITION")
       (let* ((decl-container (first elements))
              (decl-nodes (sal-xml-elements decl-container)))
         (multiple-value-bind (declarations scope)
             (sal-predeclare-locals state decl-nodes 'sal-var-decl)
           (sal-populate-local-types state decl-nodes declarations)
           (sal-call-with-scope
            state scope
            (lambda ()
              (sal-node 'sal-for-all-definition state node
                        :local-decls declarations
                        :definitions
                        (mapcar (lambda (child)
                                  (sal-convert-definition state child))
                                (rest elements))))))))
      (t (sal-xml-fail node "Unsupported SAL definition")))))

(defun sal-convert-command (state node)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "GUARDEDCOMMAND")
       (sal-node 'sal-guarded-command state node
                 :guard (sal-convert-expression
                         state (first (sal-xml-elements (first elements))))
                 :assignments
                 (mapcar (lambda (child)
                           (sal-convert-definition state child))
                         (sal-xml-elements (second elements)))))
      ((string-equal tag "LABELEDCOMMAND")
       (sal-node 'sal-labeled-command state node
                 :label (sal-node 'sal-identifier state (first elements)
                                  :name (make-symbol
                                         (sal-xml-text (first elements))))
                 :command (sal-convert-command state (second elements))))
      ((string-equal tag "MULTICOMMAND")
       (let ((decl-nodes (sal-xml-elements (first elements))))
         (multiple-value-bind (declarations scope)
             (sal-predeclare-locals state decl-nodes 'sal-var-decl)
           (sal-populate-local-types state decl-nodes declarations)
           (sal-call-with-scope
            state scope
            (lambda ()
              (sal-node 'sal-multi-command state node
                        :local-decls declarations
                        :command (sal-convert-command state (second elements))))))))
      ((or (string-equal tag "ELSECOMMAND")
           (string-equal tag "LABELEDELSECOMMAND"))
       (sal-node 'sal-else-command state node
                 :assignments
                 (if elements
                     (mapcar (lambda (child)
                               (sal-convert-definition state child))
                             (sal-xml-elements (first elements)))
                     nil)))
      (t (sal-xml-fail node "Unsupported SAL command")))))

(defun sal-convert-command-section (state node)
  (let ((commands nil)
        (else-command nil))
    (dolist (child (sal-xml-elements node))
      (let ((command (sal-convert-command state child)))
        (if (typep command 'sal-else-command)
            (setf else-command command)
            (push command commands))))
    (sal-node 'sal-command-section state node
              :commands (nreverse commands) :else-command else-command)))

(defun sal-convert-base-module (state node)
  (let* ((children (sal-xml-elements node))
         (state-nodes
           (remove-if-not
            (lambda (child)
              (member (xmls:node-name child)
                      '("INPUTDECL" "OUTPUTDECL" "LOCALDECL" "GLOBALDECL")
                      :test #'string-equal))
            children))
         (state-vars (mapcar (lambda (child) (sal-make-state-var state child))
                             state-nodes))
         (scope (make-hash-table :test #'equal)))
    (dolist (declaration state-vars)
      (sal-scope-bind scope :value declaration))
    (sal-call-with-scope
     state scope
     (lambda ()
       (loop for child in state-nodes
             for declaration in state-vars
             do (sal-populate-state-var state child declaration))
       (let ((definitions nil)
             (initialization-definitions nil)
             (initialization-command-section nil)
             (transition-definitions nil)
             (transition-command-section nil))
         (dolist (child children)
           (let ((tag (xmls:node-name child)))
             (cond
               ((string-equal tag "DEFDECL")
                (setf definitions
                      (mapcar (lambda (definition)
                                (sal-convert-definition state definition))
                              (sal-xml-elements child))))
               ((or (string-equal tag "INITDECL")
                    (string-equal tag "TRANSDECL"))
                (let ((section-definitions nil)
                      (command-section nil))
                  (dolist (item (sal-xml-elements child))
                    (if (string-equal (xmls:node-name item) "SOMECOMMANDS")
                        (setf command-section
                              (sal-convert-command-section state item))
                        (push (sal-convert-definition state item)
                              section-definitions)))
                  (if (string-equal tag "INITDECL")
                      (setf initialization-definitions
                            (nreverse section-definitions)
                            initialization-command-section command-section)
                      (setf transition-definitions
                            (nreverse section-definitions)
                            transition-command-section command-section)))))))
         (sal-set-module-interface
          (sal-node 'sal-base-module state node
                    :definitions definitions
                    :initialization-definitions initialization-definitions
                    :initialization-command-section
                    initialization-command-section
                    :transition-definitions transition-definitions
                    :transition-command-section transition-command-section)
          state-vars))))))

(defun sal-module-state-vars (module)
  (or (state-vars module) nil))

(defun sal-convert-module-instance (state node)
  (let* ((elements (sal-xml-elements node))
         (module-name-node (first elements))
         (module-name
           (cond ((string-equal (xmls:node-name module-name-node) "MODULENAME")
                  (sal-convert-module-name state module-name-node))
                 ((string-equal (xmls:node-name module-name-node)
                                "QUALIFIEDMODULENAME")
                  (sal-convert-module-name state module-name-node t))
                 (t (sal-xml-fail module-name-node "Expected a module name"))))
         (actual-container (second elements))
         (actuals (mapcar (lambda (child)
                            (sal-convert-actual state child))
                          (sal-xml-elements actual-container)))
         (declaration (decl module-name))
         (referenced
           (and (typep declaration 'sal-module-decl)
                (parametric-module declaration)
                (module (parametric-module declaration))))
         (instance (sal-node 'sal-module-instance state node
                             :module-name module-name :actuals actuals)))
    (sal-set-module-interface instance
                              (if referenced
                                  (sal-module-state-vars referenced)
                                  nil))))

(defun sal-convert-module (state node)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "BASEMODULE")
       (sal-convert-base-module state node))
      ((or (string-equal tag "SYNCHRONOUSCOMPOSITION")
           (string-equal tag "ASYNCHRONOUSCOMPOSITION"))
       (let* ((module1 (sal-convert-module state (first elements)))
              (module2 (sal-convert-module state (second elements)))
              (module
                (sal-node (if (string-equal tag "SYNCHRONOUSCOMPOSITION")
                              'sal-synch-composition
                              'sal-asynch-composition)
                          state node :module1 module1 :module2 module2)))
         (sal-set-module-interface
          module (append (sal-module-state-vars module1)
                         (sal-module-state-vars module2)))))
      ((string-equal tag "OBSERVEMODULE")
       (let* ((module1 (sal-convert-module state (first elements)))
              (module2 (sal-convert-module state (second elements)))
              (module (sal-node 'sal-observer state node
                                :module1 module1 :module2 module2)))
         (sal-set-module-interface
          module (append (sal-module-state-vars module1)
                         (sal-module-state-vars module2)))))
      ((or (string-equal tag "MULTISYNCHRONOUS")
           (string-equal tag "MULTIASYNCHRONOUS"))
       (let* ((declaration
                (sal-make-local-declaration state (first elements)
                                            'sal-idx-var-decl))
              (scope (make-hash-table :test #'equal)))
         (sal-scope-bind scope :value declaration)
         (sal-call-with-scope
          state scope
          (lambda ()
            (let* ((child (sal-convert-module state (second elements)))
                   (module
                     (sal-node
                      (if (string-equal tag "MULTISYNCHRONOUS")
                          'sal-multi-synch-composition
                          'sal-multi-asynch-composition)
                      state node :local-decls (list declaration) :module child)))
              (sal-set-module-interface module (sal-module-state-vars child)))))))
      ((or (string-equal tag "HIDING")
           (string-equal tag "NEWOUTPUT"))
       (let* ((identifiers
                (mapcar (lambda (child) (sal-identifier-from-xml state child))
                        (sal-xml-elements (first elements))))
              (child (sal-convert-module state (second elements)))
              (module (sal-node (if (string-equal tag "HIDING")
                                    'sal-hiding 'sal-new-output)
                                state node :identifiers identifiers :module child)))
         (sal-set-module-interface module (sal-module-state-vars child))))
      ((string-equal tag "RENAMING")
       (let* ((renames
                (mapcar
                 (lambda (rename-node)
                   (let* ((parts (sal-xml-elements rename-node))
                          (from-node (first parts)))
                     (sal-node 'sal-rename state rename-node
                               :from-name
                               (sal-node 'sal-identifier state from-node
                                         :name (make-symbol
                                                (sal-xml-text from-node)))
                               :to-expr
                               (sal-convert-expression state (second parts)))))
                 (sal-xml-elements (first elements))))
              (child (sal-convert-module state (second elements)))
              (module (sal-node 'sal-renaming state node
                                :renames renames :module child)))
         (sal-set-module-interface module (sal-module-state-vars child))))
      ((string-equal tag "WITHMODULE")
       (let* ((state-nodes (sal-xml-elements (first elements)))
              (state-vars (mapcar (lambda (child)
                                    (sal-make-state-var state child))
                                  state-nodes))
              (scope (make-hash-table :test #'equal)))
         (dolist (declaration state-vars)
           (sal-scope-bind scope :value declaration))
         (sal-call-with-scope
          state scope
          (lambda ()
            (loop for child in state-nodes
                  for declaration in state-vars
                  do (sal-populate-state-var state child declaration))
            (let* ((child (sal-convert-module state (second elements)))
                   (module (sal-node 'sal-with-module state node
                                     :new-state-vars state-vars :module child)))
              (sal-set-module-interface
               module (append state-vars (sal-module-state-vars child))))))))
      ((string-equal tag "MODULEINSTANCE")
       (sal-convert-module-instance state node))
      (t (sal-xml-fail node "Unsupported SAL module")))))

(defun sal-convert-assertion-expression (state node)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "MODULEMODELS")
       (let* ((module (sal-convert-module state (first elements)))
              (scope (sal-state-vars-table (sal-module-state-vars module))))
         (sal-call-with-scope
          state scope
          (lambda ()
            (sal-node 'sal-module-models state node :module module
                      :expr (sal-convert-expression state (second elements)))))))
      ((string-equal tag "MODULEIMPLEMENTS")
       (sal-node 'sal-module-implements state node
                 :module1 (sal-convert-module state (first elements))
                 :module2 (sal-convert-module state (second elements))))
      ((string-equal tag "ASSERTIONPROPOSITION")
       (sal-node 'sal-assertion-proposition state node
                 :op (make-symbol (sal-xml-text (first elements)))
                 :assertion-exprs
                 (mapcar (lambda (child)
                           (sal-convert-assertion-expression state child))
                         (rest elements))))
      ((string-equal tag "QUALIFIEDASSERTIONNAME")
       (multiple-value-bind (name context-ref actuals)
           (sal-qualified-parts state node)
         (sal-node 'sal-qualified-assertion-name state node
                   :decl (sal-qualified-declaration state context-ref
                                                    :assertion name node)
                   :context-ref context-ref :actuals actuals)))
      (t (sal-convert-expression state node)))))

(defun sal-top-declaration-class-and-namespace (tag)
  (cond ((string-equal tag "TYPEDECLARATION")
         (values 'sal-type-decl :type))
        ((string-equal tag "CONSTANTDECLARATION")
         (values 'sal-constant-decl :value))
        ((string-equal tag "MODULEDECLARATION")
         (values 'sal-module-decl :module))
        ((string-equal tag "ASSERTIONDECLARATION")
         (values 'sal-assertion-decl :assertion))
        ((string-equal tag "CONTEXTDECLARATION")
         (values 'sal-context-name-decl :context))
        (t (values nil nil))))

(defun sal-context-table-for-namespace (context namespace)
  (ecase namespace
    (:value (constant-declarations context))
    (:type (type-declarations context))
    (:module (module-declarations context))
    (:assertion (assertion-declarations context))
    (:context (context-name-declarations context))))

(defun sal-predeclare-top-declaration (state node)
  (multiple-value-bind (class namespace)
      (sal-top-declaration-class-and-namespace (xmls:node-name node))
    (unless class
      (sal-xml-fail node "Unsupported SAL top-level declaration"))
    (let* ((identifier-node (first (sal-xml-elements node)))
           (declaration (sal-node class state node
                                  :id (sal-identifier-from-xml state
                                                               identifier-node))))
      (sal-state-bind-top state namespace declaration)
      (setf (gethash (sal-declaration-name declaration)
                     (sal-context-table-for-namespace
                      (sal-xml-state-context state) namespace))
            declaration)
      declaration)))

(defun sal-populate-top-declaration (state node declaration)
  (let ((tag (xmls:node-name node))
        (elements (sal-xml-elements node)))
    (cond
      ((string-equal tag "TYPEDECLARATION")
       (setf (type declaration)
             (when (second elements)
               (sal-convert-type state (second elements) declaration))))
      ((string-equal tag "CONSTANTDECLARATION")
       (setf (type declaration) (sal-convert-type state (second elements))
             (value declaration)
             (when (third elements)
               (sal-convert-expression state (third elements)))))
      ((string-equal tag "MODULEDECLARATION")
       (let* ((decl-nodes (sal-xml-elements (second elements))))
         (multiple-value-bind (parameters scope)
             (sal-predeclare-locals state decl-nodes 'sal-var-decl)
           (sal-populate-local-types state decl-nodes parameters)
           (setf (parametric-module declaration)
                 (sal-call-with-scope
                  state scope
                  (lambda ()
                    (sal-node 'sal-parametric-module state node
                              :local-decls parameters
                              :module (sal-convert-module state
                                                          (third elements)))))))))
      ((string-equal tag "ASSERTIONDECLARATION")
       (let ((form (second elements)))
         (setf (kind declaration)
               (make-symbol (string-upcase (sal-xml-text form)))
               (assertion-expr declaration)
               (sal-convert-assertion-expression state (third elements)))))
      ((string-equal tag "CONTEXTDECLARATION")
       (multiple-value-bind (context-ref actuals)
           (sal-convert-context-name-node state (second elements))
         (setf (context-ref declaration) context-ref
               (actuals declaration) actuals)))
      (t (sal-xml-fail node "Unsupported SAL top-level declaration")))
    declaration))

(defun sal-predeclare-context-parameters (state nodes)
  (let ((scope (make-hash-table :test #'equal))
        (declarations nil))
    (dolist (node nodes)
      (let* ((tag (xmls:node-name node))
             (elements (sal-xml-elements node))
             (type-parameter-p (string-equal tag "TYPEDECL"))
             (declaration
               (sal-node (if type-parameter-p
                             'sal-type-param-decl
                             'sal-var-param-decl)
                         state node
                         :id (sal-identifier-from-xml state (first elements)))))
        (sal-scope-bind scope (if type-parameter-p :type :value) declaration)
        (push declaration declarations)))
    (values (nreverse declarations) scope)))

(defun sal-populate-context-parameters (state nodes declarations)
  (loop for node in nodes
        for declaration in declarations
        unless (typep declaration 'sal-type-param-decl)
          do (setf (type declaration)
                   (sal-convert-type state
                                     (second (sal-xml-elements node)))))
  declarations)

(defun sal-convert-context (root file-name)
  (unless (string-equal (xmls:node-name root) "CONTEXT")
    (sal-xml-fail root "The XML document root must be CONTEXT"))
  (let* ((elements (sal-xml-elements root))
         (identifier-node (first elements))
         (parameters-node (second elements))
         (body-node (third elements))
         (temporary-state (%make-sal-xml-state))
         (context
           (sal-node 'sal-context temporary-state root
                     :id (sal-identifier-from-xml temporary-state
                                                  identifier-node)
                     :params nil :declarations nil
                     :constant-declarations (make-hash-table :test #'equal)
                     :type-declarations (make-hash-table :test #'equal)
                     :module-declarations (make-hash-table :test #'equal)
                     :assertion-declarations (make-hash-table :test #'equal)
                     :context-name-declarations (make-hash-table :test #'equal)
                     :importers nil :internal-actuals nil
                     :file-name file-name))
         (state (%make-sal-xml-state :context context))
         (parameter-nodes (sal-xml-elements parameters-node))
         (declaration-nodes (sal-xml-elements body-node)))
    (setf (context context) context
          (context (id context)) context)
    (multiple-value-bind (parameters parameter-scope)
        (sal-predeclare-context-parameters state parameter-nodes)
      (setf (sal-xml-state-scopes state) (list parameter-scope))
      (sal-populate-context-parameters state parameter-nodes parameters)
      (setf (params context) parameters)
      (let ((declarations
              (mapcar (lambda (node)
                        (sal-predeclare-top-declaration state node))
                      declaration-nodes)))
        (loop for node in declaration-nodes
              for declaration in declarations
              do (sal-populate-top-declaration state node declaration))
        (setf (declarations context) declarations)))
    context))

(defun sal-xml-to-ast (xml &key file-name)
  "Decode a SAL-to-XML document into the CLOS SAL AST.

XML may be an XML string or an open character input stream. FILE-NAME is
recorded in the returned SAL-CONTEXT."
  (let ((root
          (etypecase xml
            (string
             (with-input-from-string (stream xml)
               (xmls:parse stream :quash-errors nil)))
            (stream
             (xmls:parse xml :quash-errors nil)))))
    (sal-convert-context root file-name)))

(defun sal-find-to-xml-program ()
  (labels ((existing (path)
             (and path
                  (let ((pathname (pathname path)))
                    (and (probe-file pathname) pathname))))
           (on-path (name)
             (loop for directory
                     in (uiop:split-string (or (uiop:getenv "PATH") "")
                                           :separator '(#\:))
                   for pathname = (merge-pathnames
                                   name
                                   (uiop:ensure-directory-pathname
                                    (if (string= directory "")
                                        (uiop:getcwd)
                                        directory)))
                   when (probe-file pathname) return pathname)))
    (or (existing *sal-to-xml-program*)
        (existing (uiop:getenv "SAL_TO_XML"))
        (let ((home (uiop:getenv "SAL_HOME")))
          (and home
               (existing (merge-pathnames "tools/sal-to-xml.sh"
                                          (uiop:ensure-directory-pathname
                                           home)))))
        (on-path "sal-to-xml.sh")
        (existing (merge-pathnames
                   "projects/misc/sal/sal-3.3/tools/sal-to-xml.sh"
                   (user-homedir-pathname)))
        (error "Cannot find sal-to-xml.sh. Set PVS:*SAL-TO-XML-PROGRAM*, ~
SAL_TO_XML, or SAL_HOME."))))

(defun read-sal-file (path)
  "Read the SAL source file at PATH and return its SAL-CONTEXT CLOS AST.

The function invokes SAL 3.3's sal-to-xml.sh and decodes its standard output
with XMLS. A nonzero exporter status is reported with the exporter's diagnostic
text. Set *SAL-TO-XML-PROGRAM* to select a nonstandard SAL installation."
  (let* ((source (or (probe-file path)
                     (error "SAL source file does not exist: ~a" path)))
         (program (sal-find-to-xml-program)))
    (multiple-value-bind (xml diagnostics status)
        (uiop:run-program (list (namestring program) (namestring source))
                          :output :string
                          :error-output :string
                          :ignore-error-status t)
      (unless (zerop status)
        (error "SAL XML export failed for ~a (status ~d):~%~a"
               source status diagnostics))
      (sal-xml-to-ast xml :file-name (namestring source)))))
