;;; sal-pvs-mode.el --- Experimental SAL frontend for PVS -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'button)

(defgroup sal-pvs nil "SAL source buffers backed by PVS." :group 'languages)
(defcustom sal-pvs-bridge-directory
  (file-name-directory (directory-file-name
                        (file-name-directory (or load-file-name buffer-file-name))))
  "Directory containing the optional bridge's load.lisp."
  :type 'directory :group 'sal-pvs)
(defcustom sal-pvs-syntax-enabled t
  "Use SAL display for SAL-origin proofs/TCCs; commands remain PVS."
  :type 'boolean :group 'sal-pvs)
(defvar-local sal-pvs-module nil)
(defvar-local sal-pvs--description nil)
(defvar-local sal-pvs--source-buffer nil)
(defvar-local sal-pvs--source-file nil)

(declare-function pvs-send-and-wait "pvs-ilisp" (string &optional message status expected))
(declare-function pvs-send "pvs-ilisp" (string &optional message status))
(declare-function confirm-not-in-checker "pvs-cmds" ())
(declare-function ilisp-send "ilisp-snd" (string &optional message status and-go handler))

(defun sal-pvs--literal (value)
  "Encode data for Common Lisp without interpolating executable source."
  (let ((print-escape-newlines nil) (print-escape-nonascii nil))
    (prin1-to-string value)))

(defun sal-pvs--connect (&optional in-proof)
  (unless (fboundp 'pvs-send-and-wait)
    (user-error "Start PVS in Emacs before using the SAL frontend"))
  (when (and (not in-proof) (fboundp 'confirm-not-in-checker)) (confirm-not-in-checker))
  (let ((file (expand-file-name "load.lisp" sal-pvs-bridge-directory)))
    (pvs-send-and-wait
     (format "(progn (unless (fboundp 'pvs::sal-editor-request) (load %s)) t)"
             (sal-pvs--literal file)) nil nil)))

(defun sal-pvs--request (op &rest args)
  (let* ((wire (pvs-send-and-wait
                (format "(pvs::sal-editor-request %s%s)" op
                        (mapconcat (lambda (x) (concat " " (sal-pvs--literal x))) args ""))
                "SAL/PVS" nil))
         (response (and (stringp wire) (car (read-from-string wire)))))
    (unless (and (listp response) (or (plist-member response :ok)
                                     (plist-member response :error)))
      (error "No valid response from the SAL/PVS bridge"))
    (when (plist-get response :error)
      (with-current-buffer (get-buffer-create "*SAL/PVS Diagnostics*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (plist-get response :error) "\n" (or (plist-get response :log) ""))
          (special-mode)))
      (display-buffer "*SAL/PVS Diagnostics*")
      (user-error "%s" (plist-get response :error)))
    (plist-get response :ok)))

(defun sal-pvs--modules ()
  (save-excursion
    (goto-char (point-min))
    (let ((case-fold-search t) names)
      (while (re-search-forward "\\_<\\([A-Za-z][A-Za-z0-9_]*\\)\\s-*\\(?:\\[[^]]*\\]\\s-*\\)?:\\s-*MODULE\\_>" nil t)
        (let ((name (match-string-no-properties 1)) (start (match-beginning 0)))
          (unless (save-excursion (save-match-data (nth 8 (syntax-ppss start))))
            (push name names))))
      (append (nreverse names) '("--context")))))

(defun sal-pvs-typecheck (&optional select)
  "Save, run sal-wfc, translate, then generate PVS TCCs. SELECT changes module."
  (interactive "P")
  (unless (and buffer-file-name (string-equal (file-name-extension buffer-file-name) "sal"))
    (user-error "Visit a SAL source file first"))
  (sal-pvs--connect)
  (save-buffer)
  (setq sal-pvs--description nil)
  (when (or select (null sal-pvs-module))
    (setq sal-pvs-module (completing-read "SAL module: " (sal-pvs--modules) nil nil
                                         nil nil sal-pvs-module)))
  (sal-pvs--request :syntax sal-pvs-syntax-enabled)
  (setq sal-pvs--description (sal-pvs--request :typecheck (file-truename buffer-file-name)
                                             sal-pvs-module))
  (message "SAL/PVS: sal-wfc passed; %d source TCCs, %d formulas"
           (length (plist-get sal-pvs--description :tccs))
           (length (plist-get sal-pvs--description :formulas)))
  sal-pvs--description)

(defun sal-pvs--ensure-current ()
  (if (or (buffer-modified-p) (null sal-pvs--description))
      (sal-pvs-typecheck)
    (setq sal-pvs--description
          (sal-pvs--request :describe (plist-get sal-pvs--description :key)))))

(defun sal-pvs--prove-entry (source entry)
  (unless (buffer-live-p source) (user-error "The SAL source buffer was closed"))
  (with-current-buffer source
    (sal-pvs--connect)
    (when (buffer-modified-p) (user-error "SAL buffer changed; typecheck and select the goal again"))
    (sal-pvs--ensure-current)
    (let ((target (find-file-noselect (plist-get entry :source))))
      (when (buffer-modified-p target)
        (user-error "SAL obligation source changed; save and typecheck before proving"))
      ;; Match native pvs-prove-formula: AND-GO t inserts output and
      ;; opens the prover buffer. pvs-send uses a silent dispatch request.
      (ilisp-send
       (format "(pvs::sal-editor-prove %s %s %s %s %s)"
               (sal-pvs--literal (plist-get sal-pvs--description :key))
               (sal-pvs--literal (plist-get entry :theory))
               (sal-pvs--literal (plist-get entry :name))
               (sal-pvs--literal (buffer-name target))
               (sal-pvs--literal (plist-get entry :token))) "SAL proof" 'pr t))))

(defun sal-pvs-prove ()
  "Enter PVS on the selected module's SAL formula at point, or choose one."
  (interactive)
  (sal-pvs--connect)
  (sal-pvs--ensure-current)
  (let* ((formulas (plist-get sal-pvs--description :formulas))
         (line (line-number-at-pos))
         (entry (cl-find-if (lambda (e) (and (<= (plist-get e :line) line)
                                             (<= line (plist-get e :end-line)))) formulas)))
    (unless formulas (user-error "No supported formulas for this module; C-u C-c C-t selects another"))
    (unless entry
      (let* ((choices (mapcar (lambda (e) (cons (or (plist-get e :source-name)
                                                   (plist-get e :name)) e)) formulas))
             (name (completing-read "SAL formula: " choices nil t)))
        (setq entry (cdr (assoc name choices)))))
    (sal-pvs--prove-entry (current-buffer) entry)))

(defun sal-pvs-show-tccs ()
  "Show current TCC formulas with SAL origins and proof buttons."
  (interactive)
  (sal-pvs--connect)
  (sal-pvs--ensure-current)
  (let ((source (current-buffer)) (description sal-pvs--description)
        (buffer (get-buffer-create (format "*SAL TCCs: %s*" (buffer-name)))))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (dolist (entry (plist-get description :tccs))
          (let ((comment-start (point)))
            (insert "% ")
            (insert-text-button (format "%s:%d" (file-name-nondirectory (plist-get entry :source))
                                       (plist-get entry :line))
                                'help-echo (plist-get entry :source)
                                'action (lambda (_)
                                          (find-file (plist-get entry :source))
                                          (goto-char (point-min))
                                          (forward-line (1- (plist-get entry :line))))
                                'follow-link t)
            (insert (format "\n%% %s.%s [%s]\n" (plist-get entry :theory)
                            (plist-get entry :name) (plist-get entry :status)))
            (when (plist-get entry :source-expression)
              (dolist (line (split-string (plist-get entry :source-expression) "\n"))
                (insert "% " line "\n")))
            (add-face-text-property comment-start (point) 'font-lock-comment-face t))
          (insert-text-button (plist-get entry :name)
                              'help-echo (concat "Prove " (plist-get entry :theory) "."
                                                 (plist-get entry :name))
                              'action (lambda (_) (sal-pvs--prove-entry source entry))
                              'follow-link t)
          (insert ": OBLIGATION\n")
          (insert "  " (replace-regexp-in-string "\n" "\n  " (plist-get entry :text))
                  ";\n\n"))
        (unless (plist-get description :tccs) (insert "% No source-associated TCCs.\n"))
        (special-mode)
        (visual-line-mode 1)
        (setq sal-pvs--source-buffer source)))
    (display-buffer buffer)))

(defun sal-pvs-toggle-syntax ()
  "Toggle SAL presentation for subsequent SAL-origin prover output and TCCs."
  (interactive)
  (sal-pvs--connect t)
  (setq sal-pvs-syntax-enabled (not sal-pvs-syntax-enabled))
  (sal-pvs--request :syntax sal-pvs-syntax-enabled)
  (message "SAL-origin display: %s" (if sal-pvs-syntax-enabled "SAL" "PVS")))

(defvar sal-pvs-translation-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-v") #'sal-pvs-toggle-view)
    map))

(define-minor-mode sal-pvs-translation-mode
  "Navigation back to the SAL source of a generated PVS file."
  :lighter " SAL→PVS" :keymap sal-pvs-translation-mode-map)

(defun sal-pvs-toggle-view ()
  "Switch between a SAL buffer and its selected module's generated PVS file.
Typecheck first if necessary.  The PVS view is read-only; edit the SAL source
and typecheck again to regenerate it.  Each buffer retains its own position.
This does not change the prover/TCC syntax setting."
  (interactive)
  (if sal-pvs-translation-mode
      (let ((source (if (buffer-live-p sal-pvs--source-buffer)
                        sal-pvs--source-buffer
                      (and sal-pvs--source-file
                           (file-readable-p sal-pvs--source-file)
                           (find-file-noselect sal-pvs--source-file)))))
        (unless source (user-error "The original SAL source is no longer available"))
        (with-current-buffer source (sal-pvs-mode 1))
        (switch-to-buffer source))
    (unless (and buffer-file-name (equal (file-name-extension buffer-file-name) "sal"))
      (user-error "Use this command in a SAL buffer or its generated PVS view"))
    (sal-pvs--connect)
    (sal-pvs--ensure-current)
    (let* ((source (current-buffer))
           (source-file buffer-file-name)
           ;; Use the loaded bridge's existing API, so updating this Emacs file
           ;; alone suffices even when PVS is already running.
           (file (pvs-send-and-wait
                  (format "(namestring (pvs::sal-transition-view-pvs-file (pvs::sal-editor-view %s)))"
                          (sal-pvs--literal (plist-get sal-pvs--description :key))) nil nil)))
      (unless (and (stringp file) (file-readable-p file))
        (user-error "No generated PVS file is available; typecheck the SAL source again"))
      (let ((target (or (get-file-buffer file) (find-file-noselect file))))
        (with-current-buffer target
          (when (buffer-modified-p)
            (user-error "Generated PVS buffer has unsaved changes; resolve them before switching"))
          (unless (verify-visited-file-modtime target)
            (let ((position (point)))
              (revert-buffer t t)
              (goto-char (min position (point-max)))))
          (setq sal-pvs--source-buffer source
                sal-pvs--source-file source-file)
          (sal-pvs-translation-mode 1)
          (read-only-mode 1))
        (switch-to-buffer target)
        (message "Generated PVS translation; C-c C-v returns to SAL. Edit the SAL source to make changes.")))))

(defvar sal-pvs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-t") #'sal-pvs-typecheck)
    (define-key map (kbd "C-c C-q") #'sal-pvs-show-tccs)
    (define-key map (kbd "C-c C-p") #'sal-pvs-prove)
    (define-key map (kbd "C-c C-s") #'sal-pvs-toggle-syntax)
    map))

;; Also install the new binding when reloading into an existing Emacs session.
(define-key sal-pvs-mode-map (kbd "C-c C-v") #'sal-pvs-toggle-view)

;;;###autoload
(define-minor-mode sal-pvs-mode
  "PVS frontend for SAL buffers. Requires PVS, SAL_HOME and SAL_XMLS_SOURCE."
  :lighter " SAL/PVS" :keymap sal-pvs-mode-map)
(provide 'sal-pvs-mode)
;;; sal-pvs-mode.el ends here
