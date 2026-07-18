;; sal-transform.scm -- SALenv driver for preprocessing and normalization
;;
;; Install this file and sal-transform.sh in SAL's tools directory.  It is
;; loaded by SALenv; command-line arguments are supplied by sal-transform.sh.

(define (sal-transform/usage)
  (with-output-to-port (current-error-port)
    (lambda ()
      (print "Usage: sal-transform.scm OP INPUT INPUT-DIR DECL SYNTAX OUTPUT [CONTEXT-DIR ...]")
      (print "  OP is preprocess, simplify, or flatten")
      (print "  SYNTAX is sal or lsal; OUTPUT is a path or -"))))

(define (sal-transform/fail message object)
  (sal-transform/usage)
  (sign-error message object))

(when (< (length *arguments*) 6)
  (sal-transform/fail "Not enough arguments to sal-transform" *arguments*))

(define sal-transform/operation (list-ref *arguments* 0))
(define sal-transform/input-file (list-ref *arguments* 1))
(define sal-transform/input-dir (list-ref *arguments* 2))
(define sal-transform/target-name
  (let ((name (list-ref *arguments* 3)))
    (and (not (string=? name "")) name)))
(define sal-transform/syntax (list-ref *arguments* 4))
(define sal-transform/output-file (list-ref *arguments* 5))
(define sal-transform/context-path (list-tail *arguments* 6))

(unless (member sal-transform/operation
                '("preprocess" "simplify" "flatten"))
  (sal-transform/fail "Unknown SAL transformation" sal-transform/operation))

(unless (member sal-transform/syntax '("sal" "lsal"))
  (sal-transform/fail "Unknown SAL output syntax" sal-transform/syntax))

(define (sal-transform/declaration-name declaration)
  (let* ((id (slot-value declaration :id))
         (name (and id (slot-value id :name))))
    (cond
     ((symbol? name) (symbol->string name))
     ((string? name) name)
     (else #f))))

(define (sal-transform/selected? declaration)
  (or (not sal-transform/target-name)
      (let ((name (sal-transform/declaration-name declaration)))
        (and name (string=? sal-transform/target-name name)))))

(define (sal-transform/object object)
  (cond
   ((string=? sal-transform/operation "preprocess") object)
   ((string=? sal-transform/operation "simplify") (sal/simplify object))
   ((string=? sal-transform/operation "flatten")
    (sal-ast/flat-modules object))))

(define (sal-transform/declaration-object declaration)
  (cond
   ((instance-of? declaration <sal-module-decl>)
    (slot-value (slot-value declaration :parametric-module) :module))
   ((instance-of? declaration <sal-assertion-decl>)
    (slot-value declaration :assertion-expr))
   ((instance-of? declaration <sal-constant-decl>)
    (or (slot-value declaration :value) declaration))
   ((instance-of? declaration <sal-type-decl>)
    (or (slot-value declaration :type) declaration))
   (else declaration)))

(define (sal-transform/declaration! declaration)
  (when (sal-transform/selected? declaration)
    (cond
     ((instance-of? declaration <sal-module-decl>)
      (let ((parametric-module
             (slot-value declaration :parametric-module)))
        (set-slot-value!
         parametric-module :module
         (sal-transform/object (slot-value parametric-module :module)))))
     ((instance-of? declaration <sal-assertion-decl>)
      (set-slot-value!
       declaration :assertion-expr
       (sal-transform/object (slot-value declaration :assertion-expr))))
     ((and (string=? sal-transform/operation "simplify")
           (instance-of? declaration <sal-constant-decl>)
           (slot-value declaration :value))
      (set-slot-value!
       declaration :value
       (sal-transform/object (slot-value declaration :value))))
     ((and (string=? sal-transform/operation "simplify")
           (instance-of? declaration <sal-type-decl>)
           (slot-value declaration :type))
      (set-slot-value!
       declaration :type
       (sal-transform/object (slot-value declaration :type))))
     ((and sal-transform/target-name
           (string=? sal-transform/operation "flatten"))
      (sign-error "FLATTEN requires a module or assertion" declaration))))
  declaration)

(define (sal-transform/write-result thunk)
  (if (string=? sal-transform/output-file "-")
    (thunk)
    (with-output-to-file sal-transform/output-file thunk)))

(let* ((sal-env (make-sal-env))
       (_ (sal-env/append-to-sal-context-path!
           sal-env
           (append (list sal-transform/input-dir)
                   sal-transform/context-path)))
       (context (sal-env/context-from-file sal-env sal-transform/input-file))
       (declarations (sal-context/declarations context))
       (selected
        (and sal-transform/target-name
             (find sal-transform/selected? declarations))))
  (when (and sal-transform/target-name (not selected))
    (sign-error "Unknown declaration" sal-transform/target-name))
  (for-each sal-transform/declaration! declarations)
  (if (string=? sal-transform/syntax "lsal")
    (sal/set-sal-pp-proc! sal-ast->lsal-doc)
    (sal/set-sal-pp-proc! sal-ast->sal-doc))
  (sal/set-pp-max-depth! 100000)
  (sal/set-pp-max-num-lines! 1000000)
  (sal-transform/write-result
   (lambda ()
     (sal/pp (if selected
               (sal-transform/declaration-object selected)
               context)))))
