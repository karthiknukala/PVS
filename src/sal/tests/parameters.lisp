;;; Focused frontend regression tests. Run only through the extension-local runner.
(in-package :pvs)
(let ((root (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))
  (load (merge-pathnames "load.lisp" root))
  (load (merge-pathnames "tests/support.lisp" root)))
(setq *proof-prompt-behavior* :noquestions *proceed-without-asking* t
      *noninteractive* t *noninteractive-timeout* 60)

(defun sal-parameter-source (name)
  (merge-pathnames (format nil "examples/parameters/~a.sal" name) *sal-bridge-directory*))

(defun sal-parameter-output (name)
  (merge-pathnames (format nil "~a/" name)
                   (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_TEST_OUTPUT"))))

(defun sal-parameter-open (name module output &rest options)
  (apply #'sal-open (sal-parameter-source name) module
         :output-directory (sal-parameter-output output)
         :progress-checks nil :register nil options))

(defun sal-parameter-theory (view)
  (let ((theory (get-typechecked-theory (sal-transition-view-theory-name view))))
    (sal-test (and theory (typechecked? theory)) "parameter fixture typechecked")
    theory))

(defun sal-parameter-formal-names (theory)
  (mapcar (lambda (formal) (string (id formal)))
          (remove-if #'importing-param? (formals theory))))

(defun sal-parameter-register (view key)
  (sal-register-proof-target
   key (sal-transition-view-theory-name view) (sal-pvs-name "bounded")
   (sal-transition-view-source view) "bounded" :view view
   :module (sal-transition-view-module-name view)
   :dependencies (sal-transition-view-dependency-files view)))

(defun sal-test-generic-parameters ()
  (let* ((view (sal-parameter-open "parameter_machine" "cell" "generic"))
         (theory (sal-parameter-theory view)))
    (sal-test (= 2 (length (params (sal-transition-view-context view))))
              "type and value context formals survive native export")
    (sal-test (= 2 (length (sal-transition-view-module-parameters view)))
              "module value formals survive native export")
    (sal-test (equal (mapcar #'sal-pvs-name '("T" "Limit" "seed" "initial_count"))
                     (sal-parameter-formal-names theory))
              "context and module names survive as shallow PVS theory parameters")
    (sal-test (not (sal-transition-view-instantiated-p view))
              "generic view is not silently given concrete defaults")
    (sal-test (null (sal-transition-view-selector view))
              "generic view retains symbolic selection")
    (sal-test (sal-snapshots-current-p (sal-transition-view-source-snapshots view))
              "generic source snapshot is current")))

(defun sal-test-concrete-parameters ()
  (let* ((boolean (sal-parameter-open "parameter_machine" "cell" "concrete-boolean"
                                     :context-actuals '("BOOLEAN" "2")
                                     :module-actuals '("FALSE" "0")))
         (boolean-text (sal-transition-view-pvs-text boolean)))
    (sal-test (null (formals (sal-parameter-theory boolean)))
              "explicit context and module actuals close the generated theory")
    (sal-test (sal-transition-view-instantiated-p boolean)
              "explicit actual arguments request native SAL instantiation")
    (sal-test (string= "parameter_machine{BOOLEAN, 2}!cell[FALSE, 0]"
                       (sal-transition-view-selector boolean))
              "native selector preserves both argument lists")
    (sal-test (= 2 (length (sal-transition-view-root-actuals boolean)))
              "type and value actuals retained for the context interpretation")
    (let ((natural (sal-parameter-open "parameter_machine" "cell" "concrete-natural"
                                       :selector "parameter_machine{NATURAL, 3}!cell[7, 1]")))
      (sal-test (null (formals (sal-parameter-theory natural)))
                "qualified selector also produces a closed theory")
      (sal-test (not (string= (sal-view-key boolean) (sal-view-key natural)))
                "distinct concrete instances have distinct view identities")
      (sal-test (not (string= boolean-text (sal-transition-view-pvs-text natural)))
                "concrete type/value/module arguments affect the shallow theory"))))

(defun sal-test-library-parameters ()
  (let ((view (sal-open-context (sal-parameter-source "parameter_leaf")
                                :output-directory (sal-parameter-output "library"))))
    (sal-test (= 2 (length (formals (sal-parameter-theory view))))
              "library-only context retains type and value formals")
    (sal-test (null (sal-transition-view-flat-module view))
              "library-only context needs no artificial transition machine")
    (sal-test (= 1 (length (sal-transition-view-context-pvs-files view)))
              "library-only context emits one shallow theory")))

(defun sal-test-diamond-dependencies ()
  (let* ((view (sal-parameter-open "parameter_diamond" "system" "diamond"))
         (contexts (sal-transition-view-contexts view))
         (names (mapcar #'sal-declaration-name contexts))
         (files (mapcar #'truename (sal-transition-view-dependency-files view))))
    (sal-parameter-theory view)
    (sal-test (= 4 (length contexts)) "diamond closure contains root, two branches, and one leaf")
    (sal-test (= 4 (length (remove-duplicates names :test #'string=)))
              "shared transitive library is imported once")
    (dolist (name '("parameter_leaf" "parameter_left" "parameter_right" "parameter_diamond"))
      (sal-test (member (truename (sal-parameter-source name)) files :test #'equal)
                (format nil "source closure contains ~a" name)))
    (sal-test (and (< (position "parameter_leaf" names :test #'string=)
                     (position "parameter_left" names :test #'string=))
                   (< (position "parameter_leaf" names :test #'string=)
                      (position "parameter_right" names :test #'string=)))
              "dependency theories are ordered before their importers")
    (sal-test (sal-proof-target-p (sal-parameter-register view "parameter-diamond"))
              "concrete dependency closure can be registered as a proof target")))

(defun sal-test-distinct-import-actuals ()
  (let ((view (sal-parameter-open "parameter_instances" "system" "instances")))
    (sal-test (null (formals (sal-parameter-theory view)))
              "different interpretations of one library produce a closed machine")
    (sal-test (= 2 (length (sal-transition-view-contexts view)))
              "multiple library instances share one parameterized source theory")
    (sal-test (assoc "bounded" (sal-transition-view-properties view) :test #'string=)
              "property over both library instances survives export")
    (sal-test (sal-proof-target-p (sal-parameter-register view "parameter-instances"))
              "property with distinct library actuals can be registered")
    ;; The same input 2 must wrap at bound 2 and increment at bound 4. These
    ;; theorems check the actual translated transition, not just rendered text.
    (let* ((theory "Parameter_Instance_Semantics")
           (file (merge-pathnames (concatenate 'string theory ".pvs")
                                  (sal-parameter-output "instances")))
           (small (sal-pvs-name "small_count"))
           (large (sal-pvs-name "large_count")))
      (sal-write-file-if-changed
       file
       (format nil "~a: THEORY~%BEGIN~%  IMPORTING ~a~%  current: State = (# ~a := 2, ~a := 2 #)~%  expected: State = (# ~a := 0, ~a := 3 #)~%  conflated: State = (# ~a := 0, ~a := 0 #)~%  two_actuals_step: THEOREM step(current, expected)~%  instances_not_conflated: THEOREM NOT step(current, conflated)~%END ~a~%"
               theory (sal-transition-view-theory-name view)
               small large small large small large theory))
      (typecheck-file (pathname-name file) nil nil nil)
      (sal-test-prove theory "two_actuals_step" '(grind))
      (sal-test-prove theory "instances_not_conflated" '(grind)))))

(defun sal-test-selector-only-dependency ()
  (let* ((view (sal-parameter-open
                "parameter_machine" "cell" "selector-dependency"
                :selector "parameter_machine{parameter_selector!Value, parameter_selector!limit}!cell[parameter_selector!seed, 0]"))
         (names (mapcar #'sal-declaration-name (sal-transition-view-contexts view))))
    (sal-test (null (formals (sal-parameter-theory view)))
              "selector-only dependency produces a closed concrete theory")
    (sal-test (equal names '("parameter_machine" "parameter_selector"))
              "root context precedes selector-only context that imports it")
    (sal-test (member (truename (sal-parameter-source "parameter_selector"))
                      (mapcar #'truename (sal-transition-view-dependency-files view)) :test #'equal)
              "selector-only source is in the complete dependency closure")
    (sal-test (assoc (namestring (truename (sal-parameter-source "parameter_selector")))
                     (sal-transition-view-source-snapshots view) :test #'string=)
              "selector-only source is protected by admission snapshots"))
  (let ((view (sal-parameter-open
               "parameter_machine" "cell" "module-actual-dependency"
               :selector "parameter_machine{NATURAL, 3}!cell[parameter_selector!seed, 0]")))
    (sal-test (null (formals (sal-parameter-theory view)))
              "source used only by a module actual is imported into the closed theory")
    (sal-test (member "parameter_selector"
                      (mapcar #'sal-declaration-name (sal-transition-view-contexts view))
                      :test #'string=)
              "module-actual-only dependency survives export and elaboration")))

(defun sal-test-generic-companion-theories ()
  (let* ((view (sal-open (sal-parameter-source "parameter_machine") "cell"
                         :output-directory (sal-parameter-output "generic-contracts")
                         :progress-checks t :causality-checks t :register nil))
         (expected (sal-parameter-formal-names (sal-parameter-theory view))))
    (dolist (name (list (sal-transition-view-progress-theory-name view)
                        (sal-transition-view-causality-theory-name view)))
      (let ((theory (and name (get-typechecked-theory name))))
        (sal-test (and theory (typechecked? theory))
                  (format nil "generic companion theory ~a typechecks" name))
        (sal-test (equal expected (sal-parameter-formal-names theory))
                  (format nil "generic companion ~a preserves parameter names" name))))))

(defun sal-test-dependency-tcc-origins ()
  (let* ((view (sal-parameter-open "parameter_bad_parent" "system" "dependency-tcc"))
         (leaf (truename (sal-parameter-source "parameter_bad_leaf")))
         (obligations
          (remove-if-not
           (lambda (obligation)
             (and (equal leaf (truename (sal-source-obligation-source obligation)))
                  (search "overflow" (sal-source-obligation-name obligation)
                          :test #'char-equal)))
           (sal-transition-view-tccs view))))
    (sal-parameter-theory view)
    (sal-test obligations "imported partial function retains its native PVS TCC")
    (sal-test (every (lambda (o)
                       (and (sal-source-place-p (sal-source-obligation-place o))
                            (= 6 (sal-source-place-initial-line (sal-source-obligation-place o)))
                            (search "overflow" (or (sal-source-obligation-source-expression o) "")
                                    :test #'char-equal))) obligations)
              "dependency TCCs retain the declaring SAL line and expression")
    (sal-test (search (namestring leaf)
                      (with-output-to-string (stream) (sal-show-obligations view stream)))
              "source-level obligation display names the dependency file")
    (sal-test (some (lambda (o) (not (proved? (sal-source-obligation-declaration o)))) obligations)
              "deliberately partial imported function is not assumed proved")))

(defun sal-test-dependency-mutation-guard ()
  ;; Mutate only private test copies. Even a semantics-preserving comment must
  ;; invalidate an admission snapshot; the original example files never change.
  (let* ((sources (sal-parameter-output "mutation-sources"))
         (names '("parameter_leaf" "parameter_left" "parameter_right" "parameter_diamond"))
         (leaf (merge-pathnames "parameter_leaf.sal" sources)))
    (dolist (name names)
      (sal-write-file-if-changed (merge-pathnames (format nil "~a.sal" name) sources)
                                 (uiop:read-file-string (sal-parameter-source name))))
    (let* ((source (merge-pathnames "parameter_diamond.sal" sources))
           (view (sal-open source "system" :output-directory (sal-parameter-output "mutation-view")
                           :progress-checks nil :register nil))
           (target (sal-parameter-register view "parameter-mutation-before"))
           (original (uiop:read-file-string leaf)))
      (sal-test (sal-proof-target-p target) "snapshot guard baseline target registers")
      (unwind-protect
          (progn
            (sal-write-file-if-changed leaf (concatenate 'string original (format nil "~%% snapshot test~%")))
            (sal-test (not (sal-snapshots-current-p (sal-transition-view-source-snapshots view)))
                      "transitive dependency mutation invalidates frontend snapshot")
            (sal-test (search "changed" (or (sal-target-refusal target nil) ""))
                      "existing proof target refuses a changed transitive source")
            (sal-test
             (handler-case
                 (progn (sal-parameter-register view "parameter-mutation-after") nil)
               (error (condition)
                 (search "does not belong" (princ-to-string condition))))
             "registration rejects a stale generated view"))
        (sal-write-file-if-changed leaf original))
      (sal-test (sal-snapshots-current-p (sal-transition-view-source-snapshots view))
                "private dependency copy restored after mutation regression"))))

(load (merge-pathnames "tests/ring-parameters.lisp" *sal-bridge-directory*))
(load (merge-pathnames "tests/temporal-parameters.lisp" *sal-bridge-directory*))
(load (merge-pathnames "tests/module-parameters.lisp" *sal-bridge-directory*))
(load (merge-pathnames "tests/context-alias-parameters.lisp" *sal-bridge-directory*))

(let ((failures nil))
  (dolist (test '(sal-test-generic-parameters sal-test-concrete-parameters
                 sal-test-library-parameters sal-test-diamond-dependencies
                 sal-test-distinct-import-actuals sal-test-dependency-tcc-origins
                 sal-test-dependency-mutation-guard sal-test-selector-only-dependency
                 sal-test-generic-companion-theories sal-test-imported-ring-actuals
                 sal-test-imported-temporal-macros sal-test-unused-module-actuals
                 sal-test-unused-context-alias-actuals))
    (format t "~&SAL-PARAMETER-TEST-BEGIN ~a~%" test)
    (force-output)
    (handler-case (funcall test)
      (error (condition)
        (push (cons test (princ-to-string condition)) failures)
        (format t "~&SAL-PARAMETER-TEST-FAILED ~a: ~a~%" test condition)))
    (force-output))
  (if failures
      (format t "~&SAL-PARAMETER-TESTS-FAILED: ~d groups~%" (length failures))
      (format t "~&SAL-PARAMETER-TESTS-PASSED~%")))
