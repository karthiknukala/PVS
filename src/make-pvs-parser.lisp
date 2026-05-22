;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-pvs-parser.lisp -- 
;; Author          : Sam Owre

;; This file is intended to be called directly from a lisp image, to create
;; the PVS parser from the Ergo system. Hence it is invoked directly from
;; the PVS Makefile, not from pvs.system
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

(in-package :common-lisp)

(defmacro defconstant-if-unbound (name value &optional doc)
  `(defconstant ,name (if (boundp ',name) (symbol-value ',name) ,value)
     ,@(when doc (list doc))))
(export 'defconstant-if-unbound)

(in-package :cl-user)

(eval-when (:execute :load-toplevel)
  ;; This sets *pvs-path* and *pvs-fasl-type*
  (load "pvs-config.lisp"))

(load (format nil "~a/ess/dist-ess.lisp" *pvs-path*))
(generate-ess ergolisp sb)

#+allegro
(compile-file-if-needed (format nil "~a/src/ergo-gen-fixes" *pvs-path*))
#-allegro
(compile-file (format nil "~a/src/ergo-gen-fixes" *pvs-path*))
(load (format nil "~a/src/ergo-gen-fixes" *pvs-path*))
(let ((sbmake (intern (string :sb-make) :sb)))
  (funcall sbmake
	   :language "pvs"
	   :working-dir (format nil "~a/src/" (or *pvs-path* "."))
	   :unparser? nil))
(bye)
