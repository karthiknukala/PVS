;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; walk-and-analyze.lisp -- Compiler-style SAL AST analyses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defun sal-example-node-histogram (root &key (unique t))
  "Count nodes by concrete class."
  (sal-fold-ast
   (lambda (node histogram)
     (incf (gethash (class-name (class-of node)) histogram 0))
     histogram)
   (make-hash-table :test #'eq)
   root :unique unique))

(defun sal-example-sorted-histogram (root)
  "Return the class histogram as descending (COUNT . CLASS) pairs."
  (let ((entries nil))
    (maphash (lambda (class count)
               (push (cons count class) entries))
             (sal-example-node-histogram root))
    (sort entries #'> :key #'car)))

(defun sal-example-declaration-names (root)
  "Collect declaration names with the DO-SAL-AST iteration macro."
  (let ((names nil))
    (do-sal-ast (node root :result (nreverse names))
      (when (sal-decl? node)
        (push (sal-example-declaration-name node) names)))))

(defun sal-example-numeral-values (root)
  "Collect literal values in preorder."
  (mapcar #'sal-num (sal-collect-ast #'sal-numeral? root)))

(defun sal-example-maximum-branching-factor (root)
  "Measure tree shape with allocation-free immediate-child visits."
  (let ((maximum 0))
    (sal-walk-ast
     (lambda (node)
       (let ((children 0))
         (sal-map-children (lambda (child)
                             (declare (ignore child))
                             (incf children))
                           node)
         (setf maximum (max maximum children))))
     root)
    maximum))

(defun sal-example-declaration-use-counts (root)
  "Count value, type, module, and assertion references by identity."
  (let ((counts (make-hash-table :test #'eq)))
    (sal-walk-ast
     (lambda (node)
       (let ((target
               (cond ((sal-name-expr? node) (decl node))
                     ((sal-type-name? node) (decl node))
                     ((sal-module-name? node) (decl node))
                     ((sal-qualified-assertion-name? node) (decl node)))))
         (when (sal-decl? target)
           (incf (gethash target counts 0)))))
     root
     ;; Hash-consing may share references.  A use analysis counts occurrences,
     ;; not merely distinct node objects.
     :unique nil)
    counts))

(defun sal-example-unused-top-level-declarations (context)
  "Return top-level declarations with no syntactic references."
  (let ((uses (sal-example-declaration-use-counts context)))
    (remove-if (lambda (declaration)
                 (plusp (gethash declaration uses 0)))
               (declarations context))))

(defun sal-example-module-dependency-graph (context)
  "Map each module declaration to the modules instantiated in its body."
  (let ((graph (make-hash-table :test #'eq)))
    ;; MODULE-DECLARATIONS is a frontend lookup table.  The source-order
    ;; declarations themselves live in the ordinary AST slot.
    (dolist (declaration
             (remove-if-not #'sal-module-decl? (declarations context)))
      (let ((dependencies nil))
        (sal-walk-ast
         (lambda (node)
           (when (sal-module-name? node)
             (let ((target (decl node)))
               (when (sal-module-decl? target)
                 (pushnew target dependencies :test #'eq)))))
         (sal-example-module-body declaration))
        (setf (gethash declaration graph) (nreverse dependencies))))
    graph))

(defun sal-example-validate-references (root)
  "Check a core post-frontend invariant and return ROOT."
  (sal-walk-ast
   (lambda (node)
     (when (and (or (sal-name-expr? node)
                    (sal-module-name? node))
                (null (decl node)))
       (error "Unresolved SAL reference ~S~@[ at ~S~]" node (place node))))
   root)
  root)

(defun sal-example-first-large-numeral (root threshold)
  "Demonstrate an early-exit query."
  (sal-find-ast
   (lambda (node)
     (and (sal-numeral? node)
          (> (sal-num node) threshold)))
   root))

(defun sal-example-enclosing-module (node index)
  "Find NODE's first enclosing module declaration through INDEX."
  (let ((parents (sal-ast-index-parents index)))
    (loop for current = node then (gethash current parents)
          while current
          when (sal-module-decl? current)
            return current)))

(defun sal-example-print-analysis (context &optional
                                             (stream *standard-output*))
  "Print a compact compiler-front-end report for CONTEXT."
  (let* ((index (sal-index-ast context))
         (histogram (sal-example-sorted-histogram context))
         (uses (sal-example-declaration-use-counts context))
         (graph (sal-example-module-dependency-graph context))
         (first-command
           (first (sal-index-nodes index 'sal-guarded-command)))
         (enclosing-module
           (and first-command
                (sal-example-enclosing-module first-command index)))
         (first-name
           (sal-example-declaration-name (first (declarations context)))))
    (format stream "~&Context: ~A~%" (sal-example-declaration-name context))
    (format stream "Nodes: ~D (~D expressions, ~D guarded commands)~%"
            (sal-ast-index-count index)
            (length (sal-index-nodes index 'sal-expr :subclasses t))
            (length (sal-index-nodes index 'sal-guarded-command)))
    (format stream "Tree shape: ~D direct context children; maximum fanout ~D~%"
            (length (sal-ast-children context))
            (sal-example-maximum-branching-factor context))
    (format stream "Numeral values: ~{~D~^, ~}~%"
            (sal-example-numeral-values context))
    (when first-name
      (format stream "Index lookup for ~A: ~D declaration~:P~%"
              first-name
              (length (sal-index-declarations index first-name))))
    (when enclosing-module
      (format stream "First guarded command is enclosed by module ~A~%"
              (sal-example-declaration-name enclosing-module)))
    (format stream "Most common node classes:~%")
    (dolist (entry (subseq histogram 0 (min 8 (length histogram))))
      (format stream "  ~5D  ~A~%" (car entry) (cdr entry)))
    (format stream "Top-level declaration uses:~%")
    (dolist (declaration (declarations context))
      (format stream "  ~3D  ~A~%"
              (gethash declaration uses 0)
              (sal-example-declaration-name declaration)))
    (format stream "Syntactically unreferenced: ~{~A~^, ~}~%"
            (mapcar #'sal-example-declaration-name
                    (sal-example-unused-top-level-declarations context)))
    (format stream "Module dependency graph:~%")
    (maphash
     (lambda (module dependencies)
       (format stream "  ~A -> ~{~A~^, ~}~%"
               (sal-example-declaration-name module)
               (mapcar #'sal-example-declaration-name dependencies)))
     graph)
    index))
