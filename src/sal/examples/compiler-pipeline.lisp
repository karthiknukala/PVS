;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler-pipeline.lisp -- End-to-end SAL processing example
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :pvs)

(defstruct sal-example-compilation
  source
  original
  optimized
  index
  use-counts
  module-graph
  hash-cons-table
  output
  emitted)

(defun sal-example-compile-file (source &key output)
  "Read, validate, analyze, optimize, intern, and optionally emit SOURCE."
  (let* ((original (sal-preprocess-file source))
         (_ (sal-example-validate-references original))
         (index (sal-index-ast original))
         (uses (sal-example-declaration-use-counts original))
         (graph (sal-example-module-dependency-graph original))
         (rewritten (sal-example-optimize original)))
    (declare (ignore _))
    (multiple-value-bind (optimized hash-cons-table)
        (sal-example-canonicalize rewritten)
      (let ((emitted
              (when output
                (write-sal-file optimized output :right-margin 90)
                ;; Re-enter through SAL's parser, XML exporter, and CLOS
                ;; reader.  This catches invalid pretty-printer output.
                (sal-preprocess-file output))))
        (make-sal-example-compilation
         :source source
         :original original
         :optimized optimized
         :index index
         :use-counts uses
         :module-graph graph
         :hash-cons-table hash-cons-table
         :output output
         :emitted emitted)))))

(defun sal-example-print-compilation (compilation
                                      &optional (stream *standard-output*))
  (let ((original (sal-example-compilation-original compilation))
        (optimized (sal-example-compilation-optimized compilation))
        (table (sal-example-compilation-hash-cons-table compilation)))
    (format stream "~&~%=== ~A ===~%"
            (sal-example-compilation-source compilation))
    (sal-example-print-analysis original stream)
    (sal-example-print-optimization original optimized table stream)
    (when (sal-example-compilation-output compilation)
      (format stream "Wrote and parsed back: ~A (~D nodes)~%"
              (sal-example-compilation-output compilation)
              (sal-count-ast
               (sal-example-compilation-emitted compilation)))))
  compilation)

(defun sal-example-run-external-passes (source declaration
                                        &optional (stream *standard-output*))
  "Demonstrate the boundary between local passes and SAL's semantic passes."
  (let ((simplified
          (sal-simplify-file source :declaration declaration :syntax :lsal))
        (flattened
          (sal-flatten-file source :declaration declaration :syntax :lsal)))
    (format stream "~&SAL simplify output: ~D bytes~%"
            (length (sal-external-result-output simplified)))
    (format stream "SAL flatten output:  ~D bytes~%"
            (length (sal-external-result-output flattened)))
    (values simplified flattened)))
