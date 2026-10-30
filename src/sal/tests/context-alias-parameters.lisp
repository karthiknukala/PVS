;;; Loaded by parameters.lisp after the shared parameter test helpers.
(in-package :pvs)

(defun sal-test-unused-context-alias-actuals ()
  (let* ((view (sal-open-context (sal-parameter-source "parameter_alias_checks")
                                 :output-directory (sal-parameter-output "unused-context-aliases")))
         (source (truename (sal-parameter-source "parameter_alias_checks")))
         (obligations
          (remove-if-not
           (lambda (obligation)
             (and (search "check_module" (sal-source-obligation-name obligation)
                          :test #'char-equal)
                  (sal-source-place-p (sal-source-obligation-place obligation))
                  (= 4 (sal-source-place-initial-line
                        (sal-source-obligation-place obligation)))))
           (sal-transition-view-tccs view))))
    (sal-parameter-theory view)
    (sal-test (null (sal-transition-view-flat-module view))
              "context alias parameter checking needs no artificial machine")
    (sal-test (= 2 (length (sal-transition-view-contexts view)))
              "unused alias retains its generic library dependency")
    (sal-test obligations
              "unused out-of-domain context actual retains a native PVS TCC")
    (sal-test (some (lambda (obligation)
                      (and (equal source (truename (sal-source-obligation-source obligation)))
                           (sal-source-place-p (sal-source-obligation-place obligation))
                           (= 4 (sal-source-place-initial-line
                                 (sal-source-obligation-place obligation)))))
                    obligations)
              "unused context actual TCC points to the source alias declaration")
    (sal-test (some (lambda (obligation)
                      (not (proved? (sal-source-obligation-declaration obligation))))
                    obligations)
              "invalid unused context argument is not assumed valid")
    (sal-test (search (namestring source)
                      (with-output-to-string (stream) (sal-show-obligations view stream)))
              "source-level TCC display includes the context alias file")))
