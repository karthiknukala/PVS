;;; User-facing entry points. All generated contexts stay in this extension.
(in-package :pvs)
(defvar *sal-syntax-mode* nil)

(defun sal-view-key (view)
  (format nil "~a::~a::~a" (sal-transition-view-source view)
          (sal-transition-view-module-name view) (sal-transition-view-selector view)))

(defun sal-obligation-source-text (ast)
  (when ast (handler-case (sal-pp-to-string ast) (error () nil))))

(defun sal-collect-source-obligations (view theory)
  "Attach SAL origins to native PVS TCCs; retain the actual prover formulas."
  (mapcar
   (lambda (tcc)
     (let* ((name (string (id tcc)))
            (ast (or (sal-view-origin view name (id theory))
                     (and (generated-by tcc)
                          (sal-view-origin view (id (generated-by tcc)) (id theory)))))
            (origin (origin tcc)))
       (make-sal-source-obligation
        :name name :kind (and origin (kind origin))
        :status (proof-status tcc) :formula (str (definition tcc))
        :declaration tcc :source (sal-origin-source-file view ast)
        :place (and (typep ast 'sal-ast) (place ast))
        :source-expression (sal-obligation-source-text ast))))
   (collect-tccs theory)))

(defun sal-typecheck-view (view &key (progress-checks t) (causality-checks nil) (register t))
  "Typecheck in the generated context, collect native TCCs, register properties.
This generates obligations; it does not discharge or assume them."
  (unless (equal *sal-wfc-source* (sal-file-snapshot (sal-transition-view-source view)))
    (sal-check-well-formed (sal-transition-view-source view)))
  (let* ((file (sal-transition-view-pvs-file view))
         (directory (uiop:pathname-directory-pathname file)))
    (sal-bridge-output-path directory)
    (change-context (namestring directory))
    (dolist (context-file (sal-transition-view-context-pvs-files view))
      (typecheck-file (pathname-name context-file) nil nil nil))
    (typecheck-file (pathname-name file) nil nil nil)
    (let ((theory (get-typechecked-theory (sal-transition-view-theory-name view))))
      (unless (and theory (typechecked? theory))
        (error "Generated SAL theory did not typecheck: ~a" file))
      (setf (sal-transition-view-tccs view)
            (loop for th in
                  (remove-duplicates
                   (cons theory (mapcar (lambda (path) (get-typechecked-theory (pathname-name path)))
                                        (sal-transition-view-context-pvs-files view))) :test #'eq)
                  append (sal-collect-source-obligations view th)))
      (when (and progress-checks (sal-transition-view-progress-pvs-file view))
        (typecheck-file (pathname-name (sal-transition-view-progress-pvs-file view))
                        nil nil nil)
        (setf (sal-transition-view-tccs view)
              (append (sal-transition-view-tccs view)
                      (sal-collect-source-obligations
                       view (get-typechecked-theory
                             (sal-transition-view-progress-theory-name view))))))
      (setf (sal-transition-view-backend-admission-note view)
            (if (formals-sans-usings theory)
                "Generic SAL theories need concrete actual parameters before model checking."
                (sal-view-backend-refusal view)))
      (when (and register (sal-transition-view-backend-admission-note view))
        (format t "~&SAL checker registration deferred: ~a~%"
                (sal-transition-view-backend-admission-note view)))
      (when (and register (not (sal-transition-view-backend-admission-note view)))
        (dolist (property (sal-transition-view-properties view))
          (when (and (typep (cdr property) 'sal-ltl-g)
                     (not (sal-pvs-temporal-p
                           (first (sal-application-arguments (cdr property))))))
            (sal-register-proof-target
           (format nil "~a.~a" (sal-transition-view-theory-name view) (car property))
           (sal-transition-view-theory-name view) (sal-pvs-name (car property))
           (sal-transition-view-source view) (car property)
           :view view :module (sal-transition-view-module-name view)
           :dependencies (sal-transition-view-dependency-files view)))))
      (when (and causality-checks (sal-transition-view-causality-pvs-file view))
        (typecheck-file (pathname-name (sal-transition-view-causality-pvs-file view))
                        nil nil nil)
        (setf (sal-transition-view-tccs view)
              (append (sal-transition-view-tccs view)
                      (sal-collect-source-obligations
                       view (get-typechecked-theory
                             (sal-transition-view-causality-theory-name view))))))
      view)))

(defun sal-selection-expression (source module-name context-actuals module-actuals)
  "Construct native SAL syntax from explicit actual-argument strings."
  (unless (every #'stringp (append context-actuals module-actuals))
    (error "SAL actual arguments must be SAL expression/type strings"))
  (let* ((path (truename source))
         (manifest (sal-view-read-xml (sal-export-call path "--manifest")))
         (entry (find path (sal-xml-elements manifest)
                      :key (lambda (node) (truename (sal-xml-attribute node "PATH")))
                      :test #'equal))
         (context-name (and entry (sal-xml-attribute entry "NAME"))))
    (unless context-name (error "SAL manifest omitted the root context name"))
    (format nil "~a~a!~a~a" context-name
            (if context-actuals (format nil "{~{~a~^, ~}}" context-actuals) "") module-name
            (if module-actuals (format nil "[~{~a~^, ~}]" module-actuals) ""))))

(defun sal-open (source module-name &key output-directory (typecheck t)
                                        (progress-checks t) (causality-checks nil)
                                        (register t) selector context-actuals module-actuals)
  "Import a symbolic or concretely instantiated SAL module and its dependencies.
OUTPUT-DIRECTORY defaults to an isolated directory under src/sal/.work."
  (when (and selector (or context-actuals module-actuals))
    (error "Use either :selector or explicit context/module actuals"))
  ;; This must precede selector resolution and every native export call.
  (when typecheck (sal-check-well-formed source))
  (let* ((*sal-wfc-source* (and typecheck (sal-file-snapshot source)))
         (selection (or selector
                        (and (or context-actuals module-actuals)
                             (sal-selection-expression source module-name context-actuals module-actuals))))
         (view (sal-import-transition-view source module-name :selector selection))
         (directory (or output-directory
                        (merge-pathnames
                         (format nil ".work/generated/~a/~a/~a/"
                                 (sal-pvs-name (pathname-name source))
                                 (sal-pvs-name
                                  (sal-text-fingerprint (sal-view-key view)))
                                 (sal-pvs-name module-name))
                         *sal-bridge-directory*))))
    (sal-elaborate-view view directory :progress-checks progress-checks)
    (when causality-checks (sal-elaborate-causality view directory))
    (when typecheck
      (sal-typecheck-view view :progress-checks progress-checks
                         :causality-checks causality-checks :register register))
    (setf (gethash (sal-view-key view) *sal-transition-views*) view)
    view))

(defun sal-open-context (source &rest options)
  "Translate a SAL library context, including its formal parameters/imports."
  (apply #'sal-open source "--context" :progress-checks nil :register nil options))

(defun sal-show-obligations (view &optional (stream *standard-output*))
  "Display origins and live native obligations, optionally in SAL syntax."
  (dolist (obligation (sal-transition-view-tccs view))
    (let ((p (sal-source-obligation-place obligation)))
      (format stream "~&~a~@[:~d~] ~a [~a; ~a]~%"
              (sal-source-obligation-source obligation)
              (and (sal-source-place-p p) (sal-source-place-initial-line p))
              (sal-source-obligation-name obligation)
              (sal-source-obligation-kind obligation)
              (proof-status (sal-source-obligation-declaration obligation)))
      (when (sal-source-obligation-source-expression obligation)
        (format stream "  SAL: ~a~%" (sal-source-obligation-source-expression obligation)))
      (if (and (boundp '*sal-syntax-mode*) *sal-syntax-mode*)
          (format stream "  SAL obligation: ~a~%"
                  (sal-display-formula (definition (sal-source-obligation-declaration obligation)) view))
          (format stream "  PVS: ~a~%" (sal-source-obligation-formula obligation)))))
  view)

(defun sal-show-source (view generated-name &optional (stream *standard-output*))
  "Recover the SAL origin of a generated theorem, definition, or TCC.
For imported declarations, use THEORY::DECLARATION to disambiguate names."
  (let ((ast (sal-view-origin view generated-name)))
    (unless ast (error "No SAL source origin for ~a" generated-name))
    (format stream "~&~a~%~a~%" (sal-view-source-location view ast)
            (or (sal-obligation-source-text ast) "[normalized SAL structure]"))
    ast))

(export '(sal-open sal-open-context sal-typecheck-view sal-show-obligations sal-show-source))
