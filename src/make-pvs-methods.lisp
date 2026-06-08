;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-pvs-methods.lisp -- 
;; Author          : Sam Owre
;; Created On      : Thu Dec 31 19:16:33 1998
;; Last Modified By: Sam Owre
;; Last Modified On: Thu Dec 31 21:13:07 1998
;; Update Count    : 11
;; Status          : Stable
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

(in-package :cl-user)

(eval-when (:execute :load-toplevel)
  ;; This sets *pvs-path* and *pvs-fasl-type*
  (load "pvs-config.lisp"))

(in-package :pvs)

(load "src/defcl.lisp")
(load "src/store-object.lisp")
(load "src/classes-expr.lisp")
(load "src/classes-decl.lisp")
(load "src/prover/estructures.lisp")

(write-deferred-methods-to-file t)

(uiop:quit 0)
