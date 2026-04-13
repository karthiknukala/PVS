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

(addrule 'yices2-api ()
    ((fnums *) nonlinear? logic (mode "one-shot") solver-type
     configs params enable-options disable-options)
  (yices2-api fnums
              :nonlinear? nonlinear?
              :logic logic
              :mode mode
              :solver-type solver-type
              :configs configs
              :params params
              :enable-options enable-options
              :disable-options disable-options)
  "Invokes Yices2 through the CFFI API as an endgame solver over the selected formulas, with optional direct control of logic/config/parameter/context-option settings."
  "~%Calling Yices2 through the CFFI API,")

(defstep y2api-simp (&optional (fnums *)
                               &key nonlinear? logic
                               (mode "one-shot") solver-type configs params
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
                      :enable-options enable-options
                      :disable-options disable-options)))
  "Repeatedly skolemizes and flattens, then invokes the standalone Yices2 CFFI API prover with direct Yices2 keyword control over logic, configuration, parameters, and context flags."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 CFFI API prover")

(defstep y2api-mcsat (&optional (fnums *)
                                &key logic (mode "one-shot")
                                solver-type configs params
                                enable-options disable-options)
  (y2api-simp :fnums fnums
              :nonlinear? t
              :logic logic
              :mode mode
              :solver-type solver-type
              :configs configs
              :params params
              :enable-options enable-options
              :disable-options disable-options)
  "Repeatedly skolemizes and flattens, then invokes the Yices2 API prover in nonlinear/MCSAT mode, with optional direct Yices2 logic/config/parameter/context-option settings."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 MCSAT API prover")

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
