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

(use-package '(:ergolisp :oper :occ :term :sort :sb-runtime :lang :newattr))

(lang:lang-define 
:name "pvs"
:code-package (string :pvs) ; This works in both Allegro and SBCL
:abs-syn-package (string :pvs)
;; :conc-name "pvs7.2"
:use-packages '(:ergolisp :oper :occ :term :sort :sb-runtime :lang :newattr)
:working-dir (format nil "~asrc/" *pvs-path*)
;; :mergeable-default
;; :grammar-file (format nil "~a/src/pvs-gr.txt" *pvs-path*)
;; :lexer-file (format nil "~a/src/pvs-lexer.lisp" *pvs-path*)
;; :parser-file (format nil "~a/src/pvs-parser.lisp" *pvs-path*)
;; :unparser-file (format nil "~a/src/new-pvs-unparser.lisp" *pvs-path*)
:unparse-nts 't
;; :info-file (format nil "~a/src/new-pvs-info.lisp" *pvs-path*)
:package (string :pvs)
;; :sorts-file (format nil "~a/src/new-pvs-sorts.lisp" *pvs-path*)
;; :parse-routine-name 'pvs-parse
;; :unparse-routine-name 'pvs-unparse
;; :sort-table-name '*pvs-sort-table*	;
;; :opsig-table-name '*pvs-opsig-table*
;; :win-unparse-routine-name 'pvs-win-unparse
:sub-languages '(:lexical-terminals)
)
