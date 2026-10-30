;; -*- Mode: Emacs-Lisp; lexical-binding: t -*- ;;
;; pvs-interface.el -- Lightweight persistent PVS status pane

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

;;; Commentary:

;; This file intentionally keeps the interface small:
;;
;; - opening a .pvs file displays one dedicated side buffer;
;; - checking PVS is deferred until Emacs is idle;
;; - saving queues one asynchronous PVS request and returns immediately;
;; - typing runs only `first-change-hook', not a per-keystroke hook;
;; - moving point calls PVS's existing declaration/TCC commands asynchronously;
;; - region detection is one cheap buffer-local check; PVS lookup is
;;   idle-debounced and asynchronous.
;;
;; Plugin functions in `pvs-interface-plugin-functions' receive the source
;; buffer and insert their output into the current interface buffer.

;;; Code:

(require 'cl-lib)
(require 'button)
(require 'json)
(require 'subr-x)

(defvar pvs-interface-mode nil)
(defvar pvs-in-evaluator nil)
(defvar pvs-message-delay)

(declare-function ilisp-send "ilisp/ilisp-snd"
                  (string &optional message status and-go handler))
(declare-function pvs-formula-origin "pvs-prover" (&optional noerror))
(declare-function pvs-exit-debugger "pvs-ilisp" ())
(declare-function pvs-fref-buffer "pvs-macros" (fref))
(declare-function pvs-fref-file "pvs-macros" (fref))
(declare-function pvs-fref-kind "pvs-macros" (fref))
(declare-function pvs-fref-line "pvs-macros" (fref))
(declare-function pvs-fref-prelude-offset "pvs-macros" (fref))
(declare-function pvs-read-from-string "pvs-ilisp" (string))
(declare-function find-theory "pvs-cmds" (theoryname))
(declare-function make-pvs-formula-reference "pvs-macros" (&rest args))
(declare-function real-current-column "pvs-utils" ())
(declare-function lisp-mode "lisp-mode" ())

(defvar pvs-show-formulas-map)

(defgroup pvs-interface nil
  "Lightweight status and plugin pane for PVS source buffers."
  :prefix "pvs-interface-"
  :group 'pvs)

(defcustom pvs-interface-auto-enable t
  "Whether to enable `pvs-interface-mode' for .pvs files."
  :type 'boolean
  :group 'pvs-interface)

(defcustom pvs-interface-window-width 0.28
  "Initial width of the right-hand PVS interface window.
The mode never reapplies this after the window has been created."
  :type 'number
  :group 'pvs-interface)

(defcustom pvs-interface-idle-delay 0.15
  "Idle time before a queued PVS check starts."
  :type 'number
  :group 'pvs-interface)

(setq pvs-interface-idle-delay 0.03
      pvs-message-delay 0)

(defcustom pvs-interface-plugin-functions '(pvs-interface-tcc-plugin)
  "Functions that render sections below status and context theories.
Each function is called with the PVS source buffer while the current buffer is
the writable interface buffer."
  :type 'hook
  :group 'pvs-interface)

(defconst pvs-interface-buffer-name "*PVS Interface*")

;; Source-buffer state.
(defvar-local pvs-interface--status "Waiting for PVS...")
(defvar-local pvs-interface--status-kind 'pending)
(defvar-local pvs-interface--theories nil)
(defvar-local pvs-interface--selected-declaration nil)
(defvar-local pvs-interface--timer nil)
(defvar-local pvs-interface--generation 0)
(defvar-local pvs-interface--selection-generation 0)
(defvar-local pvs-interface--point-timer nil)
(defvar-local pvs-interface--point-position nil)
(defvar-local pvs-interface--point-reference nil)
(defvar-local pvs-interface--highlight-generation 0)
(defvar-local pvs-interface--highlight-timer nil)
(defvar-local pvs-interface--highlight-region-text nil)
(defvar-local pvs-interface--highlight-region-buffer nil)
(defvar-local pvs-interface--highlighted-term nil)
(defvar-local pvs-interface--resetting nil)
(defvar-local pvs-interface--view-generation 0)

;; Interface-buffer state.
(defvar-local pvs-interface--source-buffer nil)
(defvar-local pvs-interface--proof-key nil)
(defvar-local pvs-interface--proof-expanded nil)
(defvar-local pvs-interface--proof-loading nil)
(defvar-local pvs-interface--proof-text nil)
(defvar-local pvs-interface--proof-error nil)

(defface pvs-interface-heading-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for headings in the PVS interface."
  :group 'pvs-interface)

(defvar pvs-interface-pane-mode-map
  (let ((map (make-sparse-keymap)))
    (when (and (boundp 'pvs-show-formulas-map)
               (keymapp pvs-show-formulas-map))
      (set-keymap-parent map pvs-show-formulas-map))
    (define-key map (kbd "g") #'pvs-interface-check)
    (define-key map (kbd "q") #'pvs-interface-hide)
    map))

(define-derived-mode pvs-interface-pane-mode special-mode "PVS-Interface"
  "Major mode for the PVS interface side buffer.")

(defvar pvs-interface-mode-map (make-sparse-keymap))

;; Refresh maps when this file is evaluated in an already-running PVS.
(define-key pvs-interface-mode-map [mouse-1] nil)
(when (and (boundp 'pvs-show-formulas-map)
           (keymapp pvs-show-formulas-map))
  (set-keymap-parent pvs-interface-pane-mode-map pvs-show-formulas-map))

(defun pvs-interface--source-p (&optional buffer)
  "Return non-nil if BUFFER is a .pvs source buffer."
  (with-current-buffer (or buffer (current-buffer))
    (and (derived-mode-p 'pvs-mode)
         buffer-file-name
         (string-equal (downcase (or (file-name-extension buffer-file-name) ""))
                       "pvs"))))

(defun pvs-interface--field (key alist)
  "Return KEY's value in ALIST, accepting symbol or string keys."
  (let ((entry
         (cl-find-if
          (lambda (candidate)
            (and (consp candidate)
                 (let ((candidate-key (car candidate)))
                   (or (eq candidate-key key)
                       (and (stringp candidate-key)
                            (string= candidate-key (symbol-name key)))))))
          alist)))
    (cdr entry)))

(defun pvs-interface--as-list (value)
  "Return JSON array VALUE as a list."
  (if (vectorp value) (append value nil) value))

(defun pvs-interface--pane ()
  "Return the initialized PVS interface buffer."
  (let ((buffer (get-buffer-create pvs-interface-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'pvs-interface-pane-mode)
        (pvs-interface-pane-mode)))
    buffer))

(defun pvs-interface--source (&optional required)
  "Return the current interface source, signaling if REQUIRED and absent."
  (let ((source (if (derived-mode-p 'pvs-interface-pane-mode)
                    pvs-interface--source-buffer
                  (current-buffer))))
    (if (buffer-live-p source)
        source
      (when required (user-error "No live PVS source buffer")))))

(defun pvs-interface-source-data (&optional source)
  "Return cached plugin data for SOURCE as a property list."
  (setq source (or source (pvs-interface--source t)))
  (with-current-buffer source
    (list :buffer source
          :file buffer-file-name
          :status pvs-interface--status
          :status-kind pvs-interface--status-kind
          :theories pvs-interface--theories
          :selected-declaration pvs-interface--selected-declaration
          :highlighted-term pvs-interface--highlighted-term)))

(defun pvs-interface--insert-heading (text &optional detail)
  "Insert heading TEXT, followed on the same line by optional DETAIL."
  (insert (propertize text 'face 'pvs-interface-heading-face))
  (when detail
    (insert "  " (propertize detail 'face 'font-lock-function-name-face)))
  (insert "\n"))

(defun pvs-interface--insert-status-heading (source)
  "Insert the Status heading and reset button for SOURCE."
  (insert (propertize "Status" 'face 'pvs-interface-heading-face) "  ")
  (insert-text-button
   "[RESET]"
   'follow-link t
   'help-echo "Reset PVS, clear theories, refresh this pane, and retypecheck"
   'pvs-interface-source source
   'action #'pvs-interface-reset)
  (insert "\n"))

(defun pvs-interface--visit-theory (button)
  "Visit the theory represented by text BUTTON in the main PVS window."
  (let ((source (button-get button 'pvs-interface-source))
        (theory (button-get button 'pvs-interface-theory)))
    (when (buffer-live-p source)
      (if-let ((window (get-buffer-window source (selected-frame))))
          (select-window window)
        (pop-to-buffer source))
      (find-theory theory))))

(defun pvs-interface--insert-theories (source theories)
  "Insert THEORIES for SOURCE as a single line of navigation buttons."
  (insert (propertize "Typechecked theories"
                      'face 'pvs-interface-heading-face))
  (if theories
      (progn
        (insert "  ")
        (let ((remaining theories))
          (while remaining
            (let ((theory (pop remaining)))
              (insert-text-button
               theory
               'follow-link t
               'help-echo (format "Visit theory %s" theory)
               'pvs-interface-source source
               'pvs-interface-theory theory
               'action #'pvs-interface--visit-theory))
            (when remaining (insert ", ")))))
    (insert "  (none)"))
  (insert "\n\n"))

(defun pvs-interface--fontify-pvs (source text)
  "Return TEXT fontified with SOURCE's PVS syntax settings."
  (with-temp-buffer
    (set-syntax-table (with-current-buffer source (syntax-table)))
    (setq-local font-lock-defaults
                (buffer-local-value 'font-lock-defaults source))
    (insert text)
    (font-lock-mode 1)
    (font-lock-ensure)
    (buffer-string)))

(defun pvs-interface--fontify-lisp (text)
  "Return Lisp TEXT with Lisp syntax highlighting."
  (with-temp-buffer
    (lisp-mode)
    (insert text)
    (font-lock-ensure)
    (buffer-string)))

(defun pvs-interface--status-face (kind)
  "Return a face for status KIND."
  (pcase kind ('ok 'success) ('error 'error) (_ 'warning)))

(defun pvs-interface--render (source)
  "Render SOURCE's cached state without contacting PVS."
  (when (buffer-live-p source)
    (let ((pane (pvs-interface--pane)))
      (with-current-buffer pane
        (setq pvs-interface--source-buffer source
              default-directory (with-current-buffer source default-directory))
        (let ((inhibit-read-only t)
              (buffer-undo-list t))
          (erase-buffer)
          (with-current-buffer source
            (let ((status pvs-interface--status)
                  (kind pvs-interface--status-kind)
                  (theories pvs-interface--theories))
              (with-current-buffer pane
                (pvs-interface--insert-status-heading source)
                (insert (propertize status
                                    'face (pvs-interface--status-face kind))
                        "\n\n")
                (pvs-interface--insert-theories source theories))))
          (dolist (plugin pvs-interface-plugin-functions)
            (condition-case err
                (funcall plugin source)
              (error (insert (format "Plugin %s: %s\n"
                                     plugin (error-message-string err))))))
          (pvs-interface-current-proof-widget source)
          (pvs-interface-highlight-plugin source)
          (goto-char (point-min))
          (set-buffer-modified-p nil))))))

(defun pvs-interface--show (source)
  "Render SOURCE and show its dedicated right-hand window."
  (let* ((pane (pvs-interface--pane))
         (window (get-buffer-window pane (selected-frame))))
    (pvs-interface--render source)
    (unless (window-live-p window)
      (setq window
            (display-buffer
             pane
             `((display-buffer-in-side-window)
               (side . right)
               (slot . 0)
               (window-width . ,pvs-interface-window-width)
               (window-parameters . ((no-delete-other-windows . t)))))))
    (when (window-live-p window)
      (set-window-dedicated-p window t))))

(defun pvs-interface--render-if-current (source)
  "Render SOURCE only if the pane is already showing it."
  (when-let ((pane (get-buffer pvs-interface-buffer-name)))
    (when (eq (buffer-local-value 'pvs-interface--source-buffer pane) source)
      (pvs-interface--render source))))

(defun pvs-interface--same-workspace-p (left right)
  "Return non-nil when LEFT and RIGHT are PVS files in one workspace."
  (and (buffer-live-p left)
       (buffer-live-p right)
       (equal (with-current-buffer left
                (file-name-directory (expand-file-name buffer-file-name)))
              (with-current-buffer right
                (file-name-directory (expand-file-name buffer-file-name))))))

(defun pvs-interface--cache-context-theories (source theories)
  "Cache SOURCE workspace's typechecked THEORIES in its interface buffers."
  (dolist (buffer (buffer-list))
    (when (and (buffer-local-value 'pvs-interface-mode buffer)
               (pvs-interface--same-workspace-p source buffer))
      (with-current-buffer buffer
        (setq pvs-interface--theories theories)))))

(defun pvs-interface--render-current-workspace (source)
  "Render the pane if it currently represents SOURCE's workspace."
  (when-let* ((pane (get-buffer pvs-interface-buffer-name))
              (current-source
               (buffer-local-value 'pvs-interface--source-buffer pane)))
    (when (pvs-interface--same-workspace-p source current-source)
      (pvs-interface--render current-source))))

(defun pvs-interface--capture-views (source)
  "Capture visible SOURCE and prover window views before an interface request."
  (let (views)
    (dolist (buffer (delete-dups (delq nil (list source (get-buffer "*pvs*")))))
      (when (buffer-live-p buffer)
        (push
         (list buffer
               (buffer-local-value 'pvs-interface--view-generation buffer)
               (mapcar (lambda (window)
                         (list window
                               (window-start window)
                               (window-point window)
                               (window-hscroll window)))
                       (get-buffer-window-list buffer nil t)))
         views)))
    views))

(defun pvs-interface--restore-views (views)
  "Restore captured VIEWS unless their buffers received a user command."
  (dolist (view views)
    (let ((buffer (nth 0 view))
          (generation (nth 1 view))
          (windows (nth 2 view)))
      (when (and (buffer-live-p buffer)
                 (= generation
                    (buffer-local-value
                     'pvs-interface--view-generation buffer)))
        (dolist (state windows)
          (let ((window (nth 0 state)))
            (when (and (window-live-p window)
                       (eq (window-buffer window) buffer))
              (set-window-point window (nth 2 state))
              (set-window-start window (nth 1 state) t)
              (set-window-hscroll window (nth 3 state)))))))))

(defun pvs-interface--send (source string status handler)
  "Send STRING for SOURCE without allowing it to move source/prover views."
  (let ((views (pvs-interface--capture-views source)))
    (ilisp-send
     string nil status 'dispatch
     (lambda (error-p wait message output prompt)
       (unwind-protect
           (funcall handler error-p wait message output prompt)
         ;; PVS recenters *pvs* after running the handler for a Rule? prompt.
         ;; A zero-delay timer restores the view after that filter has returned.
         (run-at-time 0 nil #'pvs-interface--restore-views views))))))

(defun pvs-interface--request-form (file)
  "Return the single PVS request used to check FILE."
  (format
   "(pvs:write-json-to-temp-file
      (with-pvs-file (filename) %s
        (let ((error
               (handler-case
                   (progn (typecheck-file filename nil nil nil t) nil)
                 (pvs-error (err) (format nil \"~a\" err)))))
          (list (cons \"error\" error)
                (cons \"theories\"
                      (sort
                       (mapcar #'(lambda (theory)
                                   (format nil \"~a\" (id theory)))
                               (get-typechecked-theories))
                       #'string-lessp))))))"
   (prin1-to-string file)))

(defun pvs-interface--read-result (output)
  "Read the JSON result file named by PVS OUTPUT."
  (let ((file (pvs-read-from-string output)))
    (unless (and (stringp file) (file-readable-p file))
      (error "PVS did not return an interface result"))
    (unwind-protect
        (let ((json-array-type 'list)
              (json-object-type 'alist)
              (json-key-type 'symbol)
              (json-false nil))
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (let ((value (json-read)))
              (if (stringp value) (json-read-from-string value) value))))
      (delete-file file))))

(defun pvs-interface--finish-check (source generation error-p output)
  "Apply an asynchronous PVS result to SOURCE for GENERATION."
  (condition-case err
      (let ((result (if error-p
                        (error "%s" (string-trim (or output "PVS error")))
                      (pvs-interface--read-result output))))
        (when (and (buffer-live-p source)
                   (= generation
                      (buffer-local-value 'pvs-interface--generation source)))
          (with-current-buffer source
            (let ((error-message (pvs-interface--field 'error result))
                  (theories
                   (pvs-interface--as-list
                    (pvs-interface--field 'theories result))))
              (pvs-interface--cache-context-theories source theories)
              (when (timerp pvs-interface--highlight-timer)
                (cancel-timer pvs-interface--highlight-timer))
              (when (timerp pvs-interface--point-timer)
                (cancel-timer pvs-interface--point-timer))
              (cl-incf pvs-interface--highlight-generation)
              (cl-incf pvs-interface--selection-generation)
              (setq pvs-interface--selected-declaration nil
                    pvs-interface--point-timer nil
                    pvs-interface--point-position nil
                    pvs-interface--point-reference nil
                    pvs-interface--highlight-timer nil
                    pvs-interface--highlight-region-text nil
                    pvs-interface--highlight-region-buffer nil
                    pvs-interface--highlighted-term nil)
              (if error-message
                  (setq pvs-interface--status (format "%s" error-message)
                        pvs-interface--status-kind 'error)
                (setq pvs-interface--status "Ok."
                      pvs-interface--status-kind 'ok)))
            (pvs-interface--render-current-workspace source)
            ;; A lookup queued before this check may have seen an old or empty
            ;; PVS context.  Retry the still-visible selection once.
            (when-let ((pane (get-buffer pvs-interface-buffer-name)))
              (when (eq (buffer-local-value
                         'pvs-interface--source-buffer pane)
                        source)
                (pvs-interface--post-command))))))
    (error
     (when (and (buffer-live-p source)
                (= generation
                   (buffer-local-value 'pvs-interface--generation source)))
       (with-current-buffer source
         (setq pvs-interface--status
               (format "Check failed: %s" (error-message-string err))
               pvs-interface--status-kind 'error
               pvs-interface--selected-declaration nil))
       (pvs-interface--render-if-current source))))
  t)

(defun pvs-interface--dispatch-check (source generation)
  "Dispatch SOURCE check GENERATION without waiting for its result."
  (when (and (buffer-live-p source)
             (= generation
                (buffer-local-value 'pvs-interface--generation source))
             (not (buffer-modified-p source)))
    (with-current-buffer source
      (setq pvs-interface--timer nil)
      (if pvs-in-evaluator
          (progn
            (setq pvs-interface--status "Exit the PVS evaluator, then save again."
                  pvs-interface--status-kind 'pending)
            (pvs-interface--render-if-current source))
        (condition-case err
          (let ((handler
                 (lambda (error-p _wait _message output _prompt)
                   (pvs-interface--finish-check
                    source generation error-p output))))
            (pvs-interface--send
             source
             (format "(pvs::lisp (pvs::pvs-errors %s))"
                     (pvs-interface--request-form buffer-file-name))
             'tc handler))
        (error
         (setq pvs-interface--status
               (format "PVS unavailable: %s" (error-message-string err))
               pvs-interface--status-kind 'error
               pvs-interface--selected-declaration nil)
         (pvs-interface--render-if-current source)))))))

(defun pvs-interface--schedule-check (source &optional delay)
  "Queue an asynchronous check of SOURCE after DELAY seconds."
  (with-current-buffer source
    (when (timerp pvs-interface--timer)
      (cancel-timer pvs-interface--timer))
    (when (timerp pvs-interface--point-timer)
      (cancel-timer pvs-interface--point-timer))
    (cl-incf pvs-interface--generation)
    (cl-incf pvs-interface--selection-generation)
    (let ((generation pvs-interface--generation))
      (setq pvs-interface--status "Checking..."
            pvs-interface--status-kind 'pending
            pvs-interface--selected-declaration nil
            pvs-interface--point-timer nil
            pvs-interface--point-position nil
            pvs-interface--point-reference nil
            pvs-interface--timer
            (run-with-idle-timer
             (or delay pvs-interface-idle-delay) nil
             #'pvs-interface--dispatch-check source generation)))
    (pvs-interface--render-if-current source)))

(defun pvs-interface--finish-tccs
    (source generation error-p output)
  "Display asynchronous declaration TCC OUTPUT for SOURCE and GENERATION."
  (when (and (buffer-live-p source)
             (= generation
                (buffer-local-value
                 'pvs-interface--selection-generation source)))
    (with-current-buffer source
      (setq pvs-interface--selected-declaration
            (condition-case err
                (if error-p
                    (list :error (string-trim (or output "PVS error")))
                  (pvs-interface--read-result output))
              (error (list :error (error-message-string err)))))
      (pvs-interface--render-if-current source)))
  t)

(defun pvs-interface--tcc-request-form (file kind line column)
  "Return a PVS request for the declaration at FILE, KIND, LINE and COLUMN."
  (format
   "(pvs:write-json-to-temp-file
      (handler-case
          (multiple-value-bind (object containing-type object-theory)
              (get-id-object-at %s %s (list %d %d) nil)
            (declare (ignore containing-type object-theory))
            (let ((decl (if (and object (declaration? object))
                            object
                            (get-decl-at-origin %s %s %d))))
            (if (null decl)
                (list (cons \"message\" \"No declaration at point.\")
                      (cons \"tccs\" nil))
                (let* ((theory (module decl))
                       (decl-id (format nil \"~a\" (ref-to-id decl)))
                       (tccs
                        (reverse
                         (remove-if-not #'tcc? (generated decl))))
                       (has-proof
                        (and (formula-decl? decl) (default-proof decl))))
                  (when (and tccs (not (tcc-form theory)))
                    (let ((*to-emacs* nil)
                          (*standard-output* (make-broadcast-stream)))
                      (show-tccs (id theory))))
                  (list (cons \"declaration\" decl-id)
                        (cons \"proof-key\"
                              (when has-proof
                                (format nil \"~a.~a\"
                                        (id theory) decl-id)))
                        (cons \"proof-theory\"
                              (when has-proof
                                (format nil \"~a\" (id theory))))
                        (cons \"proof-formula\"
                              (when has-proof decl-id))
                        (cons
                         \"tccs\"
                         (mapcar
                          #'(lambda (tcc)
                              (let* ((tcc-id
                                      (format nil \"~a\" (id tcc)))
                                     (parsed-tcc
                                      (find tcc-id (tcc-form theory)
                                            :key #'id :test #'string=))
                                     (entry
                                      (list
                                       (cons \"id\" tcc-id)
                                       (cons \"theory\"
                                             (format nil \"~a\" (id theory)))
                                       (cons \"definition\"
                                             (str (definition tcc)))
                                       (cons \"declaration\"
                                             (unparse-decl tcc)))))
                                (when parsed-tcc
                                  (setq entry
                                        (acons \"line\"
                                               (line-begin (place parsed-tcc))
                                               entry)))
                                entry))
                          tccs)))))))
        (error (err)
          (list (cons \"error\" (format nil \"~a\" err))))))"
   (prin1-to-string file) (prin1-to-string kind) line column
   (prin1-to-string file) (prin1-to-string kind) line))

(defun pvs-interface--point-reference ()
  "Return the existing PVS formula reference at point, if available."
  (condition-case nil
      (pvs-formula-origin t)
    (error nil)))

(defun pvs-interface--same-point-reference-p (left right)
  "Return non-nil when formula references LEFT and RIGHT identify one line."
  (or (and (null left) (null right))
      (and left right
           (equal (pvs-fref-file left) (pvs-fref-file right))
           (equal (pvs-fref-buffer left) (pvs-fref-buffer right))
           (eq (pvs-fref-kind left) (pvs-fref-kind right))
           (= (pvs-fref-line left) (pvs-fref-line right))
           (= (pvs-fref-prelude-offset left)
              (pvs-fref-prelude-offset right)))))

(defun pvs-interface--dispatch-point (source generation fref column)
  "Request TCCs for SOURCE at FREF and COLUMN for GENERATION."
  (when (and (buffer-live-p source)
             (= generation
                (buffer-local-value
                 'pvs-interface--selection-generation source))
             (pvs-interface--same-point-reference-p
              fref
              (buffer-local-value
               'pvs-interface--point-reference source)))
    (with-current-buffer source
      (setq pvs-interface--point-timer nil)
      (unless (or pvs-in-evaluator (buffer-modified-p))
        (let* ((file (or (pvs-fref-file fref) (pvs-fref-buffer fref)))
               (kind (format "%s" (pvs-fref-kind fref)))
               (line (+ (pvs-fref-line fref)
                        (pvs-fref-prelude-offset fref)))
               (handler
                (lambda (error-p _wait _message output _prompt)
                  (pvs-interface--finish-tccs
                   source generation error-p output))))
          (condition-case err
              (pvs-interface--send
               source
               (format "(pvs::lisp (pvs::pvs-errors %s))"
                       (pvs-interface--tcc-request-form
                        file kind line column))
               'tc handler)
            (error
             (pvs-interface--finish-tccs
              source generation t (error-message-string err)))))))))

(defun pvs-interface--point-changed ()
  "Debounce declaration TCC lookup whenever source point moves."
  (let ((position (point)))
    (unless (equal position pvs-interface--point-position)
      (let ((fref (pvs-interface--point-reference)))
        (when (timerp pvs-interface--point-timer)
          (cancel-timer pvs-interface--point-timer))
        (cl-incf pvs-interface--selection-generation)
        (setq pvs-interface--point-timer nil
              pvs-interface--point-position position
              pvs-interface--point-reference fref)
        (cond ((buffer-modified-p)
               (setq pvs-interface--selected-declaration
                     (list :error "Save the file before requesting TCCs."))
               (pvs-interface--render-if-current (current-buffer)))
              (fref
               (let ((source (current-buffer))
                     (generation pvs-interface--selection-generation))
                 (setq pvs-interface--point-timer
                       (run-with-timer
                        pvs-interface-idle-delay nil
                        #'pvs-interface--dispatch-point
                        source generation fref
                        (real-current-column))))))))))

(defun pvs-interface--tcc-formula-reference (tcc)
  "Return a PVS formula reference for rendered TCC data TCC."
  (let ((theory (pvs-interface--field 'theory tcc))
        (line (pvs-interface--field 'line tcc)))
    (when (and theory (numberp line))
      (make-pvs-formula-reference
       :kind 'tccs
       :theory theory
       :file theory
       :buffer pvs-interface-buffer-name
       :line line))))

(defun pvs-interface--formula-reference-at-point ()
  "Return the rendered TCC formula reference at point, if any."
  (or (get-text-property (point) 'pvs-interface-formula-reference)
      (and (> (point) (point-min))
           (get-text-property (1- (point))
                              'pvs-interface-formula-reference))))

(defun pvs-interface--formula-origin-advice (original &optional noerror)
  "Use a rendered TCC reference, otherwise call ORIGINAL with NOERROR."
  (if (derived-mode-p 'pvs-interface-pane-mode)
      (or (pvs-interface--formula-reference-at-point)
          (unless noerror
            (user-error "Point is not on a declaration TCC")))
    (funcall original noerror)))

(defun pvs-interface-tcc-plugin (source)
  "Render TCCs for SOURCE's selected declaration."
  (let* ((selection (with-current-buffer source
                      pvs-interface--selected-declaration))
         (notice (and (listp selection)
                      (or (plist-get selection :error)
                          (pvs-interface--field 'error selection)
                          (pvs-interface--field 'message selection)))))
    (pvs-interface--insert-heading
     "Declaration TCCs"
     (and (listp selection)
          (pvs-interface--field 'declaration selection)))
    (cond ((null selection) (insert "Move point to a declaration.\n"))
          ((eq selection 'loading) (insert "Loading...\n"))
          (notice (insert notice "\n"))
          (t
           (let ((tccs (pvs-interface--as-list
                        (pvs-interface--field 'tccs selection))))
             (if tccs
                 (dolist (tcc tccs)
                   (insert "\n")
                   (let ((start (point))
                         (fref (pvs-interface--tcc-formula-reference tcc)))
                     (insert
                      (pvs-interface--fontify-pvs
                       source
                       (or (pvs-interface--field 'declaration tcc)
                           (format "%s: OBLIGATION\n  %s"
                                   (pvs-interface--field 'id tcc)
                                   (pvs-interface--field 'definition tcc)))))
                     (when fref
                       (add-text-properties
                        start (point)
                        `(pvs-interface-formula-reference ,fref
                          help-echo "Run PVS formula commands here"
                          rear-nonsticky t)))
                     (insert "\n")))
               (insert "  No TCCs.\n")))))))

(defun pvs-interface--proof-request-form (file theory formula)
  "Return a PVS request for FORMULA's proof in THEORY and FILE."
  (let ((directory (file-name-directory file))
        (filename (file-name-nondirectory file)))
    (format
     "(pvs:write-json-to-temp-file
      (handler-case
          (list
           (cons \"proof\"
                 (proof-script-to-string
                  (get-proof-script
                   (list (cons :directory %s)
                         (cons :file %s)
                         (cons :theory %s)
                         (cons :formula %s))
                   nil))))
        (error (err)
          (list (cons \"error\" (format nil \"~a\" err))))))"
     (prin1-to-string directory)
     (prin1-to-string filename)
     (prin1-to-string theory)
     (prin1-to-string formula))))

(defun pvs-interface--finish-proof (source key error-p output)
  "Apply lazy proof OUTPUT for SOURCE and proof KEY."
  (let* ((result
          (condition-case err
              (if error-p
                  (list :error (string-trim (or output "PVS error")))
                (pvs-interface--read-result output))
            (error (list :error (error-message-string err)))))
         (error-message
          (or (plist-get result :error)
              (pvs-interface--field 'error result))))
    (when-let ((pane (get-buffer pvs-interface-buffer-name)))
      (with-current-buffer pane
        (when (and (eq pvs-interface--source-buffer source)
                   (equal pvs-interface--proof-key key))
          (setq pvs-interface--proof-loading nil
                pvs-interface--proof-error error-message
                pvs-interface--proof-text
                (and (not error-message)
                     (pvs-interface--field 'proof result)))
          (pvs-interface--render-if-current source)))))
  t)

(defun pvs-interface--dispatch-proof (source key theory formula)
  "Fetch SOURCE's proof KEY for THEORY and FORMULA asynchronously."
  (when (buffer-live-p source)
    (if pvs-in-evaluator
        (pvs-interface--finish-proof
         source key t "Exit the PVS evaluator before loading a proof.")
      (with-current-buffer source
        (let ((handler
               (lambda (error-p _wait _message output _prompt)
                 (pvs-interface--finish-proof source key error-p output))))
          (condition-case err
              (pvs-interface--send
               source
               (format "(pvs::lisp (pvs::pvs-errors %s))"
                       (pvs-interface--proof-request-form
                        buffer-file-name theory formula))
               'listing handler)
            (error
             (pvs-interface--finish-proof
              source key t (error-message-string err)))))))))

(defun pvs-interface--toggle-current-proof (button)
  "Toggle the current-proof body represented by BUTTON."
  (let ((source (button-get button 'pvs-interface-source))
        (key (button-get button 'pvs-interface-proof-key))
        (theory (button-get button 'pvs-interface-proof-theory))
        (formula (button-get button 'pvs-interface-proof-formula))
        dispatch)
    (when (and (buffer-live-p source)
               (equal key pvs-interface--proof-key))
      (setq pvs-interface--proof-expanded
            (not pvs-interface--proof-expanded))
      (when (and pvs-interface--proof-expanded
                 (not pvs-interface--proof-text)
                 (not pvs-interface--proof-error)
                 (not pvs-interface--proof-loading))
        (setq pvs-interface--proof-loading t
              dispatch t))
      (pvs-interface--render-if-current source)
      (when dispatch
        (pvs-interface--dispatch-proof source key theory formula)))))

(defun pvs-interface-current-proof-widget (source)
  "Render SOURCE's current proof as a collapsed transient widget."
  (let* ((selection (with-current-buffer source
                      pvs-interface--selected-declaration))
         (backend-key (and (listp selection)
                           (pvs-interface--field 'proof-key selection)))
         (theory (and backend-key
                      (pvs-interface--field 'proof-theory selection)))
         (formula (and backend-key
                       (pvs-interface--field 'proof-formula selection)))
         (key (and backend-key (cons source backend-key))))
    (if (not backend-key)
        (setq pvs-interface--proof-key nil
              pvs-interface--proof-expanded nil
              pvs-interface--proof-loading nil
              pvs-interface--proof-text nil
              pvs-interface--proof-error nil)
      (unless (equal key pvs-interface--proof-key)
        (setq pvs-interface--proof-key key
              pvs-interface--proof-expanded nil
              pvs-interface--proof-loading nil
              pvs-interface--proof-text nil
              pvs-interface--proof-error nil))
      (insert "\n")
      (insert-text-button
       (if pvs-interface--proof-expanded
           "▾ Current Proof"
         "▸ Current Proof")
       'face 'pvs-interface-heading-face
       'follow-link t
       'help-echo "Show or hide the current proof"
       'pvs-interface-source source
       'pvs-interface-proof-key key
       'pvs-interface-proof-theory theory
       'pvs-interface-proof-formula formula
       'action #'pvs-interface--toggle-current-proof)
      (insert "\n")
      (when pvs-interface--proof-expanded
        (cond (pvs-interface--proof-loading
               (insert "Loading...\n"))
              (pvs-interface--proof-error
               (insert (propertize pvs-interface--proof-error 'face 'error)
                       "\n"))
              (pvs-interface--proof-text
               (insert (pvs-interface--fontify-lisp
                        pvs-interface--proof-text)
                       "\n")))))))

(defun pvs-interface--active-region-term ()
  "Return the selected declaration name, or nil for no usable region."
  (when (use-region-p)
    (let ((term (string-trim
                 (buffer-substring-no-properties
                  (region-beginning) (region-end)))))
      (when (and (not (string-empty-p term))
                 (<= (length term) 256)
                 (not (string-match-p "[[:space:]]" term)))
        term))))

(defun pvs-interface--highlight-request-form (file term)
  "Return the PVS request that finds declarations named TERM for FILE."
  (format
   "(pvs:write-json-to-temp-file
      (with-pvs-file (filename) %s
        (find-declaration %s)))"
   (prin1-to-string file) (prin1-to-string term)))

(defun pvs-interface--finish-highlight
    (source generation term error-p output)
  "Apply highlighted TERM lookup OUTPUT to SOURCE for GENERATION."
  (when (and (buffer-live-p source)
             (= generation
                (buffer-local-value
                 'pvs-interface--highlight-generation source))
             (equal term
                    (buffer-local-value
                     'pvs-interface--highlight-region-text source)))
    (with-current-buffer source
      (setq pvs-interface--highlighted-term
            (unless error-p
              (condition-case nil
                  (when-let ((declarations
                              (pvs-interface--read-result output)))
                    (list :term term :declarations declarations))
                (error nil))))
      (pvs-interface--render-if-current source)))
  t)

(defun pvs-interface--dispatch-highlight (source generation term)
  "Look up selected TERM for SOURCE and GENERATION without waiting."
  (when (and (buffer-live-p source)
             (= generation
                (buffer-local-value
                 'pvs-interface--highlight-generation source))
             (equal term
                    (buffer-local-value
                     'pvs-interface--highlight-region-text source)))
    (with-current-buffer source
      (setq pvs-interface--highlight-timer nil)
      (unless pvs-in-evaluator
        (condition-case nil
            (let ((handler
                   (lambda (error-p _wait _message output _prompt)
                     (pvs-interface--finish-highlight
                      source generation term error-p output))))
              (pvs-interface--send
               source
               (format "(pvs::lisp (pvs::pvs-errors %s))"
                       (pvs-interface--highlight-request-form
                        buffer-file-name term))
               'listing handler))
          (error
           (pvs-interface--finish-highlight
            source generation term t nil)))))))

(defun pvs-interface--track-highlight-region (region-buffer source)
  "Track REGION-BUFFER's active selection for interface SOURCE."
  (when (and (buffer-live-p region-buffer)
             (buffer-live-p source)
             (buffer-local-value 'pvs-interface-mode source))
    (let ((term (with-current-buffer region-buffer
                  (pvs-interface--active-region-term))))
      (with-current-buffer source
        (unless (and (equal term pvs-interface--highlight-region-text)
                     (eq region-buffer pvs-interface--highlight-region-buffer))
          (when (timerp pvs-interface--highlight-timer)
            (cancel-timer pvs-interface--highlight-timer))
          (cl-incf pvs-interface--highlight-generation)
          (let ((had-result pvs-interface--highlighted-term))
            (setq pvs-interface--highlight-timer nil
                  pvs-interface--highlight-region-text term
                  pvs-interface--highlight-region-buffer region-buffer
                  pvs-interface--highlighted-term nil)
            ;; Avoid repainting while a selection is being extended.  A repaint
            ;; is needed here only to remove a definition already on screen.
            (when had-result
              (pvs-interface--render-if-current (current-buffer))))
          (when term
            (let ((source (current-buffer))
                  (generation pvs-interface--highlight-generation))
              (setq pvs-interface--highlight-timer
                    (run-with-timer
                     pvs-interface-idle-delay nil
                     #'pvs-interface--dispatch-highlight
                     source generation term)))))))))

(defun pvs-interface--highlight-region-changed ()
  "Debounce lookup when this source buffer's active region changes."
  (when pvs-interface-mode
    (pvs-interface--track-highlight-region (current-buffer)
                                           (current-buffer))))

(defun pvs-interface--pane-source ()
  "Return the live source currently represented by the interface pane."
  (when-let ((pane (get-buffer pvs-interface-buffer-name)))
    (let ((source (buffer-local-value 'pvs-interface--source-buffer pane)))
      (when (and (buffer-live-p source)
                 (buffer-local-value 'pvs-interface-mode source))
        source))))

(defun pvs-interface--prover-post-command ()
  "Track a selected term in the live PVS prover buffer."
  (when (eq (current-buffer) (get-buffer "*pvs*"))
    (cl-incf pvs-interface--view-generation)
    (when-let ((source (pvs-interface--pane-source)))
      (pvs-interface--track-highlight-region (current-buffer) source))))

(defun pvs-interface--install-prover-tracking ()
  "Install lightweight highlighted-term tracking in the PVS process buffer."
  (when (eq (current-buffer) (get-buffer "*pvs*"))
    (add-hook 'post-command-hook #'pvs-interface--prover-post-command nil t)))

(defun pvs-interface--post-command ()
  "Update point-driven TCCs and active-region lookup after a source command."
  (when pvs-interface-mode
    (cl-incf pvs-interface--view-generation)
    (pvs-interface--point-changed)
    (pvs-interface--highlight-region-changed)))

(defun pvs-interface-highlight-plugin (source)
  "Render PVS declarations matching SOURCE's actively highlighted term."
  (when-let* ((result (with-current-buffer source
                       pvs-interface--highlighted-term))
              (declarations (plist-get result :declarations)))
    (insert "\n")
    (pvs-interface--insert-heading "Highlighted term")
    (let ((remaining declarations))
      (while remaining
        (when-let ((text (pvs-interface--field 'decl-ppstring
                                               (pop remaining))))
          (insert (pvs-interface--fontify-pvs source text) "\n")
          (when remaining (insert "\n")))))))

(defun pvs-interface--first-change ()
  "Invalidate cached data once when a checked source is first edited."
  (when pvs-interface-mode
    (when (timerp pvs-interface--timer) (cancel-timer pvs-interface--timer))
    (when (timerp pvs-interface--point-timer)
      (cancel-timer pvs-interface--point-timer))
    (setq pvs-interface--timer nil
          pvs-interface--point-timer nil
          pvs-interface--point-position nil
          pvs-interface--point-reference nil)
    (cl-incf pvs-interface--generation)
    (cl-incf pvs-interface--selection-generation)
    (setq pvs-interface--selected-declaration nil
          pvs-interface--status "Modified; save to check."
          pvs-interface--status-kind 'pending)
    (pvs-interface--render-if-current (current-buffer))))

(defun pvs-interface--after-save ()
  "Queue one nonblocking PVS check after saving the current source."
  (when pvs-interface-mode
    (pvs-interface--schedule-check (current-buffer) 0)))

(defun pvs-interface-check ()
  "Save if needed, then queue a nonblocking PVS check."
  (interactive)
  (let ((source (pvs-interface--source t)))
    (if (buffer-modified-p source)
        (with-current-buffer source (save-buffer))
      (pvs-interface--schedule-check source 0))))

(defun pvs-interface--finish-reset (source error-p output)
  "Finish resetting SOURCE using PVS OUTPUT.
When ERROR-P is non-nil, keep the reset failure visible in the pane."
  (when (and (buffer-live-p source)
             (buffer-local-value 'pvs-interface--resetting source))
    (with-current-buffer source
      (setq pvs-interface--resetting nil)
      (if error-p
          (progn
            (setq pvs-interface--status
                  (format "Reset failed: %s"
                          (string-trim (or output "PVS error")))
                  pvs-interface--status-kind 'error)
            (pvs-interface--render-if-current source))
        ;; Do not typecheck until PVS confirms that its theory tables are clear.
        (if (buffer-modified-p)
            (progn
              (setq pvs-interface--status "Modified; save to check."
                    pvs-interface--status-kind 'pending)
              (pvs-interface--render-if-current source))
          (pvs-interface--schedule-check source 0)))))
  t)

(defun pvs-interface--invalidate-all-sources-for-reset (source)
  "Clear cached interface state after a global reset initiated by SOURCE."
  (dolist (buffer (buffer-list))
    (when (buffer-local-value 'pvs-interface-mode buffer)
      (with-current-buffer buffer
        (dolist (timer (list pvs-interface--timer
                             pvs-interface--point-timer
                             pvs-interface--highlight-timer))
          (when (timerp timer) (cancel-timer timer)))
        (cl-incf pvs-interface--generation)
        (cl-incf pvs-interface--selection-generation)
        (cl-incf pvs-interface--highlight-generation)
        (setq pvs-interface--resetting (eq buffer source)
              pvs-interface--status
              (if (eq buffer source)
                  "Resetting PVS..."
                "PVS context reset; checking when displayed.")
              pvs-interface--status-kind 'pending
              pvs-interface--theories nil
              pvs-interface--selected-declaration nil
              pvs-interface--highlighted-term nil
              pvs-interface--timer nil
              pvs-interface--point-timer nil
              pvs-interface--point-position nil
              pvs-interface--point-reference nil
              pvs-interface--highlight-timer nil
              pvs-interface--highlight-region-text nil
              pvs-interface--highlight-region-buffer nil))))
  (pvs-interface--render-if-current source))

(defun pvs-interface-reset (&optional button)
  "Reset PVS and the interface pane, then retypecheck its source file.
BUTTON is the reset button when invoked from the interface pane."
  (interactive)
  (let ((source (or (and button
                         (button-get button 'pvs-interface-source))
                    (pvs-interface--source t))))
    (unless (buffer-live-p source)
      (user-error "No live PVS source buffer"))
    (unless (buffer-local-value 'pvs-interface--resetting source)
      (with-current-buffer source
        (when (buffer-modified-p)
          (save-buffer))
        ;; The Lisp clear below affects every workspace, so invalidate every
        ;; open interface buffer before accepting any more backend results.
        (pvs-interface--invalidate-all-sources-for-reset source)
        (let ((handler
               (lambda (error-p _wait _message output _prompt)
                 (pvs-interface--finish-reset
                  source error-p output))))
          (condition-case err
              (progn
                (pvs-exit-debugger)
                (pvs-interface--send
                 source
                 "(pvs::lisp (pvs::pvs-errors
                                (clear-theories :workspace :all)))"
                 'reset handler))
            (error
             (pvs-interface--finish-reset
              source t (error-message-string err)))))))))

(defun pvs-interface--hide-window ()
  "Delete the PVS interface side window in the selected frame."
  (when-let ((window (get-buffer-window pvs-interface-buffer-name
                                        (selected-frame))))
    (set-window-parameter window 'no-delete-other-windows nil)
    (set-window-dedicated-p window nil)
    (delete-window window)))

(defun pvs-interface-hide ()
  "Disable and hide the current PVS interface."
  (interactive)
  (let ((source (pvs-interface--source)))
    (when (and (buffer-live-p source)
               (buffer-local-value 'pvs-interface-mode source))
      (with-current-buffer source (pvs-interface-mode -1))))
  (pvs-interface--hide-window))

(defun pvs-interface--kill-source ()
  "Cancel pending work when a PVS source buffer is killed."
  (when (timerp pvs-interface--timer) (cancel-timer pvs-interface--timer))
  (when (timerp pvs-interface--point-timer)
    (cancel-timer pvs-interface--point-timer))
  (when (timerp pvs-interface--highlight-timer)
    (cancel-timer pvs-interface--highlight-timer))
  (when-let ((pane (get-buffer pvs-interface-buffer-name)))
    (when (eq (buffer-local-value 'pvs-interface--source-buffer pane)
              (current-buffer))
      (pvs-interface--hide-window))))

(define-minor-mode pvs-interface-mode
  "Show a lightweight, asynchronously updated interface for this PVS file."
  :init-value nil
  :lighter " PVS-I"
  (if pvs-interface-mode
      (if (pvs-interface--source-p)
          (progn
            (add-hook 'first-change-hook #'pvs-interface--first-change nil t)
            (add-hook 'after-save-hook #'pvs-interface--after-save nil t)
            (add-hook 'kill-buffer-hook #'pvs-interface--kill-source nil t)
            (add-hook 'post-command-hook
                      #'pvs-interface--post-command nil t)
            (pvs-interface--show (current-buffer))
            (pvs-interface--schedule-check (current-buffer))
            (pvs-interface--post-command))
        (setq pvs-interface-mode nil)
        (user-error "PVS Interface mode requires a .pvs source buffer"))
    (remove-hook 'first-change-hook #'pvs-interface--first-change t)
    (remove-hook 'after-save-hook #'pvs-interface--after-save t)
    (remove-hook 'kill-buffer-hook #'pvs-interface--kill-source t)
    (remove-hook 'post-command-hook
                 #'pvs-interface--highlight-region-changed t)
    (remove-hook 'post-command-hook #'pvs-interface--post-command t)
    (when (timerp pvs-interface--timer) (cancel-timer pvs-interface--timer))
    (when (timerp pvs-interface--point-timer)
      (cancel-timer pvs-interface--point-timer))
    (when (timerp pvs-interface--highlight-timer)
      (cancel-timer pvs-interface--highlight-timer))
    (cl-incf pvs-interface--highlight-generation)
    (cl-incf pvs-interface--selection-generation)
    (setq pvs-interface--timer nil
          pvs-interface--point-timer nil
          pvs-interface--point-position nil
          pvs-interface--point-reference nil
          pvs-interface--highlight-timer nil
          pvs-interface--highlight-region-text nil
          pvs-interface--highlight-region-buffer nil
          pvs-interface--highlighted-term nil)
    (when-let ((pane (get-buffer pvs-interface-buffer-name)))
      (when (eq (buffer-local-value 'pvs-interface--source-buffer pane)
                (current-buffer))
        (pvs-interface--hide-window)))))

(defalias 'pim #'pvs-interface-mode)

(defun pvs-interface--maybe-enable ()
  "Enable the lightweight interface for a .pvs source buffer."
  (when (and pvs-interface-auto-enable
             (not noninteractive)
             (pvs-interface--source-p))
    (pvs-interface-mode 1)))

(defun pvs-interface--window-buffer-changed (window)
  "Make the pane follow a PVS source newly displayed in WINDOW."
  (when (window-live-p window)
    (let ((buffer (window-buffer window)))
      (when (and (buffer-live-p buffer)
                 (buffer-local-value 'pvs-interface-mode buffer))
        (let ((pane (get-buffer pvs-interface-buffer-name)))
          (unless (and pane
                       (eq (buffer-local-value 'pvs-interface--source-buffer pane)
                           buffer))
            (pvs-interface--show buffer)
            ;; A displayed source is the active interface source.  Refresh its
            ;; PVS context asynchronously instead of showing another buffer's
            ;; cached theory list indefinitely.
            (unless (or (buffer-modified-p buffer)
                        (buffer-local-value
                         'pvs-interface--resetting buffer))
              (pvs-interface--schedule-check buffer 0))))))))

(add-hook 'pvs-mode-hook #'pvs-interface--maybe-enable)
(add-hook 'ilisp-mode-hook #'pvs-interface--install-prover-tracking)
(add-hook 'window-buffer-change-functions
          #'pvs-interface--window-buffer-changed)

(when-let ((prover (get-buffer "*pvs*")))
  (with-current-buffer prover
    (pvs-interface--install-prover-tracking)))

(when (and (fboundp 'pvs-formula-origin)
           (not (advice-member-p #'pvs-interface--formula-origin-advice
                                 'pvs-formula-origin)))
  (advice-add 'pvs-formula-origin :around
              #'pvs-interface--formula-origin-advice))

;; Loading this file while PVS is running should update already-open source
;; buffers too.  This is also useful during normal PVS development, where the
;; Emacs interface is commonly reloaded without restarting Emacs.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (bound-and-true-p pvs-interface-mode)
      (remove-hook 'activate-mark-hook
                   'pvs-interface--region-activated t)
      (remove-hook 'deactivate-mark-hook
                   'pvs-interface--region-deactivated t)
      (remove-hook 'post-command-hook
                   #'pvs-interface--highlight-region-changed t)
      (add-hook 'post-command-hook
                #'pvs-interface--post-command nil t)
      (pvs-interface--post-command))))

(provide 'pvs-interface)

;;; pvs-interface.el ends here
