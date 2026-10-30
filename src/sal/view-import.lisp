;;; view-import.lisp -- Import native SAL normalization into a shared PVS view.
(in-package :pvs)

(defparameter *sal-view-export-program*
  (merge-pathnames "tools/sal-view-export.sh"
                   (uiop:pathname-directory-pathname
                    (or *load-truename* *compile-file-truename*))))

(defun sal-view-xml-state (context)
  "Seed a new expression reader with CONTEXT's resolved declarations."
  (let ((state (%make-sal-xml-state :context context)))
    (dolist (pair (list (cons :value (constant-declarations context))
                       (cons :type (type-declarations context))
                       (cons :module (module-declarations context))
                       (cons :assertion (assertion-declarations context))
                       (cons :context (context-name-declarations context))))
      (maphash (lambda (name declaration)
                 (declare (ignore name))
                 (sal-state-bind-top state (car pair) declaration))
               (cdr pair)))
    (dolist (parameter (params context))
      (sal-state-bind-top state
                          (if (typep parameter 'sal-type-param-decl) :type :value)
                          parameter))
    state))

(defun sal-view-check-source-profile (context)
  "Every non-prelude reference must resolve to an exported source context."
  (sal-walk-ast
   (lambda (node)
     (when (or (typep node 'sal-qualified-name-ref)
               (typep node 'sal-context-name-decl))
       (let ((reference (context-ref node)))
         (when (and reference
                    (not (string= (sal-declaration-name reference) "prelude"))
                    (not (file-name reference)))
           (error "SAL dependency is missing from the export closure: ~a"
                  (sal-declaration-name reference))))))
   context)
  context)

(defun sal-view-read-xml (xml)
  (with-input-from-string (stream xml) (xmls:parse stream :quash-errors nil)))

(defun sal-view-ordered-sources (entries)
  "Order (FILE . CONTEXT-XML) entries by source references, including the root.
A selector-only actual context can itself depend on the selected root context;
the envelope's SOURCE element need not be the last item in dependency order."
  (let ((by-name (make-hash-table :test #'equal))
        (marks (make-hash-table :test #'equal))
        (ordered nil))
    (dolist (entry entries)
      (let ((name (sal-xml-text (first (sal-xml-elements (cdr entry))))))
        (when (gethash name by-name)
          (error "Duplicate SAL source context in export closure: ~a" name))
        (setf (gethash name by-name) entry)))
    (labels ((visit (name)
               (case (gethash name marks)
                 (:complete (return-from visit nil))
                 (:active (error "Cyclic SAL context dependency: ~a" name)))
               (let ((entry (gethash name by-name)))
                 (when entry
                   (setf (gethash name marks) :active)
                   (let ((pending (list (cdr entry))))
                     (loop while pending for node = (pop pending) do
                       (when (string-equal (xmls:node-name node) "CONTEXTNAME")
                         (let ((dependency (sal-xml-text (first (sal-xml-elements node)))))
                           (unless (string= dependency name) (visit dependency))))
                       (setf pending (append (sal-xml-elements node) pending))))
                   (setf (gethash name marks) :complete)
                   (push entry ordered)))))
      (dolist (entry entries)
        (visit (sal-xml-text (first (sal-xml-elements (cdr entry)))))))
    (nreverse ordered)))

(defun sal-view-parse-xml (xml source source-text)
  "Decode source contexts and normalized relations without losing instances."
  (let* ((root (sal-view-read-xml xml))
         (version (sal-xml-attribute root "VERSION"))
         (_ (unless (and (string-equal (xmls:node-name root) "SALVIEW")
                         (member version '("1" "2") :test #'equal))
              (sal-xml-fail root "Expected SALVIEW version 1 or 2")))
         (known (make-hash-table :test #'equal))
         (contexts nil)
         (context nil)
         (dependencies (sal-xml-child root "DEPENDENCIES"))
         (source-node (sal-xml-child root "SOURCE" t))
         (root-context-xml (first (sal-xml-elements source-node)))
         (entries (list (cons (namestring source) root-context-xml))))
    (declare (ignore _))
    (dolist (entry (and dependencies (sal-xml-elements dependencies)))
      (let ((file (sal-xml-attribute entry "FILE")))
        (unless file (sal-xml-fail entry "Dependency has no source file"))
        (push (cons file (first (sal-xml-elements entry))) entries)))
    (dolist (entry (sal-view-ordered-sources (nreverse entries)))
      (let ((converted (sal-convert-context (cdr entry) (car entry) :contexts known)))
        (push converted contexts)
        (when (eq (cdr entry) root-context-xml) (setf context converted))))
    (let* ((state (sal-view-xml-state context))
           (flat-node (sal-xml-child root "FLATMODULE"))
           (parameter-node (sal-xml-child root "MODULEPARAMETERS"))
           (parameter-nodes (and parameter-node (sal-xml-elements parameter-node)))
           (actuals-node (sal-xml-child root "ROOTACTUALS")))
      (setf contexts (nreverse contexts)
            (sal-xml-state-external-contexts state) known)
      (mapc #'sal-view-check-source-profile contexts)
      (multiple-value-bind (parameters parameter-scope)
          (sal-predeclare-locals state parameter-nodes 'sal-var-decl)
        (sal-call-with-scope
         state parameter-scope
         (lambda ()
           (sal-populate-local-types state parameter-nodes parameters)
           (let* ((var-nodes (and flat-node (sal-xml-elements
                                            (sal-xml-child flat-node "STATEVARS" t))))
                  (state-vars (mapcar (lambda (node) (sal-make-state-var state node)) var-nodes))
                  (scope (make-hash-table :test #'equal))
                  (root-actuals (and actuals-node
                                     (mapcar (lambda (node) (sal-convert-actual state node))
                                             (sal-xml-elements actuals-node)))))
             (dolist (declaration state-vars) (sal-scope-bind scope :value declaration))
             (sal-call-with-scope
              state scope
              (lambda ()
                (loop for node in var-nodes for declaration in state-vars
                      do (sal-populate-state-var state node declaration))
                (flet ((section (name)
                         (let ((node (sal-xml-child flat-node name t)))
                           (unless (= 1 (length (sal-xml-elements node)))
                             (sal-xml-fail node "Expected exactly one expression"))
                           (sal-convert-expression state (first (sal-xml-elements node))))))
                  (let* ((flat (and flat-node
                                    (sal-set-module-interface
                                     (sal-node 'sal-flat-module state flat-node
                                               :definition (section "DEFINITION")
                                               :initialization (section "INITIALIZATION")
                                               :transition (section "TRANSITION")
                                               :skip (section "SKIP") :choice-vars nil)
                                     state-vars)))
                         (properties-node (sal-xml-child root "PROPERTIES"))
                         (properties
                          (mapcar
                           (lambda (node)
                             (let ((name (sal-xml-attribute node "NAME")))
                               (unless (and name (string-equal (xmls:node-name node) "PROPERTY")
                                            (= 1 (length (sal-xml-elements node))))
                                 (sal-xml-fail node "Malformed property"))
                               (cons name (sal-convert-expression state (first (sal-xml-elements node))))))
                           (and properties-node (sal-xml-elements properties-node)))))
                    (make-sal-transition-view
                     :source source :source-text source-text :context context :contexts contexts
                     :module-name (sal-xml-attribute root "MODULE")
                     :selector (sal-xml-attribute root "SELECTOR")
                     :instantiated-p (equal (sal-xml-attribute root "INSTANTIATED") "true")
                     :root-actuals root-actuals :module-parameters parameters
                     :flat-module flat :properties properties
                     :module-checks (sal-view-read-module-checks root state known)
                     :dependency-files (mapcar #'file-name contexts)
                     :property-origins
                     (mapcar (lambda (entry)
                               (cons (car entry) (gethash (car entry) (assertion-declarations context))))
                             properties)))))))))))))

(defun sal-view-read-module-checks (root selected-state contexts)
  "Import independent source module actual checks before flattening erases them."
  (let ((section (sal-xml-child root "MODULECHECKS")))
    (mapcar
     (lambda (entry)
       (let* ((owner-name (sal-xml-attribute entry "CONTEXT"))
              (owner (and owner-name (gethash owner-name contexts)))
              (scope (sal-xml-attribute entry "SCOPE"))
              (children (sal-xml-elements entry)))
         (unless (and (string-equal (xmls:node-name entry) "MODULECHECK")
                      owner (member scope '("context" "view") :test #'string=)
                      (= 1 (length children)))
           (sal-xml-fail entry "Malformed native module argument check"))
         (let* ((state (if (string= scope "view") selected-state
                          (sal-view-xml-state owner)))
                (expression
                  (progn
                    (setf (sal-xml-state-external-contexts state) contexts)
                    (sal-convert-expression state (first children)))))
           (when (sal-source-place-from-xml entry)
             (setf (place expression) (sal-source-place-from-xml entry)))
           (make-sal-module-check :context owner :scope scope
                                  :name (sal-xml-attribute entry "NAME")
                                  :expression expression))))
     (and section (sal-xml-elements section)))))

(defun sal-export-call (path target &optional selector)
  (multiple-value-bind (xml diagnostics status)
      (uiop:run-program
       (append (list (namestring *sal-view-export-program*) (namestring path) target)
               (and selector (list selector)))
       :directory (sal-backend-work-directory)
       :output :string :error-output :string :ignore-error-status t)
    (unless (zerop status)
      (error "SAL view export failed (~d):~%~a~%~a" status diagnostics xml))
    xml))

(defun sal-manifest-files (xml)
  (let ((root (sal-view-read-xml xml)))
    (unless (string-equal (xmls:node-name root) "SALMANIFEST")
      (sal-xml-fail root "Expected SALMANIFEST dependency inventory"))
    (mapcar (lambda (entry)
              (or (probe-file (or (sal-xml-attribute entry "PATH")
                                  (sal-xml-attribute entry "FILE")
                                  (sal-xml-fail entry "Dependency has no path")))
                  (sal-xml-fail entry "Dependency source does not exist")))
            (sal-xml-elements root))))

(defun sal-import-transition-view (source module-name &key selector)
  "Import generic or instantiated SAL with a complete stable dependency closure.
The first SAL pass discovers files. Snapshots surround the second semantic
export; any changed or newly discovered dependency rejects that export."
  (let* ((path (or (probe-file source) (error "SAL source not found: ~a" source)))
         (files (sal-manifest-files (sal-export-call path "--manifest" selector)))
         (configuration (sal-user-configuration-path))
         (snapshots (mapcar #'sal-file-snapshot
                            (remove-duplicates (append (list path) files
                                                       (and configuration (list configuration)))
                                               :test #'equal)))
         (source-text (cdr (assoc (namestring path) snapshots :test #'string=)))
         (xml (sal-export-call path module-name selector)))
    (unless (sal-snapshots-current-p snapshots)
      (error "SAL source, dependency, or configuration changed during export"))
    (let ((view (sal-view-parse-xml xml path source-text)))
      (dolist (file (sal-transition-view-dependency-files view))
        (unless (member (truename file) files :test #'equal)
          (error "SAL dependency closure changed while exporting: ~a" file)))
      (setf (sal-transition-view-source-snapshots view) snapshots
            (sal-transition-view-selector view) selector)
      view)))

(export '(sal-import-transition-view sal-view-parse-xml *sal-view-export-program*))
