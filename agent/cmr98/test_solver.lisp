(load (merge-pathnames "cmr98_solver.lisp" *load-truename*))
(in-package :cmr98)
(defun bits (value width)
  (loop for i below width collect (if (logbitp i value) 1 0)))
(defun solution-holds (solution environment)
  (case (first solution)
    (:valid t) (:unsat nil)
    (:solved
     (let ((fresh (make-hash-table :test #'equal)))
       (block check
         (dolist (row (second solution) t)
           (destructuring-bind (name len normal) row
             (let ((value (gethash name environment)) (at 0))
               (assert (= len (length value)))
               (dolist (p normal)
                 (destructuring-bind (key lo n) p
                   (assert (zerop lo))
                   (let ((chunk (subseq value at (+ at n))))
                     (if (eq (first key) :const)
                         (unless (every (lambda (b) (= b (second key))) chunk)
                           (return-from check nil))
                         (multiple-value-bind (old found) (gethash key fresh)
                           (if found (unless (equal old chunk) (return-from check nil))
                               (setf (gethash key fresh) chunk))))
                     (incf at n))))
               (assert (= at len))))))))))

(defun check-equations (equations)
  (let ((vars (variables (loop for (a b) in equations append (list a b))))
        (env (make-hash-table :test #'equal))
        (solution (solve equations)) names widths)
    (maphash (lambda (name width) (push name names) (push width widths)) vars)
    (labels ((visit (names widths)
               (if names
                   (loop for v below (expt 2 (car widths)) do
                     (setf (gethash (car names) env) (bits v (car widths)))
                     (visit (cdr names) (cdr widths)))
                   (let ((expected
                           (every (lambda (eqn)
                                    (equal (evaluate-term (first eqn) env)
                                           (evaluate-term (second eqn) env))) equations)))
                     (assert (eq (not (null expected))
                                 (not (null (solution-holds solution env)))))
                     (dolist (eqn equations)
                       (dolist (term eqn)
                         (let ((normal-env (make-hash-table :test #'equal)))
                           (maphash (lambda (name value)
                                      (setf (gethash (list :var name) normal-env) value)) env)
                           (assert (equal (evaluate-term term env)
                                          (evaluate-normal (canon term) normal-env))))))))))
      (visit names widths)))
  t)

(let* ((x '(:var x 4)) (y '(:var y 4))
       (terms (list x y '(:const 0 4) '(:const 1 4)
                    (list :cat (list :cut x 1 0) (list :cut x 3 2))
                    (list :cut (list :cat x y) 5 2)
                    (list :cat (list :cut y 3 2) (list :cut x 1 0))))
       (count 0))
  (dolist (a terms)
    (dolist (b terms)
      (check-equations (list (list a b))) (incf count)))
  ;; Exhaustive systems exercise transitive closure and propagated conflicts.
  (dolist (a terms)
    (dolist (b terms)
      (check-equations (list (list x a) (list y b))) (incf count)))
  (loop for n from 2 to 8 do
    (loop for len from 1 below n do
      (loop for lo from 0 to (- n len) do
        (loop for other from 0 to (- n len) do
          (check-equations
           (list (list (list :cut (list :var 'x n) (+ lo len -1) lo)
                       (list :cut (list :var 'x n) (+ other len -1) other))))
          (incf count)))))
  (check-equations nil)
  ;; A million-bit unchanged block stays one column rather than bit-blasting.
  (let ((result (solve '(((:var x 1000000) (:var y 1000000))))))
    (assert (eq (first result) :solved))
    (assert (= (getf *last-statistics* :fresh) 1))
    (assert (= (getf *last-statistics* :columns) 2)))
  (format t "~&CMR98: ~d equation systems checked exhaustively; wide interval test passed.~%" count))

;; Independently check each certificate edge's provenance and interval bounds.
(let* ((x '(:var x 6)) (y '(:var y 6))
       (eqs (list (list (list :cut x 5 1) (list :cut x 4 0))
                  (list (list :cat (list :cut x 5 3) (list :cut y 2 0)) y)))
       (goals (list (list (list :cut x 5 5) (list :cut x 0 0))))
       (env (make-hash-table :test #'equal))
       (normal-env (make-hash-table :test #'equal)))
  (multiple-value-bind (edges targets) (certificate-plan eqs goals)
    (assert (= (length targets) 1))
    (dolist (edge edges) (assert (< (first edge) (length eqs))))
    (loop for a below 64 do (loop for b below 64 do
      (setf (gethash 'x env) (bits a 6) (gethash 'y env) (bits b 6)
            (gethash '(:var x) normal-env) (bits a 6)
            (gethash '(:var y) normal-env) (bits b 6))
      (dolist (edge (append edges targets))
        (destructuring-bind (num lo len left right) edge
          (let ((eqn (nth num (append eqs goals))))
            (loop for term in eqn for piece in (list left right) do
              (assert (equal (subseq (evaluate-term term env) lo (+ lo len))
                             (evaluate-normal (list piece) normal-env))))))))))
  ;; Target-only equalities must never be smuggled into the source edges.
  (multiple-value-bind (edges targets) (certificate-plan nil goals)
    (assert (null edges)) (assert targets)))
(format t "CMR98: certificate projection provenance and target separation passed.~%")
(let ((eqs '(((:cut (:var x 1000000) 999999 1)
              (:cut (:var x 1000000) 999998 0)))))
  (dolist (operation (list (lambda () (solve eqs :max-columns 8))
                          (lambda () (certificate-plan eqs nil :max-columns 8))))
    (assert (handler-case (progn (funcall operation) nil)
              (error (c) (search "column limit" (princ-to-string c)))))))
(format t "CMR98: explicit column resource bounds passed.~%")
