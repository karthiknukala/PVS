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
 - `api.spec`: Yices2 C API typedefs to be used by the `y2bindings.lisp` macro loaders

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
