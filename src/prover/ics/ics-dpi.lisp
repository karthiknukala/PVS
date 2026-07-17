;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ics-dpi.lisp --
;;   SBCL-safe PVS decision-procedure-interface bridge to the ICS engine.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(in-package :pvs)

;; ICS ships an Allegro-style FF binding file, but this PVS build is owned by
;; SBCL.  This bridge therefore uses the ICS executable and the regular PVS
;; decision-procedure-interface state protocol.  The boundary is intentionally
;; conservative: unsupported atoms are ignored by ICS and left to the rest of
;; the prover.

(defparameter *ics-home* nil
  "Root of the local ICS checkout.  NIL means $ICS_HOME or ~/git/ICS.")

(defparameter *ics-binary* nil
  "Explicit path to the ICS executable.  NIL means search under *ICS-HOME*.")

(defparameter *ics-keep-temp-files* nil)
(defparameter *ics-verbose* nil)

(defvar *ics-last-input* nil)
(defvar *ics-last-output* nil)
(defvar *ics-last-error-output* nil)
(defvar *ics-witness-counter* 0)

(defstruct (ics-dpi-state (:constructor make-ics-dpi-state
                                        (&key assertions props
                                              (generation 0))))
  assertions
  props
  generation)

(defstruct (ics-formula (:constructor make-ics-formula (kind text)))
  kind
  text)

(defun ics-atom (text)
  (make-ics-formula :atom text))

(defun ics-prop (text)
  (make-ics-formula :prop text))

(defun ics-formula-atom-p (formula)
  (and (ics-formula-p formula)
       (eq (ics-formula-kind formula) :atom)))

(defun ics-formula-prop-p (formula)
  (and (ics-formula-p formula)
       (eq (ics-formula-kind formula) :prop)))

(defun ics-as-prop (formula)
  (format nil "[~a]"
          (etypecase formula
            (ics-formula (ics-formula-text formula))
            (string formula))))

(defun ics-note (control &rest args)
  (if (fboundp 'pvs-message)
      (apply #'pvs-message control args)
      (apply #'format t control args)))

(defun ics-string-prefix-p (prefix string)
  (let ((plen (length prefix)))
    (and (<= plen (length string))
         (string= prefix string :end2 plen))))

(defun ics-expand-home (path)
  (let ((namestring (etypecase path
                      (pathname (namestring path))
                      (string path))))
    (cond ((string= namestring "~")
           (user-homedir-pathname))
          ((ics-string-prefix-p "~/" namestring)
           (merge-pathnames (subseq namestring 2) (user-homedir-pathname)))
          (t
           (pathname namestring)))))

(defun ics-home-pathname ()
  (let ((home (or *ics-home*
                  (uiop:getenv "ICS_HOME")
                  (merge-pathnames "git/ICS/" (user-homedir-pathname)))))
    (uiop:ensure-directory-pathname
     (if (pathnamep home) home (ics-expand-home home)))))

(defun ics-binary-candidates ()
  (let ((home (ignore-errors (ics-home-pathname))))
    (append
     (when *ics-binary*
       (list (if (pathnamep *ics-binary*)
                 *ics-binary*
                 (ics-expand-home *ics-binary*))))
     (when home
       (append (ignore-errors
                 (directory (merge-pathnames "bin/*/ics" home)))
               (list (merge-pathnames "ics" home))))
     (list "ics"))))

(defun ics-executable ()
  (or (loop for candidate in (ics-binary-candidates)
            when (and (pathnamep candidate) (probe-file candidate))
              return (namestring (truename candidate)))
      (let ((candidate (car (last (ics-binary-candidates)))))
        (if (pathnamep candidate) (namestring candidate) candidate))))

(defun ics-executable-present-p ()
  (let ((exe (ics-executable)))
    (or (and (pathnamep exe) (probe-file exe))
        (and (stringp exe)
             (or (probe-file exe)
                 (ignore-errors
                   (uiop:run-program (list exe "-version")
                                     :output :string
                                     :error-output :string
                                     :ignore-error-status t)
                   t))))))

(defun ics-temp-pathname ()
  (loop for i from 0
        for name = (format nil "pvs-ics-~d-~d-~d.ics"
                           (get-universal-time)
                           (get-internal-real-time)
                           i)
        for path = (merge-pathnames name (uiop:temporary-directory))
        unless (probe-file path)
          return path))

(defun ics-run-script (script)
  (let ((path (ics-temp-pathname)))
    (setf *ics-last-input* script)
    (unwind-protect
         (progn
           (with-open-file (out path
                                :direction :output
                                :if-exists :supersede
                                :if-does-not-exist :create)
             (write-string script out))
           (let* ((exe (ics-executable))
                  (values
                   (multiple-value-list
                    (uiop:run-program (list exe (namestring path))
                                      :output :string
                                      :error-output :string
                                      :ignore-error-status t)))
                  (stdout (or (first values) ""))
                  (stderr (or (second values) "")))
             (setf *ics-last-output* stdout
                   *ics-last-error-output* stderr)
             (when *ics-verbose*
               (format t "~%ICS input:~%~a~%ICS output:~%~a~%~a"
                       script stdout stderr))
             (values stdout stderr)))
      (unless *ics-keep-temp-files*
        (ignore-errors (delete-file path))))))

(defun ics-script-for-assertions (assertions)
  (with-output-to-string (out)
    (dolist (assertion assertions)
      (format out "assert ~a.~%" assertion))))

(defun ics-prop-conjunction (props &optional formula)
  (let ((parts (append (mapcar #'ics-as-prop props)
                       (when formula (list (ics-as-prop formula))))))
    (cond ((null parts) "tt")
          ((null (cdr parts)) (car parts))
          (t (format nil "~{~a~^ & ~}" parts)))))

(defun ics-script-for-query (assertions props &optional formula)
  (with-output-to-string (out)
    (dolist (assertion assertions)
      (format out "assert ~a.~%" assertion))
    (format out "sat [~a].~%" (ics-prop-conjunction props formula))))

(defun ics-event-char-p (ch)
  (or (alpha-char-p ch) (char= ch #\_)))

(defun ics-output-events (string)
  (let ((events nil)
        (len (length string)))
    (loop for i from 0 below len
          when (char= (char string i) #\:)
            do (let ((start (1+ i)))
                 (loop with j = start
                       while (and (< j len)
                                  (ics-event-char-p (char string j)))
                       do (incf j)
                       finally
                          (when (< start j)
                            (let* ((word (subseq string start j))
                                   (event (intern (string-upcase word)
                                                  :keyword)))
                              (when (member event
                                            '(:ok :valid :unsat :sat
                                              :true :false :error
                                              :invalid :unknown))
                                (push event events)))))))
    (nreverse events)))

(defun ics-run-assertions (assertions)
  (multiple-value-bind (stdout stderr)
      (ics-run-script (ics-script-for-assertions assertions))
    (let* ((events (append (ics-output-events stdout)
                           (ics-output-events stderr)))
           (last-event (car (last events))))
      (values (or last-event :unknown) stdout stderr events))))

(defun ics-run-query (assertions props &optional formula)
  (multiple-value-bind (stdout stderr)
      (ics-run-script (ics-script-for-query assertions props formula))
    (let* ((events (append (ics-output-events stdout)
                           (ics-output-events stderr)))
           (last-event (car (last events))))
      (values (or last-event :unknown) stdout stderr events))))

(defun ics-keyword-symbol-p (name)
  (member (string-downcase name)
          '("assert" "can" "simplify" "exit" "valid" "unsat" "save"
            "restore" "remove" "forget" "reset" "sig" "type" "def"
            "prop" "sigma" "solve" "help" "model" "check" "set"
            "toggle" "get" "trace" "untrace" "find" "inv" "dep"
            "solution" "partition" "syntax" "commands" "ctxt" "diseq"
            "echo" "undo" "show" "symtab" "sign" "dom" "split" "sat"
            "load" "true" "false" "empty" "full" "union" "inter" "diff"
            "sub" "tt" "ff" "inl" "inr" "outl" "outr" "inj" "out"
            "cons" "car" "cdr" "nil" "lambda" "if" "then" "else" "end"
            "create" "sup" "inf")
          :test #'string=))

(defun ics-sanitize-symbol (object)
  (let* ((raw (etypecase object
                (symbol (symbol-name object))
                (string object)
                (integer (format nil "n_~d" object))))
         (down (string-downcase raw))
         (body
          (with-output-to-string (out)
            (loop for ch across down
                  do (write-char
                      (if (or (alphanumericp ch)
                              (char= ch #\_)
                              (char= ch #\'))
                          ch
                          #\_)
                      out)))))
    (when (zerop (length body))
      (setf body "pvs"))
    (unless (alpha-char-p (char body 0))
      (setf body (format nil "pvs_~a" body)))
    (if (ics-keyword-symbol-p body)
        (format nil "pvs_~a" body)
        body)))

(defun ics-join-infix (operator args)
  (cond ((null args) nil)
        ((null (cdr args)) (car args))
        (t
         (with-output-to-string (out)
           (write-char #\( out)
           (write-string (car args) out)
           (dolist (arg (cdr args))
             (format out " ~a ~a" operator arg))
           (write-char #\) out)))))

(defun ics-unsupported ()
  (throw 'ics-unsupported nil))

(defun ics-dp-true-p (term)
  (or (eq term 'true)
      (equal term '(true))))

(defun ics-dp-false-p (term)
  (or (eq term 'false)
      (equal term '(false))))

(defun ics-rational-string (n)
  (if (integerp n)
      (princ-to-string n)
      (format nil "~d/~d" (numerator n) (denominator n))))

(defun ics-pack-product (args)
  (cond ((null args) "0b")
        ((null (cdr args)) (car args))
        (t (format nil "cons(~a, ~a)"
                   (car args)
                   (ics-pack-product (cdr args))))))

(defun ics-translate-dp-term (term)
  (cond ((integerp term) (princ-to-string term))
        ((rationalp term) (ics-rational-string term))
        ((symbolp term)
         (cond ((eq term 'true) "true")
               ((eq term 'false) "false")
               (t (ics-sanitize-symbol term))))
        ((and (consp term) (null (cdr term)) (symbolp (car term)))
         (ics-translate-dp-term (car term)))
        ((consp term)
         (let* ((op (car term))
                (args (cdr term))
                (tr-args (mapcar #'ics-translate-dp-term args)))
           (case op
             ((PLUS +)
              (or (ics-join-infix "+" tr-args) "0"))
             ((TIMES *)
              (or (ics-join-infix "*" tr-args) "1"))
             ((DIFFERENCE -)
              (if (= (length tr-args) 1)
                  (format nil "(- ~a)" (first tr-args))
                  (ics-join-infix "-" tr-args)))
             (MINUS
              (if (= (length tr-args) 1)
                  (format nil "(- ~a)" (first tr-args))
                  (ics-unsupported)))
             (DIVIDE
              (if (and (= (length args) 2)
                       (integerp (first args))
                       (integerp (second args)))
                  (format nil "~d/~d" (first args) (second args))
                  (ics-unsupported)))
             (EXPT
              (if (and (= (length tr-args) 2) (integerp (second args)))
                  (format nil "(~a ^ ~d)" (first tr-args) (second args))
                  (ics-unsupported)))
             (tupcons
              (ics-pack-product tr-args))
             (car
              (if (= (length tr-args) 1)
                  (format nil "car(~a)" (first tr-args))
                  (ics-unsupported)))
             (cdr
              (if (= (length tr-args) 1)
                  (format nil "cdr(~a)" (first tr-args))
                  (ics-unsupported)))
             (update
              (if (= (length tr-args) 3)
                  (format nil "~a[~a := ~a]"
                          (first tr-args) (second tr-args) (third tr-args))
                  (ics-unsupported)))
             (t
              (let ((opname (ics-sanitize-symbol op)))
                (cond ((and (ics-string-prefix-p "apply" opname)
                            (>= (length tr-args) 2))
                       (reduce #'(lambda (fun arg)
                                   (format nil "(~a $ ~a)" fun arg))
                               (rest tr-args)
                               :initial-value (first tr-args)))
	                      (tr-args
	                       (format nil "~a(~{~a~^, ~})" opname tr-args))
	                      (t opname)))))))
        (t (ics-unsupported))))

(defun ics-translate-dp-atom (term &optional negated?)
  (cond ((ics-dp-true-p term)
         (if negated? "true = false" "true = true"))
        ((ics-dp-false-p term)
         (if negated? "true = true" "true = false"))
        ((and (consp term) (eq (car term) 'not))
         (ics-translate-dp-atom (cadr term) (not negated?)))
        ((consp term)
         (let ((op (car term))
               (args (cdr term)))
           (labels ((binary (positive negative)
                      (unless (= (length args) 2)
                        (ics-unsupported))
                      (format nil "~a ~a ~a"
                              (ics-translate-dp-term (first args))
                              (if negated? negative positive)
                              (ics-translate-dp-term (second args)))))
             (case op
               (equal (binary "=" "<>"))
               (nequal (binary "<>" "="))
               (lessp (binary "<" ">="))
               (lesseqp (binary "<=" ">"))
               (greaterp (binary ">" "<="))
               (greatereqp (binary ">=" "<"))
               (t
                (format nil "~a = ~a"
                        (ics-translate-dp-term term)
                        (if negated? "false" "true")))))))
        (t
         (format nil "~a = ~a"
                 (ics-translate-dp-term term)
                 (if negated? "false" "true")))))

(defun ics-project-product (payload index arity)
  (cond ((= arity 1) payload)
        ((zerop index) (format nil "car(~a)" payload))
        (t (ics-project-product (format nil "cdr(~a)" payload)
                                (1- index)
                                (1- arity)))))

(defun ics-constructor-result-type (constructor)
  (let ((ctype (find-supertype (type constructor))))
    (if (funtype? ctype)
        (range ctype)
        ctype)))

(defun ics-constructor-list (ptype)
  (constructors (find-supertype ptype)))

(defun ics-same-constructor-p (left right)
  (or (same-declaration left right)
      (same-id left right)))

(defun ics-constructor-position (constructor ptype)
  (let* ((constructors (ics-constructor-list ptype))
         (pos (or (position constructor constructors
                            :test #'ics-same-constructor-p)
                  (position (id constructor) constructors
                            :key #'id :test #'eq))))
    (or pos (ics-unsupported))))

(defun ics-constructor-arguments (constructor)
  (or (ignore-errors (accessors constructor))
      nil))

(defun ics-constructor-term (constructor args)
  (let* ((rtype (ics-constructor-result-type constructor))
         (index (ics-constructor-position constructor rtype))
         (payload (ics-pack-product args)))
    (format nil "inj[~d](~a)" index payload)))

(defun ics-accessor-term (accessor arg)
  (let ((constructors (constructor accessor)))
    (unless (and (consp constructors) (null (cdr constructors)))
      (ics-unsupported))
    (let* ((constructor (car constructors))
           (rtype (ics-constructor-result-type constructor))
           (cindex (ics-constructor-position constructor rtype))
           (accessors (ics-constructor-arguments constructor))
           (aindex (or (position accessor accessors :test #'same-declaration)
                       (position (id accessor) accessors
                                 :key #'id :test #'eq))))
      (unless aindex
        (ics-unsupported))
      (ics-project-product (format nil "out[~d](~a)" cindex arg)
                           aindex
                           (length accessors)))))

(defun ics-fresh-witness ()
  (incf *ics-witness-counter*)
  (format nil "pvs_ics_witness_~d" *ics-witness-counter*))

(defun ics-constructor-shape-formula (constructor arg)
  (let* ((accessors (ics-constructor-arguments constructor))
         (witnesses (loop repeat (length accessors)
                          collect (ics-fresh-witness)))
         (constructor-term (ics-constructor-term constructor witnesses)))
    (ics-atom (format nil "~a = ~a" arg constructor-term))))

(defun ics-recognizer-formula (recognizer arg negated?)
  (let* ((constructor (constructor recognizer))
         (rtype (ics-constructor-result-type constructor))
         (constructors (ics-constructor-list rtype)))
    (if negated?
        (let ((alternatives
               (loop for alt in constructors
                     unless (ics-same-constructor-p constructor alt)
                       collect (ics-constructor-shape-formula alt arg))))
          (cond ((null alternatives)
                 (ics-prop "ff"))
                ((null (cdr alternatives))
                 (car alternatives))
                (t
                 (ics-prop
                  (format nil "~{~a~^ | ~}"
                          (mapcar #'ics-as-prop alternatives))))))
        (ics-constructor-shape-formula constructor arg))))

(defgeneric ics-pvs-term (expr))

(defmethod ics-pvs-term ((expr number-expr))
  (princ-to-string (number expr)))

(defmethod ics-pvs-term ((expr rational-expr))
  (ics-rational-string (slot-value expr 'number)))

(defmethod ics-pvs-term ((expr name-expr))
  (cond ((constructor? expr)
         (if (ics-constructor-arguments expr)
             (ics-unsupported)
             (ics-constructor-term expr nil)))
        ((tc-eq expr *true*) "true")
        ((tc-eq expr *false*) "false")
        (t
         (ics-translate-dp-term (top-translate-to-old-prove expr)))))

(defmethod ics-pvs-term ((expr tuple-expr))
  (ics-pack-product (mapcar #'ics-pvs-term (exprs expr))))

(defmethod ics-pvs-term ((expr projection-application))
  (let* ((arg (ics-pvs-term (argument expr)))
         (index (1- (index expr))))
    (ics-project-product arg index (length (types (find-supertype
                                                   (type (argument expr))))))))

(defmethod ics-pvs-term ((expr application))
  (let* ((operator (operator expr))
         (args (arguments expr))
         (tr-args (mapcar #'ics-pvs-term args))
         (op-id (and (typep operator 'name-expr) (id operator))))
    (cond ((constructor? operator)
           (ics-constructor-term operator tr-args))
          ((accessor? operator)
           (unless (= (length tr-args) 1)
             (ics-unsupported))
           (ics-accessor-term operator (first tr-args)))
          ((member op-id '(+ - *) :test #'eq)
           (case op-id
             (+ (or (ics-join-infix "+" tr-args) "0"))
             (* (or (ics-join-infix "*" tr-args) "1"))
             (- (if (= (length tr-args) 1)
                    (format nil "(- ~a)" (first tr-args))
                    (ics-join-infix "-" tr-args)))))
          ((eq op-id '/)
           (if (and (= (length args) 2)
                    (typep (first args) 'number-expr)
                    (typep (second args) 'number-expr))
               (format nil "~d/~d" (number (first args)) (number (second args)))
               (ics-unsupported)))
          ((and (typep operator 'name-expr) tr-args)
           (format nil "~a(~{~a~^, ~})"
                   (ics-sanitize-symbol
                    (ics-translate-dp-term
                     (top-translate-to-old-prove operator)))
                   tr-args))
          ((typep operator 'name-expr)
           (ics-sanitize-symbol
            (ics-translate-dp-term
             (top-translate-to-old-prove operator))))
          (t
           (ics-unsupported)))))

(defmethod ics-pvs-term ((expr t))
  (declare (ignore expr))
  (ics-unsupported))

(defun ics-pvs-comparison-atom (op args negated?)
  (unless (= (length args) 2)
    (ics-unsupported))
  (let ((operator
         (if negated?
             (case op (< ">=") (<= ">") (> "<=") (>= "<") (t nil))
             (case op (< "<") (<= "<=") (> ">") (>= ">=") (t nil)))))
    (unless operator
      (ics-unsupported))
    (ics-atom
     (format nil "~a ~a ~a"
             (ics-pvs-term (first args))
             operator
             (ics-pvs-term (second args))))))

(defun ics-pvs-atom (expr &optional negated?)
  (cond ((negation? expr)
         (ics-pvs-atom (args1 expr) (not negated?)))
        ((equation? expr)
         (ics-atom
          (format nil "~a ~a ~a"
                  (ics-pvs-term (args1 expr))
                  (if negated? "<>" "=")
                  (ics-pvs-term (args2 expr)))))
        ((disequation? expr)
         (ics-atom
          (format nil "~a ~a ~a"
                  (ics-pvs-term (args1 expr))
                  (if negated? "=" "<>")
                  (ics-pvs-term (args2 expr)))))
        ((application? expr)
         (let* ((operator (operator expr))
                (args (arguments expr))
                (op-id (and (typep operator 'name-expr) (id operator))))
           (cond ((and (recognizer? operator) (= (length args) 1))
                  (ics-recognizer-formula operator
                                          (ics-pvs-term (first args))
                                          negated?))
                 ((member op-id '(< <= > >=) :test #'eq)
                  (ics-pvs-comparison-atom op-id args negated?))
                 (t
                  (ics-atom
                   (format nil "~a = ~a"
                           (ics-pvs-term expr)
                           (if negated? "false" "true")))))))
        (t
         (ics-atom
          (format nil "~a = ~a"
                  (ics-pvs-term expr)
                  (if negated? "false" "true"))))))

(defun ics-translate-pvs-atom/direct (expr &optional negated?)
  (catch 'ics-unsupported
    (ics-pvs-atom expr negated?)))

(defun ics-translate-pvs-atom (expr &optional negated?)
  (or (and (typep expr 'expr)
           (ics-translate-pvs-atom/direct expr negated?))
      (catch 'ics-unsupported
        (ics-atom
         (ics-translate-dp-atom
         (if (typep expr 'expr)
             (top-translate-to-old-prove expr)
             expr)
         negated?)))))

(defun ics-empty-state ()
  (make-ics-dpi-state :assertions nil :props nil :generation 0))

(defun pvs-to-ics-reset ()
  (setf *ics-witness-counter* 0
        *ics-last-input* nil
        *ics-last-output* nil
        *ics-last-error-output* nil)
  nil)

(defun ics-state-unchanged? (old-state new-state)
  (and (ics-dpi-state-p old-state)
       (ics-dpi-state-p new-state)
       (= (ics-dpi-state-generation old-state)
          (ics-dpi-state-generation new-state))
       (equal (ics-dpi-state-assertions old-state)
              (ics-dpi-state-assertions new-state))
       (equal (ics-dpi-state-props old-state)
              (ics-dpi-state-props new-state))))

(defun ics-extend-state (state formula)
  (let ((text (ics-formula-text formula)))
    (cond ((ics-formula-atom-p formula)
           (if (member text (ics-dpi-state-assertions state) :test #'equal)
               state
               (make-ics-dpi-state
                :assertions (append (ics-dpi-state-assertions state)
                                    (list text))
                :props (ics-dpi-state-props state)
                :generation (1+ (ics-dpi-state-generation state)))))
          ((ics-formula-prop-p formula)
           (if (member text (ics-dpi-state-props state) :test #'equal)
               state
               (make-ics-dpi-state
                :assertions (ics-dpi-state-assertions state)
                :props (append (ics-dpi-state-props state) (list text))
                :generation (1+ (ics-dpi-state-generation state)))))
          (t state))))

(defun ics-process (state expr)
  (let* ((state (or state (ics-empty-state)))
         (formula (ics-translate-pvs-atom expr)))
    (if (null formula)
        state
        (if (and (ics-formula-atom-p formula)
                 (null (ics-dpi-state-props state)))
            (multiple-value-bind (status stdout stderr)
                (ics-run-assertions
                 (append (ics-dpi-state-assertions state)
                         (list (ics-formula-text formula))))
              (declare (ignore stdout stderr))
              (case status
                (:unsat :unsat)
                (:valid :valid)
                (:ok (ics-extend-state state formula))
                (otherwise
                 (when *ics-verbose*
                   (ics-note "ICS did not handle ~a; status was ~a"
                             expr status))
                 state)))
            (multiple-value-bind (status stdout stderr)
                (ics-run-query (ics-dpi-state-assertions state)
                               (ics-dpi-state-props state)
                               formula)
              (declare (ignore stdout stderr))
              (case status
                (:unsat :unsat)
                (:sat (ics-extend-state state formula))
                (otherwise
                 (when *ics-verbose*
                   (ics-note "ICS did not handle ~a; status was ~a"
                             expr status))
                 state)))))))

(defun ics-is-valid (state expr)
  (let* ((state (or state (ics-empty-state)))
         (negated-formula (ics-translate-pvs-atom expr t)))
    (when negated-formula
      (multiple-value-bind (status stdout stderr)
          (ics-run-query (ics-dpi-state-assertions state)
                         (ics-dpi-state-props state)
                         negated-formula)
        (declare (ignore stdout stderr))
        (case status
          (:unsat *true*)
          (:sat nil)
          (otherwise
           (when *ics-verbose*
             (ics-note "ICS validity query did not handle ~a; status was ~a"
                       expr status))
           nil))))))

(defun ics-init (&optional noisy?)
  (when noisy?
    (if (ics-executable-present-p)
        (ics-note "ICS decision procedure executable: ~a" (ics-executable))
        (ics-note "ICS executable not found; set *ICS-HOME* or *ICS-BINARY*.")))
  t)

(defun register-ics-decision-procedure ()
  (pushnew 'ics *decision-procedures*)
  (let ((entry (assoc 'ics *decision-procedure-descriptions*)))
    (if entry
        (setf (cdr entry) "ICS")
        (push (cons 'ics "ICS") *decision-procedure-descriptions*)))
  'ics)

(register-ics-decision-procedure)

(defmethod dpi-init* ((dp (eql 'ics)))
  (declare (ignore dp))
  (ics-init nil))

(defmethod dpi-start* ((dp (eql 'ics)) (prove-body function))
  (declare (ignore dp))
  (let* ((*translate-id-counter* nil)
         (*translate-id-hash* (init-if-rec *translate-id-hash*))
         (*translate-to-prove-hash* (init-if-rec *translate-to-prove-hash*))
         (typealist primtypealist)
         (*subtype-names* nil)
         (*named-exprs* nil)
         (*rec-type-dummies* nil)
         (*local-typealist* *local-typealist*)
         (applysymlist nil)
         (sigalist sigalist)
         (usealist usealist)
         (findalist findalist))
    (pvs-to-ics-reset)
    (initprover)
    (newcounter *translate-id-counter*)
    (funcall prove-body)))

(defmethod dpi-end* ((dp (eql 'ics)) proofstate)
  (declare (ignore dp proofstate))
  (pvs-to-ics-reset))

(defmethod dpi-empty-state* ((dp (eql 'ics)))
  (declare (ignore dp))
  (ics-empty-state))

(defmethod dpi-process* ((dp (eql 'ics)) expr state)
  (declare (ignore dp))
  (let ((result (ics-process state expr)))
    (case result
      (:unsat (values *false* state))
      (:valid (values *true* state))
      (otherwise (values nil result)))))

(defmethod dpi-valid?* ((dp (eql 'ics)) state pvs-expr)
  (declare (ignore dp))
  (ics-is-valid state pvs-expr))

(defmethod dpi-push-state* ((dp (eql 'ics)) state)
  (declare (ignore dp))
  state)

(defmethod dpi-pop-state* ((dp (eql 'ics)) state)
  (declare (ignore dp))
  state)

(defmethod dpi-copy-state* ((dp (eql 'ics)) state)
  (declare (ignore dp))
  (if (ics-dpi-state-p state)
      (make-ics-dpi-state
       :assertions (copy-list (ics-dpi-state-assertions state))
       :props (copy-list (ics-dpi-state-props state))
       :generation (ics-dpi-state-generation state))
      state))

(defmethod dpi-restore-state* ((dp (eql 'ics)) state)
  (declare (ignore dp))
  state)

(defmethod dpi-state-changed?* ((dp (eql 'ics)) old-state new-state)
  (declare (ignore dp))
  (not (ics-state-unchanged? old-state new-state)))

(defmethod dpi-disjunction?* ((dp (eql 'ics)) term)
  (declare (ignore dp))
  (and (consp term) (eq (car term) 'or)))

(defmethod dpi-proposition?* ((dp (eql 'ics)) term)
  (declare (ignore dp))
  (and (consp term)
       (memq (car term) '(if if* implies not and iff))))

(defmethod dpi-term-arguments* ((dp (eql 'ics)) term)
  (declare (ignore dp))
  (when (consp term) (cdr term)))

(defmethod dpi-canon* ((dp (eql 'ics)) term state)
  (declare (ignore dp state))
  term)
