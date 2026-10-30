;;; Shared setup for extraction and fresh-process proof replay.
(in-package :pvs)
(let ((root (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
  (load (merge-pathnames "load.lisp" root))
  (load (merge-pathnames "tests/support.lisp" root)))
(setq *proof-prompt-behavior* :noquestions *proceed-without-asking* t
      *noninteractive* t *noninteractive-timeout* 60)

(defun sal-reverse-output (name)
  (merge-pathnames (format nil "~a/" name)
                  (uiop:ensure-directory-pathname
                   (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT"))))

(defun sal-reverse-context (&key prepare)
  (let ((directory (sal-reverse-output "context")))
    (when prepare
      (dolist (source (append
                      (directory (merge-pathnames "examples/reverse/*.pvs"
                                                  *sal-bridge-directory*))
                      (mapcar (lambda (name)
                                (merge-pathnames (format nil "theories/~a.pvs" name)
                                                 *sal-bridge-directory*))
                              '("SAL_Transition_System" "SAL_Transition_View"))))
        (sal-write-file-if-changed
         (merge-pathnames (file-namestring source) directory)
         (uiop:read-file-string source))))
    (change-context (namestring directory))
    directory))

(defun sal-reverse-typecheck (file &optional (theory file))
  (typecheck-file file)
  (let ((th (get-typechecked-theory theory)))
    (sal-test (and th (typechecked? th))
              (format nil "native PVS theory ~a typechecks" theory))
    th))

(defun sal-reverse-tccs (theory &key replay)
  (let ((th (get-typechecked-theory theory)))
    (dolist (dependency (remove-duplicates (cons th (all-importings th)) :test #'eq))
      (unless (from-prelude? dependency)
        (dolist (tcc (collect-tccs dependency))
          (if replay
              (progn
                (sal-test (justification tcc)
                          (format nil "saved native TCC ~a.~a"
                                  (id dependency) (id tcc)))
                (sal-test (eq (status-flag
                              (prove-decl tcc :strategy '(then (rerun) (quit)))) '!)
                          (format nil "fresh native TCC replay ~a.~a"
                                  (id dependency) (id tcc))))
              (sal-test-prove (string (id dependency)) (string (id tcc)) '(grind))))))))

(defun sal-reverse-extract (theory formula)
  (let* ((id (format nil "~a.~a" theory formula))
         (extraction (sal-extract-pvs theory formula
                                     :output-directory (sal-reverse-output id)))
         (target (sal-pvs-extraction-target extraction)))
    (sal-test (and target (equal id (sal-proof-target-id target)))
              (format nil "exact native theorem registered: ~a" id))
    (sal-test (probe-file (sal-pvs-extraction-source extraction))
              (format nil "readable SAL artifact retained: ~a" id))
    extraction))

(defun sal-reverse-saved-proof (theory name)
  (let* ((th (get-typechecked-theory theory))
         (decl (find name (theory th)
                     :key (lambda (d) (if (formula-decl? d) (string (id d)) ""))
                     :test #'string=)))
    (sal-test (and decl (justification decl))
              (format nil "saved native model-checker proof ~a.~a" theory name))
    (sal-test (eq (status-flag (prove-decl decl :strategy '(then (rerun) (quit)))) '!)
              (format nil "fresh native model-checker replay ~a.~a" theory name))))
