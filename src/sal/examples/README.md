# SAL AST compiler examples

This directory contains two small but nontrivial SAL programs and a set of
compiler-style passes over their SBCL CLOS ASTs.

The examples demonstrate:

- allocation-free child visits and iterative preorder walking;
- folds, searches, collections, class histograms, and node counts;
- declaration-use analysis using identity-resolved references;
- module dependency graph construction;
- reusable class/name/parent indexes;
- bottom-up persistent rewriting with structural sharing;
- optimizer idempotence and structural comparison;
- destructive hash-consing that preserves declaration identity;
- pretty-printing an optimized AST back to SAL; and
- invoking SAL's semantic simplifier and flattener.

The files are organized as a small compiler rather than isolated snippets:

- `walk-and-analyze.lisp` contains walkers, folds, early-exit search,
  declaration-use analysis, tree-shape metrics, parent/name/class indexes,
  reference validation, and a module dependency graph.
- `rewrite-and-intern.lisp` contains a persistent constant-folding pass,
  fixed-point iteration, an identity-preserving rename, structural
  hashing/equality checks, and hash-consing.
- `compiler-pipeline.lisp` connects ingestion, validation, analysis,
  optimization, interning, emission, parser round-tripping, simplification,
  and flattening.
- `run-examples.lisp` exercises the complete pipeline on both models.

## Models

- `bounded_counter.sal` contains guarded commands, state variables, temporal
  properties, deliberately foldable constants, and an unused declaration.
- `arbiter.sal` contains three communicating modules and a composed `system`
  module, making its module dependency graph visible.

## Running

From the repository root, with Quicklisp and SAL 3.3 installed:

```sh
SAL_HOME=/path/to/sal-3.3 \
sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --load src/sal/examples/bootstrap.lisp
```

This runs the CLOS frontend, analyses, optimizer, hash-consing, and emitter.
Optimized SAL files are written to the system temporary directory.

To additionally invoke SAL's simplifier and flattener:

```sh
SAL_HOME=/path/to/sal-3.3 SAL_EXAMPLES_EXTERNAL=1 \
sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --load src/sal/examples/bootstrap.lisp
```

The static transformation scripts must be installed in `$SAL_HOME/tools`, or
`PVS:*SAL-TRANSFORM-PROGRAM*` must name the bundled `sal-transform.sh`.

Inside an already running PVS Lisp image, the shorter form is:

```lisp
(load "src/sal/examples/run-examples.lisp")
```

Load the individual Lisp files instead when experimenting with one pass at a
time.  Every example definition begins with `SAL-EXAMPLE-` to avoid colliding
with the compiler itself.

For example, after loading those files:

```lisp
(defparameter *counter* (sal-example-load "bounded_counter.sal"))

;; Fast queries and indexes.
(sal-example-declaration-names *counter*)
(sal-example-numeral-values *counter*)
(sal-example-first-large-numeral *counter* 20)
(sal-index-declarations (sal-index-ast *counter*) "counter"
                        :type 'sal-module-decl)

;; A persistent optimization followed by canonical interning.
(defparameter *optimized* (sal-example-optimize *counter*))
(multiple-value-bind (canonical table)
    (sal-example-canonicalize *optimized*)
  (values canonical
          (sal-hash-cons-table-hits table)
          (sal-hash-cons-table-count table)))

;; SAL's semantic pipeline remains available when it is actually needed.
(sal-simplify-file (sal-example-path "bounded_counter.sal")
                   :declaration "counter")
(sal-flatten-file (sal-example-path "arbiter.sal")
                  :declaration "system")
```

The full runner visibly folds `LIMIT` to 8 and `UNUSED_BUDGET` to 42, reports
`system -> requester1, requester2, arbiter_core`, verifies optimizer
idempotence, and reparses every emitted file.
