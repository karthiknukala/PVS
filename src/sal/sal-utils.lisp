;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sal-utils.lisp -- Traversal, interning, indexing, and SAL tool utilities
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

(export '(sal-map-children
          sal-ast-children
          sal-walk-ast
          do-sal-ast
          sal-fold-ast
          sal-find-ast
          sal-collect-ast
          sal-count-ast
          sal-rewrite-ast
          sal-index-ast
          sal-ast-index
          sal-ast-index-root
          sal-ast-index-count
          sal-ast-index-by-class
          sal-ast-index-by-declaration-name
          sal-ast-index-parents
          sal-index-nodes
          sal-index-declarations
          sal-ast-structural-hash
          sal-ast-structural-equal
          sal-clear-ast-hashes
          sal-hash-cons-ast
          sal-hash-cons-table
          make-sal-hash-cons-table
          clear-sal-hash-cons-table
          sal-hash-cons-table-hits
          sal-hash-cons-table-misses
          sal-hash-cons-table-count
          *sal-transform-program*
          sal-find-transform-program
          sal-external-result
          sal-external-result-operation
          sal-external-result-source
          sal-external-result-declaration
          sal-external-result-syntax
          sal-external-result-output
          sal-external-result-diagnostics
          sal-external-result-status
          sal-run-external-transformation
          sal-preprocess-file
          sal-simplify-file
          sal-flatten-file
          sal-transform-ast))

;;; Structural children

(defgeneric sal-map-children (function ast)
  (:documentation
   "Call FUNCTION on each structural child of AST, in source order.

Semantic back-pointers, caches, source locations, declaration references, and
context indexes are deliberately not children.  This is the CLOS counterpart
of SAL 3.3's sal-ast/for-each-children protocol."))

(defgeneric sal-rewrite-children (function ast))
(defgeneric sal-update-children (function ast))

(defmethod sal-map-children (function (ast sal-ast))
  (declare (ignore function))
  ast)

(defmethod sal-rewrite-children (function (ast sal-ast))
  (declare (ignore function))
  ast)

(defmethod sal-update-children (function (ast sal-ast))
  (declare (ignore function))
  ast)

(declaim (inline sal-call-on-child))

(defun sal-call-on-child (function value)
  (when (typep value 'sal-ast)
    (funcall function value)))

(defun sal-map-child-list (function list)
  "Map FUNCTION over the SAL nodes in LIST, preserving LIST when unchanged."
  (let ((changedp nil)
        (result nil))
    (dolist (value list)
      (let ((new-value (if (typep value 'sal-ast)
                           (funcall function value)
                           value)))
        (unless (eq value new-value)
          (setf changedp t))
        (push new-value result)))
    (if changedp (nreverse result) list)))

(defun sal-copy-with-slot-values (ast slot-values)
  "Shallow-copy AST, replacing the slots in SLOT-VALUES.

SLOT-VALUES is an alist.  Effective slots are copied directly so this remains
usable while the generated PVS COPY methods are not yet loaded."
  (let ((copy (make-instance (class-of ast))))
    (dolist (slot (#+allegro mop:class-slots
                   #+sbcl sb-mop:class-slots
                   (class-of ast)))
      (let ((name (#+allegro mop:slot-definition-name
                   #+sbcl sb-mop:slot-definition-name
                   slot)))
        (when (slot-boundp ast name)
          (setf (slot-value copy name) (slot-value ast name)))))
    (dolist (entry slot-values copy)
      (setf (slot-value copy (car entry)) (cdr entry)))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun sal-child-spec-slot (spec)
    (if (consp spec) (first spec) spec))

  (defun sal-child-spec-list-p (spec)
    (and (consp spec) (eq (second spec) :list))))

(defmacro define-sal-children (class &rest specs)
  "Define allocation-free visit, persistent rewrite, and destructive update
methods for CLASS.  A spec is SLOT or (SLOT :LIST)."
  (let ((function (gensym "FUNCTION"))
        (ast (gensym "AST"))
        (visit-forms nil)
        (rewrite-bindings nil)
        (rewrite-tests nil)
        (rewrite-updates nil)
        (update-forms nil))
    (dolist (spec specs)
      (let* ((slot (sal-child-spec-slot spec))
             (listp (sal-child-spec-list-p spec))
             (old (gensym (format nil "OLD-~A-" slot)))
             (new (gensym (format nil "NEW-~A-" slot))))
        (push (if listp
                  `(dolist (child (slot-value ,ast ',slot))
                     (sal-call-on-child ,function child))
                  `(sal-call-on-child ,function (slot-value ,ast ',slot)))
              visit-forms)
        (push `(,old (slot-value ,ast ',slot)) rewrite-bindings)
        (push `(,new ,(if listp
                          `(sal-map-child-list ,function ,old)
                          `(if (typep ,old 'sal-ast)
                               (funcall ,function ,old)
                               ,old)))
              rewrite-bindings)
        (push `(not (eq ,old ,new)) rewrite-tests)
        (push `(cons ',slot ,new) rewrite-updates)
        (push
         (if listp
             `(let* ((old (slot-value ,ast ',slot))
                     (new (sal-map-child-list ,function old)))
                (unless (eq old new)
                  (setf (slot-value ,ast ',slot) new
                        (slot-value ,ast 'hash) nil)))
             `(let* ((old (slot-value ,ast ',slot))
                     (new (if (typep old 'sal-ast)
                              (funcall ,function old)
                              old)))
                (unless (eq old new)
                  (setf (slot-value ,ast ',slot) new
                        (slot-value ,ast 'hash) nil))))
         update-forms)))
    `(progn
       (defmethod sal-map-children (,function (,ast ,class))
         ,@(nreverse visit-forms)
         ,ast)
       (defmethod sal-rewrite-children (,function (,ast ,class))
         (let* ,(nreverse rewrite-bindings)
           (if (or ,@(nreverse rewrite-tests))
               (sal-copy-with-slot-values
                ,ast (list ,@(nreverse rewrite-updates)))
               ,ast)))
       (defmethod sal-update-children (,function (,ast ,class))
         ,@(nreverse update-forms)
         ,ast))))

;; These definitions intentionally track sal-ast-for-each.scm.  A few cached
;; or derivable fields (for example expression TYPE and component tables) are
;; not syntax-tree edges and are therefore not followed.
(define-sal-children sal-decl id)
(define-sal-children sal-typed-decl id type)
(define-sal-children sal-const-decl id type value)
(define-sal-children sal-type-decl id type)
(define-sal-children sal-constant-decl id type value)
(define-sal-children sal-constructor-decl id type (accessors :list))
(define-sal-children sal-module-decl id parametric-module)
(define-sal-children sal-parametric-module (local-decls :list) module)
(define-sal-children sal-context-name-decl id (actuals :list))
(define-sal-children sal-assertion-decl id assertion-expr)
(define-sal-children sal-context id (params :list) (declarations :list))

(define-sal-children sal-qualified-name-expr (actuals :list))
(define-sal-children sal-qualified-type-name (actuals :list))
(define-sal-children sal-qualified-module-name (actuals :list))
(define-sal-children sal-qualified-assertion-name (actuals :list))
(define-sal-children sal-definition-expression (lhs-list :list) expr)
(define-sal-children sal-tuple-literal (exprs :list))
(define-sal-children sal-application fun arg)
(define-sal-children sal-local-binds-expr (local-decls :list) expr)
(define-sal-children sal-record-literal (entries :list))
(define-sal-children sal-record-entry id expr)
(define-sal-children sal-simple-selection target idx)
(define-sal-children sal-update-expr target idx new-value)
(define-sal-children sal-conditional cond-expr then-expr else-expr)
(define-sal-children sal-next-operator name-expr)
(define-sal-children sal-mod-init module)
(define-sal-children sal-mod-trans module)
(define-sal-children sal-pre-operator expr)

(define-sal-children sal-function-type domain range)
(define-sal-children sal-tuple-type (types :list))
(define-sal-children sal-record-type (fields :list))
(define-sal-children sal-field id type)
(define-sal-children sal-state-type module)
(define-sal-children sal-subtype expr)
(define-sal-children sal-bounded-subtype expr lower upper)
(define-sal-children sal-scalar-type (scalar-elements :list))
(define-sal-children sal-data-type (constructors :list))

(define-sal-children sal-simple-definition lhs rhs)
(define-sal-children sal-for-all-definition (local-decls :list)
  (definitions :list))
(define-sal-children sal-command-section (commands :list) else-command)
(define-sal-children sal-guarded-command guard (assignments :list))
(define-sal-children sal-labeled-command label command)
(define-sal-children sal-multi-command (local-decls :list) command)
(define-sal-children sal-else-command (assignments :list))

(define-sal-children sal-module (state-vars :list))
(define-sal-children sal-module-composition module1 module2)
(define-sal-children sal-multi-composition (local-decls :list) module)
(define-sal-children sal-org-module (identifiers :list) module)
(define-sal-children sal-with-module (new-state-vars :list) module)
(define-sal-children sal-renaming (renames :list) module)
(define-sal-children sal-rename from-name to-expr)
(define-sal-children sal-module-instance module-name (actuals :list))
(define-sal-children sal-base-module (state-vars :list) (definitions :list)
  (initialization-definitions :list) initialization-command-section
  (transition-definitions :list) transition-command-section)
(define-sal-children sal-flat-module (state-vars :list) definition
  initialization transition skip component-info valid-input-expr
  valid-state-expr valid-constant-expr)
(define-sal-children sal-base-component-info (input-data :list)
  (output-data :list) (owned-data :list))
(define-sal-children sal-multi-component-info (local-decls :list) component)
(define-sal-children sal-composite-component-info (components :list))

(define-sal-children sal-module-models module expr)
(define-sal-children sal-module-implements module1 module2)
(define-sal-children sal-assertion-proposition (assertion-exprs :list))

(define-sal-children sal-nested-trace-info info)
(define-sal-children sal-nested-list-trace-info (info-list :list))
(define-sal-children sal-esm-composition-statement (statements :list))
(define-sal-children sal-esm-case expr (case-entries :list))
(define-sal-children sal-esm-case-entry value statement)
(define-sal-children sal-esm-when-undefined lhs statement)
(define-sal-children sal-esm-new-binds-statement (local-decls :list) statement)
(define-sal-children sal-esm-guard expr)
(define-sal-children sal-esm-assignment lhs rhs)
(define-sal-children sal-esm-module (state-vars :list) definition
  initialization transition)

(defun sal-ast-children (ast)
  "Return a freshly allocated list of AST's immediate structural children."
  (check-type ast sal-ast)
  (let ((children nil))
    (sal-map-children (lambda (child) (push child children)) ast)
    (nreverse children)))

;;; Fast traversal and persistent rewriting

(defun sal-walk-ast (function root &key (unique t))
  "Call FUNCTION in preorder on ROOT and its structural descendants.

The explicit adjustable-vector stack avoids control-stack growth and per-edge
consing.  UNIQUE uses an EQ table, which is normally desirable for shared or
hash-consed trees.  Sibling order follows SAL-MAP-CHILDREN."
  (check-type root sal-ast)
  (let ((pending (make-array 64 :adjustable t :fill-pointer 0))
        (seen (and unique (make-hash-table :test #'eq))))
    (vector-push-extend root pending)
    (loop while (plusp (fill-pointer pending))
          for ast = (vector-pop pending)
          unless (and seen (gethash ast seen))
            do (when seen (setf (gethash ast seen) t))
               (funcall function ast)
               (let ((start (fill-pointer pending)))
                 (sal-map-children
                  (lambda (child) (vector-push-extend child pending)) ast)
                 ;; The stack is LIFO; reverse only the newly pushed segment.
                 (loop for left from start
                       for right downfrom (1- (fill-pointer pending))
                       while (< left right)
                       do (rotatef (aref pending left) (aref pending right)))))
    root))

(defmacro do-sal-ast ((variable root &key (unique t) result) &body body)
  "Iterate VARIABLE over ROOT's AST nodes.  RETURN exits the implicit block."
  `(block nil
     (sal-walk-ast (lambda (,variable) ,@body) ,root :unique ,unique)
     ,result))

(defun sal-fold-ast (function initial-value root &key (unique t))
  "Fold FUNCTION over ROOT.  FUNCTION receives a node and the accumulator."
  (let ((value initial-value))
    (sal-walk-ast (lambda (ast) (setf value (funcall function ast value)))
                  root :unique unique)
    value))

(defun sal-find-ast (predicate root &key (unique t))
  "Return the first node satisfying PREDICATE, or NIL."
  (block found
    (sal-walk-ast (lambda (ast)
                    (when (funcall predicate ast)
                      (return-from found ast)))
                  root :unique unique)
    nil))

(defun sal-collect-ast (predicate root &key (unique t))
  "Collect, in traversal order, all nodes satisfying PREDICATE."
  (let ((result nil))
    (sal-walk-ast (lambda (ast)
                    (when (funcall predicate ast)
                      (push ast result)))
                  root :unique unique)
    (nreverse result)))

(defun sal-count-ast (root &key type predicate (unique t))
  "Count nodes below ROOT, optionally restricted by TYPE and PREDICATE."
  (let ((count 0))
    (sal-walk-ast
     (lambda (ast)
       (when (and (or (null type) (typep ast type))
                  (or (null predicate) (funcall predicate ast)))
         (incf count)))
     root :unique unique)
    count))

(defun sal-rewrite-ast (function root &key (memoize t))
  "Persistently rewrite ROOT bottom-up with FUNCTION.

Unchanged paths retain object identity and shared input nodes are rewritten
once when MEMOIZE is true.  FUNCTION must return a SAL AST node.  Declaration
references and CONTEXT slots are semantic back-pointers rather than children;
transformations that replace contexts or binding declarations must repair
those references themselves."
  (check-type root sal-ast)
  (let ((memo (and memoize (make-hash-table :test #'eq))))
    (labels ((rewrite (ast)
               (or (and memo (gethash ast memo))
                   (let* ((with-new-children
                            (sal-rewrite-children #'rewrite ast))
                          (result (funcall function with-new-children)))
                     (unless (typep result 'sal-ast)
                       (error "SAL rewrite returned non-AST value ~s for ~s"
                              result ast))
                     (when memo (setf (gethash ast memo) result))
                     result))))
      (rewrite root))))

;;; Indexes

(defstruct (sal-ast-index (:constructor %make-sal-ast-index))
  root
  (count 0 :type fixnum)
  (by-class (make-hash-table :test #'eq) :type hash-table)
  (by-declaration-name (make-hash-table :test #'equal) :type hash-table)
  parents)

(defun sal-node-declaration-name (ast)
  (when (typep ast 'sal-decl)
    (let* ((identifier (slot-value ast 'id))
           (name (and identifier (slot-value identifier 'name))))
      (etypecase name
        (null nil)
        (symbol (symbol-name name))
        (string name)))))

(defun sal-index-ast (root &key (parents t))
  "Build class, declaration-name, and optional parent indexes for ROOT."
  (let ((index (%make-sal-ast-index
                :root root
                :parents (and parents (make-hash-table :test #'eq)))))
    (sal-walk-ast
     (lambda (ast)
       (incf (sal-ast-index-count index))
       (push ast (gethash (class-name (class-of ast))
                          (sal-ast-index-by-class index)))
       (let ((name (sal-node-declaration-name ast)))
         (when name
           (push ast (gethash name
                              (sal-ast-index-by-declaration-name index)))))
       (when (sal-ast-index-parents index)
         (sal-map-children
          (lambda (child)
            (unless (gethash child (sal-ast-index-parents index))
              (setf (gethash child (sal-ast-index-parents index)) ast)))
          ast)))
     root)
    (maphash (lambda (class nodes)
               (setf (gethash class (sal-ast-index-by-class index))
                     (nreverse nodes)))
             (sal-ast-index-by-class index))
    (maphash (lambda (name nodes)
               (setf (gethash name
                              (sal-ast-index-by-declaration-name index))
                     (nreverse nodes)))
             (sal-ast-index-by-declaration-name index))
    index))

(defun sal-index-nodes (index class &key subclasses)
  "Return nodes in INDEX whose class is CLASS.

With SUBCLASSES true, include instances of subclasses as well."
  (check-type index sal-ast-index)
  (let ((class-object (etypecase class
                        (symbol (find-class class))
                        (standard-class class))))
    (if subclasses
        (let ((result nil))
          (maphash (lambda (name nodes)
                     (declare (ignore name))
                     (dolist (node nodes)
                       (when (typep node class-object)
                         (push node result))))
                   (sal-ast-index-by-class index))
          (nreverse result))
        (copy-list
         (gethash (class-name class-object) (sal-ast-index-by-class index))))))

(defun sal-index-declarations (index name &key type)
  "Return declarations named NAME, optionally restricted to TYPE."
  (let ((declarations
          (copy-list
           (gethash (string name)
                    (sal-ast-index-by-declaration-name index)))))
    (if type (remove-if-not (lambda (decl) (typep decl type)) declarations)
        declarations)))

;;; Structural hashing and hash-consing

(defgeneric sal-ast-atom-key (ast)
  (:documentation
   "Return the non-child, semantics-relevant key for an AST node."))

(defmethod sal-ast-atom-key ((ast sal-ast))
  (declare (ignore ast))
  nil)

(defmethod sal-ast-atom-key ((ast sal-identifier))
  (list (slot-value ast 'name)))

(defmethod sal-ast-atom-key ((ast sal-expr))
  (list (slot-value ast 'type)))

(defmethod sal-ast-atom-key ((ast sal-numeral))
  (list (slot-value ast 'type) (slot-value ast 'num)))

(defmethod sal-ast-atom-key ((ast sal-string-expr))
  (list (slot-value ast 'type) (slot-value ast 'string)))

(defmethod sal-ast-atom-key ((ast sal-name-expr))
  (list (slot-value ast 'type) (slot-value ast 'decl)))

(defmethod sal-ast-atom-key ((ast sal-qualified-name-expr))
  (list (slot-value ast 'type) (slot-value ast 'decl)
        (slot-value ast 'context-ref)))

(defmethod sal-ast-atom-key ((ast sal-type-name))
  (list (slot-value ast 'decl)))

(defmethod sal-ast-atom-key ((ast sal-qualified-type-name))
  (list (slot-value ast 'decl) (slot-value ast 'context-ref)))

(defmethod sal-ast-atom-key ((ast sal-module-name))
  (list (slot-value ast 'decl)))

(defmethod sal-ast-atom-key ((ast sal-qualified-module-name))
  (list (slot-value ast 'decl) (slot-value ast 'context-ref)))

(defmethod sal-ast-atom-key ((ast sal-qualified-assertion-name))
  (list (slot-value ast 'type) (slot-value ast 'decl)
        (slot-value ast 'context-ref)))

(defmethod sal-ast-atom-key ((ast sal-context-name-decl))
  (list (slot-value ast 'context-ref)))

(defmethod sal-ast-atom-key ((ast sal-assertion-decl))
  (list (slot-value ast 'kind)))

(defmethod sal-ast-atom-key ((ast sal-assertion-proposition))
  (list (slot-value ast 'type) (slot-value ast 'op)))

(defmethod sal-ast-atom-key ((ast sal-labeled-trace-info))
  (list (slot-value ast 'label)))

(defmethod sal-ast-atom-key ((ast sal-multi-choice-trace-info))
  (list (slot-value ast 'choice-var-names)
        (slot-value ast 'original-var-names)))

(defmethod sal-ast-atom-key ((ast sal-multi-sequence-trace-info))
  (list (slot-value ast 'idx-var-name)))

(defmethod sal-ast-atom-key ((ast sal-choice-trace-info))
  (list (slot-value ast 'choice-var-name)))

(declaim (inline sal-mix-hash))

(defun sal-mix-hash (seed value)
  (logand most-positive-fixnum
          (logxor value (+ #x9e3779b9 (* 33 seed)))))

(defun sal-ast-structural-hash (ast)
  "Compute a source-location- and cache-independent structural hash for AST."
  (check-type ast sal-ast)
  (let ((memo (make-hash-table :test #'eq)))
    (labels ((hash-node (node)
               (multiple-value-bind (old presentp) (gethash node memo)
                 (if presentp old
                     (let ((value
                             (sal-mix-hash
                              (sxhash (class-name (class-of node)))
                              (sxhash (sal-ast-atom-key node)))))
                       (sal-map-children
                        (lambda (child)
                          (setf value (sal-mix-hash value (hash-node child))))
                        node)
                       (setf (gethash node memo) value)
                       value)))))
      (hash-node ast))))

(defun sal-ast-structural-equal (left right)
  "Compare two SAL ASTs modulo locations, contexts, indexes, and caches."
  (let ((seen (make-hash-table :test #'eq)))
    (labels ((seen-p (a b)
               (let ((right-table (gethash a seen)))
                 (and right-table (gethash b right-table))))
             (mark-seen (a b)
               (let ((right-table
                       (or (gethash a seen)
                           (setf (gethash a seen)
                                 (make-hash-table :test #'eq)))))
                 (setf (gethash b right-table) t)))
             (same (a b)
               (or (eq a b)
                   (and (typep a 'sal-ast)
                        (typep b 'sal-ast)
                        (eq (class-of a) (class-of b))
                        (equal (sal-ast-atom-key a) (sal-ast-atom-key b))
                        (or (seen-p a b)
                            (progn
                              (mark-seen a b)
                              (let ((a-children (sal-ast-children a))
                                    (b-children (sal-ast-children b)))
                                (and (= (length a-children)
                                        (length b-children))
                                     (every #'same a-children
                                                   b-children)))))))))
      (same left right))))

(defun sal-clear-ast-hashes (root)
  "Clear cached HASH slots below ROOT after destructive AST edits."
  (sal-walk-ast (lambda (ast) (setf (slot-value ast 'hash) nil)) root)
  root)

(defstruct (sal-hash-cons-table
             (:constructor %make-sal-hash-cons-table))
  (buckets (make-hash-table :test #'eql) :type hash-table)
  (hits 0 :type fixnum)
  (misses 0 :type fixnum))

(defun make-sal-hash-cons-table (&key (size 4096))
  "Create a reusable structural-interning table."
  (%make-sal-hash-cons-table
   :buckets (make-hash-table :test #'eql :size size)))

(defun clear-sal-hash-cons-table (table)
  (clrhash (sal-hash-cons-table-buckets table))
  (setf (sal-hash-cons-table-hits table) 0
        (sal-hash-cons-table-misses table) 0)
  table)

(defun sal-hash-cons-table-count (table)
  (sal-hash-cons-table-misses table))

(defun sal-default-hash-consable-p (ast)
  ;; Declarations are binders and are intentionally identity-bearing.
  (not (typep ast 'sal-decl)))

(defun sal-hash-from-canonical-children (ast)
  "Hash AST in constant local work after its children have been processed."
  (let ((value
          (sal-mix-hash (sxhash (class-name (class-of ast)))
                        (sxhash (sal-ast-atom-key ast)))))
    (sal-map-children
     (lambda (child)
       (setf value
             (sal-mix-hash
              value
              (or (slot-value child 'hash)
                  (sal-ast-structural-hash child)))))
     ast)
    value))

(defun sal-hash-cons-ast (root &key
                                 (table (make-sal-hash-cons-table))
                                 (predicate #'sal-default-hash-consable-p))
  "Destructively replace duplicate subtrees below ROOT with canonical nodes.

The traversal is bottom-up and never interns declaration objects by default,
which preserves binding identity.  Name/type/module references are compared by
their declaration identity.  Return the canonical root and TABLE as values.
Because SAL ASTs are mutable, call SAL-CLEAR-AST-HASHES after later mutation or
use a fresh table for the next interning pass."
  (check-type root sal-ast)
  (let ((memo (make-hash-table :test #'eq)))
    (labels ((intern-node (ast)
               (multiple-value-bind (old presentp) (gethash ast memo)
                 (if presentp old
                     (progn
                       (sal-update-children #'intern-node ast)
                       (let* ((hash (sal-hash-from-canonical-children ast))
                              (bucket (gethash hash
                                               (sal-hash-cons-table-buckets
                                                table)))
                              (canonical
                                (and (funcall predicate ast)
                                     (find ast bucket
                                           :test #'sal-ast-structural-equal))))
                         (setf (slot-value ast 'hash) hash)
                         (cond
                           (canonical
                            (incf (sal-hash-cons-table-hits table)))
                           ((funcall predicate ast)
                            (push ast (gethash hash
                                              (sal-hash-cons-table-buckets
                                               table)))
                            (incf (sal-hash-cons-table-misses table))
                            (setf canonical ast))
                           (t (setf canonical ast)))
                         (setf (gethash ast memo) canonical)
                         canonical))))))
      (values (intern-node root) table))))

;;; SAL transformation tool bridge

(defparameter *sal-transform-program* nil
  "The sal-transform.sh program used for external SAL transformations.

When NIL, PVS checks SAL_TRANSFORM_PROGRAM, SAL_HOME/tools, the installation
that contains *SAL-TO-XML-PROGRAM*, PATH, and PVS's bundled script.  The
bundled script is the copy intended for installation in SAL's tools directory;
when used in place, set SAL_HOME so it can locate bin/salenv.")

(define-condition sal-external-transformation-error (error)
  ((operation :initarg :operation :reader sal-external-error-operation)
   (source :initarg :source :reader sal-external-error-source)
   (status :initarg :status :reader sal-external-error-status)
   (diagnostics :initarg :diagnostics :reader sal-external-error-diagnostics))
  (:report
   (lambda (condition stream)
     (format stream "SAL ~a failed for ~a (status ~d)~@[~%~a~]"
             (sal-external-error-operation condition)
             (sal-external-error-source condition)
             (sal-external-error-status condition)
             (let ((text (sal-external-error-diagnostics condition)))
               (and text (plusp (length text)) text))))))

(defstruct sal-external-result
  operation
  source
  declaration
  syntax
  output
  diagnostics
  status)

(defun sal-executable-on-path (name)
  (loop for directory in (uiop:split-string (or (uiop:getenv "PATH") "")
                                             :separator '(#\:))
        for path = (merge-pathnames
                    name
                    (uiop:ensure-directory-pathname
                     (if (string= directory "") (uiop:getcwd) directory)))
        when (probe-file path) return path))

(defun sal-find-transform-program ()
  "Locate sal-transform.sh or signal an actionable error."
  (labels ((existing (path)
             (and path (probe-file (pathname path))))
           (under-home (relative)
             (let ((home (uiop:getenv "SAL_HOME")))
               (and home
                    (existing (merge-pathnames
                               relative
                               (uiop:ensure-directory-pathname home))))))
           (beside-exporter ()
             (ignore-errors
               (let* ((exporter (sal-find-to-xml-program))
                      (tools (uiop:pathname-directory-pathname exporter)))
                 (existing (merge-pathnames "sal-transform.sh" tools)))))
           (bundled-copy ()
             (and (boundp '*pvs-path*)
                  *pvs-path*
                  (existing
                   (merge-pathnames
                    "src/sal/tools/sal-transform.sh"
                    (uiop:ensure-directory-pathname *pvs-path*))))))
    (or (existing *sal-transform-program*)
        (existing (uiop:getenv "SAL_TRANSFORM_PROGRAM"))
        (under-home "tools/sal-transform.sh")
        (beside-exporter)
        (sal-executable-on-path "sal-transform.sh")
        (bundled-copy)
        (error "Cannot find sal-transform.sh. Install the scripts from ~
PVS/src/sal/tools in SAL's tools directory, or set ~
PVS:*SAL-TRANSFORM-PROGRAM*, SAL_TRANSFORM_PROGRAM, or SAL_HOME."))))

(defun sal-run-external-transformation
    (path operation &key declaration (syntax :lsal) context-path)
  "Invoke SAL 3.3's semantic transformation OPERATION on PATH.

OPERATION is :PREPROCESS, :SIMPLIFY, or :FLATTEN.  DECLARATION optionally
selects one top-level module, assertion, constant, or type.  The result is a
SAL-EXTERNAL-RESULT whose OUTPUT is SALenv's complete internal LSAL text by
default; pass :SYNTAX :SAL for the human-oriented printer.

SAL's flattened sal-flat-module class has no official XML serializer, so the
bridge deliberately returns text rather than pretending it is re-readable SAL
source.  Use SAL-PREPROCESS-FILE when a CLOS context is required."
  (unless (member operation '(:preprocess :simplify :flatten))
    (error "Unknown SAL transformation ~s" operation))
  (unless (member syntax '(:lsal :sal))
    (error "SAL transformation syntax must be :LSAL or :SAL, not ~s" syntax))
  (let* ((source (or (probe-file path)
                     (error "SAL source file does not exist: ~a" path)))
         (program (sal-find-transform-program))
         (declaration-name (and declaration (string declaration)))
         (context-directories
           (mapcar (lambda (directory)
                     (namestring (uiop:ensure-directory-pathname directory)))
                   context-path)))
    (multiple-value-bind (output diagnostics status)
        (uiop:run-program
         (append (list (namestring program)
                       (string-downcase (symbol-name operation))
                       (namestring source)
                       (or declaration-name "")
                       (string-downcase (symbol-name syntax))
                       "-")
                 context-directories)
         :output :string :error-output :string :ignore-error-status t)
      (unless (zerop status)
        (error 'sal-external-transformation-error
               :operation operation :source source :status status
               :diagnostics diagnostics))
      (make-sal-external-result
       :operation operation :source source
       :declaration declaration-name :syntax syntax
       :output output :diagnostics diagnostics :status status))))

(defun sal-preprocess-file (path)
  "Run SAL's parser/SXML preprocessor and return the CLOS context for PATH."
  (read-sal-file path))

(defun sal-simplify-file (path &key declaration (syntax :lsal) context-path)
  "Run SAL's SAL/SIMPLIFY routine and return a SAL-EXTERNAL-RESULT."
  (sal-run-external-transformation
   path :simplify :declaration declaration :syntax syntax
   :context-path context-path))

(defun sal-flatten-file (path &key declaration (syntax :lsal) context-path)
  "Run SAL's SAL-AST/FLAT-MODULES routine and return a SAL-EXTERNAL-RESULT."
  (sal-run-external-transformation
   path :flatten :declaration declaration :syntax syntax
   :context-path context-path))

(defun sal-transform-ast (context operation &key declaration
                                                    (syntax :lsal)
                                                    context-path)
  "Pretty-print a CLOS SAL CONTEXT to a temporary source file and transform it
with SALenv.  Return a SAL-EXTERNAL-RESULT."
  (check-type context sal-context)
  (let* ((identifier-name (slot-value (slot-value context 'id) 'name))
         (context-name (etypecase identifier-name
                         (symbol (symbol-name identifier-name))
                         (string identifier-name)))
         (directory
           (merge-pathnames
            (format nil "pvs-sal-ast-~36r-~36r/"
                    (get-universal-time) (random most-positive-fixnum))
            (uiop:temporary-directory)))
         (path (merge-pathnames (format nil "~a.sal" context-name) directory)))
    (unwind-protect
         (progn
           (ensure-directories-exist path)
           (write-sal-file context path :qualified-names t)
           (let ((result
                   (sal-run-external-transformation
                    path operation :declaration declaration :syntax syntax
                    :context-path context-path)))
             (setf (sal-external-result-source result) context)
             result))
      (uiop:delete-directory-tree directory :validate t
                                             :if-does-not-exist :ignore))))
