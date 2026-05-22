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

(in-package :clos)
#+allegro
(preload-forms)

#+allegro
(excl::preload-constructors (:cl-user :lisp :pvs))

#+allegro
(excl::precache-generic-functions (:cl-user :lisp :pvs))

#+lucid
(compile-all-dispatch-code)
