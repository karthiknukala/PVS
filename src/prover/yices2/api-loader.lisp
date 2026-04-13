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

(defun yices2-api (sformnums)
  (ensure-yices2-api-implementation)
  (yices2-api-dispatch sformnums))

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

(addrule 'yices2-api () ((fnums *))
  (yices2-api fnums)
  "Invokes Yices2 through the CFFI API as an endgame solver over the selected formulas."
  "~%Calling Yices2 through the CFFI API,")

(defstep y2api-simp (&optional (fnums *))
  (let ((loaded? (ensure-yices2-api-implementation)))
    (then (skosimp*) (yices2-api :fnums fnums)))
  "Repeatedly skolemizes and flattens, then invokes the standalone Yices2 CFFI API prover."
  "Repeatedly skolemizing and flattening, and then invoking the Yices2 CFFI API prover")

(addrule 'y2api-show-model nil nil
  (yices2-api-show-model-dispatch)
  "Prints the most recent Yices2 API model, if one was produced by a satisfiable run.")

(addrule 'y2api-show-counterexample nil nil
  (yices2-api-show-counterexample-dispatch)
  "Prints the most recent Yices2 API counterexample, if one was produced by a satisfiable run.")

(addrule 'y2api-show-unsat-core nil nil
  (yices2-api-show-unsat-core-dispatch)
  "Prints the most recent Yices2 API UNSAT core, if one was produced by an unsatisfiable run.")
