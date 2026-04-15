;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; api-loader.lisp --
;;   Lightweight loader for the standalone Yices2 CFFI prover integration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2006, SRI International.  All Rights Reserved.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
;; --------------------------------------------------------------------

(in-package :pvs)

(defvar *yices2-api-implementation-loaded* nil)
(defvar *yices2-api-implementation-loading* nil)
(defvar *yices2-api-suppress-errors* nil)

(defun yices2-api-source-file (name)
  (assert *pvs-path*)
  (format nil "~a/src/prover/yices2/~a.lisp" *pvs-path* name))

(defun ensure-yices2-api-implementation ()
  (unless *yices2-api-implementation-loaded*
    (when *yices2-api-implementation-loading*
      (error "Recursive attempt to load the Yices2 API prover implementation"))
    (let ((*yices2-api-implementation-loading* t))
      (load (yices2-api-source-file "bindings"))
      (load (yices2-api-source-file "api-prover"))
      (unless (fboundp 'yices2-api-dispatch)
        (error "Yices2 API prover implementation did not define yices2-api-dispatch"))
      (setq *yices2-api-implementation-loaded* t)))
  t)

(defun yices2-api (sformnums &rest option-plist)
  (ensure-yices2-api-implementation)
  (apply #'yices2-api-dispatch sformnums option-plist))

(defun yices2-api-quiet (sformnums &rest option-plist)
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (special *yices2-api-suppress-errors*))
      (let ((*yices2-api-suppress-errors* t))
        (apply #'yices2-api-run ps sformnums option-plist))))

(defun yices2-api-show-model-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-show-last-model)
      (values 'X nil nil)))

(defun yices2-api-show-counterexample-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-show-last-counterexample)
      (values 'X nil nil)))

(defun yices2-api-show-unsat-core-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-show-last-unsat-core)
      (values 'X nil nil)))

(defun yices2-api-show-library-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-show-library)
      (values 'X nil nil)))

(defun yices2-api-show-help-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-show-help)
      (values 'X nil nil)))

(defun yices2-api-set-library-dispatch (library)
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-set-library library)
      (values 'X nil nil)))

(defun yices2-api-use-default-library-dispatch ()
  (ensure-yices2-api-implementation)
  #'(lambda (ps)
      (declare (ignore ps))
      (yices2-api-use-default-library)
      (values 'X nil nil)))

(defun yices2-api-strategy-quote (object)
  (if (or (null object)
          (eq object t)
          (numberp object)
          (stringp object)
          (keywordp object)
          (characterp object))
      object
      (list 'quote object)))

(defun yices2-api-unquote-strategy-data (object)
  (if (and (consp object)
           (eq (car object) 'quote)
           (consp (cdr object))
           (null (cddr object)))
      (cadr object)
      object))

(defun yices2-api-expand-name-object-p (object)
  (or (stringp object)
      (and (symbolp object)
           (not (keywordp object)))
      (typep object 'name)
      (typep object 'simple-decl)))

(defun yices2-api-expand-name-string (object)
  (let ((object (yices2-api-unquote-strategy-data object)))
    (cond ((stringp object) object)
          ((and (symbolp object)
                (not (keywordp object)))
           (symbol-name object))
          (t (format nil "~a" object)))))

(defun yices2-api-expand-name-key (object)
  (string-downcase (yices2-api-expand-name-string object)))

(defun yices2-api-expand-spec-form-p (object)
  (let ((object (yices2-api-unquote-strategy-data object)))
    (or (yices2-api-expand-name-object-p object)
        (and (consp object)
             (yices2-api-expand-name-object-p (car object))))))

(defun yices2-api-expand-spec-sequence-p (object)
  (and (listp object)
       (every #'yices2-api-expand-spec-form-p object)))

(defun yices2-api-parse-expand-count (name options)
  (labels ((bad-count ()
             (error "Malformed Y2API expansion spec for ~s: expected NAME, (NAME N), or (NAME :DEPTH N)." name))
           (check-count (count)
             (if (and (integerp count)
                      (> count 0))
                 count
                 (error "Y2API expansion count/depth for ~s must be a positive integer, got ~s." name count))))
    (cond ((null options)
           1)
          ((and (null (cdr options))
                (integerp (car options)))
           (check-count (car options)))
          ((and (= (length options) 2)
                (memq (car options) '(:count :depth)))
           (check-count (cadr options)))
          (t
           (bad-count)))))

(defun yices2-api-make-expand-spec (name count)
  (list (yices2-api-expand-name-string name)
        (yices2-api-expand-name-key name)
        count))

(defun yices2-api-normalize-expand-spec (object)
  (let ((object (yices2-api-unquote-strategy-data object)))
    (cond ((yices2-api-expand-name-object-p object)
           (yices2-api-make-expand-spec object 1))
          ((and (consp object)
                (yices2-api-expand-name-object-p (car object)))
           (yices2-api-make-expand-spec
            (car object)
            (yices2-api-parse-expand-count (car object) (cdr object))))
          (t
           (error "Malformed Y2API expansion spec: ~s" object)))))

(defun yices2-api-normalize-expand-specs (object)
  (let ((object (yices2-api-unquote-strategy-data object)))
    (cond ((null object)
           nil)
          ((yices2-api-expand-spec-sequence-p object)
           (mapcar #'yices2-api-normalize-expand-spec object))
          (t
           (list (yices2-api-normalize-expand-spec object))))))

(defun yices2-api-filter-expand-specs (enabled disabled)
  (if (null disabled)
      enabled
      (remove-if #'(lambda (spec)
                     (member (cadr spec) disabled :test #'string=))
                 enabled)))

(defun yices2-api-expand-specs-after-success (specs current-spec)
  (let ((done nil))
    (loop for spec in specs
          if (and (not done)
                  (eq spec current-spec))
            append
            (progn
              (setq done t)
              (let ((count (caddr spec)))
                (when (> count 1)
                  (list (list (car spec) (cadr spec) (1- count))))))
          else
            collect spec)))

(defun yices2-api-make-primitive-step (fnums nonlinear? logic mode solver-type
                                             configs params verbosity quiet?
                                             enable-options disable-options
                                             &optional suppress-errors?)
  (let ((qfnums (yices2-api-strategy-quote fnums))
        (qnonlinear (yices2-api-strategy-quote nonlinear?))
        (qlogic (yices2-api-strategy-quote logic))
        (qmode (yices2-api-strategy-quote mode))
        (qsolver-type (yices2-api-strategy-quote solver-type))
        (qconfigs (yices2-api-strategy-quote configs))
        (qparams (yices2-api-strategy-quote params))
        (qverbosity (yices2-api-strategy-quote verbosity))
        (qquiet (yices2-api-strategy-quote quiet?))
        (qenable-options (yices2-api-strategy-quote enable-options))
        (qdisable-options (yices2-api-strategy-quote disable-options)))
    `(,(if suppress-errors? 'yices2-api-quiet 'yices2-api)
      :fnums ,qfnums
      :nonlinear? ,qnonlinear
      :logic ,qlogic
      :mode ,qmode
      :solver-type ,qsolver-type
      :configs ,qconfigs
      :params ,qparams
      :verbosity ,qverbosity
      :quiet? ,qquiet
      :enable-options ,qenable-options
      :disable-options ,qdisable-options)))

(addrule 'yices2-api ()
    ((fnums *) nonlinear? logic (mode "one-shot") solver-type
     configs params verbosity quiet? enable-options disable-options)
  (yices2-api fnums
              :nonlinear? nonlinear?
              :logic logic
              :mode mode
              :solver-type solver-type
              :configs configs
              :params params
              :verbosity verbosity
              :quiet? quiet?
              :enable-options enable-options
              :disable-options disable-options)
  "Invokes Yices2 through the CFFI API as an endgame solver over the selected formulas, with optional direct control of logic/config/parameter/context-option settings."
  "~%Calling Yices2 through the CFFI API,")

(addrule 'yices2-api-quiet ()
    ((fnums *) nonlinear? logic (mode "one-shot") solver-type
     configs params verbosity quiet? enable-options disable-options)
  (yices2-api-quiet fnums
                    :nonlinear? nonlinear?
                    :logic logic
                    :mode mode
                    :solver-type solver-type
                    :configs configs
                    :params params
                    :verbosity verbosity
                    :quiet? quiet?
                    :enable-options enable-options
                    :disable-options disable-options)
  "Invokes Yices2 through the CFFI API but suppresses non-fatal solver errors so higher-level strategies can recover."
  "~%Calling Yices2 through the CFFI API,")

(defstep y2api-simp (&optional (fnums *)
                               &key nonlinear? logic
                               (mode "one-shot") solver-type configs params
                               verbosity
                               quiet?
                               enable-options disable-options)
  (let ((loaded? (ensure-yices2-api-implementation)))
    (then (skeep)
          (yices2-api :fnums fnums
                      :nonlinear? nonlinear?
                      :logic logic
                      :mode mode
                      :solver-type solver-type
                      :configs configs
                      :params params
                      :verbosity verbosity
                      :quiet? quiet?
                      :enable-options enable-options
                      :disable-options disable-options)))
  "Repeatedly skolemizes and flattens, then invokes the standalone Yices2 CFFI API prover with direct Yices2 keyword control over logic, configuration, parameters, and context flags."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 CFFI API prover")

(defstep y2api-mcsat (&optional (fnums *)
                                &key logic (mode "one-shot")
                                solver-type configs params
                                verbosity
                                quiet?
                                enable-options disable-options)
  (y2api-simp :fnums fnums
              :nonlinear? t
              :logic logic
              :mode mode
              :solver-type solver-type
              :configs configs
              :params params
              :verbosity verbosity
              :quiet? quiet?
              :enable-options enable-options
              :disable-options disable-options)
  "Repeatedly skolemizes and flattens, then invokes the Yices2 API prover in nonlinear/MCSAT mode, with optional direct Yices2 logic/config/parameter/context-option settings."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 MCSAT API prover")

(defhelper y2api-expand__ (expand-specs fnums expand-assert? solver-step)
  (let ((expand-specs (yices2-api-unquote-strategy-data expand-specs))
        (fnums (yices2-api-unquote-strategy-data fnums))
        (expand-assert? (yices2-api-unquote-strategy-data expand-assert?)))
    (let ((qexpand-specs (yices2-api-strategy-quote expand-specs))
          (qfnums (yices2-api-strategy-quote fnums))
          (qexpand-assert? (yices2-api-strategy-quote expand-assert?)))
      (let ((step (if expand-specs
                      `(try ,solver-step
                            (skip)
                            (y2api-expand-next__$ ,qexpand-specs ,qexpand-specs
                                                  ,qfnums ,qexpand-assert?
                                                  ,solver-step))
                      solver-step)))
        step)))
  "Internal helper for y2api-expand." "")

(defhelper y2api-expand-next__ (pending-specs all-specs fnums expand-assert?
                                              solver-step)
  (let ((pending-specs (yices2-api-unquote-strategy-data pending-specs))
        (all-specs (yices2-api-unquote-strategy-data all-specs))
        (fnums (yices2-api-unquote-strategy-data fnums))
        (expand-assert? (yices2-api-unquote-strategy-data expand-assert?)))
    (if (null pending-specs)
        '(skip)
        (let ((name (car (car pending-specs)))
              (next-specs (yices2-api-expand-specs-after-success
                           all-specs
                           (car pending-specs))))
          (let ((qpending-rest (yices2-api-strategy-quote (cdr pending-specs)))
                (qall-specs (yices2-api-strategy-quote all-specs))
                (qnext-specs (yices2-api-strategy-quote next-specs))
                (qfnums (yices2-api-strategy-quote fnums))
                (qexpand-assert? (yices2-api-strategy-quote expand-assert?)))
            (let ((step `(try (expand ,name :fnum ,qfnums
                                      :assert? ,qexpand-assert?)
                              (then (skeep)
                                    (y2api-expand__$ ,qnext-specs
                                                     ,qfnums
                                                     ,qexpand-assert?
                                                     ,solver-step))
                              (y2api-expand-next__$ ,qpending-rest
                                                    ,qall-specs
                                                    ,qfnums
                                                    ,qexpand-assert?
                                                    ,solver-step))))
              step)))))
  "Internal helper for y2api-expand." "")

(defstep y2api-expand (&optional (fnums *)
                                 &key expand-enable expand-disable
                                 (expand-assert? 'none)
                                 nonlinear? logic
                                 (mode "one-shot") solver-type configs params
                                 verbosity
                                 quiet?
                                 enable-options disable-options)
  (let ((enabled-specs
         (yices2-api-normalize-expand-specs expand-enable))
        (disabled-keys
         (mapcar #'cadr (yices2-api-normalize-expand-specs expand-disable))))
    (let ((expand-specs
           (yices2-api-filter-expand-specs enabled-specs disabled-keys))
          (solver-step
           (yices2-api-make-primitive-step fnums nonlinear? logic mode
                                           solver-type configs params
                                           verbosity
                                           quiet?
                                           enable-options disable-options
                                           t)))
      (then (skeep)
            (y2api-expand__$ expand-specs fnums expand-assert? solver-step))))
  "Skolemizes and flattens, invokes the standalone Yices2 CFFI API prover, and if needed interleaves additional prover calls with selected definition expansions. Use :expand-enable to list expandable names, optionally as (\"name\" N) or (\"name\" :depth N), and :expand-disable to remove names from that list."
  "Interleaving Yices2 API solving with selected definition expansions")

(addrule 'y2api-show-model nil nil
  (yices2-api-show-model-dispatch)
  "Prints the most recent Yices2 API model, if one was produced by a satisfiable run.")

(addrule 'y2api-show-counterexample nil nil
  (yices2-api-show-counterexample-dispatch)
  "Prints the most recent Yices2 API counterexample, if one was produced by a satisfiable run.")

(addrule 'y2api-show-unsat-core nil nil
  (yices2-api-show-unsat-core-dispatch)
  "Prints the most recent Yices2 API UNSAT core, if one was produced by an unsatisfiable run.")

(addrule 'y2api-show-library nil nil
  (yices2-api-show-library-dispatch)
  "Prints the active Yices2 shared library, resolved pathname, version, and MCSAT availability.")

(addrule 'y2api-help nil nil
  (yices2-api-show-help-dispatch)
  "Prints a Yices2 API reference covering commands, keyword arguments, logic names, configuration keys, context switches, and search parameters.")

(addrule 'y2api-use-library (string) ()
  (yices2-api-set-library-dispatch string)
  "Switches the standalone Yices2 API prover to the given shared library and loads it immediately."
  "~%Switching the Yices2 API library to ~a")

(addrule 'y2api-use-default-library nil nil
  (yices2-api-use-default-library-dispatch)
  "Restores the standalone Yices2 API prover to the default CFFI libyices search.")
