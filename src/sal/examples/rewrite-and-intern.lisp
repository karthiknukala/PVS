;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rewrite-and-intern.lisp -- Persistent SAL optimization examples
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defun sal-example-numeral-like (template origin value)
  "Create VALUE using TEMPLATE's numeral representation and ORIGIN metadata."
  (sal-copy-with-slot-values
   template
   (list (cons 'num value)
         (cons 'type (type origin))
         (cons 'place (place origin))
         (cons 'context (context origin))
         (cons 'hash nil)
         (cons 'internal-idx nil))))

(defun sal-example-fold-addition (node)
  "Fold constant additions and the additive identity."
  (if (not (sal-add? node))
      node
      (let ((arguments (sal-example-application-arguments node)))
        (cond
          ((and arguments (every #'sal-numeral? arguments))
           (sal-example-numeral-like
            (first arguments) node
            (reduce #'+ arguments :key #'sal-num)))
          ((and (= (length arguments) 2)
                (sal-numeral? (first arguments))
                (zerop (sal-num (first arguments))))
           (second arguments))
          ((and (= (length arguments) 2)
                (sal-numeral? (second arguments))
                (zerop (sal-num (second arguments))))
           (first arguments))
          (t node)))))

(defun sal-example-optimize (root)
  "Run the example optimizer to a fixed point."
  (loop for before = root then after
        for after = (sal-rewrite-ast #'sal-example-fold-addition before)
        when (eq before after)
          return after))

(defun sal-example-constant-addition-p (node)
  (and (sal-add? node)
       (every #'sal-numeral?
              (sal-example-application-arguments node))))

(defun sal-example-pass-idempotent-p (pass root)
  "Check a useful optimizer regression property."
  (let* ((once (funcall pass root))
         (twice (funcall pass once)))
    (sal-ast-structural-equal once twice)))

(defun sal-example-rename-declaration! (root declaration new-name)
  "Rename DECLARATION without invalidating identity-based references."
  (setf (name (id declaration)) (make-symbol (string new-name)))
  (sal-clear-ast-hashes root)
  root)

(defun sal-example-canonicalize (root &optional table)
  "Hash-cons ROOT and return the canonical root and interning table."
  (sal-hash-cons-ast
   root :table (or table (make-sal-hash-cons-table :size 16384))))

(defun sal-example-print-optimization (before after table
                                       &optional (stream *standard-output*))
  (format stream "~&Optimizer changed root: ~:[no~;yes~]~%"
          (not (eq before after)))
  (format stream "Nodes before/after: ~D / ~D~%"
          (sal-count-ast before) (sal-count-ast after))
  (format stream "Foldable additions before/after: ~D / ~D~%"
          (sal-count-ast before :predicate #'sal-example-constant-addition-p)
          (sal-count-ast after :predicate #'sal-example-constant-addition-p))
  (format stream "Structural hashes before/after: ~X / ~X~%"
          (sal-ast-structural-hash before)
          (sal-ast-structural-hash after))
  (format stream "Hash-cons hits/misses: ~D / ~D~%"
          (sal-hash-cons-table-hits table)
          (sal-hash-cons-table-misses table))
  (format stream "Canonical table entries: ~D~%"
          (sal-hash-cons-table-count table))
  (format stream "Optimizer idempotent: ~:[no~;yes~]~%"
          (sal-example-pass-idempotent-p #'sal-example-optimize after)))
