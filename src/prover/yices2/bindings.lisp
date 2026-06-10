;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bindings.lisp --
;;   CFFI bindings for the public Yices2 API declared in yices.h
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2026, SRI International.  All Rights Reserved.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the 3-Clause BSD License.
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; 3-Clause BSD License for more details.
;; --------------------------------------------------------------------

(in-package :pvs)

(defparameter *yices2-default-foreign-library-spec*
  '((:darwin (:or "libyices.2.dylib" "libyices.dylib" "libyices"))
    (:unix (:or "libyices.so.2" "libyices.so" "libyices"))
    (:windows (:or "libyices.dll" "yices.dll" "libyices"))
    (t (:default "libyices"))))

(defvar *yices2-foreign-library-selection* nil)

(defun configure-yices2-foreign-library (&optional library)
  (let ((selection
         (when library
           (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return)
                                       (if (pathnamep library)
                                           (namestring library)
                                           library))))
             (unless (> (length trimmed) 0)
               (error "The Yices2 library name/path must not be empty"))
             trimmed))))
    (setq *yices2-foreign-library-selection* selection)
    (eval `(cffi:define-foreign-library yices2
             ,@(or (and selection `((t ,selection)))
                   *yices2-default-foreign-library-spec*)))
    'yices2))

(configure-yices2-foreign-library)

(defconstant +yices-null-term+ -1)
(defconstant +yices-null-type+ -1)
(defconstant +yices-version+ 2)
(defconstant +yices-version-major+ 7)
(defconstant +yices-version-patchlevel+ 0)

(cffi:defctype term_t :int32)
(cffi:defctype type_t :int32)
(cffi:defctype smt_status_t :int32)
(cffi:defctype yices_gen_mode_t :int32)
(cffi:defctype yval_tag_t :int32)
(cffi:defctype error_code_t :int32)
(cffi:defctype term_constructor_t :int32)

;; Opaque API types are represented as pointers.
(cffi:defctype context_t :pointer)
(cffi:defctype model_t :pointer)
(cffi:defctype ctx_config_t :pointer)
(cffi:defctype param_t :pointer)
(cffi:defctype lp_algebraic_number_t :pointer)
(cffi:defctype mpz_t :pointer)
(cffi:defctype mpq_t :pointer)
(cffi:defctype file_t :pointer)
(cffi:defctype yices_oom_callback_t :pointer)

(cffi:defcstruct term_vector_t
  (capacity :uint32)
  (size :uint32)
  (data (:pointer term_t)))

(cffi:defcstruct type_vector_t
  (capacity :uint32)
  (size :uint32)
  (data (:pointer type_t)))

(cffi:defcstruct yval_t
  (node_id :int32)
  (node_tag yval_tag_t))

(cffi:defcstruct yval_vector_t
  (capacity :uint32)
  (size :uint32)
  (data (:pointer (:struct yval_t))))

(cffi:defcstruct error_report_t
  (code error_code_t)
  (line :uint32)
  (column :uint32)
  (term1 term_t)
  (type1 type_t)
  (term2 term_t)
  (type2 type_t)
  (badval :int64))

(cffi:defcstruct interpolation_context_t
  (ctx_A context_t)
  (ctx_B context_t)
  (interpolant term_t)
  (model model_t))

;; Functions returning char * transfer ownership to the caller.  These are
;; bound as raw pointers so callers can release them via yices_free_string.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun yices2-trim (string)
    (string-trim '(#\Space #\Tab #\Newline #\Return) string))

  (defun yices2-string-prefix-p (prefix string)
    (let ((prefix-length (length prefix)))
      (and (<= prefix-length (length string))
           (string= prefix string :end2 prefix-length))))

  (defun yices2-whitespace-char-p (char)
    (member char '(#\Space #\Tab #\Newline #\Return)))

  (defun yices2-collapse-whitespace (string)
    (with-output-to-string (out)
      (let ((need-space nil)
            (emitted-char nil))
        (loop for char across string
              do (if (yices2-whitespace-char-p char)
                     (setf need-space emitted-char)
                     (progn
                       (when need-space
                         (write-char #\Space out))
                       (write-char char out)
                       (setf emitted-char t
                             need-space nil)))))))

  (defun yices2-normalize-c-type (type)
    (let ((collapsed (yices2-collapse-whitespace type)))
      (with-output-to-string (out)
        (loop for i from 0 below (length collapsed)
              for char = (char collapsed i)
              for prev = (and (> i 0) (char collapsed (1- i)))
              for next = (and (< (1+ i) (length collapsed))
                              (char collapsed (1+ i)))
              do (cond ((char= char #\Space)
                        (unless (or (and prev (char= prev #\*))
                                    (and next (char= next #\*))
                                    (and next (char= next #\[))
                                    (and prev (char= prev #\])))
                          (write-char char out)))
                       (t
                        (write-char char out)))))))

  (defun yices2-strip-qualifiers (type)
    (let ((result (yices2-normalize-c-type type)))
      (loop
        do (cond ((yices2-string-prefix-p "const " result)
                  (setf result (subseq result 6)))
                 ((yices2-string-prefix-p "volatile " result)
                  (setf result (subseq result 9)))
                 (t
                  (return result))))))

  (defun yices2-identifier-char-p (char)
    (or (alphanumericp char)
        (char= char #\_)))

  (defun yices2-sanitize-arg-name (name)
    (cond ((string= name "t") "t_")
          ((string= name "nil") "nil_")
          (t name)))

  (defun yices2-split-parameters (params)
    (let ((pieces nil)
          (start 0)
          (paren-depth 0)
          (bracket-depth 0))
      (labels ((emit-piece (end)
                 (let ((piece (yices2-trim (subseq params start end))))
                   (when (> (length piece) 0)
                     (push piece pieces)))))
        (loop for i from 0 below (length params)
              for char = (char params i)
              do (case char
                   (#\( (incf paren-depth))
                   (#\) (decf paren-depth))
                   (#\[ (incf bracket-depth))
                   (#\] (decf bracket-depth))
                   (#\, (when (and (zerop paren-depth)
                                   (zerop bracket-depth))
                          (emit-piece i)
                          (setf start (1+ i))))))
        (emit-piece (length params)))
      (nreverse pieces)))

  (defun yices2-parse-parameter (parameter)
    (let ((param (yices2-trim parameter)))
      (cond ((or (zerop (length param))
                 (string= param "void"))
             nil)
            ((search "(*" param)
             (let* ((name-start (+ (search "(*" param) 2))
                    (name-end (position #\) param :start name-start))
                    (name (subseq param name-start name-end)))
               (list (yices2-sanitize-arg-name name)
                     "void (*)(void)")))
            (t
             (let* ((end (length param))
                    (array-pos (and (> end 0)
                                    (char= (char param (1- end)) #\])
                                    (position #\[ param :from-end t))))
               (when array-pos
                 (setf end array-pos))
               (loop while (and (> end 0)
                                (yices2-whitespace-char-p (char param (1- end))))
                     do (decf end))
               (let ((name-end end))
                 (loop while (and (> end 0)
                                  (yices2-identifier-char-p (char param (1- end))))
                       do (decf end))
                 (let* ((name (subseq param end name-end))
                        (type (yices2-trim (subseq param 0 end)))
                        (type (if array-pos
                                  (concatenate 'string type " *")
                                  type)))
                   (list (yices2-sanitize-arg-name name)
                         (yices2-normalize-c-type type)))))))))

  (defun yices2-parse-function-declaration (declaration)
    (let* ((decl (yices2-trim declaration))
           (decl (if (and (> (length decl) 0)
                          (char= (char decl (1- (length decl))) #\;))
                     (subseq decl 0 (1- (length decl)))
                     decl))
           (open (position #\( decl))
           (close (position #\) decl :from-end t))
           (head (yices2-trim (subseq decl 0 open)))
           (params (yices2-trim (subseq decl (1+ open) close)))
           (head-end (length head)))
      (loop while (and (> head-end 0)
                       (yices2-whitespace-char-p (char head (1- head-end))))
            do (decf head-end))
      (let ((name-end head-end))
        (loop while (and (> head-end 0)
                         (yices2-identifier-char-p (char head (1- head-end))))
              do (decf head-end))
        (list (subseq head head-end name-end)
              (yices2-trim (subseq head 0 head-end))
              (remove nil (mapcar #'yices2-parse-parameter
                                  (yices2-split-parameters params)))))))

  (defun yices2-parse-variable-declaration (declaration)
    (let* ((decl (yices2-trim declaration))
           (decl (if (and (> (length decl) 0)
                          (char= (char decl (1- (length decl))) #\;))
                     (subseq decl 0 (1- (length decl)))
                     decl))
           (end (length decl)))
      (loop while (and (> end 0)
                       (yices2-whitespace-char-p (char decl (1- end))))
            do (decf end))
      (let ((name-end end))
        (loop while (and (> end 0)
                         (yices2-identifier-char-p (char decl (1- end))))
              do (decf end))
        (list (subseq decl end name-end)
              (yices2-trim (subseq decl 0 end))))))

  (defun yices2-symbol (name)
    (intern (string-upcase name) :pvs))

  (defun yices2-struct-type-form (name)
    `(:struct ,(yices2-symbol name)))

  (defun yices2-pointer-type-form (type)
    `(:pointer ,type))

  (defun yices2-primitive-cffi-type (name)
    (cond ((string= name "int") :int)
          ((string= name "int32_t") :int32)
          ((string= name "uint32_t") :uint32)
          ((string= name "int64_t") :int64)
          ((string= name "uint64_t") :uint64)
          ((string= name "double") :double)
          ((string= name "float") :float)
          (t nil)))

  (defun yices2-cffi-type (c-type)
    (let* ((raw (yices2-normalize-c-type c-type))
           (stripped (yices2-strip-qualifiers raw))
           (primitive (yices2-primitive-cffi-type stripped)))
      (cond ((string= stripped "void") :void)
            ((or (string= stripped "void(*)(void)")
                 (string= stripped "void (*)(void)"))
             'yices_oom_callback_t)
            ((string= raw "const char*") :string)
            ((string= stripped "char*") :pointer)
            (primitive primitive)
            (t
             (let* ((star-count (count #\* stripped))
                    (base (yices2-trim (remove #\* stripped))))
               (cond
                 ((yices2-primitive-cffi-type base)
                  (cond ((zerop star-count)
                         (yices2-primitive-cffi-type base))
                        ((= star-count 1)
                         (yices2-pointer-type-form
                          (yices2-primitive-cffi-type base)))
                        (t
                         :pointer)))
                 ((member base '("context_t" "model_t" "ctx_config_t" "param_t"
                                 "lp_algebraic_number_t")
                          :test #'string=)
                  (if (= star-count 1)
                      (yices2-symbol base)
                      :pointer))
                 ((string= base "FILE")
                  (if (= star-count 1)
                      'file_t
                      :pointer))
                 ((member base '("mpz_t" "mpq_t") :test #'string=)
                  (if (<= star-count 1)
                      (yices2-symbol base)
                      :pointer))
                 ((member base '("term_vector_t" "type_vector_t" "yval_t"
                                 "yval_vector_t" "error_report_t"
                                 "interpolation_context_t")
                          :test #'string=)
                  (cond ((zerop star-count)
                         (yices2-struct-type-form base))
                        ((= star-count 1)
                         (yices2-pointer-type-form
                          (yices2-struct-type-form base)))
                        (t
                         :pointer)))
                 ((member base '("term_t" "type_t" "smt_status_t"
                                 "yices_gen_mode_t" "yval_tag_t"
                                 "error_code_t" "term_constructor_t")
                          :test #'string=)
                  (cond ((zerop star-count)
                         (yices2-symbol base))
                        ((= star-count 1)
                         (yices2-pointer-type-form (yices2-symbol base)))
                        (t
                         :pointer)))
                 (t
                  (error "Unsupported Yices2 C type: ~a" c-type))))))))

  (defun yices2-function-declaration-p (declaration)
    (not (null (position #\( declaration))))

  (defun yices2-read-api-spec (path)
    (let ((pathname (probe-file path)))
      (unless pathname
        (error "Missing Yices2 API spec: ~a" path))
      (with-open-file (stream pathname :direction :input)
        (loop for line = (read-line stream nil nil)
              while line
              for trimmed = (yices2-trim line)
              unless (or (zerop (length trimmed))
                         (char= (char trimmed 0) #\#)
                         (char= (char trimmed 0) #\;))
                collect trimmed))))

  (defun yices2-current-api-spec-pathname ()
    (merge-pathnames #p"api.spec"
                     (or *compile-file-pathname*
                         *load-truename*
                         *default-pathname-defaults*)))

  (defun yices2-defcvar-form (declaration)
    (destructuring-bind (name type)
        (yices2-parse-variable-declaration declaration)
      `(cffi:defcvar (,(yices2-symbol name) ,name)
         ,(yices2-cffi-type type))))

  (defun yices2-defcfun-form (declaration)
    (destructuring-bind (name return-type params)
        (yices2-parse-function-declaration declaration)
      `(cffi:defcfun (,(yices2-symbol name) ,name)
         ,(yices2-cffi-type return-type)
         ,@(mapcar (lambda (param)
                     (destructuring-bind (param-name param-type) param
                       `(,(yices2-symbol param-name)
                         ,(yices2-cffi-type param-type))))
                   params))))

  (defmacro define-yices2-bindings ()
    (let ((declarations (yices2-read-api-spec
                         (yices2-current-api-spec-pathname))))
      `(progn
         ,@(mapcar (lambda (declaration)
                     (if (yices2-function-declaration-p declaration)
                         (yices2-defcfun-form declaration)
                         (yices2-defcvar-form declaration)))
                   declarations))))
  (define-yices2-bindings))
