;;; PVS-origin extraction and proof admission.  The compiler is trusted;
;;; reconstruction of SAL proof evidence is deliberately a separate project.
(in-package :pvs)

(defstruct sal-pvs-extraction
  theory declaration state-type initial step property declarations metadata
  source source-text target)

(defvar *sal-pvs-extractions* (make-hash-table :test #'equal))

(defun sal-pvs-native-prelude-theory-p (theory)
  (eq theory (gethash (id theory) *prelude*)))

(defun sal-pvs-native-source-file (theory)
  "Prelude exemption requires identity, not a user theory with the same name."
  (unless (sal-pvs-native-prelude-theory-p theory)
    (let ((file (filename theory)) (directory (context-path theory)))
      (unless (and file directory)
        (error "Cannot capture native PVS source for ~a" (id theory)))
      (or (probe-file (merge-pathnames (make-pathname :name file :type "pvs")
                                       (uiop:ensure-directory-pathname directory)))
          (error "Native PVS source unavailable: ~a" (id theory))))))

(defun sal-pvs-source-theories (theory declarations)
  "Conservative native source/TCC closure, never a semantic instantiation API."
  (remove-duplicates
   (loop for root in (remove-duplicates
                     (cons theory (remove nil (mapcar #'module declarations)))
                     :test #'eq)
         append (cons root (all-importings root)))
   :test #'eq))

(defun sal-pvs-source-snapshots (theories)
  (dolist (theory theories)
    (unless (or (sal-pvs-native-prelude-theory-p theory)
                (and (typechecked? theory) (parsed? theory)))
      (error "PVS source is not currently typechecked: ~a. Typecheck it before extraction."
             (id theory)))
    ;; Some PVS versions retain a content digest in the native context entry;
    ;; others clear it on save-context. Use it when present, without replacing
    ;; native freshness checks or requiring an unavailable receipt on replay.
    (unless (sal-pvs-native-prelude-theory-p theory)
      (let* ((entry (get-context-file-entry theory))
             (digest (and entry (ce-md5sum entry))))
        (when (and (integerp digest) (plusp digest)
                   (/= digest (md5-file (sal-pvs-native-source-file theory))))
          (error "PVS source content differs from its typechecked context: ~a. Typecheck it before extraction."
                 (id theory))))))
  (let* ((files (remove nil (mapcar #'sal-pvs-native-source-file theories)))
         (canonical (sal-check-library-sources files))
         (configuration (sal-user-configuration-path)))
    (mapcar #'sal-file-snapshot
            (remove-duplicates
             (append files canonical (and configuration (list configuration)))
             :test #'equal))))

(defun sal-extract-pvs (theory-name theorem-name &key output-directory)
  "Extract a typed native PVS invariant into a finite, shallow SAL machine.

THEOREM-NAME must be the actual invariant declaration of a concrete instance
of SAL_Transition_System (possibly through SAL_Transition_View interpretations).
The transition relation and property are derived from its typed AST, not supplied
by the caller. This does not typecheck or modify the original PVS development.
Native TCCs stay in that development and must be complete before proof closure.
All output is restricted to src/sal. Re-extract before replay in a fresh process."
  (let* ((theory (if (typep theory-name 'module) theory-name (get-theory theory-name)))
         (declaration
          (and theory
               (find-if (lambda (decl)
                          (and (formula-decl? decl)
                               (string= (string theorem-name) (string (id decl)))))
                        (theory theory))))
         (target-id (and declaration (format nil "~a.~a" (id theory) (id declaration)))))
    (unless (and theory declaration (typechecked? theory) (typechecked? declaration)
                 (eq (module declaration) theory))
      (error "Expected an already typechecked PVS theorem: ~a.~a" theory-name theorem-name))
    ;; A failed refresh must not leave an earlier target silently registered.
    (remhash target-id *sal-proof-targets*)
    (remhash target-id *sal-pvs-extractions*)
    (when (or (formals-sans-usings theory) (formals declaration) (decl-formals declaration))
      (error "PVS extraction requires a closed concrete theorem, not a generic declaration."))
    (let ((*current-context* (context declaration)) (*generate-tccs* 'none))
      (let* ((initial-theories (sal-pvs-source-theories theory nil))
             (initial-snapshots (sal-pvs-source-snapshots initial-theories)))
        (multiple-value-bind (state initial step property wrappers)
            (sal-pvs-invariant-components declaration)
          (multiple-value-bind (text used metadata)
              (sal-pvs-to-sal-render state initial step property :context-name "pvs_machine")
            (unless (getf metadata :finite-p)
              (error "The PVS-to-SAL compiler did not establish a finite exact fragment."))
            (let* ((declarations
                    (remove-duplicates
                     (mapcan #'sal-pvs-original-declarations (append wrappers used))
                     :test #'eq))
                   (theories (sal-pvs-source-theories theory declarations))
                   (snapshots (sal-pvs-source-snapshots theories))
                   (directory
                    (sal-bridge-output-path
                     (uiop:ensure-directory-pathname
                      (or output-directory
                          (merge-pathnames
                           (format nil ".work/reverse/~a/~a/"
                                   (sal-pvs-name target-id)
                                   (sal-pvs-name
                                    (sal-text-fingerprint
                                     (namestring (sal-pvs-native-source-file theory)))))
                           *sal-bridge-directory*)))))
                   (source (merge-pathnames
                            (format nil "~a.sal" (getf metadata :context-name)) directory))
                   (tccs (remove-duplicates
                          (loop for th in theories unless (sal-pvs-native-prelude-theory-p th)
                                append (collect-tccs th)) :test #'eq)))
              (unless (sal-snapshots-current-p initial-snapshots)
                (error "PVS source changed during extraction; typecheck and extract again."))
              (sal-write-file-if-changed source text)
              ;; Native SAL accepts the emitted source before it can become a
              ;; prover target. This is a syntax/WFC check, not a proof of it.
              (sal-view-read-xml (sal-export-call source "--source"))
              (unless (and (sal-snapshots-current-p snapshots)
                           (string= text (uiop:read-file-string source)))
                (error "PVS/SAL source changed during extraction."))
              (ensure-closed-definition declaration)
              (let* ((target
                      (make-sal-proof-target
                       :id target-id :theory theory :declaration declaration
                       :formula (closed-definition declaration)
                       :source source :assertion (getf metadata :assertion-name)
                       :module (getf metadata :module-name) :kind :pvs-invariant
                       :snapshots (cons (sal-file-snapshot source) snapshots)
                       :tccs tccs :proof-dependencies declarations))
                     (extraction
                      (make-sal-pvs-extraction
                       :theory theory :declaration declaration :state-type state
                       :initial initial :step step :property property
                       :declarations declarations :metadata metadata
                       :source source :source-text text :target target)))
                (setf (gethash target-id *sal-proof-targets*) target
                      (gethash target-id *sal-pvs-extractions*) extraction)
                extraction))))))))

(defun sal-show-pvs-extraction (extraction &optional (stream *standard-output*))
  "Display the native origin, emitted SAL, and outstanding native obligations."
  (let ((target (sal-pvs-extraction-target extraction)))
    (format stream "~&PVS theorem: ~a (~a)~%SAL machine: ~a~%"
            (sal-proof-target-id target)
            (sal-pvs-native-source-file (sal-pvs-extraction-theory extraction))
            (sal-pvs-extraction-source extraction))
    (format stream "~a~%" (sal-pvs-extraction-source-text extraction))
    (dolist (tcc (sal-proof-target-tccs target))
      (format stream "~&~a.~a [~a] ~a~%  ~a~%"
              (id (module tcc)) (id tcc) (proof-status tcc)
              (sal-pvs-native-source-file (module tcc)) (definition tcc)))
    (format stream "~&~d native TCC(s) still require complete proofs.~%"
            (length (sal-target-unfinished-tccs target)))))

(addrule 'sal-check-pvs (target) ((backend :smc) (depth 10))
  (lambda (proofstate)
    (let ((registered (gethash (sal-proof-target-key target) *sal-proof-targets*)))
      (if (and registered (eq (sal-proof-target-kind registered) :pvs-invariant))
          (funcall (sal-check-rule target backend depth) proofstate)
          (progn
            (commentary "SAL: extract this native PVS invariant with sal-extract-pvs first.")
            (values 'X nil nil)))))
  "Check the original singleton PVS invariant through its extracted finite SAL
machine. Refuses stale sources, incomplete native TCCs, changed goals, and
unsupported fragments. :smc is exhaustive; :bmc requests induction. The compiler
and checker are trusted; proof evidence reconstruction is future work."
  "Checking extracted PVS invariant ~a")

(export '(sal-extract-pvs sal-show-pvs-extraction sal-check-pvs
          sal-pvs-extraction sal-pvs-extraction-source sal-pvs-extraction-source-text
          sal-pvs-extraction-target sal-pvs-extraction-declarations
          sal-pvs-extraction-metadata sal-pvs-extraction-state-type
          sal-pvs-extraction-initial sal-pvs-extraction-step sal-pvs-extraction-property))
