;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; classes.lisp -- CLOS representation of the SAL abstract syntax tree
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

;;; This is the CLOS counterpart of the class hierarchy in SAL 3.3's
;;; sal-ast.scm.  As with the PVS AST, DEFCL supplies an accessor and initarg
;;; for every slot, initializes unspecified slots to NIL, and defines a
;;; SAL-FOO? class predicate.

(in-package :pvs)

;;; PVS and SAL share a package, and a few SAL slot names are already used by
;;; (or are defined later as) ordinary PVS functions.  Those names cannot be
;;; CLOS generic accessors.  This is DEFCL's small exceptional-case companion:
;;; it retains the original slot names and initargs while allowing explicitly
;;; prefixed accessors, and records the same metadata used by PVS persistence.
(defmacro defcl-with-accessors (name superclasses &rest slot-specs)
  (let ((predicate (intern (format nil "~a?" name) :pvs))
        (slot-info (mapcar (lambda (spec) (list (first spec))) slot-specs)))
    `(progn
       (defclass ,name ,superclasses
         ,(mapcar
           (lambda (spec)
             (destructuring-bind (slot accessor) spec
               `(,slot :accessor ,accessor
                       :initarg ,(intern (string slot) :keyword)
                       :initarg ,slot
                       :initform nil)))
           slot-specs))
       (when (fboundp 'declare-make-instance)
         (declare-make-instance ,name))
       (declaim (inline ,predicate))
       (defun ,predicate (object)
         (typep object ',name))
       (eval-when (:execute :compile-toplevel :load-toplevel)
         (setq *slot-info*
               (cons (cons ',name (list ',superclasses ',slot-info))
                     (delete (assoc ',name *slot-info*) *slot-info*))))
       ',name)))

;;; Basic AST nodes

(defcl sal-ast ()
  place
  context
  hash
  internal-idx)

(defcl sal-ast-leaf (sal-ast))

(defcl sal-identifier (sal-ast-leaf)
  name)

(defcl sal-new-binds-ast (sal-ast))

(defcl sal-local-binds-ast (sal-new-binds-ast))

;;; Declarations

(defcl sal-decl (sal-ast)
  id)

(defcl sal-typed-decl (sal-decl)
  type)

(defcl sal-const-decl (sal-typed-decl)
  value)

(defcl sal-auxiliary-decl (sal-const-decl))

(defcl sal-context (sal-decl)
  params
  declarations
  constant-declarations
  type-declarations
  module-declarations
  assertion-declarations
  context-name-declarations
  sal-env
  importers
  internal-actuals
  file-name)

(defcl sal-type-param-decl (sal-decl))

(defcl sal-var-decl (sal-typed-decl))

(defcl sal-var-param-decl (sal-var-decl))

(defcl sal-idx-var-decl (sal-var-decl))

;;; CURR-NODE and NEXT-NODE support construction of the dependency graph.
(defcl sal-state-var-decl (sal-var-decl)
  curr-node
  next-node)

(defcl sal-input-state-var-decl (sal-state-var-decl))

(defcl sal-choice-input-state-var-decl (sal-input-state-var-decl))

(defcl sal-output-state-var-decl (sal-state-var-decl))

(defcl sal-global-state-var-decl (sal-state-var-decl))

(defcl sal-local-state-var-decl (sal-state-var-decl))

(defcl sal-let-decl (sal-const-decl))

(defcl sal-top-decl (sal-decl))

(defcl sal-recursive-decl (sal-top-decl))

(defcl sal-type-decl (sal-recursive-decl)
  type)

(defcl sal-module-decl (sal-top-decl)
  parametric-module)

(defcl sal-parametric-module (sal-local-binds-ast)
  local-decls
  module)

(defcl sal-constant-decl (sal-const-decl sal-recursive-decl)
  memoize?)

(defcl sal-implicit-decl (sal-constant-decl))

(defcl sal-constructor-decl (sal-implicit-decl)
  accessors
  recognizer-decl
  data-type-decl)

(defcl sal-recognizer-decl (sal-implicit-decl)
  constructor-decl)

(defcl sal-accessor-decl (sal-implicit-decl)
  constructor-decl)

(defcl sal-scalar-element-decl (sal-implicit-decl)
  scalar-type-decl)

(defcl sal-context-name-decl (sal-top-decl)
  context-ref
  actuals)

(defcl sal-assertion-decl (sal-top-decl)
  kind
  assertion-expr)

;;; Names

(defcl sal-name-ref (sal-ast-leaf))

(defcl sal-qualified-name-ref (sal-name-ref))

;;; Expressions

(defcl sal-expr (sal-ast)
  type)

(defcl sal-simple-expr (sal-expr))

(defcl sal-application (sal-expr)
  fun
  arg)

(defcl sal-infix-application (sal-application))

(defcl sal-in (sal-application))

(defcl sal-binary-application (sal-application))

(defcl sal-binary-infix-application
    (sal-binary-application sal-infix-application))

(defcl sal-unary-application (sal-application))

(defcl sal-builtin-application (sal-application))

;;; SAL-BUILTIN-APPLICATION already implies SAL-APPLICATION; the
;;; redundant direct edge in the Bigloo hierarchy is omitted for a valid and
;;; unambiguous CLOS class precedence list.
(defcl sal-constructor-application (sal-builtin-application))

(defcl sal-recognizer-application
    (sal-unary-application sal-builtin-application))

(defcl sal-accessor-application
    (sal-unary-application sal-builtin-application))

(defcl sal-eq
    (sal-binary-infix-application sal-builtin-application))

(defcl sal-assignment (sal-eq))

(defcl sal-diseq
    (sal-binary-infix-application sal-builtin-application))

(defcl sal-propositional-application (sal-builtin-application))

(defcl sal-binary-propositional-application
    (sal-propositional-application sal-binary-infix-application))

(defcl sal-unary-propositional-application
    (sal-propositional-application sal-unary-application))

(defcl sal-iff (sal-binary-propositional-application sal-eq))

(defcl sal-xor (sal-binary-propositional-application sal-diseq))

(defcl sal-and (sal-propositional-application sal-infix-application))

(defcl sal-or (sal-propositional-application sal-infix-application))

(defcl sal-choice (sal-or))

(defcl sal-not (sal-unary-propositional-application))

(defcl sal-implies (sal-binary-propositional-application))

(defcl sal-temporal-application (sal-builtin-application))

(defcl sal-ltl-application (sal-temporal-application))

(defcl sal-unary-ltl-application
    (sal-ltl-application sal-unary-application))

(defcl sal-binary-ltl-application
    (sal-ltl-application sal-binary-application))

(defcl sal-ltl-x (sal-unary-ltl-application))

(defcl sal-ltl-g (sal-unary-ltl-application))

(defcl sal-ltl-f (sal-unary-ltl-application))

(defcl sal-ltl-u (sal-binary-ltl-application))

(defcl sal-ltl-r (sal-binary-ltl-application))

(defcl sal-ltl-w (sal-binary-ltl-application))

(defcl sal-ltl-m (sal-binary-ltl-application))

(defcl sal-ctl-application (sal-temporal-application))

(defcl sal-unary-ctl-application
    (sal-ctl-application sal-unary-application))

(defcl sal-binary-ctl-application
    (sal-ctl-application sal-binary-application))

(defcl sal-ctl-ax (sal-unary-ctl-application))

(defcl sal-ctl-ex (sal-unary-ctl-application))

(defcl sal-ctl-ag (sal-unary-ctl-application))

(defcl sal-ctl-eg (sal-unary-ctl-application))

(defcl sal-ctl-af (sal-unary-ctl-application))

(defcl sal-ctl-ef (sal-unary-ctl-application))

(defcl sal-ctl-au (sal-binary-ctl-application))

(defcl sal-ctl-eu (sal-binary-ctl-application))

(defcl sal-ctl-ar (sal-binary-ctl-application))

(defcl sal-ctl-er (sal-binary-ctl-application))

(defcl sal-accepting (sal-temporal-application sal-unary-application))

(defcl sal-weak-accepting (sal-accepting))

(defcl sal-arith-application (sal-builtin-application))

(defcl sal-binary-arith-application
    (sal-arith-application sal-binary-application))

(defcl sal-arith-op (sal-arith-application))

(defcl sal-infix-arith-op (sal-arith-op sal-infix-application))

(defcl sal-binary-arith-op
    (sal-arith-op sal-binary-arith-application))

(defcl sal-binary-infix-arith-op
    (sal-binary-arith-op sal-infix-arith-op))

(defcl sal-add (sal-infix-arith-op))

(defcl sal-sub (sal-binary-infix-arith-op))

(defcl sal-mul (sal-infix-arith-op))

(defcl sal-div (sal-binary-infix-arith-op))

(defcl sal-idiv (sal-binary-infix-arith-op))

(defcl sal-mod (sal-binary-infix-arith-op))

(defcl sal-max (sal-binary-arith-op))

(defcl sal-min (sal-binary-arith-op))

(defcl sal-arith-relation
    (sal-binary-arith-application sal-infix-application))

(defcl sal-inequality (sal-arith-relation))

(defcl sal-lt (sal-inequality))

(defcl sal-gt (sal-inequality))

(defcl sal-ge (sal-inequality))

(defcl sal-le (sal-inequality))

(defcl sal-real-pred (sal-unary-application sal-arith-application))

(defcl sal-int-pred (sal-unary-application sal-arith-application))

(defcl sal-definition-expression (sal-expr)
  lhs-list
  expr)

;;; The redundant SAL-EXPR direct superclass on these leaf/simple nodes is
;;; inherited through SAL-SIMPLE-EXPR. NUM is already the ground prover's
;;; rational-numerator macro, so it cannot also name a generic accessor.
(defcl-with-accessors sal-numeral (sal-ast-leaf sal-simple-expr)
  (num sal-num))

(defcl sal-name-expr (sal-name-ref sal-simple-expr)
  decl)

(defcl sal-var-param-name-expr (sal-name-expr))

(defcl sal-qualified-name-expr
    (sal-name-expr sal-qualified-name-ref)
  context-ref
  actuals)

(defcl sal-scalar (sal-qualified-name-expr))

(defcl sal-true (sal-scalar))

(defcl sal-false (sal-scalar))

(defcl sal-constructor (sal-qualified-name-expr))

(defcl sal-accessor (sal-qualified-name-expr))

(defcl sal-recognizer (sal-qualified-name-expr))

(defcl sal-local-binds-expr (sal-local-binds-ast sal-expr)
  local-decls
  expr)

(defcl sal-lambda (sal-local-binds-expr))

(defcl sal-set-pred-expr (sal-lambda))

(defcl sal-set-list-expr (sal-set-pred-expr))

(defcl sal-quantified-expr (sal-local-binds-expr))

(defcl sal-for-all-expr (sal-quantified-expr))

(defcl sal-exists-expr (sal-quantified-expr))

(defcl sal-multi-choice-expr (sal-exists-expr))

(defcl sal-let-expr (sal-local-binds-expr))

(defcl sal-collection-literal (sal-expr))

(defcl sal-array-literal (sal-lambda sal-collection-literal))

(defcl sal-tuple-literal (sal-collection-literal)
  exprs)

(defcl sal-arg-tuple-literal (sal-tuple-literal))

(defcl sal-record-literal (sal-collection-literal)
  entries)

(defcl sal-state-record-literal (sal-record-literal))

(defcl sal-record-entry (sal-ast)
  id
  expr)

(defcl sal-selection (sal-expr))

(defcl sal-array-selection (sal-application sal-selection))

(defcl sal-simple-selection (sal-selection)
  target
  idx)

(defcl sal-tuple-selection (sal-simple-selection))

(defcl sal-record-selection (sal-simple-selection))

(defcl sal-update-expr (sal-expr)
  target
  idx
  new-value)

(defcl sal-function-update (sal-update-expr))

(defcl sal-array-update (sal-function-update))

(defcl sal-record-update (sal-update-expr))

(defcl sal-tuple-update (sal-update-expr))

(defcl-with-accessors sal-conditional (sal-expr)
  (cond-expr sal-cond-expr)
  (then-expr sal-then-expr)
  (else-expr sal-else-expr))

(defcl sal-next-operator (sal-simple-expr)
  name-expr)

;;; STRING is inherited from COMMON-LISP in the PVS package and cannot also
;;; name a generic accessor.  Keep it as the slot/initarg name used by SAL,
;;; but expose SAL-STRING as the accessor.
(defcl-with-accessors sal-string-expr
    (sal-ast-leaf sal-simple-expr)
  (string sal-string))

(defcl sal-mod-init (sal-expr)
  module)

(defcl sal-mod-trans (sal-expr)
  module)

(defcl sal-ring-application (sal-unary-application))

(defcl sal-ring-pre (sal-ring-application))

(defcl sal-ring-succ (sal-ring-application))

(defcl sal-debug-application (sal-application))

(defcl sal-debug-print (sal-debug-application))

(defcl sal-debug-expr (sal-debug-application))

;;; Used while generating counterexamples.
(defcl sal-pre-operator (sal-expr)
  expr)

;;; Types

(defcl sal-type (sal-ast))

(defcl sal-type-name (sal-type sal-name-ref)
  decl)

(defcl sal-type-param-name (sal-type-name))

(defcl sal-qualified-type-name
    (sal-type-name sal-qualified-name-ref)
  context-ref
  actuals)

(defcl sal-any-type (sal-qualified-type-name))

(defcl sal-bool-type (sal-qualified-type-name))

(defcl sal-number-type (sal-qualified-type-name))

(defcl sal-real-type (sal-number-type))

(defcl sal-int-type (sal-real-type))

(defcl sal-nat-type (sal-int-type))

(defcl sal-string-type (sal-qualified-type-name))

(defcl sal-function-type (sal-type)
  domain
  range)

(defcl sal-array-type (sal-function-type))

(defcl sal-tuple-type (sal-type)
  types)

(defcl sal-domain-tuple-type (sal-tuple-type))

(defcl sal-record-type (sal-type)
  fields)

(defcl sal-field (sal-ast)
  id
  type)

(defcl sal-state-type (sal-type)
  module)

(defcl sal-subtype (sal-type)
  expr)

(defcl sal-bounded-subtype (sal-subtype)
  lower
  upper)

(defcl sal-subrange (sal-bounded-subtype))

(defcl sal-symmetric-type (sal-subrange))

(defcl sal-scalar-set-type (sal-symmetric-type))

(defcl sal-ring-set-type (sal-symmetric-type))

;;; Type definitions

(defcl sal-type-def (sal-type))

(defcl sal-scalar-type (sal-type-def)
  scalar-elements)

(defcl sal-data-type (sal-type-def)
  constructors)

;;; Definitions and commands

(defcl sal-definition (sal-ast))

(defcl sal-simple-definition (sal-definition)
  lhs
  rhs)

(defcl sal-simple-selection-definition (sal-simple-definition))

(defcl sal-for-all-definition (sal-local-binds-ast sal-definition)
  local-decls
  definitions)

(defcl sal-command-section (sal-ast)
  commands
  else-command)

(defcl sal-command (sal-ast))

(defcl sal-guarded-command (sal-command)
  guard
  assignments)

(defcl sal-labeled-command (sal-command)
  label
  command)

(defcl sal-multi-command (sal-local-binds-ast sal-command)
  local-decls
  command)

(defcl sal-else-command (sal-command)
  assignments)

;;; Modules

(defcl sal-module (sal-ast)
  state-vars
  state-vars-table)

(defcl sal-non-base-module (sal-module))

(defcl sal-module-composition (sal-non-base-module)
  module1
  module2)

(defcl sal-asynch-composition (sal-module-composition))

(defcl sal-synch-composition (sal-module-composition))

(defcl sal-observer (sal-synch-composition))

(defcl sal-multi-composition
    (sal-local-binds-ast sal-non-base-module)
  local-decls
  module)

(defcl sal-multi-asynch-composition (sal-multi-composition))

(defcl sal-multi-synch-composition (sal-multi-composition))

(defcl sal-renaming (sal-non-base-module)
  renames
  module)

(defcl sal-rename (sal-ast)
  from-name
  to-expr)

(defcl sal-org-module (sal-non-base-module)
  identifiers
  module)

(defcl sal-hiding (sal-org-module))

(defcl sal-new-output (sal-org-module))

(defcl sal-with-module (sal-new-binds-ast sal-non-base-module)
  new-state-vars
  module)

(defcl sal-module-name (sal-name-ref)
  decl)

(defcl sal-qualified-module-name
    (sal-module-name sal-qualified-name-ref)
  context-ref
  actuals)

(defcl sal-module-instance (sal-non-base-module)
  module-name
  actuals)

(defcl sal-base-module (sal-new-binds-ast sal-module)
  definitions
  initialization-definitions
  initialization-command-section
  transition-definitions
  transition-command-section)

(defcl-with-accessors sal-flat-module (sal-new-binds-ast sal-module)
  (definition definition)
  (initialization initialization)
  (transition transition)
  (skip sal-skip)
  (transition-trace-info transition-trace-info)
  (choice-vars choice-vars)
  (component-info component-info)
  (valid-input-expr valid-input-expr)
  (valid-state-expr valid-state-expr)
  (valid-constant-expr valid-constant-expr))

(defcl sal-component-info (sal-ast)
  data)

(defcl sal-base-component-info (sal-component-info)
  input-data
  output-data
  owned-data)

(defcl sal-multi-component-info
    (sal-component-info sal-local-binds-ast)
  local-decls
  component)

(defcl sal-composite-component-info (sal-component-info)
  components)

(defcl sal-derived-flat-module (sal-flat-module)
  original-module
  var-trace-info
  const-trace-info)

(defcl sal-sliced-flat-module (sal-derived-flat-module))

(defcl sal-simple-data-flat-module (sal-derived-flat-module))

(defcl sal-sliced-simple-data-flat-module
    (sal-sliced-flat-module sal-simple-data-flat-module))

(defcl sal-boolean-flat-module (sal-derived-flat-module))

(defcl sal-sliced-boolean-flat-module
    (sal-sliced-flat-module sal-boolean-flat-module))

;;; Assertions

(defcl sal-assertion-expr (sal-expr))

(defcl sal-module-models (sal-assertion-expr)
  module
  expr)

(defcl sal-module-implements (sal-assertion-expr)
  module1
  module2)

(defcl sal-assertion-proposition (sal-assertion-expr)
  op
  assertion-exprs)

(defcl sal-qualified-assertion-name
    (sal-qualified-name-ref sal-assertion-expr)
  decl
  context-ref
  actuals)

;;; Traceability

(defcl sal-trace-info (sal-ast))

(defcl sal-transition-trace-info (sal-trace-info))

(defcl sal-else-trace-info (sal-trace-info))

(defcl sal-nested-trace-info (sal-trace-info)
  info)

(defcl sal-module-instance-trace-info (sal-nested-trace-info))

(defcl sal-labeled-trace-info (sal-nested-trace-info)
  label)

(defcl sal-multi-trace-info (sal-nested-trace-info))

(defcl sal-multi-choice-trace-info (sal-multi-trace-info)
  choice-var-names
  original-var-names)

(defcl sal-multi-command-choice-trace-info
    (sal-multi-choice-trace-info))

(defcl sal-multi-sequence-trace-info (sal-multi-trace-info)
  idx-var-name)

(defcl sal-nested-list-trace-info (sal-trace-info)
  info-list)

(defcl sal-choice-trace-info (sal-nested-list-trace-info)
  choice-var-name)

(defcl sal-sequence-trace-info (sal-nested-list-trace-info))

;;; Explicit-state module representation

(defcl sal-esm-component (sal-ast))

;;; NUM-ALTERNATIVES caches the result of SAL-ESM/NUM-ALTERNATIVES.
(defcl sal-esm-statement (sal-esm-component)
  num-alternatives)

(defcl sal-esm-composition-statement (sal-esm-statement)
  statements)

(defcl sal-esm-choice (sal-esm-composition-statement))

(defcl sal-esm-seq (sal-esm-composition-statement))

(defcl sal-esm-monitor-seq (sal-esm-seq))

(defcl sal-esm-case (sal-esm-statement)
  expr
  case-entries)

(defcl sal-esm-case-entry (sal-esm-component)
  value
  statement)

(defcl sal-esm-when-undefined (sal-esm-statement)
  lhs
  statement)

(defcl sal-esm-new-binds-statement (sal-esm-statement)
  local-decls
  statement)

(defcl sal-esm-multi-seq (sal-esm-new-binds-statement))

(defcl sal-esm-multi-choice (sal-esm-new-binds-statement))

;;; NO-DELAY? is true when an ESM leaf cannot be delayed because a variable
;;; it uses does not yet have a value.
(defcl-with-accessors sal-esm-leaf (sal-esm-statement)
  (dependencies sal-dependencies)
  (no-delay? no-delay?))

(defcl sal-esm-guard (sal-esm-leaf)
  expr)

(defcl sal-esm-assignment (sal-esm-leaf)
  lhs
  rhs)

(defcl sal-esm-choice-assignment (sal-esm-assignment))

(defcl sal-esm-module (sal-esm-component sal-module)
  initialization
  transition
  definition
  transition-trace-info
  choice-vars)

(defcl sal-data-flat-esm-module (sal-esm-module)
  original-module
  var-trace-info)
