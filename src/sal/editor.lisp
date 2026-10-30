;;; Data-only Emacs interface. The native PVS prover still owns proof state.
(in-package :pvs)
(defvar *sal-editor-view-tokens* (make-hash-table :test #'eq))

(defun sal-editor-view-token (view)
  (or (gethash view *sal-editor-view-tokens*)
      (setf (gethash view *sal-editor-view-tokens*) (string (gensym "SAL-VIEW-")))))

(defun sal-editor-view (key)
  (let ((view (or (gethash key *sal-transition-views*)
                  (error "SAL view is no longer loaded; typecheck the buffer again"))))
    (unless (sal-snapshots-current-p (sal-transition-view-source-snapshots view))
      (error "SAL source or dependencies changed; typecheck again before proving"))
    (unless (string= (sal-transition-view-pvs-text view)
                     (uiop:read-file-string (sal-transition-view-pvs-file view)))
      (error "Generated PVS source changed; typecheck the SAL buffer again"))
    (dolist (entry (sal-transition-view-context-pvs-texts view))
      (unless (and (probe-file (car entry))
                   (string= (cdr entry) (uiop:read-file-string (car entry))))
        (error "Generated PVS dependency changed; typecheck the SAL buffer again")))
    (change-context (namestring (uiop:pathname-directory-pathname (sal-transition-view-pvs-file view))))
    view))

(defun sal-editor-entry (view decl ast &optional source place obligation)
  ;; A context switch may reload declarations from PVS's binary context.
  (let* ((th (get-typechecked-theory (string (id (module decl)))))
         (decl (or (and th (find (id decl) (append (assuming th) (theory th))
                                 :key (lambda (d) (and (formula-decl? d) (id d)))))
                   (error "Typecheck the SAL buffer again to refresh declarations")))
         (p (or place (and (typep ast 'sal-ast) (place ast)))))
    (list :token (sal-editor-view-token view)
          :theory (string (id (module decl))) :name (string (id decl))
          :source-name (and (typep ast 'sal-decl) (sal-declaration-name ast))
          :source (namestring (or source (sal-origin-source-file view ast)))
          :line (if (sal-source-place-p p) (sal-source-place-initial-line p) 1)
          :end-line (if (sal-source-place-p p) (sal-source-place-final-line p) 1)
          :status (format nil "~a" (proof-status decl))
          :source-expression (and obligation (sal-source-obligation-source-expression obligation))
          :text (if *sal-syntax-mode*
                    (if obligation (sal-display-tcc-formula (definition decl) view)
                        (sal-display-formula (definition decl) view))
                    (str (definition decl))))))

(defun sal-editor-description (view)
  (let ((theory (get-typechecked-theory (sal-transition-view-theory-name view))))
    (list :key (sal-view-key view) :module (sal-transition-view-module-name view)
          :syntax (if *sal-syntax-mode* "SAL" "PVS")
          :wfc *sal-last-wfc-result*
          :formulas
          (loop for (name . ast) in (sal-transition-view-property-origins view)
                for decl = (find-if (lambda (d) (and (formula-decl? d)
                                                     (string= (string (id d)) (sal-pvs-name name))))
                                   (theory theory))
                when decl collect (sal-editor-entry view decl ast))
          :tccs (mapcar (lambda (o)
                         (sal-editor-entry view (sal-source-obligation-declaration o) nil
                                           (sal-source-obligation-source o)
                                           (sal-source-obligation-place o) o))
                       (sal-transition-view-tccs view)))))

(defun sal-editor-typecheck (source module)
  (when *in-checker* (error "Exit the PVS prover before typechecking SAL"))
  (sal-editor-description
   (if (string= module "--context") (sal-open-context source)
       (sal-open source module))))

(defun sal-editor-request (operation &rest arguments)
  "Return a printed data plist inside a string; never send executable Elisp."
  (let* ((log (make-string-output-stream))
         (answer
           (handler-case
               (let ((*standard-output* log))
                 (list :ok
                       (ecase operation
                         (:typecheck (apply #'sal-editor-typecheck arguments))
                         (:describe (sal-editor-description (sal-editor-view (first arguments))))
                         (:syntax (sal-set-syntax-mode (first arguments))
                                  (if *sal-syntax-mode* "SAL" "PVS")))))
             (error (e) (list :error (format nil "~a" e))))))
    (write-to-string (append answer (list :log (get-output-stream-string log)))
                     :case :downcase :pretty nil)))

(defun sal-editor-prove (key theory-name declaration-name buffer &optional token)
  "Start the real PVS proof, save with native machinery, then locate SAL."
  (when *in-checker* (error "Exit the current PVS prover first"))
  (let* ((view (sal-editor-view key))
         (directory (uiop:pathname-directory-pathname (sal-transition-view-pvs-file view))))
    (when (and token (not (equal token (sal-editor-view-token view))))
      (error "This SAL goal list is obsolete; refresh TCCs and select the goal again"))
    (change-context (namestring directory))
    (let* ((th (get-typechecked-theory theory-name))
           (decl (and th (find-if (lambda (d) (and (formula-decl? d)
                                                   (string= (string (id d)) declaration-name)))
                                 (append (assuming th) (theory th)))))
           (entries (sal-editor-description view))
           (entry (find-if (lambda (e) (and (string= theory-name (getf e :theory))
                                           (string= declaration-name (getf e :name))))
                          (append (getf entries :formulas) (getf entries :tccs)))))
      (unless (and decl (typechecked? decl) entry
                   (sal-display-view-for-declaration decl))
        (error "Not a current theorem/TCC belonging to this SAL view"))
      (unwind-protect
          ;; Native proof-status entry resolves the exact declaration name.
          ;; The ppe/tccs entry points select a line in a generated listing.
          (prove-file-at (filename th) declaration-name 1 nil "proof-status" buffer 0)
        (when *to-emacs*
          (let ((line (getf entry :line)))
            ;; With no theory directory, PVS's Emacs protocol expects a live
            ;; buffer name, not a pathname. The editor opens the source buffer.
            (pvs-locate buffer decl (vector line 0 line 0))))))))

(export '(sal-editor-typecheck sal-editor-request sal-editor-prove))
