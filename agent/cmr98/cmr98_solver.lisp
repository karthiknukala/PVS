;;; CMR sections 5-6, represented as LSB-first intervals.
;;; No prover globals, state, oracle calls, or proof-status mutations.
(defpackage :cmr98
  (:use :cl)
  (:export :canon :solve :certificate-plan :width :evaluate-term :evaluate-normal :*last-statistics*))
(in-package :cmr98)

;; Public AST: (:var name width), (:const 0|1 width), (:cat high low),
;;             (:cut term high low). All widths are positive.
;; Normal form pieces: (key offset width); key = (:var name) | (:const bit).
(defvar *last-statistics* nil)
(defun positive (n)
  (unless (and (integerp n) (plusp n)) (error "Non-positive width: ~s" n)) n)
(defun width (term)
  (ecase (first term)
    ((:var :const) (positive (third term)))
    (:cat (+ (width (second term)) (width (third term))))
    (:cut (destructuring-bind (tag arg hi lo) term
            (declare (ignore tag))
            (unless (and (integerp lo) (integerp hi) (<= 0 lo hi)
                         (< hi (width arg))) (error "Invalid extraction: ~s" term))
            (1+ (- hi lo))))))
(defun const-piece-p (p) (eq (caar p) :const))
(defun piece-cut (p lo len)
  (list (first p) (if (const-piece-p p) 0 (+ (second p) lo)) len))
(defun compact (pieces)
  (let (out)
    (dolist (p pieces (nreverse out))
      (let ((q (car out)))
        (if (and q (equal (first p) (first q))
                 (or (const-piece-p p) (= (second p) (+ (second q) (third q)))))
            (setf (third q) (+ (third q) (third p)))
            (push (copy-list p) out))))))
(defun window (pieces lo len)
  (loop with end = (+ lo len) with pos = 0
        for p in pieces for next = (+ pos (third p))
        for left = (max pos lo) for right = (min next end)
        when (< left right) collect (piece-cut p (- left pos) (- right left))
        do (setf pos next)))
(defun canon (term)
  (width term)
  (compact
   (ecase (first term)
     (:var (list (list (list :var (second term)) 0 (third term))))
     (:const (unless (member (second term) '(0 1)) (error "Not a bit constant"))
             (list (list (list :const (second term)) 0 (third term))))
     (:cat (append (canon (third term)) (canon (second term))))
     (:cut (window (canon (second term)) (fourth term)
                   (1+ (- (third term) (fourth term))))))))
(defun align (left right)
  "Common refinement at the existing term boundaries."
  (let ((a (copy-tree left)) (b (copy-tree right)) out)
    (loop while (and a b) do
      (let ((len (min (third (car a)) (third (car b)))))
        (push (list (piece-cut (car a) 0 len) (piece-cut (car b) 0 len)) out)
        (flet ((advance (xs)
                 (if (= len (third (car xs))) (cdr xs)
                     (cons (piece-cut (car xs) len (- (third (car xs)) len)) (cdr xs)))))
          (setf a (advance a) b (advance b)))))
    (when (or a b) (error "Unequal equation widths"))
    (nreverse out)))
(defun variables (terms)
  (let ((vars (make-hash-table :test #'equal)))
    (labels ((walk (term)
               (case (first term)
                 (:var (multiple-value-bind (old found) (gethash (second term) vars)
                         (when (and found (/= old (third term)))
                           (error "Inconsistent width for ~s" (second term)))
                       (setf (gethash (second term) vars) (third term))))
                 (:cat (walk (second term)) (walk (third term)))
                 (:cut (walk (second term))))))
      (mapc #'walk terms))
    vars))

(defun solve (equations &key (max-columns 4096))
  "Return (:valid), (:unsat), or (:solved ((name width normal-form)...)).
The solved form is existential in its (:fresh id) keys.
An interval common-refinement formulation of CMR's column propagation:
cuts propagate through repeated/shared intervals to a fixed point; union/find
merges equal-width columns, giving fresh representatives and constant clashes.
This avoids allocating individual bits unless the constraints force unit cuts."
  (let* ((vars (variables (loop for (a b) in equations append (list a b))))
         (cuts (make-hash-table :test #'equal))
         (parent (make-hash-table :test #'equal))
         (rank (make-hash-table :test #'equal))
         (constants (make-hash-table :test #'equal))
         (fresh (make-hash-table :test #'equal))
         (column-count (hash-table-count vars))
         (relations nil) (valid t) (next-fresh 0) (rounds 0))
    (positive max-columns)
    (when (> column-count max-columns) (error "CMR column limit ~d exceeded" max-columns))
    (maphash (lambda (name len) (setf (gethash name cuts) (list 0 len))) vars)
    (dolist (eqn equations)
      (destructuring-bind (a b) eqn
        (unless (= (width a) (width b)) (error "Equation width mismatch"))
        (let ((left (canon a)) (right (canon b)))
          (unless (equal left right) (setf valid nil))
          (setf relations (nconc relations (align left right))))))
    (labels
        ((add-cut (piece cut)
           (unless (const-piece-p piece)
             (let* ((name (second (first piece))) (old (gethash name cuts)))
               (unless (member cut old)
                 (when (> (incf column-count) max-columns)
                   (error "CMR column limit ~d exceeded" max-columns))
                 (push cut (gethash name cuts)) t))))
         (local-cuts (piece)
           (let ((lo (second piece)) (len (third piece)))
             (sort (remove-duplicates
                    (append (list 0 len)
                            (unless (const-piece-p piece)
                              (loop for cut in (gethash (second (first piece)) cuts)
                                    when (< lo cut (+ lo len)) collect (- cut lo)))))
                   #'<)))
         (root (node)
           (multiple-value-bind (p found) (gethash node parent)
             (cond ((not found)
                    (setf (gethash node parent) node)
                    (when (const-piece-p node)
                      (setf (gethash node constants) (second (first node))))
                    node)
                   ((equal p node) node)
                   (t (setf (gethash node parent) (root p))))))
         (merge-nodes (a b)
           (assert (= (third a) (third b)))
           (let ((ra (root a)) (rb (root b)))
             (unless (equal ra rb)
               (multiple-value-bind (ca has-a) (gethash ra constants)
                 (multiple-value-bind (cb has-b) (gethash rb constants)
                   (when (and has-a has-b (/= ca cb))
                     (return-from solve '(:unsat)))
                   (when (< (gethash ra rank 0) (gethash rb rank 0))
                     (rotatef ra rb))
                   (setf (gethash rb parent) ra)
                   (when (= (gethash ra rank 0) (gethash rb rank 0))
                     (incf (gethash ra rank 0)))
                   (when (or has-a has-b)
                     (setf (gethash ra constants) (if has-a ca cb))))))))
         (representative (node)
           (let ((r (root node)))
             (multiple-value-bind (bit found) (gethash r constants)
               (if found (list (list :const bit) 0 (third node))
                   (list (or (gethash r fresh)
                             (setf (gethash r fresh) (list :fresh (incf next-fresh))))
                         0 (third node)))))))
      (dolist (rel relations)
        (dolist (p rel) (add-cut p (second p)) (add-cut p (+ (second p) (third p)))))
      ;; Propagate all interior boundaries through equality translations.
      ;; Finite termination: every added cut is an integer within a variable.
      (loop with changed = t while changed do
        (setf changed nil)
        (incf rounds)
        (dolist (rel relations)
          (destructuring-bind (a b) rel
            (dolist (cut (union (local-cuts a) (local-cuts b)))
              (when (add-cut a (+ (second a) cut)) (setf changed t))
              (when (add-cut b (+ (second b) cut)) (setf changed t))))))
      (dolist (rel relations)
        (destructuring-bind (a b) rel
          (let ((boundaries (sort (union (local-cuts a) (local-cuts b)) #'<)))
            (loop for (lo hi) on boundaries while hi do
              (merge-nodes (piece-cut a lo (- hi lo)) (piece-cut b lo (- hi lo)))))))
      (let (answer)
        (maphash
         (lambda (name len)
           (let ((boundaries (sort (copy-list (gethash name cuts)) #'<)))
             (push (list name len
                         (compact
                          (loop for (lo hi) on boundaries while hi collect
                            (representative (list (list :var name) lo (- hi lo))))))
                   answer))) vars)
        (setf *last-statistics*
              (list :variables (hash-table-count vars) :rounds rounds
                    :columns (hash-table-count parent) :fresh next-fresh))
        (if valid '(:valid) (list :solved (nreverse answer)))))))

(defun evaluate-term (term environment)
  "Independent executable bit semantics, used by differential tests."
  (ecase (first term)
    (:var (gethash (second term) environment))
    (:const (make-list (third term) :initial-element (second term)))
    (:cat (append (evaluate-term (third term) environment)
                  (evaluate-term (second term) environment)))
    (:cut (subseq (evaluate-term (second term) environment)
                  (fourth term) (1+ (third term))))))
(defun evaluate-normal (normal environment)
  (loop for (key lo len) in normal append
    (if (eq (first key) :const) (make-list len :initial-element (second key))
        (subseq (gethash key environment) lo (+ lo len)))))

(defun certificate-plan (equations targets &key (max-columns 4096))
  "Return source columns with projection provenance, plus aligned target columns.
Every edge carries (equation-number source-offset length left-piece right-piece).
Targets introduce boundaries only, never assumed equalities."
  (let* ((all (append equations targets))
         (vars (variables (loop for (a b) in all append (list a b))))
         (cuts (make-hash-table :test #'equal))
         (column-count (hash-table-count vars)) (relations nil))
    (positive max-columns)
    (when (> column-count max-columns) (error "CMR column limit ~d exceeded" max-columns))
    (maphash (lambda (name len) (setf (gethash name cuts) (list 0 len))) vars)
    (loop for (a b) in all for num from 0 do
      (unless (= (width a) (width b)) (error "Unequal certificate widths"))
      (loop with pos = 0 for (left right) in (align (canon a) (canon b)) do
        (push (list num pos left right) relations)
        (incf pos (third left))))
    (setf relations (nreverse relations))
    (labels ((add-cut (piece pos)
               (unless (const-piece-p piece)
                 (let ((name (second (first piece))))
                   (unless (member pos (gethash name cuts))
                     (when (> (incf column-count) max-columns)
                       (error "CMR column limit ~d exceeded" max-columns))
                     (push pos (gethash name cuts)) t))))
             (local-cuts (piece)
               (let ((lo (second piece)) (len (third piece)))
                 (append (list 0 len)
                         (unless (const-piece-p piece)
                           (loop for cut in (gethash (second (first piece)) cuts)
                                 when (< lo cut (+ lo len)) collect (- cut lo)))))))
      (dolist (rel relations)
        (dolist (piece (cddr rel))
          (add-cut piece (second piece))
          (add-cut piece (+ (second piece) (third piece)))))
      (loop with changed = t while changed do
        (setf changed nil)
        (dolist (rel relations)
          (destructuring-bind (num pos a b) rel
            (declare (ignore num pos))
            (dolist (cut (union (local-cuts a) (local-cuts b)))
              (when (add-cut a (+ (second a) cut)) (setf changed t))
              (when (add-cut b (+ (second b) cut)) (setf changed t))))))
      (let (sources goals)
        (dolist (rel relations)
          (destructuring-bind (num pos a b) rel
            (let ((bounds (sort (remove-duplicates
                                 (append (local-cuts a) (local-cuts b))) #'<)))
              (loop for (lo hi) on bounds while hi do
                (let ((edge (list num (+ pos lo) (- hi lo)
                                  (piece-cut a lo (- hi lo))
                                  (piece-cut b lo (- hi lo)))))
                  (if (< num (length equations)) (push edge sources)
                      (push edge goals)))))))
        (values (nreverse sources) (nreverse goals))))))
