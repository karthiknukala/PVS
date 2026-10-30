;;; Shared transition-system view and source provenance.  No PVS core changes.
(in-package :pvs)

(defvar *sal-bridge-directory*
  (uiop:pathname-directory-pathname (or *load-truename* *compile-file-truename*)))

(defstruct sal-transition-view
  source source-text source-snapshots context module-name flat-module properties property-origins
  contexts context-pvs-files context-pvs-texts module-parameters root-actuals
  instantiated-p selector module-actuals module-checks dependency-files
  backend-admission-note
  theory-name pvs-file pvs-text progress-theory-name progress-pvs-file
  causality-theory-name causality-pvs-file
  (origins (make-hash-table :test #'equal))
  tccs)

(defstruct sal-source-obligation
  name kind status formula declaration source place source-expression)

(defstruct sal-module-check context scope name expression)

(defvar *sal-transition-views* (make-hash-table :test #'equal))

(defun sal-bridge-output-path (path)
  "Resolve PATH and reject writes outside this extension, including symlinks."
  (let* ((root (truename *sal-bridge-directory*))
         (absolute (merge-pathnames path (uiop:getcwd)))
         (parent (uiop:pathname-directory-pathname absolute)))
    (when (or (wild-pathname-p absolute)
              (intersection '(:up :back) (pathname-directory absolute)))
      (error "SAL bridge output paths cannot contain parent traversal or wildcards: ~a" path))
    (labels ((resolved (p)
               (or (probe-file p)
                   (let ((up (uiop:pathname-parent-directory-pathname p)))
                     (unless (and up (not (equal up p)))
                       (error "Cannot resolve output path ~a" path))
                     (merge-pathnames (enough-namestring p up) (resolved up))))))
      (let* ((resolved-parent (resolved parent))
             (target (or (probe-file absolute)
                         (merge-pathnames (file-namestring absolute)
                                          resolved-parent))))
        (unless (uiop:subpathp target root)
          (error "SAL bridge output must stay under ~a: ~a" root path))
        target))))

(defun sal-write-file-if-changed (file text)
  "Avoid invalidating PVS import caches when elaboration is unchanged."
  (let ((path (sal-bridge-output-path file)))
    (unless (and (probe-file path) (string= text (uiop:read-file-string path)))
      (ensure-directories-exist path)
      (with-open-file (out path :direction :output :if-exists :supersede
                               :if-does-not-exist :create)
        (write-string text out)))
    path))

(defun sal-prepare-output-directory (directory)
  "Create an extension-local context and install the small semantic library."
  (let ((dir (sal-bridge-output-path (uiop:ensure-directory-pathname directory))))
    (ensure-directories-exist (merge-pathnames "placeholder" dir))
    (dolist (name '("SAL_Transition_System.pvs" "SAL_Transition_View.pvs" "SAL_Progress_Contract.pvs" "SAL_CTL.pvs"
                   "SAL_Causality_Contract.pvs"))
      (let ((from (merge-pathnames (concatenate 'string "theories/" name)
                                  *sal-bridge-directory*))
            (to (merge-pathnames name dir)))
        (when (and (probe-file from) (not (equal (namestring from) (namestring to))))
          (sal-write-file-if-changed to (uiop:read-file-string from)))))
    dir))

(defun sal-origin-source-file (view ast)
  "Use the actual declaring SAL context, including imported source files."
  (or (and (typep ast 'sal-ast) (sal-source-place-p (place ast))
           (sal-source-place-source-file (place ast)))
      (and (typep ast 'sal-ast)
           (let ((ctx (if (typep ast 'sal-context) ast (context ast))))
             (and (typep ctx 'sal-context) (file-name ctx))))
      (sal-transition-view-source view)))

(defun sal-view-source-location (view ast)
  (let ((p (and (typep ast 'sal-ast) (place ast))))
    (format nil "~a~@[:~d~]~@[:~d~]"
            (sal-origin-source-file view ast)
            (and (sal-source-place-p p) (sal-source-place-initial-line p))
            (and (sal-source-place-p p) (sal-source-place-initial-column p)))))

(defun sal-view-origin (view generated-name &optional theory-name)
  "Resolve a generated declaration/TCC to its longest matching source name."
  (let ((name (if theory-name
                  (format nil "~a::~a" theory-name generated-name)
                  (string generated-name)))
        (best nil) (length -1))
    (maphash
     (lambda (key ast)
       (when (and (> (length key) length)
                  (or (string= key name)
                      (and (< (length key) (length name))
                           (string= key name :end2 (length key))
                           (char= (char name (length key)) #\_))))
         (setf best ast length (length key))))
     (sal-transition-view-origins view))
    (or best (and theory-name (sal-view-origin view generated-name)))))

(export '(sal-transition-view make-sal-transition-view
          sal-transition-view-source sal-transition-view-source-text
          sal-transition-view-context sal-transition-view-module-name
          sal-transition-view-contexts sal-transition-view-context-pvs-files
          sal-transition-view-module-parameters sal-transition-view-root-actuals
          sal-transition-view-module-checks
          sal-transition-view-instantiated-p sal-transition-view-selector
          sal-transition-view-dependency-files sal-transition-view-source-snapshots
          sal-transition-view-backend-admission-note
          sal-transition-view-flat-module sal-transition-view-properties
          sal-transition-view-property-origins sal-transition-view-theory-name
          sal-transition-view-pvs-file sal-transition-view-origins
          sal-transition-view-pvs-text sal-transition-view-causality-theory-name
          sal-transition-view-causality-pvs-file
          sal-transition-view-progress-theory-name sal-transition-view-progress-pvs-file
          sal-transition-view-tccs sal-source-obligation
          sal-bridge-output-path sal-prepare-output-directory))
