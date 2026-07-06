;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2structures.lisp --
;;   Data structures for Yices2 proof state, incremental solver scoping/cleanup
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

;; --------------------------------------------------------------------
;; Dynamic solver state

(defvar *y2/context* nil)
(defvar *y2/model* nil)
(defvar *y2/params* nil)
(defvar *y2/config* nil)
(defvar *y2/initialized?* nil)
(defvar *y2/init-depth* 0)

(defvar *y2/manager* nil)
(defvar *y2/stack* nil)

;; These are the usual Yices smt_status_t enum values.
;; Verify once against your local yices_types.h.
(defconstant +y2/status-idle+ 0)
(defconstant +y2/status-searching+ 1)
(defconstant +y2/status-unknown+ 2)
(defconstant +y2/status-sat+ 3)
(defconstant +y2/status-unsat+ 4)
(defconstant +y2/status-interrupted+ 5)
(defconstant +y2/status-error+ 6)

(defun y2/%nonnull-pointer-p (ptr)
  (and ptr (not (cffi:null-pointer-p ptr))))

(defun y2/error-string ()
  (let ((ptr (%y2/yices_error_string)))
    (if (y2/%nonnull-pointer-p ptr)
        (unwind-protect
             (cffi:foreign-string-to-lisp ptr)
          (%y2/yices_free_string ptr))
        "unknown Yices2 error")))

(defun y2/clear-error ()
  (%y2/yices_clear_error))

(defun y2/raise-last-error (&optional (prefix "Yices2 error"))
  (let ((msg (ignore-errors (y2/error-string))))
    (y2api-err "~a~@[: ~a~]" prefix msg)))

(defun y2/check-code (code &optional (what "Yices2 call failed"))
  "Yices convention: many functions return negative values on error."
  (when (minusp code)
    (y2/raise-last-error what))
  code)

(defun y2/check-pointer (ptr &optional (what "Yices2 returned a null pointer"))
  (unless (y2/%nonnull-pointer-p ptr)
    (y2/raise-last-error what))
  ptr)

(defun y2/status-keyword (status)
  (case status
    (#.+y2/status-idle+ :idle)
    (#.+y2/status-searching+ :searching)
    (#.+y2/status-unknown+ :unknown)
    (#.+y2/status-sat+ :sat)
    (#.+y2/status-unsat+ :unsat)
    (#.+y2/status-interrupted+ :interrupted)
    (#.+y2/status-error+ :error)
    (otherwise status)))

;; --------------------------------------------------------------------
;; Initialization

(defun y2/init ()
  "Initialize Yices if needed."
  (unless *y2/initialized?*
    (%y2/yices_init)
    (setf *y2/initialized?* t))
  (incf *y2/init-depth*)
  t)

(defun y2/%release-yices ()
  (when (plusp *y2/init-depth*)
    (decf *y2/init-depth*))
  (when (and *y2/initialized?* (zerop *y2/init-depth*))
    (%y2/yices_exit)
    (setf *y2/initialized?* nil))
  t)

(defun y2/exit ()
  "Shut down Yices, regardless of the current initialization depth."
  (when *y2/initialized?*
    (%y2/yices_exit))
  (setf *y2/initialized?* nil
        *y2/init-depth* 0)
  t)

(defmacro y2/with-yices (() &body body)
  "Initialize Yices around BODY and release it afterward."
  `(let ((initialized? nil))
     (unwind-protect
          (progn
            (y2/init)
            (setf initialized? t)
            ,@body)
       (when initialized?
         (y2/%release-yices)))))

;; --------------------------------------------------------------------
;; Small argument normalizers

(defun y2/%name-string (name)
  (cond ((stringp name)
         name)
        ((symbolp name)
         (string-downcase (symbol-name name)))
        (t
         (y2api-err "Expected a Yices2 option/configuration name, got ~s" name))))

(defun y2/%value-string (value)
  (cond ((null value) "false")
        ((eq value t) "true")
        ((stringp value) value)
        ((symbolp value) (string-downcase (symbol-name value)))
        ((numberp value) (princ-to-string value))
        (t (format nil "~a" value))))

(defun y2/%name-value-pair-p (object)
  (and (consp object)
       (or (atom (cdr object))
           (and (consp (cdr object))
                (null (cddr object))))))

(defun y2/%normalize-name-value-pair (pair what)
  (unless (y2/%name-value-pair-p pair)
    (y2api-err "Malformed Yices2 ~a pair: ~s" what pair))
  (cons (y2/%name-string (car pair))
        (y2/%value-string
         (if (and (consp (cdr pair))
                  (null (cddr pair)))
             (cadr pair)
             (cdr pair)))))

(defun y2/normalize-name-value-pairs (object what)
  "Accept either a plist or a list of (name value)/(name . value) pairs."
  (cond ((null object)
         nil)
        ((and (listp object)
              (every #'y2/%name-value-pair-p object))
         (mapcar #'(lambda (pair)
                     (y2/%normalize-name-value-pair pair what))
                 object))
        ((and (listp object)
              (evenp (length object)))
         (loop for (name value) on object by #'cddr
               collect (cons (y2/%name-string name)
                             (y2/%value-string value))))
        (t
         (y2api-err
          "Malformed Yices2 ~a list: expected a plist or a list of pairs, got ~s"
          what object))))

(defun y2/normalize-option-list (object what)
  (cond ((null object)
         nil)
        ((or (stringp object) (symbolp object))
         (list (y2/%name-string object)))
        ((listp object)
         (mapcar #'y2/%name-string object))
        (t
         (y2api-err "Malformed Yices2 ~a list: ~s" what object))))

(defun y2/%set-pair (pairs name value)
  (let ((key (y2/%name-string name)))
    (acons key
           (y2/%value-string value)
           (remove key pairs :key #'car :test #'string=))))

(defun y2/%remove-string (name strings)
  (remove (y2/%name-string name) strings :test #'string=))


;; --------------------------------------------------------------------
;; Manager and stack structures

(defstruct (y2-manager (:constructor %make-y2-manager))
  (stacks (make-hash-table :test #'equal))
  default-stack
  closed?)

(defstruct (y2-assertion (:constructor %make-y2-assertion))
  index
  name
  term
  depth)

(defstruct (y2-stack (:constructor %make-y2-stack))
  name
  manager
  logic
  mode
  mcsat
  config-pairs
  param-pairs
  enable-options
  disable-options
  config
  context
  params
  model
  interpolant
  assertions
  (next-assertion-index 0)
  (status :idle)
  (depth 0)
  closed?)

(defun y2/%stack-key (name)
  name)

(defun y2/%ensure-manager-open (manager)
  (unless (and (y2-manager-p manager)
               (not (y2-manager-closed? manager)))
    (y2api-err "No open Yices2 manager: ~s" manager))
  manager)

(defun y2/%ensure-stack-object (stack)
  (unless (and (y2-stack-p stack)
               (not (y2-stack-closed? stack)))
    (y2api-err "No open Yices2 stack: ~s" stack))
  stack)

(defun y2/current-manager ()
  *y2/manager*)

(defun y2/ensure-manager ()
  (unless *y2/manager*
    (y2api-err "No active Yices2 manager. Use Y2/WITH-MANAGER or Y2/WITH-SOLVER."))
  (y2/%ensure-manager-open *y2/manager*))

(defun y2/current-stack ()
  *y2/stack*)

(defun y2/ensure-stack ()
  (unless *y2/stack*
    (y2api-err "No active Yices2 stack. Use Y2/WITH-STACK or Y2/WITH-SOLVER."))
  (y2/%ensure-stack-object *y2/stack*))

(defun y2/ensure-context (&optional (stack *y2/stack*))
  (cond ((and stack (y2-stack-p stack))
         (y2/ensure-stack-open stack)
         (y2-stack-context stack))
        (*y2/context*
         *y2/context*)
        (t
         (y2api-err "No active Yices2 context. Use Y2/WITH-STACK or Y2/WITH-SOLVER."))))

(defun y2/ensure-model (&optional (stack *y2/stack*))
  (let ((model (cond ((and stack (y2-stack-p stack))
                      (y2-stack-model stack))
                     (t
                      *y2/model*))))
    (unless model
      (y2api-err "No active Yices2 model. Call Y2/CHECK! and get :SAT first."))
    model))

(defun y2/%mcsat-enabled-p ()
  (and (boundp '+y2api/mcsat-enabled?+)
       +y2api/mcsat-enabled?+))

(defun y2/%ensure-mcsat-enabled ()
  (unless (y2/%mcsat-enabled-p)
    (y2api-err "Requested MCSAT, but this Yices2 dylib does not have MCSAT enabled.")))

(defun y2/%stack-config-pairs (stack)
  (let* ((config-pairs (y2-stack-config-pairs stack))
         (has-solver-type? (find "solver-type" config-pairs
                                 :key #'car :test #'string=)))
    (append
     (when (y2-stack-mode stack)
       (list (cons "mode" (y2/%value-string (y2-stack-mode stack)))))
     (when (and (y2-stack-mcsat stack)
                (not has-solver-type?))
       (list (cons "solver-type" "mcsat")))
     config-pairs)))

(defun y2/%make-stack-config (stack)
  (when (y2-stack-mcsat stack)
    (y2/%ensure-mcsat-enabled))
  (let ((config (y2/check-pointer
                 (%y2/yices_new_config)
                 "Could not create Yices2 config")))
    (when (y2-stack-logic stack)
      (y2/check-code
       (%y2/yices_default_config_for_logic
        config (y2/%value-string (y2-stack-logic stack)))
       "Could not set Yices2 default config for logic"))
    (dolist (pair (y2/%stack-config-pairs stack))
      (y2/check-code
       (%y2/yices_set_config config (car pair) (cdr pair))
       (format nil "Could not set Yices2 config ~a" (car pair))))
    config))

(defun y2/%apply-context-options (context enable-options disable-options)
  (dolist (option enable-options)
    (y2/check-code
     (%y2/yices_context_enable_option context option)
     (format nil "Could not enable Yices2 context option ~a" option)))
  (dolist (option disable-options)
    (y2/check-code
     (%y2/yices_context_disable_option context option)
     (format nil "Could not disable Yices2 context option ~a" option))))

(defun y2/%make-stack-params (stack)
  (when (y2-stack-param-pairs stack)
    (let ((params (y2/check-pointer
                   (%y2/yices_new_param_record)
                   "Could not create Yices2 parameter record")))
      (%y2/yices_default_params_for_context (y2-stack-context stack) params)
      (dolist (pair (y2-stack-param-pairs stack))
        (y2/check-code
         (%y2/yices_set_param params (car pair) (cdr pair))
         (format nil "Could not set Yices2 parameter ~a" (car pair))))
      params)))

(defun y2/%free-stack-model (stack)
  (when (y2/%nonnull-pointer-p (y2-stack-model stack))
    (%y2/yices_free_model (y2-stack-model stack)))
  (setf (y2-stack-model stack) nil)
  (when (eq stack *y2/stack*)
    (setf *y2/model* nil)))

(defun y2/%set-stack-model (stack model)
  (y2/%free-stack-model stack)
  (setf (y2-stack-model stack) model)
  (when (eq stack *y2/stack*)
    (setf *y2/model* model))
  model)

(defun y2/%clear-stack-result-state (stack)
  (y2/%free-stack-model stack)
  (setf (y2-stack-interpolant stack) +y2/null-term+
        (y2-stack-status stack) :idle))

(defun y2/%clear-stack-assertions (stack)
  (setf (y2-stack-assertions stack) nil
        (y2-stack-next-assertion-index stack) 0))

(defun y2/%term-name (term)
  (let ((ptr (ignore-errors (%y2/yices_get_term_name term))))
    (when (y2/%nonnull-pointer-p ptr)
      (cffi:foreign-string-to-lisp ptr))))

(defun y2/%record-assertion! (stack term name)
  (let ((assertion
         (%make-y2-assertion
          :index (prog1 (y2-stack-next-assertion-index stack)
                   (incf (y2-stack-next-assertion-index stack)))
          :name (or name (y2/%term-name term))
          :term term
          :depth (y2-stack-depth stack))))
    (setf (y2-stack-assertions stack)
          (nconc (y2-stack-assertions stack) (list assertion)))
    assertion))

(defun y2/%discard-popped-assertions! (stack)
  (setf (y2-stack-assertions stack)
        (remove-if #'(lambda (assertion)
                       (> (y2-assertion-depth assertion)
                          (y2-stack-depth stack)))
                   (y2-stack-assertions stack))))

(defun y2/%free-stack-resources (stack)
  (y2/%free-stack-model stack)
  (when (y2/%nonnull-pointer-p (y2-stack-context stack))
    (%y2/yices_free_context (y2-stack-context stack)))
  (when (y2/%nonnull-pointer-p (y2-stack-params stack))
    (%y2/yices_free_param_record (y2-stack-params stack)))
  (when (y2/%nonnull-pointer-p (y2-stack-config stack))
    (%y2/yices_free_config (y2-stack-config stack)))
  (setf (y2-stack-context stack) nil
        (y2-stack-params stack) nil
        (y2-stack-config stack) nil
        (y2-stack-status stack) :idle
        (y2-stack-depth stack) 0)
  (y2/%clear-stack-assertions stack))

(defun y2/open-stack! (stack)
  (y2/%ensure-stack-object stack)
  (unless (y2-stack-context stack)
    (let* ((config (y2/%make-stack-config stack))
           (context (y2/check-pointer
                     (%y2/yices_new_context config)
                     "Could not create Yices2 context")))
      (setf (y2-stack-config stack) config
            (y2-stack-context stack) context)
      (y2/%apply-context-options
       context
       (y2-stack-enable-options stack)
       (y2-stack-disable-options stack))
      (setf (y2-stack-params stack)
            (y2/%make-stack-params stack))))
  stack)

(defun y2/ensure-stack-open (stack)
  (y2/open-stack! stack)
  stack)

(defun y2/free-stack! (stack)
  (y2/%ensure-stack-object stack)
  (y2/%free-stack-resources stack)
  (setf (y2-stack-closed? stack) t)
  t)

(defun y2/free-manager! (manager)
  (y2/%ensure-manager-open manager)
  (maphash #'(lambda (name stack)
               (declare (ignore name))
               (when (and (y2-stack-p stack)
                          (not (y2-stack-closed? stack)))
                 (y2/free-stack! stack)))
           (y2-manager-stacks manager))
  (clrhash (y2-manager-stacks manager))
  (setf (y2-manager-closed? manager) t)
  t)

(defun y2/manager-stack (manager name &optional error?)
  (let* ((manager (y2/%ensure-manager-open manager))
         (stack (gethash (y2/%stack-key name)
                         (y2-manager-stacks manager))))
    (cond (stack stack)
          (error?
           (y2api-err "No Yices2 stack named ~s" name))
          (t nil))))

(defun y2/manager-stack-names (&optional (manager (y2/ensure-manager)))
  (let ((names nil))
    (maphash #'(lambda (name stack)
                 (declare (ignore stack))
                 (push name names))
             (y2-manager-stacks manager))
    (nreverse names)))

(defun y2/manager-add-stack! (manager name &key logic mode mcsat configs params
                                           enable-options disable-options replace?)
  (let* ((manager (y2/%ensure-manager-open manager))
         (key (y2/%stack-key name))
         (old-stack (gethash key (y2-manager-stacks manager))))
    (cond ((and old-stack replace?)
           (y2/free-stack! old-stack))
          (old-stack
           (y2api-err "Yices2 stack ~s already exists" name)))
    (let ((stack (%make-y2-stack
                  :name key
                  :manager manager
                  :logic logic
                  :mode mode
                  :mcsat mcsat
                  :config-pairs
                  (y2/normalize-name-value-pairs configs "configuration")
                  :param-pairs
                  (y2/normalize-name-value-pairs params "parameter")
                  :enable-options
                  (y2/normalize-option-list enable-options "context option")
                  :disable-options
                  (y2/normalize-option-list disable-options "context option")
                  :interpolant +y2/null-term+)))
      (y2/open-stack! stack)
      (setf (gethash key (y2-manager-stacks manager)) stack)
      (unless (y2-manager-default-stack manager)
        (setf (y2-manager-default-stack manager) key))
      stack)))

(defun y2/manager-remove-stack! (manager name)
  (let* ((manager (y2/%ensure-manager-open manager))
         (key (y2/%stack-key name))
         (stack (gethash key (y2-manager-stacks manager))))
    (when stack
      (y2/free-stack! stack)
      (remhash key (y2-manager-stacks manager))
      (when (equal key (y2-manager-default-stack manager))
        (setf (y2-manager-default-stack manager) nil)))
    stack))

(defun y2/make-manager (&key default-stack logic mode mcsat configs params
                             enable-options disable-options)
  (let ((manager (%make-y2-manager)))
    (when default-stack
      (y2/manager-add-stack!
       manager default-stack
       :logic logic
       :mode mode
       :mcsat mcsat
       :configs configs
       :params params
       :enable-options enable-options
       :disable-options disable-options)
      (setf (y2-manager-default-stack manager)
            (y2/%stack-key default-stack)))
    manager))

(defun y2/%call-with-stack (stack thunk)
  (y2/ensure-stack-open stack)
  (let ((*y2/stack* stack)
        (*y2/context* (y2-stack-context stack))
        (*y2/config* (y2-stack-config stack))
        (*y2/params* (y2-stack-params stack))
        (*y2/model* (y2-stack-model stack)))
    (funcall thunk)))

(defun y2/%call-with-manager (manager thunk)
  (let ((*y2/manager* (y2/%ensure-manager-open manager)))
    (let ((default-stack
           (and (y2-manager-default-stack manager)
                (y2/manager-stack manager
                                  (y2-manager-default-stack manager)))))
      (if default-stack
          (y2/%call-with-stack default-stack thunk)
          (funcall thunk)))))

(defmacro y2/with-manager ((manager &key (default-stack :default)
                                      logic mode mcsat configs params
                                      enable-options disable-options)
                           &body body)
  "Create a scoped manager that owns one or more named Yices2 stacks."
  `(let ((,manager nil)
         (initialized? nil))
     (unwind-protect
          (progn
            (y2/init)
            (setf initialized? t
                  ,manager
                  (y2/make-manager
                   :default-stack ,default-stack
                   :logic ,logic
                   :mode ,mode
                   :mcsat ,mcsat
                   :configs ,configs
                   :params ,params
                   :enable-options ,enable-options
                   :disable-options ,disable-options))
            (y2/%call-with-manager ,manager #'(lambda () ,@body)))
       (when (and ,manager
                  (not (y2-manager-closed? ,manager)))
         (y2/free-manager! ,manager))
       (when initialized?
         (y2/%release-yices)))))

(defmacro y2/with-stack ((name &key (manager '*y2/manager*)
                               logic mode mcsat configs params
                               enable-options disable-options)
                         &body body)
  "Select a named stack in MANAGER, creating it if it does not exist."
  (let ((manager-var (gensym "MANAGER-"))
        (stack-var (gensym "STACK-")))
    `(let* ((,manager-var (or ,manager (y2/ensure-manager)))
            (,stack-var
             (or (y2/manager-stack ,manager-var ,name)
                 (y2/manager-add-stack!
                  ,manager-var ,name
                  :logic ,logic
                  :mode ,mode
                  :mcsat ,mcsat
                  :configs ,configs
                  :params ,params
                  :enable-options ,enable-options
                  :disable-options ,disable-options))))
       (let ((*y2/manager* ,manager-var))
         (y2/%call-with-stack ,stack-var #'(lambda () ,@body))))))

;; --------------------------------------------------------------------
;; Backward-compatible raw config/context macros

(defmacro y2/with-config ((config &key logic mode mcsat configs) &body body)
  `(let ((,config (%y2/yices_new_config)))
     (when (cffi:null-pointer-p ,config)
       (y2/raise-last-error "Could not create Yices2 config"))
     (unwind-protect
          (progn
            ,@(when logic
                `((y2/check-code
                   (%y2/yices_default_config_for_logic ,config ,logic)
                   "Could not set Yices2 default config for logic")))
            ,@(when mode
                `((y2/check-code
                   (%y2/yices_set_config ,config "mode" ,mode)
                   "Could not set Yices2 mode")))
            ,@(when mcsat
                `((y2/%ensure-mcsat-enabled)
                  (y2/check-code
                   (%y2/yices_set_config ,config "solver-type" "mcsat")
                   "Could not set Yices2 solver type")))
            (dolist (pair (y2/normalize-name-value-pairs
                           ,configs "configuration"))
              (y2/check-code
               (%y2/yices_set_config ,config (car pair) (cdr pair))
               (format nil "Could not set Yices2 config ~a" (car pair))))
            ,@body)
       (%y2/yices_free_config ,config))))

(defmacro y2/with-context ((ctx &key logic mode mcsat configs params
                                enable-options disable-options)
                           &body body)
  (let ((manager (gensym "MANAGER-")))
    `(y2/with-manager
         (,manager :default-stack (gensym "Y2-CONTEXT-")
                   :logic ,logic
                   :mode ,mode
                   :mcsat ,mcsat
                   :configs ,configs
                   :params ,params
                   :enable-options ,enable-options
                   :disable-options ,disable-options)
       (let ((,ctx *y2/context*))
         ,@body))))

(defmacro y2/with-solver ((&key logic mode mcsat configs params
                                enable-options disable-options)
                          &body body)
  "Main ergonomic entry point for one scoped solver stack."
  (let ((manager (gensym "MANAGER-")))
    `(y2/with-manager
         (,manager :default-stack :solver
                   :logic ,logic
                   :mode ,mode
                   :mcsat ,mcsat
                   :configs ,configs
                   :params ,params
                   :enable-options ,enable-options
                   :disable-options ,disable-options)
       ,@body)))

;; --------------------------------------------------------------------
;; Stack configuration and reset operations

(defun y2/reset-stack! (&key (stack (y2/ensure-stack)))
  "Drop all assertions and push scopes from STACK, preserving its configuration."
  (let ((stack (y2/%ensure-stack-object stack)))
    (y2/ensure-stack-open stack)
    (y2/%clear-stack-result-state stack)
    (%y2/yices_reset_context (y2-stack-context stack))
    (setf (y2-stack-depth stack) 0
          (y2-stack-status stack) :idle)
    (y2/%clear-stack-assertions stack)
    stack))

(defun y2/reconfigure-stack! (&key (stack (y2/ensure-stack))
                                   (logic nil logic?)
                                   (mode nil mode?)
                                   (mcsat nil mcsat?)
                                   (configs nil configs?)
                                   (params nil params?)
                                   (enable-options nil enable-options?)
                                   (disable-options nil disable-options?))
  "Rebuild STACK with new configuration. Existing assertions are discarded."
  (let ((stack (y2/%ensure-stack-object stack)))
    (when logic?
      (setf (y2-stack-logic stack) logic))
    (when mode?
      (setf (y2-stack-mode stack) mode))
    (when mcsat?
      (setf (y2-stack-mcsat stack) mcsat))
    (when configs?
      (setf (y2-stack-config-pairs stack)
            (y2/normalize-name-value-pairs configs "configuration")))
    (when params?
      (setf (y2-stack-param-pairs stack)
            (y2/normalize-name-value-pairs params "parameter")))
    (when enable-options?
      (setf (y2-stack-enable-options stack)
            (y2/normalize-option-list enable-options "context option")))
    (when disable-options?
      (setf (y2-stack-disable-options stack)
            (y2/normalize-option-list disable-options "context option")))
    (y2/%free-stack-resources stack)
    (y2/open-stack! stack)
    stack))

(defun y2/set-logic! (logic &key (stack (y2/ensure-stack)))
  (y2/reconfigure-stack! :stack stack :logic logic))

(defun y2/set-mode! (mode &key (stack (y2/ensure-stack)))
  (y2/reconfigure-stack! :stack stack :mode mode))

(defun y2/set-mcsat! (enabled? &key (stack (y2/ensure-stack)))
  (y2/reconfigure-stack! :stack stack :mcsat enabled?))

(defun y2/set-config! (name value &key (stack (y2/ensure-stack)))
  "Set one Yices2 context configuration on STACK and rebuild the context."
  (let ((stack (y2/%ensure-stack-object stack)))
    (setf (y2-stack-config-pairs stack)
          (y2/%set-pair (y2-stack-config-pairs stack) name value))
    (y2/reconfigure-stack! :stack stack)))

(defun y2/set-param! (name value &key (stack (y2/ensure-stack)))
  "Set one Yices2 search parameter on STACK."
  (let ((stack (y2/%ensure-stack-object stack)))
    (setf (y2-stack-param-pairs stack)
          (y2/%set-pair (y2-stack-param-pairs stack) name value))
    (when (y2/%nonnull-pointer-p (y2-stack-params stack))
      (%y2/yices_free_param_record (y2-stack-params stack))
      (setf (y2-stack-params stack) nil))
    (setf (y2-stack-params stack)
          (y2/%make-stack-params stack))
    stack))

(defun y2/enable-option! (option &key (stack (y2/ensure-stack)))
  (let* ((stack (y2/%ensure-stack-object stack))
         (option (y2/%name-string option)))
    (y2/check-code
     (%y2/yices_context_enable_option (y2/ensure-context stack) option)
     (format nil "Could not enable Yices2 context option ~a" option))
    (pushnew option (y2-stack-enable-options stack) :test #'string=)
    (setf (y2-stack-disable-options stack)
          (y2/%remove-string option (y2-stack-disable-options stack)))
    (y2/%clear-stack-result-state stack)
    stack))

(defun y2/disable-option! (option &key (stack (y2/ensure-stack)))
  (let* ((stack (y2/%ensure-stack-object stack))
         (option (y2/%name-string option)))
    (y2/check-code
     (%y2/yices_context_disable_option (y2/ensure-context stack) option)
     (format nil "Could not disable Yices2 context option ~a" option))
    (pushnew option (y2-stack-disable-options stack) :test #'string=)
    (setf (y2-stack-enable-options stack)
          (y2/%remove-string option (y2-stack-enable-options stack)))
    (y2/%clear-stack-result-state stack)
    stack))

;; --------------------------------------------------------------------
;; Context operations

(defun y2/assert! (term &key (stack (y2/ensure-stack)) name)
  (let ((stack (y2/%ensure-stack-object stack)))
    (y2/check-code
     (%y2/yices_assert_formula (y2/ensure-context stack) term)
     "Yices2 assert failed")
    (y2/%record-assertion! stack term name)
    (y2/%clear-stack-result-state stack)
    term))

(defun y2/assert-named! (name term &key (stack (y2/ensure-stack)))
  (y2/assert! term :stack stack :name name))

(defun y2/assert-all! (&rest terms)
  (let ((stack (y2/ensure-stack)))
    (y2/%with-term-array (arr terms)
      (y2/check-code
       (%y2/yices_assert_formulas
        (y2/ensure-context stack) (length terms) arr)
       "Yices2 assert formulas failed"))
    (dolist (term terms)
      (y2/%record-assertion! stack term nil))
    (y2/%clear-stack-result-state stack)
    terms))

(defun y2/push! (&key (stack (y2/ensure-stack)))
  (let ((stack (y2/%ensure-stack-object stack)))
    (y2/check-code
     (%y2/yices_push (y2/ensure-context stack))
     "Yices2 push failed")
    (incf (y2-stack-depth stack))
    (y2/%clear-stack-result-state stack)
    (y2-stack-depth stack)))

(defun y2/pop! (&key (stack (y2/ensure-stack)))
  (let ((stack (y2/%ensure-stack-object stack)))
    (when (zerop (y2-stack-depth stack))
      (y2api-err "Cannot pop Yices2 stack ~s: no matching push"
                 (y2-stack-name stack)))
    (y2/check-code
     (%y2/yices_pop (y2/ensure-context stack))
     "Yices2 pop failed")
    (decf (y2-stack-depth stack))
    (y2/%discard-popped-assertions! stack)
    (y2/%clear-stack-result-state stack)
    (y2-stack-depth stack)))

(defmacro y2/with-push (() &body body)
  `(progn
     (y2/push!)
     (unwind-protect
          (progn ,@body)
       (y2/pop!))))

(defun y2/context-status (&key (stack (y2/ensure-stack)))
  (let* ((stack (y2/%ensure-stack-object stack))
         (status (%y2/yices_context_status (y2/ensure-context stack))))
    (setf (y2-stack-status stack) (y2/status-keyword status))))

(defun y2/%stack-param-pointer (stack)
  (or (y2-stack-params stack)
      (cffi:null-pointer)))

(defun y2/%check-status (stack status keep-subst)
  (let ((keyword (y2/status-keyword status)))
    (setf (y2-stack-status stack) keyword)
    (case status
      (#.+y2/status-sat+
       (y2/%set-stack-model
        stack
        (y2/check-pointer
         (%y2/yices_get_model (y2/ensure-context stack) keep-subst)
         "Could not get Yices2 model"))
       :sat)
      (#.+y2/status-unsat+
       (y2/%free-stack-model stack)
       :unsat)
      (#.+y2/status-unknown+
       (y2/%free-stack-model stack)
       :unknown)
      (#.+y2/status-interrupted+
       (y2/%free-stack-model stack)
       :interrupted)
      (#.+y2/status-error+
       (setf (y2-stack-status stack) :error)
       (y2/raise-last-error "Yices2 check failed"))
      (otherwise
       (y2/%free-stack-model stack)
       keyword))))

(defun y2/check! (&key (stack (y2/ensure-stack)) assumptions (keep-subst 1))
  (let ((stack (y2/%ensure-stack-object stack)))
    (y2/%free-stack-model stack)
    (let ((status
           (if assumptions
               (y2/%with-term-array (arr assumptions)
                 (%y2/yices_check_context_with_assumptions
                  (y2/ensure-context stack)
                  (y2/%stack-param-pointer stack)
                  (length assumptions)
                  arr))
               (%y2/yices_check_context
                (y2/ensure-context stack)
                (y2/%stack-param-pointer stack)))))
      (y2/%check-status stack status keep-subst))))

(defun y2/check-stack! (stack &key assumptions (keep-subst 1))
  (y2/check! :stack stack :assumptions assumptions :keep-subst keep-subst))

(defmacro y2/solve ((&key logic mode mcsat configs params
                          enable-options disable-options)
                    &body body)
  `(y2/with-solver (:logic ,logic
                    :mode ,mode
                    :mcsat ,mcsat
                    :configs ,configs
                    :params ,params
                    :enable-options ,enable-options
                    :disable-options ,disable-options)
     ,@body
     (y2/check!)))

;; --------------------------------------------------------------------
;; Pretty printing

(defun y2/%assertion-print-mode (assertions terms?)
  (cond (terms?
         :terms)
        ((or (null assertions)
             (eq assertions :none))
         nil)
        ((member assertions '(:names :summary :indices t))
         :names)
        ((member assertions '(:terms :full))
         :terms)
        (t
         (y2api-err
          "Bad assertion print mode ~s; expected NIL, :NAMES, or :TERMS"
          assertions))))

(defun y2/%stack-names-for-print (manager)
  (sort (copy-list (y2/manager-stack-names manager))
        #'string<
        :key #'princ-to-string))

(defun y2/%write-indent (stream indent)
  (dotimes (i indent)
    (write-char #\Space stream)))

(defun y2/%print-indented-lines (stream string indent)
  (with-input-from-string (input string)
    (loop for line = (read-line input nil nil)
          while line
          do (progn
               (y2/%write-indent stream indent)
               (write-line line stream)))))

(defun y2/%print-name-value-pairs (stream label pairs indent)
  (when pairs
    (y2/%write-indent stream indent)
    (format stream "~a:~%" label)
    (dolist (pair pairs)
      (y2/%write-indent stream (+ indent 2))
      (format stream "~a = ~a~%" (car pair) (cdr pair)))))

(defun y2/%print-string-list (stream label strings indent)
  (when strings
    (y2/%write-indent stream indent)
    (format stream "~a: ~{~a~^, ~}~%" label strings)))

(defun y2/%term-string-for-print (term width height offset)
  (handler-case
      (let ((ptr (%y2/yices_term_to_string term width height offset)))
        (if (y2/%nonnull-pointer-p ptr)
            (unwind-protect
                 (cffi:foreign-string-to-lisp ptr)
              (%y2/yices_free_string ptr))
            (format nil "#<Yices2 term ~s>" term)))
    (error (condition)
      (format nil "#<Yices2 term ~s: ~a>" term condition))))

(defun y2/%stack-print-arguments (args)
  (if (and args (not (keywordp (first args))))
      (values (first args) (rest args))
      (values (y2/ensure-stack) args)))

(defun y2/%manager-print-arguments (args)
  (if (and args (not (keywordp (first args))))
      (values (first args) (rest args))
      (values (y2/ensure-manager) args)))

(defun y2/print-stack (&rest args)
  "Pretty-print one Yices2 stack.

Usage:
  (Y2/PRINT-STACK)
  (Y2/PRINT-STACK stack :ASSERTIONS :TERMS)

ASSERTIONS may be NIL/:NONE, :NAMES, or :TERMS.  :NAMES prints only assertion
indices, optional names, and scope depths.  :TERMS also prints each asserted
term."
  (multiple-value-bind (stack options)
      (y2/%stack-print-arguments args)
    (destructuring-bind (&key (stream *standard-output*)
                              (assertions :names)
                              terms?
                              (width 120)
                              (height 80)
                              (offset 0))
        options
      (let* ((stack (y2/%ensure-stack-object stack))
             (mode (y2/%assertion-print-mode assertions terms?))
             (assertion-list (y2-stack-assertions stack)))
        (format stream "~&Stack ~s~%" (y2-stack-name stack))
        (format stream "  status: ~s  depth: ~d  assertions: ~d~%"
                (y2-stack-status stack)
                (y2-stack-depth stack)
                (length assertion-list))
        (format stream "  logic: ~:[<unset>~;~:*~a~]  mode: ~:[<unset>~;~:*~a~]  mcsat: ~:[no~;yes~]~%"
                (y2-stack-logic stack)
                (y2-stack-mode stack)
                (y2-stack-mcsat stack))
        (format stream "  context: ~:[closed~;open~]  model: ~:[none~;available~]~%"
                (y2-stack-context stack)
                (y2-stack-model stack))
        (y2/%print-name-value-pairs
         stream "configs" (y2-stack-config-pairs stack) 2)
        (y2/%print-name-value-pairs
         stream "params" (y2-stack-param-pairs stack) 2)
        (y2/%print-string-list
         stream "enabled options" (y2-stack-enable-options stack) 2)
        (y2/%print-string-list
         stream "disabled options" (y2-stack-disable-options stack) 2)
        (when mode
          (y2/%write-indent stream 2)
          (format stream "assertions:~%")
          (if assertion-list
              (dolist (assertion assertion-list)
                (let ((name (y2-assertion-name assertion)))
                  (y2/%write-indent stream 4)
                  (format stream "[~d]~@[ ~a~] depth=~d~%"
                          (y2-assertion-index assertion)
                          name
                          (y2-assertion-depth assertion))
                  (when (eq mode :terms)
                    (y2/%print-indented-lines
                     stream
                     (y2/%term-string-for-print
                      (y2-assertion-term assertion) width height offset)
                     6))))
              (progn
                (y2/%write-indent stream 4)
                (format stream "<none>~%"))))
        stack))))

(defun y2/stack-string (&rest args)
  (multiple-value-bind (stack options)
      (y2/%stack-print-arguments args)
    (with-output-to-string (stream)
      (apply #'y2/print-stack stack :stream stream options))))

(defun y2/print-manager (&rest args)
  "Pretty-print the full Yices2 manager context and all stacks it owns."
  (multiple-value-bind (manager options)
      (y2/%manager-print-arguments args)
    (destructuring-bind (&key (stream *standard-output*)
                              (assertions :names)
                              terms?
                              (width 120)
                              (height 80)
                              (offset 0))
        options
      (let ((manager (y2/%ensure-manager-open manager)))
        (format stream "~&Yices2 manager~%")
        (format stream "  default stack: ~:[<none>~;~:*~s~]~%"
                (y2-manager-default-stack manager))
        (format stream "  stacks: ~d~%"
                (hash-table-count (y2-manager-stacks manager)))
        (dolist (name (y2/%stack-names-for-print manager))
          (terpri stream)
          (y2/print-stack
           (y2/manager-stack manager name t)
           :stream stream
           :assertions assertions
           :terms? terms?
           :width width
           :height height
           :offset offset))
        manager))))

(defun y2/manager-string (&rest args)
  (multiple-value-bind (manager options)
      (y2/%manager-print-arguments args)
    (with-output-to-string (stream)
      (apply #'y2/print-manager manager :stream stream options))))

(defun y2/print-context (&rest args)
  "Alias for Y2/PRINT-MANAGER."
  (apply #'y2/print-manager args))

(defun y2/context-string (&rest args)
  "Alias for Y2/MANAGER-STRING."
  (apply #'y2/manager-string args))

;; --------------------------------------------------------------------
;; Interpolation over two stacks

(defun y2/%stack-designator (designator manager)
  (cond ((y2-stack-p designator)
         (y2/%ensure-stack-object designator))
        (manager
         (y2/manager-stack manager designator t))
        (t
         (y2api-err "No manager available for stack designator ~s" designator))))

(defun y2/check-interpolation! (stack-a stack-b
                                &key (manager *y2/manager*) build-model)
  "Check two stack contexts using Yices interpolation.

Returns three values: status keyword, interpolant term or NIL, and model pointer
or NIL. The returned model, when present, is owned by STACK-A."
  (let* ((manager (and manager (y2/%ensure-manager-open manager)))
         (stack-a (y2/%stack-designator stack-a manager))
         (stack-b (y2/%stack-designator stack-b manager)))
    (y2/ensure-stack-open stack-a)
    (y2/ensure-stack-open stack-b)
    (y2/%free-stack-model stack-a)
    (setf (y2-stack-interpolant stack-a) +y2/null-term+)
    (cffi:with-foreign-object (ictx '(:struct interpolation_context_t))
      (setf (cffi:foreign-slot-value
             ictx '(:struct interpolation_context_t) 'ctx_A)
            (y2-stack-context stack-a)
            (cffi:foreign-slot-value
             ictx '(:struct interpolation_context_t) 'ctx_B)
            (y2-stack-context stack-b)
            (cffi:foreign-slot-value
             ictx '(:struct interpolation_context_t) 'interpolant)
            +y2/null-term+
            (cffi:foreign-slot-value
             ictx '(:struct interpolation_context_t) 'model)
            (cffi:null-pointer))
      (let* ((status (%y2/yices_check_context_with_interpolation
                      ictx
                      (y2/%stack-param-pointer stack-a)
                      (if build-model 1 0)))
             (keyword (y2/status-keyword status))
             (interpolant
              (cffi:foreign-slot-value
               ictx '(:struct interpolation_context_t) 'interpolant))
             (model
              (cffi:foreign-slot-value
               ictx '(:struct interpolation_context_t) 'model)))
        (setf (y2-stack-status stack-a) keyword
              (y2-stack-status stack-b) keyword)
        (when (= status +y2/status-error+)
          (y2/raise-last-error "Yices2 interpolation check failed"))
        (when (and (integerp interpolant)
                   (/= interpolant +y2/null-term+))
          (setf (y2-stack-interpolant stack-a) interpolant))
        (when (y2/%nonnull-pointer-p model)
          (y2/%set-stack-model stack-a model))
        (values keyword
                (and (integerp interpolant)
                     (/= interpolant +y2/null-term+)
                     interpolant)
                (and (y2/%nonnull-pointer-p model)
                     model))))))
