# CMR bitvectors: proof-producing PVS strategies

This implements the composition/extraction fragment of David Cyrluk, Oliver
Möller and Harald Rueß, *An Efficient Decision Procedure for a Theory of
Fixed-Sized Bitvectors with Composition and Extraction*. The supplied PDF
identifies itself as Ulm technical report UIB-96-8. The requested filename
`cmr98_bv.pvs` is retained.

All implementation, proof artifacts, tests and integration fixes are under
`agent/`; no core PVS files were edited. Development used `codex-interface`.

## Use in a retained proof session

Start `agent/server.py mcp` or keep `agent/server.py repl` running, using the
configuration in [the agent README](../README.md). Prepare this directory with
file `cmr98_examples`, then open, for example,
`cmr98_examples.pvs#cmr98_examples#overlap` using its absolute path.

```
(cmr98-bv$)
```

The `$` form records the expansion into native proof commands. Use it for
portable saved proofs. `(cmr98-bv)` is the ordinary composite strategy.
Both accept an optional column limit, for example `(cmr98-bv$ 8192)`;
the default is 4096 variable partitions. Hitting the bound reports a diagnostic
and leaves the goal open. Wide unsplit blocks do not allocate individual bits.

For an existing context, make this theory available through the normal PVS
library/context mechanism and use `IMPORTING cmr98_bv` so that all concrete
instances are visible. Load `pvs-strategies` with `pvs_load_strategy` while
operations are idle. Importing only `cmr98_bv[8,4,4]`, for example, restricts
lemma resolution to that instance and is insufficient for arbitrary columns.
The strategy requires these semantic lemmas to be visible.

After `(skosimp*)`, `(cmr98-solved-form$)` prints the pure solver's candidate
for the antecedent equations, including existential fresh representatives.
It does not prove anything. `(cmr98-columns$)` compiles the current exposed
sequent without another skolemization. Independent sessions may run concurrently;
keep one owner per proof cursor. Inspect, undo, postpone, and hot-reload strategy
code through the same persistent process. Source changes require closing the
affected sessions and preparing the context again.

Save the explicit completed native proof record, then verify it in a fresh
context. `test_saved_proofs_replay_without_cmr_lisp` performs the stronger check:
it copies only `.pvs` and `.prf` files and replays with **no CMR Lisp or strategy
file present**. The usual PVS prelude and prover remain the trusted foundation.

## What is implemented

| Paper concept | Implementation and checked semantic basis |
|---|---|
| Section 3, fixed widths and bit indexing | Prelude `bvec`, `bvec0`, `bvec1`, `o`, `^`; positive widths and least-significant-bit index zero |
| Definition 3.2 composition/extraction laws | `concat_assoc`, `concat_low`, `concat_high`, `concat_cross`, `slice_full`, `slice_nested`, `slice_join` |
| Section 5 canonization | `cmr98:canon`: LSB-first intervals; eliminate nested extracts, distribute over composition, merge adjacent constants/contiguous slices |
| Section 6 shared slicing | `certificate-plan`: aligned boundaries propagated through shared/repeated occurrences; `split_equation`, `project_equal` |
| Equality and constant propagation | `cmr98:solve`: ranked union/find and constant classes; `column_transitive`, `constant_conflict` |
| Fresh solved-form variables | Existential `:fresh` classes; `shared_solved_form`, `extract_solved_form` with explicit padding witnesses |
| Overlapping extracts | Fixed-point propagation of translated boundaries; `overlap_period` and positive/negative periodicity examples |

The pure Common Lisp solver accepts:

```lisp
(:var name width)
(:const 0-or-1 width)                 ; uniform zero/one vectors
(:cat high-term low-term)
(:cut term inclusive-high inclusive-low)
```

`cmr98:solve` accepts a list of pairs of terms and returns `(:valid)`, `(:unsat)`
or `(:solved ((name width pieces) ...))`. Pieces have the form
`(key offset length)`. Fresh keys in a solved form are **existentially quantified**;
replacing that quantification by arbitrary universally quantified values would
be incorrect. Unconstrained padding also gets fresh representatives.
`cmr98:certificate-plan` returns source edges with equation number, projection
offset, length and normalized endpoints, separately from target columns.

The implementation uses interval common refinement instead of reproducing the
paper's A/B/C variable naming and each `csolve` pseudocode branch literally.
It propagates boundaries to a fixed point, then computes equivalence classes.
It preserves large intervals when possible; overlap can force unit columns.
No claim is made that this implementation achieves the paper's stated asymptotic
bound. The resource limit applies to the pure solver as well, through
`:max-columns`.

## How a result becomes a proof

`cmr98_pvs.lisp` reads typed PVS expressions and checks their prelude declaration
identities. It emits a script, not an oracle answer:

1. Canonize and align input terms, including target boundaries. Targets never
   become source equations.
2. For each source column, propose two normalization identities using `case`.
   Prove their checking branches independently by expanding the prelude
   definitions, applying extensionality, skolemizing, reducing applications,
   lifting conditionals, and using native arithmetic/propositional steps.
3. Instantiate `cmr98_bv[width,1,1].project_equal` with the original operands,
   offset and length. Its premise is an existing antecedent equation. The
   established identities connect this projection to the normalized column.
4. Prove the target's recomposition identities the same way. PVS's native
   congruence reasoning propagates column equalities through the composition.
   Instantiate `constant_conflict` where needed to expose inconsistent classes.

Thus the certificate path delegates equality closure to PVS's existing `assert`
engine; the pure solver's union/find is also available for diagnostic solved
forms. No custom proof rule, axiom, `trust`, external SMT solver, status mutation,
or evaluator result closes a goal. A mistaken planner produces an unproved
checking branch. The regression suite deliberately supplies a false candidate
identity and checks that this branch cannot be bypassed.

The saved examples contain lemma instantiations and native steps, with no
`CMR98-*` strategy calls. The formalization verifies the semantic laws used by
these certificates. It does **not** contain a mechanized proof of termination,
completeness, or complexity of the entire Common Lisp implementation, nor a
formal AST-level proof of every clause of Theorems 5.2 and 6.1.

## Supported proof fragment

The automatic strategy supports concrete positive widths, literal extraction
bounds, named vector variables/constants, concatenation, extraction, conjunctions
of antecedent equations, and equality conclusions or inconsistent antecedents.
Quantified variables are skolemized first. It currently attempts the first
supported equality conclusion. Boolean structure can be exposed using normal
PVS commands before invoking it.

It is not an arithmetic/shift/bitwise solver or a full Shostak combination
plugin. Symbolic widths, zero-length vectors, nonliteral bounds, arbitrary
vector-valued functions, general Boolean combinations of disequalities, and
unsupported operators may remain open. A remaining goal is not automatically
a counterexample. These are interface/automation limits, not extra assumptions
added to the theorems.

## Validation and interaction findings

Validated on 2026-10-30 with the agent's fingerprinted SBCL/PVS baseline.
The combined pytest run passed **37 tests in 97.30s**:

- **17 semantic lemmas + 27 separately recorded TCCs** freshly replayed; the
  typechecker additionally subsumes seven generated TCCs.
- **10 positive examples**: identity, nested and crossing extraction, transitive
  propagation, overlapping periodicity, constant conflict, shared composition,
  constants, and a million-bit interval projection. Both deliberate false
  conjectures stay unproved.
- **630 equation systems exhaustively checked** against independent finite-bit
  semantics, including all equal-length self-slice pairs for widths 2–8.
  Separate checks cover certificate projection provenance, target separation,
  million-bit interval preservation, and explicit resource limits.
- Repeated generation in two simultaneous proof sessions, unchanged worker PID,
  a prepared PVSio bitvector expression evaluated concurrently, strategy reload,
  undo, diagnostic solved forms, and malicious-certificate rejection.
- Fresh replay with all CMR implementation/strategy code absent, plus the full
  agent regression suite and deterministic native concurrency probes.

The retained-session workflow was useful in practice: residual branches could
be inspected and corrected, strategies reloaded, and completed alternatives
saved without reconstructing the session. The final paired development run
closed overlap in about 2.6 seconds, conflict in 1.4 seconds, and the million-bit
projection in 0.6 seconds on this machine. These are illustrative RPC timings,
not a controlled speed comparison with batch proving. No quantitative speedup
claim is justified by this experiment.

This workload also exposed failures beyond the original small agent fixtures.
The local fixes are:

| Patch | Evidence and repair |
|---|---|
| `../patches/bdd.lisp` | Concurrent native BDD calls reached a foreign-manager abort; serialize complete BDD transactions, including nested calls |
| `../patches/parser.lisp` | Parallel proof parsing/tooltip generation produced invalid source positions; serialize the complete parser transaction |
| `../patches/traversal.lisp` | SBCL identified `*mapobject-cache*` in a corrupt hash-chain diagnostic; allocate per-call AST traversal/substitution caches, including nested calls and inspection |
| `../patches/session-output.lisp` | An ordinary Lisp error entered a background debugger; publish it as a condition instead of calling `break` |

Core-patch validation required worker restarts during development. Ordinary
proof steps, retries, strategy reloads, undo and evaluation did not. The tests
qualify this workload on the supported backend; they do not establish that
arbitrary PVS backends or stateful Lisp attachments are thread safe.

## Reproduce

From the repository root (Python dependencies as in `agent/README.md`):

```sh
bin/arm-MacOSX/runtime/sbcl/bin/sbcl --noinform --no-userinit \
  --script agent/cmr98/test_solver.lisp
agent/.venv/bin/python -m pytest -q agent/tests agent/cmr98/test_integration.py
```

The SBCL path above is the tested macOS/ARM runtime; use the corresponding
bundled SBCL on another supported host. Integration tests create disposable
contexts, never competing writers in this directory.

For manual experimentation, `interact.py URL METHOD JSON_PARAMS` makes a native
RPC call to an **already-running** worker and closes only its socket. Native
proof IDs survive reconnection. `prove_examples.py URL` exercises paired native
sessions and saves successful alternatives; it intentionally leaves unsuccessful
attempts available for inspection. Its JSON report distinguishes native proof
status from a response-rendering error. It never blindly resends an uncertain
proof command.

## Mechanized metatheory and MCP exercise

`cmr98_metatheory.pvs` and `.prf` add **15 proved results and 9 distinct TCCs**
(9 further generated TCCs are subsumed). The first theory defines an AST,
positive width, well-formedness, atomic-column normal forms, valuation semantics,
and conversion to prelude `bvec`. Structural induction proves normalization
soundness. Atom separation establishes canonical completeness under all
valuations. Composition and extraction agree with prelude `o` and `^`.

`cmr98_partition[N]` proves conflict soundness, constructs a model of every
consistent equivalence partition, proves least equivalence closure preserves
models, derives satisfiability iff no zero/one conflict, and proves that fresh
representatives describe exactly all solutions. These are mathematical
obligations for a partition implementation; this is **not** a refinement proof
of the Lisp union/find or interval algorithm, or a complexity result.

Development used the public MCP tools, including concurrent proof sessions,
tree navigation, typed inspection, undo, explicit instantiation, and saving.
The saved proofs replay without CMR Lisp or custom strategies:

```sh
agent/.venv/bin/python agent/cmr98/verify_metatheory.py
agent/.venv/bin/python -m pytest -q agent/tests agent/cmr98/test_integration.py
```

`mcp_console.py` is a small persistent console over the real MCP stdio transport.
It accepts `{ "tool": "pvs_command", "arguments": {...} }`; a JSON array submits
independent calls concurrently. It is useful when these MCP tools are not
registered in the surrounding agent runtime. Keep it running between calls.
