# Modular SAL in PVS

These examples keep SAL modules as native PVS theories. The flat translation
remains available beside them. Both use PVS's own typechecker and TCC generator.

## In your running PVS Emacs

Reload `src/sal/load.lisp` in the PVS Lisp buffer if the bridge was already
loaded, and reload `src/sal/emacs/sal-pvs-mode.el` with `M-x load-file`.

1. Visit [counter.sal](counter.sal).
2. Enable the existing `sal-pvs-mode` if it is not already enabled.
3. Press `C-c C-t`; the sole module `bounded` is selected automatically.
4. Press `C-c C-v` to see its PVS theory; press it again to return to SAL.
5. Press `C-c C-q` to inspect TCCs and their commented SAL source links.

The frontend preserves module structure without invoking the flat translator.
The flat counterparts are retained in the comparison examples and regression tests.

From PVS Lisp, the same selection is:

```lisp
(defparameter v
  (sal-open "/path/to/kn-pvs/src/sal/examples/modular/counter.sal"
            "bounded" :translation :modular))
(sal-show-obligations v)
```

## Counter: native typing at the assignment

The SAL increment is:

```sal
increment: count < Limit --> count' = count + 1
```

Its [PVS counterpart](pvs/counter__bounded.pvs) contains:

```pvs
increment_enabled(s, next: State): bool = (s`count < Limit)

increment_value(s: State,
                next: {candidate: State | increment_enabled(s, candidate)}): Count =
  s`count + 1

increment(s, next: State): bool =
  increment_enabled(s, next) AND next`count = increment_value(s, next)
```

PVS generates `increment_value_TCC1` from the function's result type. The
dependent argument gives it the command guard. There is no Boolean surrogate
for checking whether the RHS has type `Count`.

The state type allows `0..Limit+1`; the theorem `within_limit` establishes that
the initialized machine stays within `0..Limit`. To use SAL on that theorem:

1. Switch to the PVS view with `C-c C-v`.
2. Run `M-x prove-tccs-importchain`, select `counter__bounded`, and use `(grind)`.
3. Return to SAL with `C-c C-v`, place point on `within_limit`, and press `C-c C-p`.
4. Enter `(sal-check "counter__bounded.within_limit")`.

[bad_counter.sal](bad_counter.sal) removes the increment guard and gives it an
always-enabled alternative. PVS still emits the source-linked
`overflow_value_TCC1`; the other alternative cannot hide the subtype error.

## Open components: inputs stay open

[open_component.sal](open_component.sal) contains a Boolean source and a latch:

```sal
INPUT request: BOOLEAN
OUTPUT acknowledged: BOOLEAN
INITIALIZATION acknowledged = FALSE
TRANSITION [ sample: TRUE --> acknowledged' = request ]
```

The [latch theory](pvs/open_component__latch.pvs) constrains the output on a
step. Its `idle` relation preserves `acknowledged` and leaves `request` free.
This matters when composing it with the source:

- [connected](pvs/open_component__connected.pvs) uses synchronous composition:
  both component step relations hold.
- [interleaved](pvs/open_component__interleaved.pvs) uses asynchronous composition:
  one component steps while the other satisfies its own idle relation.

Wiring is a typed record projection through `SAL_Module_Lift`. Component
definitions are imported and reused. Optional progress TCCs live in a separate
`*_progress` theory, using the selected module's qualified state and relations.

## N-ary composition: one parameterized family

[nary.sal](nary.sal) has a positive context parameter `N` and the family:

```sal
sync: MODULE =
  WITH OUTPUT values: ARRAY Index OF [0..2]
    (|| (i: Index): RENAME value TO values[i] IN cell);
```

The [PVS family](pvs/nary__sync.pvs) keeps `N` as a theory parameter, imports
[nary__cell](pvs/nary__cell.pvs), and defines a projection and a lifted component:

```pvs
cell_state(s: State, i: Index): nary__cell[N].State =
  (# value := s`values(i) #)

machine: SAL_Module[State].Module =
  SAL_Indexed_Module[State, Index].synchronous(
    LAMBDA (i: Index): cell_at(i))
```

`cell_at` lifts the imported component using that projection. The shared theory
quantifies over `Index`; it never enumerates the N cells. The cell's native
increment TCC is generated in its component theory with the original SAL source
location. [The asynchronous counterpart](pvs/nary__async.pvs) selects one active
index and uses each other component's idle relation.

[nary_demo.sal](nary_demo.sal) instantiates this context at `N=3`. Typecheck its
`sync` module with the same frontend, run `prove-tccs-importchain` on
`nary_demo__sync` with `(grind)`, and enter its `aligned` theorem from SAL:

```lisp
(sal-check "nary_demo__sync.aligned")
```

The regression runs this command and replays its saved PVS proof. The generic
component theories are also reused by the three-cell instance.

## Compare the two translations

The [PVS directory](pvs/) contains the readable theories, the flat `SAL_sal_*`
counterparts, and `*__comparison.pvs` theories. Each comparison defines a typed
record map `to_flat` and proves equality of `defined`, `initial`, `step`, and
`idle`. Shared library files are links to the actual theories under `src/sal/theories`.

Run with the existing `SAL_HOME`, `SAL_XMLS_SOURCE`, and optional `PVS_BIN` settings:

```sh
src/sal/tools/run-modular-tests.sh
```

The runner checks source TCCs, module/context parameters, imported instances,
quantified initialization and commands, open-component framing, both forms of
N-ary composition, and the native SAL proof strategies. Alongside the tutorial,
13 construct-level fixtures are regenerated with two sets of names. They cover
private state, GLOBAL framing, output promotion, inline and empty components,
conditional selections, observers, nested composition, indexed parameters, and
CTL. The runner proves 128 relation equalities and their typing dependencies,
then replays the relation proofs in a fresh PVS process.
Logs and proof files stay in the printed `src/sal/.work/tests/modular.*` directory.

To refresh these checked-in counterparts from that successful run:

```sh
python3 src/sal/tools/update-modular-examples.py src/sal/.work/tests/modular.RUN
```
