;;; Load after demo.lisp, using run-demo.sh. All writes stay under doc/.
;;; Regenerate the complete source/output pairs used by the tutorial slides.
(in-package :pvs)

(defun sal-doc-copy-counterpart (source directory)
  (let ((target (merge-pathnames (file-namestring source) directory)))
    (ensure-directories-exist target)
    (sal-write-file-if-changed target (uiop:read-file-string source))))

(dolist (entry '(("integration/library_counter.sal" "machine" "counter")
                 ("integration/terminal_deadlock.sal" "machine" "terminal")
                 ("integration/record_array.sal" "machine" "record-array")
                 ("parameters/parameter_machine.sal" "cell" "parameters")))
  (destructuring-bind (source module tag) entry
    (let* ((view (sal-doc-open source module
                              (concatenate 'string "counterparts-" tag)))
           (destination (merge-pathnames (format nil "counterparts/~a/" tag)
                                         *sal-doc-directory*)))
      (dolist (file (append (list (sal-transition-view-source view)
                                 (sal-transition-view-pvs-file view))
                           (sal-transition-view-context-pvs-files view)
                           (list (merge-pathnames "../theories/SAL_Transition_System.pvs"
                                                  *sal-doc-directory*))))
        (sal-doc-copy-counterpart file destination)))))

(sal-doc-native "Reverse_Counter")
(let* ((extraction (sal-extract-pvs
                    "Reverse_Counter" "safe"
                    :output-directory
                    (merge-pathnames ".demo/counterparts-reverse/"
                                     *sal-doc-directory*)))
       (destination (merge-pathnames "counterparts/reverse/" *sal-doc-directory*)))
  (sal-doc-copy-counterpart (sal-pvs-extraction-source extraction) destination)
  (dolist (name '("Reverse_Counter.pvs" "Reverse_Counter_Library.pvs"
                  "SAL_Transition_View.pvs" "SAL_Transition_System.pvs"))
    (sal-doc-copy-counterpart
      (merge-pathnames (concatenate 'string ".demo/native/" name) *sal-doc-directory*)
      destination)))

(format t "~&SAL-TUTORIAL-COUNTERPARTS-EXPORTED~%")
