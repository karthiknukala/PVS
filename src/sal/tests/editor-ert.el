;;; editor-ert.el --- Editor-side regression tests -*- lexical-binding: t; -*-
(require 'ert)
(load (expand-file-name "../emacs/sal-pvs-mode.el" (file-name-directory load-file-name)) nil t)

(ert-deftest sal-pvs-data-quoting ()
  (let ((value "file\" (delete-file \"x\") \\ with spaces.sal"))
    (should (equal (car (read-from-string (sal-pvs--literal value))) value))))

(ert-deftest sal-pvs-module-selection ()
  (with-temp-buffer
    (modify-syntax-entry ?% "<")
    (modify-syntax-entry ?\n ">")
    (insert "% ignored: MODULE =\nmain: MODULE = BEGIN END;\ncell [n: INTEGER]: MODULE = BEGIN END;")
    (should (equal (sal-pvs--modules) '("main" "cell" "--context")))))

(ert-deftest sal-pvs-failed-check-clears-targets ()
  (with-temp-buffer
    (setq buffer-file-name "/src/demo.sal" sal-pvs-module "machine"
          sal-pvs--description '(:key "stale"))
    (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
              ((symbol-function 'save-buffer) #'ignore)
              ((symbol-function 'file-truename) #'identity)
              ((symbol-function 'sal-pvs--request)
               (lambda (op &rest _) (when (eq op :typecheck) (error "sal-wfc failed")))))
      (should-error (sal-pvs-typecheck))
      (should-not sal-pvs--description))))

(ert-deftest sal-pvs-selects-source-formula-at-point ()
  (with-temp-buffer
    (insert "model\nfirst theorem\nbody\nsecond theorem\n")
    (setq sal-pvs--description
          '(:formulas ((:name "first" :line 2 :end-line 3)
                       (:name "second" :line 4 :end-line 4))))
    (goto-char (point-min)) (forward-line 2)
    (let (selected)
      (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                ((symbol-function 'sal-pvs--prove-entry) (lambda (_ entry) (setq selected entry))))
        (sal-pvs-prove)
        (should (equal (plist-get selected :name) "first"))))))

(ert-deftest sal-pvs-tcc-buttons-retain-distinct-goals ()
  (let ((source (generate-new-buffer "sal-ert-source")) target)
    (unwind-protect
        (with-current-buffer source
          (setq sal-pvs--description
                '(:syntax "SAL" :tccs ((:theory "T" :name "a" :source "/a.sal" :line 3 :text "TRUE")
                                       (:theory "T" :name "b" :source "/a.sal" :line 4 :text "FALSE"))))
          (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                    ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                    ((symbol-function 'display-buffer) #'ignore)
                    ((symbol-function 'sal-pvs--prove-entry) (lambda (_ entry) (setq target entry))))
            (sal-pvs-show-tccs)
            (with-current-buffer "*SAL TCCs: sal-ert-source*"
              (goto-char (point-min)) (search-forward "\na:")
              (button-activate (button-at (- (point) 2)))
              (should (equal (plist-get target :name) "a"))
              (search-forward "\nb:")
              (button-activate (button-at (- (point) 2)))
              (should (equal (plist-get target :name) "b")))))
      (kill-buffer source)
      (when (get-buffer "*SAL TCCs: sal-ert-source*") (kill-buffer "*SAL TCCs: sal-ert-source*")))))

(ert-deftest sal-pvs-toggle-works-during-proof ()
  (let ((sal-pvs-syntax-enabled t) connected)
    (cl-letf (((symbol-function 'sal-pvs--connect) (lambda (&optional during) (setq connected during)))
              ((symbol-function 'sal-pvs--request) (lambda (&rest _) "PVS")))
      (sal-pvs-toggle-syntax)
      (should connected)
      (should-not sal-pvs-syntax-enabled))))

(ert-deftest sal-pvs-rejects-dirty-buffer-before-proving ()
  (with-temp-buffer
    (insert "changed")
    (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore))
      (should-error (sal-pvs--prove-entry (current-buffer) '(:name "old")) :type 'user-error))))

(ert-deftest sal-pvs-proof-returns-to-live-import-source-buffer ()
  (let ((target (generate-new-buffer "sal-import-target")) sent send-options)
    (unwind-protect
        (with-temp-buffer
          (setq sal-pvs--description '(:key "view"))
          (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                    ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                    ((symbol-function 'find-file-noselect) (lambda (_) target))
                    ((symbol-function 'ilisp-switch-to-lisp) #'ignore)
                    ((symbol-function 'pvs-send) (lambda (&rest _) (ert-fail "Proof entry must not suppress process output")))
                    ((symbol-function 'ilisp-send)
                     (lambda (wire &rest options) (setq sent wire send-options options))))
            (sal-pvs--prove-entry (current-buffer)
                                 '(:source "/import.sal" :theory "T" :name "goal" :token "token"))
            (should (equal send-options '("SAL proof" pr t)))
            (let ((form (car (read-from-string sent))))
              (should (equal (nth 3 form) "goal"))
              (should (equal (nth 4 form) (buffer-name target)))
              (should (equal (nth 5 form) "token")))
            (with-current-buffer target (insert "unsaved dependency"))
            (should-error
             (sal-pvs--prove-entry (current-buffer) '(:source "/import.sal"))
             :type 'user-error)))
      (kill-buffer target))))

(ert-deftest sal-pvs-source-translation-roundtrip ()
  (let ((source (generate-new-buffer "sal-view-source"))
        (target (generate-new-buffer "sal-view-target")) (requests 0))
    (unwind-protect
        (save-window-excursion
          (with-current-buffer source
            (setq buffer-file-name "/source.sal" sal-pvs--description '(:key "selected-view"))
            (insert "SAL source") (set-buffer-modified-p nil) (goto-char 4))
          (with-current-buffer target
            (setq buffer-file-name "/generated.pvs")
            (insert "PVS translation") (set-buffer-modified-p nil) (goto-char 6))
          (switch-to-buffer source)
          (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                    ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                    ((symbol-function 'pvs-send-and-wait)
                     (lambda (wire &rest _)
                       (cl-incf requests)
                       (should (string-match-p "selected-view" wire)) "/generated.pvs"))
                    ((symbol-function 'file-readable-p) (lambda (_) t))
                    ((symbol-function 'get-file-buffer) (lambda (_) target))
                    ((symbol-function 'verify-visited-file-modtime) (lambda (_) t)))
            (sal-pvs-toggle-view)
            (should (eq (current-buffer) target))
            (should buffer-read-only)
            (should sal-pvs-translation-mode)
            (should (= (point) 6))
            (should (eq (key-binding (kbd "C-c C-v")) #'sal-pvs-toggle-view))
            (sal-pvs-toggle-view)
            (should (eq (current-buffer) source))
            (should (= (point) 4))
            (should (= requests 1))))
      (kill-buffer source) (kill-buffer target))))

(ert-deftest sal-pvs-translation-refresh-preserves-edits ()
  (let ((target (generate-new-buffer "sal-refresh-target")) (refreshes 0))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name "/source.sal" sal-pvs--description '(:key "view"))
          (with-current-buffer target
            (setq buffer-file-name "/generated.pvs")
            (insert "unsaved PVS edit"))
          (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                    ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                    ((symbol-function 'pvs-send-and-wait) (lambda (&rest _) "/generated.pvs"))
                    ((symbol-function 'file-readable-p) (lambda (_) t))
                    ((symbol-function 'get-file-buffer) (lambda (_) target))
                    ((symbol-function 'verify-visited-file-modtime) (lambda (_) nil))
                    ((symbol-function 'switch-to-buffer) #'ignore)
                    ((symbol-function 'revert-buffer)
                     (lambda (&rest _) (cl-incf refreshes) (erase-buffer) (insert "regenerated PVS")
                       (set-buffer-modified-p nil))))
            (should-error (sal-pvs-toggle-view) :type 'user-error)
            (should (= refreshes 0))
            (with-current-buffer target
              (should (equal (buffer-string) "unsaved PVS edit"))
              (set-buffer-modified-p nil))
            (sal-pvs-toggle-view)
            (should (= refreshes 1))
            (with-current-buffer target (should (equal (buffer-string) "regenerated PVS")))))
      (with-current-buffer target (set-buffer-modified-p nil))
      (kill-buffer target))))

(ert-deftest sal-pvs-view-key-installed-on-reload ()
  (should (eq (lookup-key sal-pvs-mode-map (kbd "C-c C-v")) #'sal-pvs-toggle-view)))

(ert-deftest sal-pvs-tcc-formula-with-commented-source ()
  (let ((source (generate-new-buffer "sal-tcc-source")))
    (unwind-protect
        (with-current-buffer source
          (setq sal-pvs--description
                '(:syntax "SAL" :tccs ((:theory "T" :name "goal" :source "/models/a.sal" :line 3
                                       :status "unproved" :source-expression "x' = x + 1\nAND y' = y"
                                       :text "FORALL (x: INTEGER):\n  x + 1 <= LIMIT"))))
          (cl-letf (((symbol-function 'sal-pvs--connect) #'ignore)
                    ((symbol-function 'sal-pvs--ensure-current) #'ignore)
                    ((symbol-function 'display-buffer) #'ignore))
            (sal-pvs-show-tccs)
            (with-current-buffer "*SAL TCCs: sal-tcc-source*"
              (should (equal (buffer-string)
                             "% a.sal:3\n% T.goal [unproved]\n% x' = x + 1\n% AND y' = y\ngoal: OBLIGATION\n  FORALL (x: INTEGER):\n    x + 1 <= LIMIT;\n\n"))
              (goto-char (point-min))
              (search-forward "a.sal:3")
              (should (button-at (1- (point))))
              (let (visited line)
                (cl-letf (((symbol-function 'find-file) (lambda (path) (setq visited path)))
                          ((symbol-function 'forward-line) (lambda (n) (setq line n))))
                  (button-activate (button-at (1- (point)))))
                (should (equal visited "/models/a.sal"))
                (should (= line 2)))
              (goto-char (point-min))
              (search-forward "FORALL")
              (should-not (invisible-p (1- (point)))))))
      (kill-buffer source)
      (when (get-buffer "*SAL TCCs: sal-tcc-source*")
        (kill-buffer "*SAL TCCs: sal-tcc-source*")))))

(ert-run-tests-batch-and-exit)
