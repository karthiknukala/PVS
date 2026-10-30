;;; Standard Org/Beamer export; no custom exporter or Babel execution.
(defvar sal-doc-export-root
  (file-name-directory (or load-file-name buffer-file-name)))
(setq temporary-file-directory (expand-file-name ".build/tmp/" sal-doc-export-root)
      org-persist-directory (expand-file-name ".build/org-persist/" sal-doc-export-root))
(require 'cl-lib)
(setq native-comp-jit-compilation nil
      native-comp-deferred-compilation nil
      make-backup-files nil auto-save-default nil create-lockfiles nil
      enable-local-variables nil)
(require 'package)
(package-initialize)
(dolist (variable '("PVS_EMACS_DIR" "SAL_EMACS_DIR"))
  (add-to-list 'load-path (or (getenv variable) (error "Set %s" variable))))
(require 'pvs-mode)
(require 'sal-mode)
(require 'engrave-faces-latex)
(require 'ox-beamer)
(setq org-latex-src-block-backend 'engraved
      org-latex-remove-logfiles nil
      org-export-use-babel nil
      org-export-with-broken-links nil
      org-latex-pdf-process
      '("latexmk -pdf -interaction=nonstopmode -halt-on-error -file-line-error -outdir=%o %f"))
(let* ((root (file-name-directory (or load-file-name buffer-file-name)))
       (build (expand-file-name ".build/" root))
       (source (expand-file-name "sal-pvs-tutorial.org" root))
       (tex (expand-file-name "sal-pvs-tutorial.tex" build)))
  (make-directory build t)
  (setq temporary-file-directory build)
  (find-file source)
  (org-export-to-file 'beamer tex)
  (let ((pdf (org-latex-compile tex)))
    (unless (file-exists-p pdf) (error "Org did not create the Beamer PDF"))
    (copy-file pdf (expand-file-name "sal-pvs-tutorial.pdf" root) t)
    (copy-file tex (expand-file-name "sal-pvs-tutorial.tex" root) t)
    (message "SAL-PVS-SLIDES-EXPORTED: %s" pdf)))
