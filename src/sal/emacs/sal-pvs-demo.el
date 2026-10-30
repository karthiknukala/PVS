;;; sal-pvs-demo.el --- Configure the isolated SAL demo -*- lexical-binding: t; -*-
;; Loaded after PVS initialization by tools/start-editor.sh.
(let* ((here (file-name-directory (or load-file-name buffer-file-name)))
       (bridge (expand-file-name ".." here))
       (sal-home (or (getenv "SAL_HOME") (error "Set SAL_HOME before starting PVS"))))
  (load (expand-file-name "etc/sal-mode.el" sal-home) nil t)
  (load (expand-file-name "sal-pvs-mode.el" here) nil t)
  (add-to-list 'auto-mode-alist '("\\.sal\\'" . sal-mode))
  (add-hook 'sal-mode-hook #'sal-pvs-mode)
  (find-file (expand-file-name "examples/bounded_counter.sal" bridge))
  (message "SAL demo ready: C-c C-t (counter), C-c C-q (TCCs), C-c C-p (prove)."))
