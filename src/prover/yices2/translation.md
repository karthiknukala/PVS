# Yices2 API Translation Notes

This note describes how the Yices2 CFFI prover in `api-prover.lisp` now
encodes predicate subtypes and dependent types, and how it recognizes the
solver-facing `yices2BV` bitvector vocabulary.

## Predicate Subtypes and Dependent Types

### Summary

Yices2 does not provide a native subtype constructor in the C API, so the
translation uses:

- a carrier Yices type
- extra Boolean invariant formulas over terms of that carrier type

The implementation reuses the existing PVS `type-predicates` machinery to
build those invariants instead of inventing a second subtype encoding inside
the Yices layer.

### Carrier Types

`yices2-api-type` still maps PVS types to plain Yices carrier sorts:

- `{x: T | p(x)}` uses the carrier for `T`
- dependent function domains use the carrier for the domain supertype
- tuple and record components use the carrier for each component type

This keeps the Yices sort translation simple and pushes refinement semantics
into formulas.

### Invariant Formulas

`yices2-api-type-predicate-formulas` applies every predicate returned by
`(type-predicates (type expr) t)` to the translated expression.

That gives the right invariant shape for:

- predicate subtypes
- dependent function ranges
- dependent tuple components
- dependent record fields

Examples:

- `pos = {x:int | x > 0}` becomes carrier `int` plus `pos?(x)`
- `f: [x:int -> {y:int | y > x}]` becomes carrier `int -> int` plus
  `FORALL x:int: f(x) > x`
- `[# x:int, y:{n:int | n > x} #]` becomes a tuple carrier plus a predicate
  relating field selections

### Global Symbols

When `yices2-api-global-term` creates a Yices symbol, it also registers the
symbol's type invariants as extra assumptions.

This is cached so that:

- each global symbol is translated once
- each invariant formula is generated once
- recursive type-predicate expansion does not loop

The relevant helpers are:

- `yices2-api-global-invariant-formulas`
- `yices2-api-register-global-invariants`
- `yices2-api-register-assumption`

### Quantifiers and Lambdas

`yices2-api-term` now handles binding expressions through
`yices2-api-binding-term`.

#### Bound variables

Each binder introduces fresh Yices variables with `yices_new_variable` at the
carrier type of the PVS binding.

#### Quantifier guards

For `forall` and `exists`, the translator computes the bound variable's
type-predicate formulas and turns them into guards:

- `FORALL x: S: P(x)` becomes `forall x: carrier(S). guard(x) => P(x)`
- `EXISTS x: S: P(x)` becomes `exists x: carrier(S). guard(x) and P(x)`

This works for ordinary predicate subtypes and for richer function/tuple/record
refinements because the guard comes from `type-predicates`, not just from a
simple subtype shell.

#### Lambdas

`lambda` terms are translated with carrier-typed binders using `yices_lambda`.
The lambda body is not wrapped in a guard. Instead, refinements on function
values are captured by the type-predicate formulas attached to the surrounding
typed term or symbol.

That keeps the Yices lambda total on the carrier sort while still allowing
dependent range obligations to be stated as formulas.

### Assumptions and Logic Selection

`yices2-api-build-assumptions` now collects three kinds of assumptions:

- translated goal formulas
- existing ground subtype constraints from `type-constraints`
- invariant formulas introduced while translating global symbols

Assumptions are deduplicated by translated Yices term.

Because translated assumptions can now contain quantifiers, the prover upgrades
the requested logic automatically when needed:

- `QF_*` becomes the corresponding quantified logic name
- non-`QF_*` logic names are left unchanged

This happens in `yices2-api-run` before the context configuration is created.

## Bitvectors via `yices2BV`

If translated assumptions contain bitvector terms and the requested logic does
not already mention bitvectors, the prover switches to `ALL` so Yices2 gets a
logic that accepts the generated terms.

The file `yices2BV.pvs` defines a solver-facing PVS theory whose declarations
mirror the bitvector sorts and operators supported by Yices2.

The theory is intentionally uninterpreted: users can map `yices2BV` into their
own bitvector development with ordinary PVS theory interpretation, and the
Yices2 translators recognize either:

- direct uses of `yices2BV`
- declarations generated from importing `yices2BV`
- declarations reached through explicit theory mappings back to `yices2BV`

Both the text translator in `translate-to-yices2.lisp` and the CFFI/API path in
`api-prover.lisp` understand this vocabulary. The supported solver-facing
constructs include:

- bitvector sorts via `bvec[N]`
- constants such as `bvconst`, `bvzero`, `bvone`, `bvminusone`, `bvarray`
- arithmetic, bitwise, shift/rotate, extract/concat/repeat/extend operators
- Boolean-valued comparisons plus `bitextract`
- one-bit bitvector reductions `redand`, `redor`, and `redcomp`

## What This Adds

Compared with the earlier Yices2 API path, the translation now supports:

- direct translation of `forall`, `exists`, and `lambda`
- binder-local subtype and dependent-type guards
- global function/tuple/record invariants derived from `type-predicates`
- automatic logic upgrade from `QF_*` to quantified variants when required
- recognition and encoding of the `yices2BV` bitvector theory

## Remaining Limits

This does not change the rest of the explicit PVS fragment supported by the
Yices2 API prover. In particular:

- there is still no native subtype sort in Yices; refinements are formulas
- unsupported surface forms such as `cases` and strings remain unsupported in
  `api-prover.lisp`
- richer datatype/scalar semantics are still mostly erased to carrier types
- model reconstruction is still limited to the previously supported fragments

So the current design should be read as:

"Translate refined and dependent typing into carrier sorts plus invariant
formulas, and attach those formulas at symbol creation and binder boundaries."
