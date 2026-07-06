;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; multi-stack-examples.lisp --
;;   Examples for using several Yices2 stacks under one scoped manager
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

;; These examples assume y2bindings.lisp, y2structures.lisp, and y2macros.lisp
;; are already loaded.

(defun y2/example-multi-stack-portfolio ()
  "Use one manager as a small portfolio of independent Yices2 stacks.

The manager owns four named stacks:
  :NONLINEAR-GUARD  QF_NRA with MCSAT
  :PACKET-MCSAT     QF_BV with MCSAT
  :LINEAR-BUDGET    QF_LRA on the DPLL(T)/CDCL(T) side
  :FEATURE-FLAGS    QF_BV on the DPLL(T)/CDCL(T) side

The return value is an alist mapping each scenario to the solver status."
  (y2/with-manager (mgr :default-stack :linear-budget
                        :logic "QF_LRA"
                        :mode "push-pop"
                        :configs '((solver-type dpllt)))
    (declare (ignore mgr))
    (y2/with-vars ((x real) (y real)
                   (steel real) (copper real) (labor real)
                   (opcode (bv 8)) (lane (bv 8)) (tag (bv 8))
                   (current (bv 8)) (enable (bv 8))
                   (disable (bv 8)) (next (bv 8)))
      (let ((results nil))
        (flet ((note (name status)
                 (push (cons name status) results)))
          (y2/with-stack (:nonlinear-guard
                          :logic "QF_NRA"
                          :mode "push-pop"
                          :mcsat t)
            (y2/assert-named!
             "tool head remains inside radius 5"
             (y2/<= (y2/+ (y2/* x x) (y2/* y y)) (y2/rat 25)))
            (y2/with-push ()
              (y2/assert-named! "known boundary point"
                                (y2/and (y2/= x (y2/rat 3))
                                        (y2/= y (y2/rat 4))))
              (note :nra-mcsat-boundary-point (y2/check!)))
            (y2/with-push ()
              (y2/assert-named! "unsafe northeast corner request"
                                (y2/and (y2/>= x (y2/rat 4))
                                        (y2/>= y (y2/rat 4))))
              (note :nra-mcsat-corner-request (y2/check!))))

          (y2/with-stack (:packet-mcsat
                          :logic "QF_BV"
                          :mode "push-pop"
                          :mcsat t)
            (y2/assert-named!
             "tag is a reversible 8-bit packet digest"
             (y2/bv= tag
                     (y2/bvxor
                      (y2/bv+ (y2/bv* opcode (y2/bvconst 8 #x07))
                              lane)
                      (y2/bvconst 8 #xa5))))
            (y2/assert-named! "lane id fits four physical lanes"
                              (y2/bv< lane (y2/bvconst 8 4)))
            (y2/with-push ()
              (y2/assert-named! "look for a packet with digest 0x5a"
                                (y2/bv= tag (y2/bvconst 8 #x5a)))
              (note :bv-mcsat-packet-search (y2/check!)))
            (y2/with-push ()
              (y2/assert-named! "zero packet has a fixed digest"
                                (y2/and (y2/bv= opcode (y2/bvzero 8))
                                        (y2/bv= lane (y2/bvzero 8))
                                        (y2/bv= tag (y2/bvconst 8 #x5a))))
              (note :bv-mcsat-zero-packet-contradiction (y2/check!))))

          (y2/with-stack (:linear-budget)
            (y2/assert-named! "steel is nonnegative"
                              (y2/nonnegative? steel))
            (y2/assert-named! "copper is nonnegative"
                              (y2/nonnegative? copper))
            (y2/assert-named!
             "press capacity"
             (y2/<= (y2/+ (y2/* (y2/rat 2) steel) copper)
                    (y2/rat 120)))
            (y2/assert-named!
             "plating capacity"
             (y2/<= (y2/+ steel (y2/* (y2/rat 3) copper))
                    (y2/rat 150)))
            (y2/assert-named!
             "labor accounting"
             (y2/= labor
                   (y2/+ (y2/* (y2/rat 3) steel)
                         (y2/* (y2/rat 2) copper))))
            (y2/with-push ()
              (y2/assert-named! "balanced rush order"
                                (y2/and (y2/>= steel (y2/rat 30))
                                        (y2/>= copper (y2/rat 30))
                                        (y2/<= labor (y2/rat 170))))
              (note :lra-cdclt-balanced-order (y2/check!)))
            (y2/with-push ()
              (y2/assert-named! "oversubscribed rush order"
                                (y2/and (y2/>= steel (y2/rat 40))
                                        (y2/>= copper (y2/rat 50))
                                        (y2/<= labor (y2/rat 210))))
              (note :lra-cdclt-oversubscribed-order (y2/check!))))

          (y2/with-stack (:feature-flags
                          :logic "QF_BV"
                          :mode "push-pop"
                          :configs '((solver-type dpllt)))
            (y2/assert-named!
             "feature update equation"
             (y2/bv= next
                     (y2/bvand (y2/bvor current enable)
                               (y2/bvnot disable))))
            (y2/assert-named!
             "a feature cannot be enabled and disabled in one patch"
             (y2/bv= (y2/bvand enable disable) (y2/bvzero 8)))
            (y2/with-push ()
              (y2/assert-named!
               "turn on bits 0 and 2 while clearing bit 4"
               (y2/and (y2/bv= current (y2/bvconst 8 #x10))
                       (y2/bv= enable (y2/bvconst 8 #x05))
                       (y2/bv= disable (y2/bvconst 8 #x10))
                       (y2/bv= next (y2/bvconst 8 #x05))))
              (note :bv-cdclt-clean-feature-patch (y2/check!)))
            (y2/with-push ()
              (y2/assert-named!
               "try to both enable and disable bit 2"
               (y2/and (y2/bv= enable (y2/bvconst 8 #x04))
                       (y2/bv= disable (y2/bvconst 8 #x04))))
              (note :bv-cdclt-conflicting-feature-patch (y2/check!))))

          (nreverse results))))))

(defun y2/example-bv-mcsat-vs-cdclt ()
  "Run the same QF_BV transition problem in two different solver stacks."
  (y2/with-manager (mgr :default-stack :bv-cdclt
                        :logic "QF_BV"
                        :mode "push-pop"
                        :configs '((solver-type dpllt)))
    (declare (ignore mgr))
    (y2/with-vars ((key (bv 16))
                   (nonce (bv 16))
                   (mix (bv 16)))
      (let ((results nil))
        (flet ((note (name status)
                 (push (cons name status) results))
               (load-round ()
                 (y2/assert-named!
                  "toy 16-bit round function"
                  (y2/bv= mix
                          (y2/bvxor
                           (y2/bv+ (y2/bv* key (y2/bvconst 16 #x000d))
                                   nonce)
                           (y2/bvconst 16 #xbeef))))))
          (dolist (stack-spec '((:bv-cdclt nil)
                                (:bv-mcsat t)))
            (destructuring-bind (name mcsat?) stack-spec
              (y2/with-stack (name :logic "QF_BV"
                                   :mode "push-pop"
                                   :mcsat mcsat?
                                   :configs
                                   (unless mcsat?
                                     '((solver-type dpllt))))
                (load-round)
                (y2/with-push ()
                  (y2/assert-named!
                   "zero input produces the known beacon"
                   (y2/and (y2/bv= key (y2/bvzero 16))
                           (y2/bv= nonce (y2/bvzero 16))
                           (y2/bv= mix (y2/bvconst 16 #xbeef))))
                  (note (list name :beacon) (y2/check!)))
                (y2/with-push ()
                  (y2/assert-named!
                   "zero input cannot produce all-zero mix"
                   (y2/and (y2/bv= key (y2/bvzero 16))
                           (y2/bv= nonce (y2/bvzero 16))
                           (y2/bv= mix (y2/bvzero 16))))
                  (note (list name :blocked-zero-mix) (y2/check!)))))))
          (nreverse results)))))

(defun y2/example-nra-interpolant ()
  "Compute an interpolant between two QF_NRA/MCSAT stacks.

Stack A models private Cartesian coordinates X and Y and exports only the shared
symbol RADIUS2. Stack B models a controller limit over RADIUS2. Since X and Y
are private to stack A, a returned interpolant should summarize the conflict in
terms of RADIUS2 alone."
  (y2/with-manager (mgr :default-stack :plant
                        :logic "QF_NRA"
                        :mcsat t)
    (y2/with-vars ((x real) (y real) (radius2 real))
      (y2/with-stack (:plant)
        (y2/assert-named!
         "radius2 is the squared distance from the origin"
         (y2/= radius2
               (y2/+ (y2/* x x) (y2/* y y))))
        (y2/assert-named! "plant is in the northeast operating region"
                          (y2/and (y2/>= x (y2/rat 4))
                                  (y2/>= y (y2/rat 4)))))
      (y2/with-stack (:controller
                      :logic "QF_NRA"
                      :mcsat t)
        (y2/assert-named! "controller requires radius at most 5"
                          (y2/<= radius2 (y2/rat 25))))
      (multiple-value-bind (status interpolant)
          (y2/check-interpolation! :plant :controller :manager mgr)
        (list :status status
              :interpolant
              (and interpolant
                   (y2/term-string interpolant :width 120 :height 20)))))))

(defun y2/example-linear-interpolant ()
  "Backward-compatible name for Y2/EXAMPLE-NRA-INTERPOLANT."
  (y2/example-nra-interpolant))
