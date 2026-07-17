# Yices2 API

This folder contains Lisp/FFI bindings to the Yices2 C API.

The Yices2 CFFI API enables ergonomic Lisp macros for manipulating Yices2 terms and configuring, organizing, and invoking the Yices2 solvers.

It is tightly integrated with PVS's prover -- users can dispatch suitable sequents with the Yices2 strategies, with no external file IO.

The in-memory translation of PVS CLOS AST objects to corresponding Yices2 CFFI terms can be customized for varied encodings at both the Lisp level and at the PVS level, with corresponding interpretable Yices2 PVS theories available in this package.


## Organization

The folder is organized as follows:
 - `doc/`: documentation for the Yices2 CFFI integration, along with coarser SMT integrations
 - `theories/`: subdirectory defining Yices2-friendly PVS theories that can be interpreted at the PVS level, bringing Yices2 automation to source formalizations.
 - `examples/`: examples used in technical report under `doc/`
 - `y2bindings.lisp`: installs Yices2 bindings by reading the Yices2 C API typedefs from the `api.spec` file.
 - `y2structures.lisp`: defines scoped Yices2 managers/stacks, context ownership, solver initialization/cleanup, push/pop scopes, configuration/parameter updates, and interpolation checks.
 - `y2macros.lisp`: given C bindings in `y2bindings.lisp`, `y2macros` defines a layer of Lisp macros that lets users manipulate term structure and invoke solvers safely.
 - `y2prover.lisp`: defines the PVS proof strategies, translates the sequent according to loaded theories from the `theories/` folder (or best-effort if none)
 - `y2shostak.lisp`: registers the `y2shostak` whiteboard decision procedure.
   Baseline PVS/Shostak receives every literal and owns shared canonization,
   congruence closure, datatype/tuple/update rules, rewriting, and interface
   equalities. Specialized Yices contexts receive purified theory projections
   and publish only proved equalities, disequalities, or conflicts.
 - `y2cad.lisp`: registers the `y2cad` QF_NRA decision procedure. It expands
   polynomials into a linear system over monomial variables, uses Simplex as a
   cheap relaxation gate, and invokes an exact MCSAT monomial-compatibility
   controller only at nonlinear branch-closure checkpoints.
 - `api.spec`: Yices2 C API typedefs to be used by the `y2bindings.lisp` macro loaders

To use the hybrid solver for ordinary PVS proof commands, select it as the
decision procedure:

```lisp
(set-decision-procedure 'y2shostak)
```

Run that form in the PVS Lisp listener after opening/typechecking the target
context, then start or restart the proof.  Within the prover, the usual PVS
assertion loop invokes the whiteboard and its satellites:

```lisp
(then (skosimp*) (assert))
```

If a branch remains open, the following observational prover commands preserve
the sequent while reporting the orchestrator state and its last satisfiable
satellite projection:

```lisp
(y2shostak-status)
(y2shostak-model)
(y2shostak-counterexample)
```

Tracing follows the `grind`/`grind$` convention. Enable the compact,
black-boxish event stream before invoking `assert` with:

```lisp
(y2shostak-trace)
```

It shows whiteboard routing, selected satellites and logics, fixed-point round
results, type-predicate frontiers, conflicts, and arrangement splits. Equality
and disequality propagation through the Shostak e-graph is intentionally omitted
at both trace levels. The dollar form exposes the white-box details:

```lisp
(y2shostak-trace$)
```

In full mode, the trace additionally shows each input and baseline canonical
form, every purified assertion sent to a satellite, the PVS-to-Yices interface
vocabulary, and demand constraints routed to a satellite. Turn either mode off
with:

```lisp
(y2shostak-untrace)
```

All three trace commands leave the current sequent unchanged. At the Lisp
level, the corresponding setting is `*y2shostak-trace-level*`, whose supported
values are `nil`, `:summary`, and `:full`; the older
`*y2shostak-verbose* = t` setting remains an alias for compact tracing.

The default satellite check is a bounded, demand-driven loop. It first checks
only the accumulated base constraints and immediate interface terms. If that
does not close the branch, it adds the type predicates of those terms and
checks again; subsequent rounds expose the type predicates of one deeper layer
of subterms at a time. `*y2shostak-max-typepred-depth*` bounds this expansion.
Reaching the bound never turns the incomplete search into a proof.

Before a constraint is inserted or translated for Yices, the Shostak
whiteboard canonicalizes it. Canonically true and duplicate constraints do not
enter a Yices context, and canonically equal value terms share one Yices term.
Each routed constraint retains its pre-insertion whiteboard so it cannot rewrite
itself while being translated.

`y2shostak-counterexample` prints the residual PVS sequent first.  That sequent
is the authoritative counterexample obligation and remains available for more
interactive simplification.  The model is deliberately labeled a *satellite
projection*: it can show arithmetic and bitvector interface values, but it may
omit predicates, datatype structure, or other symbols owned only by the PVS
whiteboard.  Model assignments are never learned as logical facts.

[`examples/y2shostak.pvs`](examples/y2shostak.pvs) contains closing examples for
NLA+UF, non-convex arrangements, NLA+datatypes, BV+UF, and a cross-satellite
NLA+BV+UF obligation, plus intentionally open examples showing readable PVS
sequents and projected countermodels.

### Demand-driven linear/monomial NRA (`y2cad`)

Select the lifted QF_NRA procedure with:

```lisp
(set-decision-procedure 'y2cad)
```

For every expanded monomial `x^alpha`, `y2cad` introduces a real variable
`z_alpha`. Polynomial literals become linear constraints over the `z` terms.
The LRA/Simplex relaxation receives these constraints and `z_0 = 1`. The exact
controller additionally receives `z_ei = x_i` and recursively factored
identities `z_(alpha+beta) = z_alpha * z_beta`; consequently its QF_NRA/MCSAT
query is equisatisfiable with the original polynomial conjunction.

The scheduler is intentionally demand-driven:

- A purely linear problem uses no MCSAT context.
- An inconsistent lifted relaxation closes in Simplex and uses no MCSAT
  context.
- Satisfiable nonlinear premises are accumulated without invoking MCSAT.
- MCSAT is invoked at a nonlinear closure checkpoint, normally the negated
  goal or final DPI validity query. Its result is cached by polynomial-
  constraint generation, so repeated checks do not invoke it again.

Thus MCSAT supplies exactly the real-algebraic compatibility information that
the independent monomial variables omit; lifting is not presented as a
replacement for that information. Quantifier elimination and arbitrary
first-order RCF formulas are outside this interface. PVS first skolemizes and
propositionally decomposes the goal, leaving the existential ground QF_NRA
fragment supported by Yices MCSAT.

Diagnostics follow the same convention:

```lisp
(y2cad-trace)       % scheduling, LRA status, deferred/exact checkpoints
(y2cad-trace$)      % lifted assertions and every monomial bridge
(y2cad-status)      % includes the exact MCSAT invocation count
(y2cad-model)
(y2cad-counterexample)
(y2cad-untrace)
```

[`examples/y2cad.pvs`](examples/y2cad.pvs) includes zero-MCSAT linear and
relaxation-conflict proofs, one-MCSAT real-root and coupled-product proofs, and
an intentionally false positive-root formula with a projected algebraic model.

The satellites are selected from the accumulated whiteboard problem:

| Fragment | Satellite configuration |
| --- | --- |
| Integer difference logic | `QF_IDL`, IFW/Floyd-Warshall |
| Real difference logic | `QF_RDL`, RFW/Floyd-Warshall |
| Linear integer or real arithmetic | `QF_LIA`/`QF_LRA`, Simplex |
| Nonlinear real arithmetic | `QF_NRA`, MCSAT |
| Bitvectors | `QF_UFBV`, CDCL(T) |
| Datatypes, UF, tuples, records, updates | Baseline PVS/Shostak whiteboard |

Alien arithmetic- or bitvector-valued terms are replaced by shared interface
variables in a satellite. The orchestrator repeatedly exchanges only entailed
equalities and disequalities with the whiteboard. For non-convex combinations,
undecided boundary equalities are returned as ordinary PVS proof branches, so
the normal DPI branch-copy mechanism explores the finite arrangements.

The DPI state contains only persistent Lisp objects. A fresh scoped Yices
context is rebuilt for each satellite query, so copied proof branches do not
share foreign state. `UNKNOWN` and translation failures remain unknown and are
never treated as proofs. In particular, unrestricted nonlinear integer
arithmetic is undecidable; the `QF_NIA` satellite can decide individual cases
but cannot provide a general completeness guarantee.

For the standalone `y2/` convenience layer, load `y2bindings.lisp`, then
`y2structures.lisp`, then `y2macros.lisp`.  A manager owns named solver stacks:

```lisp
(y2/with-manager (mgr :default-stack :base :logic "QF_LIA" :mode "push-pop")
  (y2/with-vars ((x int) (y int))
    (y2/assert! (y2/< x y))
    (y2/with-stack (:side :logic "QF_LIA" :mode "push-pop")
      (y2/assert! (y2/>= x y))
      (y2/check!))
    (y2/with-stack (:base)
      (y2/with-push ()
        (y2/assert! (y2/= x y))
        (y2/check!)))))
```

More involved examples live in `examples/multi-stack-examples.lisp`.  After the
standalone `y2/` layer is loaded, load that file and call:

```lisp
(y2/example-multi-stack-portfolio)
(y2/example-bv-mcsat-vs-cdclt)
(y2/example-nra-interpolant)
```

`y2/example-multi-stack-portfolio` uses one manager as a solver portfolio:

 - `:nonlinear-guard` is a `QF_NRA` MCSAT stack for geometric safety checks.
 - `:packet-mcsat` is a `QF_BV` MCSAT stack for an 8-bit packet digest.
 - `:linear-budget` is a `QF_LRA` DPLL(T)/CDCL(T) stack for capacity planning.
 - `:feature-flags` is a `QF_BV` DPLL(T)/CDCL(T) stack for bit-mask updates.

Each stack has its own Yices context, assertions, push/pop scopes, model, and
configuration.  The manager just gives them shared lifetime and convenient names.
This makes it easy to keep several views of the same problem alive at once:
linear relaxations, nonlinear exact checks, bitvector encodings, and alternate
solver configurations can all be compared without rebuilding every term and
assertion.

MCSAT examples require a Yices2 library built with MCSAT support.  If the loaded
library reports no MCSAT support, creating an MCSAT stack raises a Yices2 error.

### Interpolating Between Stacks

Interpolating between two stacks means asking Yices to check the conjunction of
stack A and stack B, and, when the conjunction is unsatisfiable, to synthesize a
formula `I` in the vocabulary shared by the two stacks:

 - stack A implies `I`
 - `I` together with stack B is unsatisfiable
 - `I` mentions only symbols that both stacks know about

For example, stack A may know private nonlinear plant details:

```lisp
(y2/with-stack (:plant)
  (y2/assert! (y2/= radius2
                    (y2/+ (y2/* x x) (y2/* y y))))
  (y2/assert! (y2/and (y2/>= x (y2/rat 4))
                      (y2/>= y (y2/rat 4)))))
```

Stack B may know only the controller side:

```lisp
(y2/with-stack (:controller)
  (y2/assert! (y2/<= radius2 (y2/rat 25))))
```

Together they are inconsistent: stack A forces `radius2 >= 32`, while stack B
requires `radius2 <= 25`.  An interpolant is a middle formula such as
`radius2 > 25` or an equivalent Yices term.  It hides `x` and `y`, because those
coordinates are private to stack A, and communicates only the shared consequence
that the controller needs to know.

That is practically useful when one solver stack is a detailed subsystem model
and another is an environment, controller, or caller contract.  The interpolant is
a compact explanation of the conflict at the boundary between the two stacks.  It
can become a learned lemma, an interface invariant, a regression diagnostic, or a
smaller obligation to send back into PVS.

The binding entry point is:

```lisp
(y2/check-interpolation! :plant :controller :manager mgr)
```

It returns the status, the interpolant term when one is produced, and a model when
the two stacks are satisfiable and `:build-model t` is requested.

## Documentation

This integration is outlined in the (forthcoming/draft) technical report "Black-Box Decision Procedures in PVS" (located under `doc/`).
