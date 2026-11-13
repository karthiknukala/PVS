;;; Construct-level checks, regenerated with different source names.
(in-package :pvs)

(defun sal-selection-typing-regressions (root)
  (dolist (module '("safe" "bad"))
    (let* ((view (sal-open (merge-pathnames "examples/integration/selection_typing.sal"
                                          *sal-bridge-directory*)
                           module :translation :modular :progress-checks nil :register nil
                           :output-directory (merge-pathnames (format nil "selection-~a/" module) root)))
           (name (sal-transition-view-theory-name view))
           (obligation (find-if (lambda (o) (and (search "selection" (sal-source-obligation-name o))
                                                (sal-source-obligation-place o)
                                                (eq (module (sal-source-obligation-declaration o))
                                                    (get-typechecked-theory name))))
                                (sal-transition-view-tccs view))))
      (sal-test obligation "selection predicate has its own source-linked domain TCC")
      (sal-test-prove name (sal-source-obligation-name obligation) '(grind)
                      :expect-complete (equal module "safe")))))

(defun sal-structural-regressions (root &key (start 1))
  (loop for body in
    '("part[k: BOOLEAN]: MODULE = BEGIN LOCAL datum: BOOLEAN INITIALIZATION datum = k TRANSITION datum' = NOT datum END;
       assembly: MODULE = part[FALSE] || part[TRUE];"
      "part[k: BOOLEAN]: MODULE = BEGIN LOCAL datum: BOOLEAN INITIALIZATION datum = k TRANSITION datum' = NOT datum END;
       assembly: MODULE = (|| (idx: BOOLEAN): part[idx]);"
      "part: MODULE = BEGIN GLOBAL datum: BOOLEAN INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END;
       peer: MODULE = BEGIN OUTPUT extra: BOOLEAN INITIALIZATION extra = TRUE TRANSITION extra' = NOT extra END;
       assembly: MODULE = part [] peer;"
      "part: MODULE = BEGIN GLOBAL datum: BOOLEAN INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END;
       assembly: MODULE = OUTPUT datum IN part;"
      "part: MODULE = BEGIN OUTPUT datum: BOOLEAN INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END;
       assembly: MODULE = RENAME datum TO renamed IN (LOCAL datum IN part);"
      "assembly: MODULE = WITH OUTPUT spare: BOOLEAN
         (BEGIN OUTPUT datum: BOOLEAN INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END);"
      "assembly: MODULE = BEGIN INPUT choose: BOOLEAN OUTPUT datum: BOOLEAN
         INITIALIZATION datum = FALSE
         TRANSITION [ TRUE --> datum' IN IF choose THEN {TRUE} ELSE {FALSE} ENDIF ] END;"
      "part: MODULE = BEGIN OUTPUT datum: BOOLEAN INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END;
       monitor: MODULE = BEGIN INPUT datum: BOOLEAN OUTPUT extra: BOOLEAN
          DEFINITION extra = datum END;
       assembly: MODULE = OBSERVE part WITH monitor;"
      "Judgement: TYPE = BOOLEAN;
       assembly: MODULE = BEGIN OUTPUT datum: Judgement INITIALIZATION datum = FALSE TRANSITION datum' = NOT datum END;
       eventual: THEOREM assembly |- AG(AF(datum));"
      "part[k: BOOLEAN]: MODULE = BEGIN LOCAL datum: BOOLEAN INITIALIZATION datum = k TRANSITION datum' = NOT datum END;
       assembly: MODULE = ([] (idx: BOOLEAN): part[idx]);"
      "part[k: BOOLEAN]: MODULE = BEGIN LOCAL datum: BOOLEAN INITIALIZATION datum = k TRANSITION datum' = NOT datum END;
       assembly: MODULE = part[FALSE] || (part[TRUE] || part[FALSE]);"
      "part[k: BOOLEAN]: MODULE = BEGIN OUTPUT datum: BOOLEAN INITIALIZATION datum = k TRANSITION datum' = NOT datum END;
       assembly: MODULE = WITH OUTPUT cells: ARRAY BOOLEAN OF BOOLEAN
         (|| (idx: BOOLEAN): RENAME datum TO cells[idx] IN part[idx]);"
      "blank: MODULE = BEGIN END;
       assembly: MODULE = blank || blank;")
    for number from 1 when (>= number start) do
      (dolist (salt '(17 53))
        (let* ((name (format nil "wiring_~d_~d_system" number salt))
               (directory (merge-pathnames (format nil "~a/" name) root))
               (file (merge-pathnames (format nil "~a.sal" name) directory))
               (source (with-output-to-string (out)
                         (format out "~a: CONTEXT = BEGIN~%" name)
                         (loop for start = 0 then (+ pos 5)
                               for pos = (search "datum" body :start2 start) do
                                 (write-string body out :start start :end pos)
                               while pos do (format out "signal_~d" salt))
                         (format out "~%END~%"))))
          (sal-write-file-if-changed file source)
          (let* ((structured (sal-open file "assembly" :translation :modular
                                      :output-directory directory :register nil :progress-checks nil))
                 (flat (sal-open file "assembly" :translation :flat
                                :output-directory directory :register nil :progress-checks nil))
                 (comparison (sal-write-modular-comparison structured flat directory)))
            (typecheck-file (pathname-name comparison))
            (sal-test-type-tccs structured)
            (sal-test-type-tccs flat)
            (dolist (tcc (collect-tccs (get-typechecked-theory (pathname-name comparison))))
              (sal-test-prove (pathname-name comparison) (string (id tcc)) '(grind)))
            (dolist (relation '("defined" "initial" "step" "idle"))
              (sal-test-prove (pathname-name comparison) (concatenate 'string relation "_equivalent")
                ;; Match existential witnesses against the other side, then
                ;; exhaust the Boolean family index. Unrestricted matching can
                ;; choose an entire Boolean formula as the index term.
                '(then (grind :if-match nil)
                       (inst? + :where - :if-match t)
                       (grind :if-match nil)
                       (inst-cp - "TRUE") (inst - "FALSE")
                       (grind :if-match nil)))))))))
