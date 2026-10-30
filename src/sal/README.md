# SAL and PVS transition systems

This extension imports **SAL's own normalized transition relations and dependency
contexts**, translates them into ordinary PVS definitions, generates native PVS TCCs,
and registers source-associated invariants for an experimental SAL proof rule.
It lives entirely in `src/sal`; neither SAL nor the PVS build needs modification.

The reverse path extracts an admissible finite transition system from existing
typed PVS definitions and invokes SAL through a proof strategy on the original
PVS theorem. Both directions use `SAL_Transition_System` as their semantic basis.

The implementation is a working vertical slice, **not a complete SAL translator**.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the semantic boundary and next stages.

## Run

Use a working PVS image with the PVS Lisp APIs, SAL 3.3, and XMLS. The current
checkout need not have a built image. Select an existing image with `PVS_BIN`.
XMLS can already be loaded in the image; otherwise point
`SAL_XMLS_SOURCE` at its existing `xmls.lisp` source. No dependency download or
PVS rebuild is needed.

```sh
export SAL_HOME=/path/to/sal
export PVS_BIN=/path/to/pvs/pvs
export SAL_XMLS_SOURCE=/path/to/xmls/xmls.lisp
src/sal/tools/run-bridge-tests.sh
```

The runner puts contexts, proofs, transcripts and caches under `src/sal/.work/`.
It disables user PVS startup customization and the external PVS library path.
The loader itself does not alter the caller's existing PVS settings.

In a PVS raw Lisp session:

```lisp
(load "/absolute/path/to/kn-pvs/src/sal/load.lisp")
(defparameter v
  (sal-open "/absolute/path/to/kn-pvs/src/sal/examples/bounded_counter.sal"
            "counter"))
(sal-show-obligations v)
(sal-show-source v "check_step_5_TCC1") ; use a name returned by the report
```

`sal-open` returns a `sal-transition-view`, writes a readable PVS theory, changes
the current PVS context to its generated directory, typechecks it, and registers
supported safety properties. `:typecheck nil` stops after elaboration;
`:register nil` disables registration. `:output-directory` must remain under this
extension. `:progress-checks nil` omits progress obligations. Optional
`:causality-checks t` emits the structural causality contract for supported
whole-variable deterministic definitions.

## Experimental SAL editor and proof display

The optional [Emacs frontend](emacs/README.org) adds typechecking (`C-c C-t`),
source TCCs with proof buttons (`C-c C-q`), proof entry at a SAL theorem
(`C-c C-p`), source/translation switching (`C-c C-v`), and a prover/TCC syntax
toggle (`C-c C-s`). Load
`emacs/sal-pvs-mode.el` in an existing PVS Emacs session and enable the minor mode
in SAL buffers. See the guide for setup and a counter tutorial.

For a clean demo session, set `SAL_XMLS_SOURCE` and run
`src/sal/tools/start-editor.sh`. It starts this checkout's PVS with startup
customizations and external library loading disabled, loads the bridge and editor
modes, and opens the counter example. Existing startup files are left intact.

Typechecked imports now run native `sal-wfc` **before export and translation**;
a failed check stops the pipeline with its diagnostics. PVS still generates and
owns the subtype and progress obligations. Translation-only `:typecheck nil`
does not run this additional prerequisite check.

`(sal-set-syntax-mode t)` enables SAL presentation from Lisp; `(sal-syntax t)`
does so inside a proof. The formatter reads the current typed PVS goal and keeps
formula numbers and source names. Unsupported constructs explicitly fall back
to the whole PVS formula. Proof commands remain PVS. Ordinary PVS developments
are unaffected; the standalone bridge defaults to native display.

Run `tools/run-editor-tests.sh` for real PVS proof/save/replay tests and
`emacs -Q --batch -l src/sal/tests/editor-ert.el` for editor regressions.

## Parameters and dependency contexts

A generic SAL context becomes a PVS theory with ordinary type and value
parameters. A selected module adds its own parameters. Each dependency becomes
one readable `SALCTX_*.pvs` theory; qualified references carry their actual
parameters, so two uses of the same library remain distinct instances.

```lisp
;; Keep the context and module parameters symbolic.
(defparameter generic (sal-open "/path/to/sal/examples/arbiter/arbiter.sal" "arbiter"))

;; Ask SAL itself to instantiate and normalize a concrete selection.
(defparameter concrete
  (sal-open "/path/to/sal/examples/arbiter/arbiter.sal" "arbiter"
            :context-actuals '("3")))
;; Equivalent: :selector "arbiter{3}!arbiter"
;; Module actuals use :module-actuals '("1") or native module[1] syntax.

;; Library-only contexts have no artificial state machine.
(sal-open-context "/path/to/sal/examples/pcp/set.sal")
```

SAL discovers the dependency closure. The bridge snapshots every source before
semantic export and checks it again afterward; a changed import rejects the
translation. PVS generates typing and termination TCCs in the declaring library
and instantiation TCCs at its uses. `sal-show-obligations` includes imported SAL
filenames and source positions. For ambiguous generated names,
`sal-show-source` accepts `"THEORY::declaration_TCC1"`.

Generic theories are typechecked but are not registered for concrete model
checking. `sal-transition-view-backend-admission-note` reports why automatic
registration was deferred, including unaudited DIV/MOD backend semantics.
Concrete instances use separate generated contexts. Selecting a
module template covers that machine; it does not implicitly instantiate every
quantified assertion in its source context.

After discharging the native typing TCCs in the main theory and its imports, start
the generated `sal_bounded` theorem in PVS and use:

```lisp
(sal-source)
(sal-check "SAL_sal_bounded_x5F_counter_sal_counter.bounded")
(sal-show-check)
```

`sal-source` displays the original SAL theorem. `sal-check` accepts only its
registered, unchanged singleton goal. `:backend :bmc :depth 10` requests finite
BMC induction; the default `:smc` performs exhaustive finite-state checking.
Bounded absence of a counterexample never closes a proof. The rule is explicitly
**trusted experimental integration**: proof-evidence reconstruction is future
work. It refuses stale files/configuration, incomplete typing TCCs, altered
sequents, unknown output and backend approximation warnings.

For diagnostics independently of a proof:

```lisp
(sal-run-check (sal-transition-view-source v) "bounded" :backend :smc)
(sal-run-check (sal-transition-view-source v) nil
               :backend :deadlock :module "counter")
(sal-print-check-result)
```

## Native PVS definitions to SAL

An existing library defines the state and predicates in ordinary PVS. Interpret
the small interface over those definitions and state the theorem in PVS:

```pvs
Reverse_Counter: THEORY
BEGIN
  IMPORTING Reverse_Counter_Library[3] AS lib
  native: THEORY = SAL_Transition_View{{
    S := lib.State, initial := lib.initial, step := lib.step }}
  safe: THEOREM native.invariant(lib.safe)
END Reverse_Counter
```

`examples/reverse/Reverse_Counter_Library.pvs` is a parameterized PVS library
with no dependency on SAL. The interpretation selects its concrete bound. A
direct `SAL_Transition_System[State, initial, step]` import works too, as do
definitional aliases around its invariant. Make the two semantic library files
available in the PVS context; `sal-prepare-output-directory` installs them in an
extension-local context. The regression runner copies examples there so the
original sources receive no generated files.

After typechecking the native development, in the same PVS Lisp session:

```lisp
(defparameter extraction
  (sal-extract-pvs "Reverse_Counter" "safe"))
(sal-show-pvs-extraction extraction)
```

Extraction reads the theorem's resolved AST to recover the actual state,
initial predicate, step relation and property. It specializes library parameters
and theory interpretations with PVS's native substitution. It writes readable
SAL under `src/sal/.work/reverse/`, checks that SAL accepts it, and registers the
exact native theorem. It does not typecheck or rewrite the user's development.
The generated module has one structured state variable, an initial-state set,
and a successor set defined by the original relation. Nondeterminism and empty
successor sets are preserved; no stuttering transitions are inserted.

Discharge the native PVS TCCs in the theorem and its imports, then use this rule
at the original theorem goal:

```lisp
(sal-check-pvs "Reverse_Counter.safe")
;; Or finite k-induction:
(sal-check-pvs "Reverse_Counter.safe" :backend :bmc :depth 4)
(sal-show-check)
```

A false property retains the SAL counterexample and leaves the PVS goal open.
The rule shares `sal-check`'s exact-goal, source-snapshot and native-TCC guards,
including TCCs generated by theory interpretations. Proof dependencies include
the unfolded library declarations and their originals. Re-extract before replay
in a fresh PVS process; no registry state is serialized into the proof file.
This is an experimental trusted compiler/checker rule, with proof-evidence
reconstruction still deferred.

Before the first extraction, freshness follows PVS's native typechecking and
timestamp checks, supplemented by its source digest when available. Some PVS
versions clear that digest on context save, so retypecheck after editing a
development; same-timestamp edits cannot always be detected at that stage.
After registration, exact source-content snapshots detect byte changes.

The admitted fragment is deliberately finite: Booleans, syntactically bounded
integer subtypes with their full predicates, nondependent records and tuples,
scalar enumerations, and finite functions represented as SAL arrays. Pure
nonrecursive definitions, Boolean and integer arithmetic/comparison operations,
conditionals, finite quantifiers, record access, and direct record/array updates
are supported. Unsupported expressions fail admission with their PVS origin.
Unbounded carriers, opaque constants, recursion, dependent data, unaudited
prelude operations, and arbitrary temporal theorems are not admitted. Integer
division/modulus and real arithmetic are outside this fragment. Extraction
inlines pure definitions; large dependency slices may need future helper sharing.

Run the extraction, refusal, checker, and fresh-process proof replay tests with
the same environment as the frontend suite:

```sh
src/sal/tools/run-reverse-tests.sh
```

## Examples

| Source | Demonstrates |
|---|---|
| `examples/bounded_counter.sal` | Enums, guarded updates, source-linked typing checks and invariant proof |
| `examples/arbiter.sal` | Binary synchronous module composition |
| `examples/integration/indexed_composition.sal` | Indexed synchronous and asynchronous composition as functions/quantifiers, without enumerating component instances |
| `examples/integration/record_array.sal` | Arrays of records, lambda expressions and nested updates |
| `examples/integration/overlapping_subtype.sal` | SAL WFC accepts an overflowing assignment; PVS retains its TCC even when another TRUE branch precedes it |
| `examples/integration/terminal_deadlock.sal` | Reachable terminal state; safety semantics retain that state and progress is a separate obligation |
| `examples/integration/causality_good.sal` | Acyclic combinational definitions |
| `examples/integration/causality_cycle.sal` | Cyclic definitions with relational fixed points but no structural evaluation order |
| `examples/integration/false_safety.sal` | A source counterexample leaves the PVS goal open |
| `examples/integration/PVS_Library_Adapter.pvs` and `library_counter.sal` | Native PVS definitions, a transition-system interpretation, proved encode/decode and initial/step correspondence, and reuse of a SAL-proved invariant |
| `examples/reverse/Reverse_Counter*.pvs` | Automatic extraction from a parameterized PVS library through a theory interpretation; safety, false property, and invariant alias |
| `examples/reverse/Reverse_Direct.pvs` | Direct use of the parameterized transition-system theory |
| `examples/reverse/Reverse_Terminal*.pvs` | Nondeterministic native relation, reachable terminal states, and source counterexamples |
| `examples/reverse/Reverse_Array.pvs` | Native finite arrays, updates, and quantified safety |
| `examples/reverse/Reverse_Phase.pvs` | Native scalar enum and tuple state |
| `examples/reverse/Reverse_Admission.pvs` | Rejected fragments, incomplete native typing and interpretation TCCs |
| `predicate_subtype.sal`, `nondeterministic_selection.sal`, `partial_array_subtype.sal` | Predicate subtypes, membership semantics and an overflowing element update |
| `renaming_capture.sal`, `builtin_shadow.sal` | Binder capture and user identifiers that resemble builtins |
| `examples/parameters/parameter_machine.sal` | Generic type/value context parameters, module parameters, and concrete selections |
| `examples/parameters/parameter_diamond.sal`, `parameter_instances.sal` | Transitive imports, shared dependencies, and distinct interpretations of one library |
| `examples/parameters/parameter_selector.sal` | A dependency introduced only by a selector's actual arguments |
| `examples/parameters/parameter_module_domains.sal`, `parameter_alias_checks.sal` | Unused module/context actuals retain subtype checks before normalization |
| `examples/parameters/parameter_bad_parent.sal` | An imported partial function whose TCC points to the declaring SAL file |
| `examples/parameters/parameter_ring_parent.sal` | Imported RINGSET bounds and native wraparound |
| `examples/parameters/parameter_temporal_parent.sal`, `parameter_temporal_bad.sal` | Imported temporal macros and retained argument/context subtype obligations |
| `examples/integration/frontend_semantics.sal`, `frontend_nonterminating.sal` | Arithmetic, CTL terminal states, recursive definitions, and termination TCCs |
| `examples/integration/frontend_let_blocks.sal` | Shared LET expressions split into small native PVS helper definitions |

Generated `.pvs` and `.tccs` files remain directly inspectable. The source report
shows SAL spans/expressions alongside the actual PVS formula. A complete SAL
presentation of arbitrary transformed prover sequents is not implemented.

Run the focused suite with `tools/run-parameter-tests.sh`. It covers type/value
and module parameters, distinct library instances, diamond dependencies,
selector-only imports, imported TCC locations, ring bounds, temporal macro
domains, generic progress/causality contracts, and stale-source rejection.
Semantic proofs are saved and replayed in a fresh PVS process.

## Complete example corpus

`tools/run-corpus-tests.sh` inventories every `.sal`, `.lsal`, and SAL XML file
under `$SAL_HOME/examples`, then exports and typechecks every declared module
and every library-only context. It retains per-case failures and TCC counts;
successful typechecking does not mean those TCCs have been proved. See
[tests/corpus.md](tests/corpus.md) for the inventory, template handling, and
reproducible commands. All generated sources and reports stay under `.work/`.
