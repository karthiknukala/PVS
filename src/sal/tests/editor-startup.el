;;; editor-startup.el --- Real PVS/Emacs transport smoke test -*- lexical-binding: t; -*-
;; Run with tools/start-editor.sh -batch -l /absolute/path/to/this/file.
(require 'cl-lib)
(defvar sal-editor-startup-evidence
  (expand-file-name "../.work/tests/editor-startup.result" (file-name-directory load-file-name)))
(write-region "STARTING\n" nil sal-editor-startup-evidence nil 'silent)
(advice-add 'kill-emacs :before
            (lambda (&rest _)
              (when (get-buffer "*pvs*")
                (with-current-buffer "*pvs*"
                  (write-region (max (point-min) (- (point-max) 8000)) (point-max)
                                (concat sal-editor-startup-evidence ".pvs-log") nil 'silent)))))
(set-buffer (or (get-buffer "bounded_counter.sal") (error "Counter source buffer was not opened")))
(unless (bound-and-true-p sal-pvs-mode) (error "SAL minor mode was not enabled"))
(setq sal-pvs-module "counter")
(write-region "TYPECHECKING\n" nil sal-editor-startup-evidence t 'silent)
(with-timeout (90 (error "SAL/PVS typecheck transport timed out"))
  (sal-pvs-typecheck))
(write-region "TYPECHECKED\n" nil sal-editor-startup-evidence t 'silent)
(unless (plist-get sal-pvs--description :tccs) (error "No TCCs returned over PVS transport"))
(unless (equal (plist-get sal-pvs--description :syntax) "SAL") (error "SAL display not enabled"))
(unless (cl-find "sal_bounded" (plist-get sal-pvs--description :formulas)
                 :key (lambda (e) (plist-get e :name)) :test #'equal)
  (error "Missing source theorem over PVS transport"))
(let ((source (current-buffer)) (position (point)))
  (sal-pvs-toggle-view)
  (unless (and sal-pvs-translation-mode buffer-read-only
               (equal (file-name-extension buffer-file-name) "pvs")
               (save-excursion (goto-char (point-min)) (search-forward "sal_bounded" nil t)))
    (error "Generated PVS translation was not displayed"))
  (sal-pvs-toggle-view)
  (unless (and (eq (current-buffer) source) (= (point) position))
    (error "Toggle did not return to the original SAL buffer/position")))
(write-region "VIEW-ROUNDTRIP-PASSED\n" nil sal-editor-startup-evidence t 'silent)
(sal-pvs-show-tccs)
(unless (get-buffer "*SAL TCCs: bounded_counter.sal*") (error "TCC buffer not displayed"))
(with-current-buffer "*SAL TCCs: bounded_counter.sal*"
  (unless (and (eq (char-after (point-min)) ?%)
               (save-excursion (goto-char (point-min))
                               (search-forward "check_step_5_TCC1: OBLIGATION" nil t)
                               (search-forward "FORALL (" nil t))
               (not (string-match-p "SAL/PVS TCCs\\|Assuming all of:\\|Full formula" (buffer-string))))
    (error "Expected ordinary formula listing with commented source metadata"))
  (write-region (point-min) (point-max)
                (concat sal-editor-startup-evidence ".tccs") nil 'silent))
;; Exercise the real interactive transport, not just the Lisp proof entry.
(defun sal-editor-test-await (predicate description)
  (let ((deadline (+ (float-time) 15)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.1))
    (unless (funcall predicate) (error "Timed out waiting for %s" description))))

(let* ((source (get-buffer "bounded_counter.sal"))
       (entries (with-current-buffer source sal-pvs--description)))
  (pvs-send-and-wait
   "(setq pvs::*proof-prompt-behavior* :noquestions pvs::*quit-prompt-behavior* :noquestions)"
   nil nil)
  (dolist (entry (list (cl-find "check_step_5_TCC1" (plist-get entries :tccs)
                               :key (lambda (e) (plist-get e :name)) :test #'equal)
                      (car (plist-get entries :formulas))))
    (let ((start (with-current-buffer "*pvs*" (point-max)))
          (name (plist-get entry :name)))
      (let ((noninteractive nil)) (sal-pvs--prove-entry source entry))
      (unwind-protect
          (progn
            (sal-editor-test-await
             (lambda ()
               (with-current-buffer "*pvs*"
                 (let ((output (buffer-substring-no-properties start (point-max))))
                   (and (string-match-p (regexp-quote name) output)
                        (string-match-p (regexp-quote "SAL/{1}") output)
                        (not (string-match-p "Experimental SAL syntax" output))
                        (string-match-p "Rule?" output)))))
             (concat "visible initial proof state for " name))
            (when (equal name "check_step_5_TCC1")
              (let ((step-start (with-current-buffer "*pvs*" (point-max))))
                (comint-simple-send (ilisp-process) "(skosimp*)")
                (sal-editor-test-await
                 (lambda ()
                   (with-current-buffer "*pvs*"
                     (string-match-p (regexp-quote "SAL/{-1}")
                                     (buffer-substring-no-properties step-start (point-max)))))
                 "visible transformed SAL proof state"))
              (let ((step-start (with-current-buffer "*pvs*" (point-max))))
                (comint-simple-send (ilisp-process) "(sal-syntax nil)")
                (sal-editor-test-await
                 (lambda ()
                   (with-current-buffer "*pvs*"
                     (let ((text (buffer-substring-no-properties step-start (point-max))))
                       (and (string-match-p "SAL-origin display: PVS" text)
                            (not (string-match-p "SAL/" text))
                            (string-match-p "sal_count" text)))))
                 "native PVS syntax without SAL labels"))
              (let ((step-start (with-current-buffer "*pvs*" (point-max))))
                (comint-simple-send (ilisp-process) "(sal-syntax t)")
                (sal-editor-test-await
                 (lambda ()
                   (with-current-buffer "*pvs*"
                     (string-match-p "SAL/" (buffer-substring-no-properties step-start (point-max)))))
                 "restored SAL syntax")))
            (unless (get-buffer-window "*pvs*" t)
              (error "Prover buffer was not displayed"))
            (write-region (concat "INITIAL-PROOF-VISIBLE " name "\n") nil
                          sal-editor-startup-evidence t 'silent))
        (comint-simple-send (ilisp-process) "(quit)")
        (sal-editor-test-await (lambda () (not pvs-in-checker)) "proof exit")))))
(message "SAL-EDITOR-STARTUP-PASSED")
(write-region "SAL-EDITOR-STARTUP-PASSED\n" nil sal-editor-startup-evidence t 'silent)
