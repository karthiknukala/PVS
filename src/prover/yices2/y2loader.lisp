;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; y2loader.lisp --
;;   Top-level lazy loader for the direct Yices2 CFFI integration.
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

(defvar *y2api/yices2-dylib-path* nil
  "Path to the Yices2 dynamic library used by the direct CFFI bindings.")

(defvar *y2direct-implementation-loaded* nil)
(defvar *y2direct-implementation-loading* nil)

(defun y2loader-source-file (name)
  (assert *pvs-path*)
  (format nil "~a/src/prover/yices2/~a.lisp" *pvs-path* name))

(defun ensure-y2direct-implementation ()
  (unless *y2direct-implementation-loaded*
    (when *y2direct-implementation-loading*
      (error "Recursive attempt to load the direct Yices2 implementation"))
    (let ((*y2direct-implementation-loading* t))
      (dolist (file '("y2bindings" "y2structures" "y2macros" "y2direct"))
        (load (y2loader-source-file file)))
      (setq *y2direct-implementation-loaded* t)))
  t)

(defun y2loader-call-implementation (name args)
  (let ((loader-function (and (fboundp name) (symbol-function name))))
    (ensure-y2direct-implementation)
    (let ((implementation (and (fboundp name) (symbol-function name))))
      (when (or (null implementation)
                (eq implementation loader-function))
        (error "Direct Yices2 implementation did not define ~a" name))
      (apply implementation args))))

(defun y2direct (sformnums nonlinear? &optional logic (model? t))
  (y2loader-call-implementation
   'y2direct
   (list sformnums nonlinear? logic model?)))

(defun y2direct-hide-unsat-core (sformnums nonlinear? &optional logic)
  (y2loader-call-implementation
   'y2direct-hide-unsat-core
   (list sformnums nonlinear? logic)))

(addrule 'y2direct () ((fnums *) nonlinear? logic (model? t))
  (y2direct fnums nonlinear? logic model?)
  "Invokes the Yices2 C API as a direct, quantifier-free endgame solver."
  "~%Simplifying with direct Yices2,")

(addrule 'y2direct-core () ((fnums *) nonlinear? logic)
  (y2direct-hide-unsat-core fnums nonlinear? logic)
  "Computes a Yices2 unsat core for FNUMS and hides selected formulas outside the core."
  "~%Computing a direct Yices2 unsat core,")

(defstep y2direct-simp (&optional (fnums *) nonlinear? logic (model? t))
  (then (skosimp*) (y2direct :fnums fnums
                             :nonlinear? nonlinear?
                             :logic logic
                             :model? model?))
  "Repeatedly skolemizes and flattens, then invokes direct Yices2."
  "Repeatedly skolemizing and flattening, and invoking direct Yices2")

(defstep y2direct-core-simp (&optional (fnums *) nonlinear? logic)
  (then (skosimp*) (y2direct-core :fnums fnums
                                  :nonlinear? nonlinear?
                                  :logic logic)
        (y2direct :fnums * :nonlinear? nonlinear?
                  :logic logic
                  :model? nil))
  "Repeatedly skolemizes, computes a Yices2 unsat core, hides non-core formulas, then invokes direct Yices2."
  "Repeatedly skolemizing, hiding formulas outside the direct Yices2 core, and invoking direct Yices2")
