;;; Optional structural causality obligations over SAL's normalized definitions.
(in-package :pvs)

(defstruct sal-causality-graph vertices edges origins)

(defun sal-definition-causality-graph (view)
  "Extract a conservative dependency graph for deterministic DEFINITIONs.

An edge X -> Y says X's defining expression syntactically reads Y. This is a
structural scheduling criterion, not a claim that relational equations have
no solution. Partial/indexed targets and IN definitions require a finer
criterion and are rejected by this optional check. Ordinary state updates
do not participate: x' = x is delayed feedback, not an algebraic loop."
  (let* ((flat (sal-transition-view-flat-module view))
         (vertices (state-vars flat))
         (edges nil)
         (origins nil))
    (labels
        ((support (node &optional seen-lets)
           (typecase node
             (sal-type nil)
             (sal-module
              (sal-elaboration-fail node "Module expression in causality dependency"))
             (sal-next-operator
              (sal-elaboration-fail node "Next-state reference in DEFINITION causality"))
             (sal-name-expr
              (let ((declaration (decl node)))
                (cond
                  ((typep declaration 'sal-state-var-decl)
                   (unless (member declaration vertices :test #'eq)
                     (sal-elaboration-fail node "Unresolved normalized state dependency"))
                   (list declaration))
                  ((typep declaration 'sal-let-decl)
                   (when (member declaration seen-lets :test #'eq)
                     (sal-elaboration-fail node "Recursive LET in causality dependency"))
                   (support (value declaration) (cons declaration seen-lets)))
                  (t nil))))
             (sal-ast
              (remove-duplicates
               (mapcan (lambda (child) (support child seen-lets))
                       (sal-ast-children node)) :test #'eq))
             (t nil)))
         (walk (node)
           (typecase node
             (sal-true nil)
             (sal-and
              (mapc #'walk (sal-application-arguments node)))
             (sal-assignment
              (let* ((arguments (sal-application-arguments node))
                     (lhs (first arguments))
                     (rhs (second arguments)))
                (unless (and (= (length arguments) 2)
                             (typep lhs 'sal-name-expr)
                             (member (decl lhs) vertices :test #'eq))
                  (sal-elaboration-fail
                   node "Causality requires whole-variable DEFINITION targets; indexed/partial targets need a finer contract"))
                (push node origins)
                (dolist (dependency (support rhs))
                  (pushnew (cons (decl lhs) dependency) edges :test #'equal))))
             (sal-let-expr (walk (expr node)))
             (sal-for-all-expr (walk (expr node)))
             (sal-definition-expression
              (sal-elaboration-fail
               node "Nondeterministic IN definitions need a relational causality contract"))
             (t
              (sal-elaboration-fail
               node "Unsupported DEFINITION form for structural causality: ~A"
               (and node (class-name (class-of node))))))))
      (walk (definition flat)))
    (make-sal-causality-graph :vertices vertices :edges (nreverse edges)
                             :origins (nreverse origins))))

(defun sal-causality-node-name (declaration)
  (concatenate 'string "causal_" (sal-pvs-name declaration)))

(defun sal-pvs-render-causality-view (view)
  "Render an optional contract interpretation that exposes a mapped-axiom TCC.
PVS checks existence of a ranking of the actual dependency graph. The bridge
does not replace that obligation with a precomputed true/false answer."
  (unless (sal-transition-view-theory-name view)
    (sal-elaboration-fail (sal-transition-view-flat-module view)
                          "Elaborate the transition-system view before causality"))
  (let* ((graph (sal-definition-causality-graph view))
         (*sal-pvs-context* (sal-transition-view-context view))
         (name (format nil "~A_causality" (sal-transition-view-theory-name view)))
         (origin (or (first (sal-causality-graph-origins graph))
                     (sal-transition-view-flat-module view)))
         (text
           (with-output-to-string (out)
             (format out "% Structural DEFINITION causality for ~A.~%"
                     (sal-transition-view-module-name view))
             (format out "% Cyclic relational equations may still have solutions.~%")
             (format out "~A~A: THEORY~%BEGIN~%  IMPORTING ~A~%~%"
                     name (sal-pvs-view-formal-text view) (sal-pvs-view-instance view))
             (format out "  CausalNode: TYPE = {~A}~%~%"
                     (if (sal-causality-graph-vertices graph)
                         (sal-pvs-join
                          (mapcar #'sal-causality-node-name
                                  (sal-causality-graph-vertices graph)) ", ")
                         "causal_empty"))
             (dolist (edge (sal-causality-graph-edges graph))
               (format out "  % ~A depends on ~A.~%"
                       (sal-declaration-name (car edge))
                       (sal-declaration-name (cdr edge))))
             (format out "  dependency(x, y: CausalNode): bool = ~A~%~%"
                     (sal-pvs-infix
                      "OR"
                      (mapcar (lambda (edge)
                                (format nil "(x = ~A AND y = ~A)"
                                        (sal-causality-node-name (car edge))
                                        (sal-causality-node-name (cdr edge))))
                              (sal-causality-graph-edges graph))
                      "FALSE"))
             (format out "  causality: THEORY = SAL_Causality_Contract{{~%    Node := CausalNode, dependency := dependency }}~%END ~A~%" name))))
    (setf (sal-transition-view-causality-theory-name view) name
          (gethash "causality" (sal-transition-view-origins view)) origin)
    text))

(defun sal-elaborate-causality (view output-directory)
  "Write the optional causality companion within the bridge output boundary."
  (let* ((text (sal-pvs-render-causality-view view))
         (directory (sal-prepare-output-directory output-directory))
         (file (sal-bridge-output-path
                (merge-pathnames
                 (format nil "~A.pvs" (sal-transition-view-causality-theory-name view))
                 directory))))
    (sal-write-file-if-changed file text)
    (setf (sal-transition-view-causality-pvs-file view) file)
    view))

(export '(sal-causality-graph sal-causality-graph-vertices
          sal-causality-graph-edges sal-causality-graph-origins
          sal-definition-causality-graph sal-pvs-render-causality-view
          sal-elaborate-causality))
