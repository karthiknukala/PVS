# Parameterized contexts and dependency examples

These examples use native SAL syntax. The frontend asks SAL to resolve context
instances and flatten modules, then emits ordinary PVS parameterized theories,
records, functions, and transition predicates. Library contexts are retained as
separate shallow theories rather than copied into every machine.

| Source | What it exercises |
| --- | --- |
| `parameter_machine.sal` | Type and value context parameters plus two module parameters. |
| `parameter_leaf.sal` | A parameterized library with a bounded counter operation. |
| `parameter_left.sal`, `parameter_right.sal` | Transitive imports of the same parameterized library. |
| `parameter_diamond.sal` | A concrete machine using both branches of a dependency diamond. |
| `parameter_instances.sal` | Two interpretations of one library with different bounds. |
| `parameter_selector.sal` | A dependency used only by concrete selector arguments, which itself imports the generic root. |
| `parameter_bad_leaf.sal`, `parameter_bad_parent.sal` | An intentionally partial imported function whose range obligation must remain visible as a source-level PVS TCC. |
| `parameter_alias_library.sal`, `parameter_alias_checks.sal` | Unused context aliases still check their actual parameter domains, including an intentionally invalid bound. |

After loading `src/sal/load.lisp` in PVS, resolve source paths before the
frontend switches to each generated PVS context:

```lisp
(defun parameter-example (name)
  (merge-pathnames name
    (merge-pathnames "examples/parameters/" *sal-bridge-directory*)))

;; A generic component: T, Limit, seed, and initial_count become PVS formals.
(sal-open (parameter-example "parameter_machine.sal") "cell" :register nil)

;; A closed native SAL instance using type, value, and module actuals.
(sal-open (parameter-example "parameter_machine.sal") "cell"
          :context-actuals '("BOOLEAN" "2")
          :module-actuals '("FALSE" "0")
          :register nil)

;; The equivalent explicit selector interface.
(sal-open (parameter-example "parameter_machine.sal") "cell"
          :selector "parameter_machine{BOOLEAN, 2}!cell[FALSE, 0]"
          :register nil)

;; A library does not need an artificial module.
(sal-open-context (parameter-example "parameter_leaf.sal"))

;; Source-level TCCs include declarations from imported files.
(sal-show-obligations
 (sal-open (parameter-example "parameter_bad_parent.sal") "system" :register nil))
```

Actual arguments above are SAL expression/type strings. The frontend preserves
symbolic parameters unless concrete arguments are supplied. Generic theories
can be developed in PVS; the external model-checker proof-target interface
requires a closed concrete instance. Typechecking generates obligations and
does not establish the deliberately partial example's correctness.

Run the focused regression suite from the repository root:

```sh
SAL_HOME="$HOME/git/kn-sal" src/sal/tools/run-parameter-tests.sh
```

The suite checks parameter preservation and concrete specialization, library
imports, diamond deduplication and dependency order, different actuals for the
same imported context, imported TCC source spans, and rejection after a
transitive source changes. It also proves that the same input wraps at bound 2
but increments at bound 4 in the translated transition, checks selector-only
dependency ordering and snapshots, and typechecks generic progress/causality
companions. The mutation test only changes private copies under
`src/sal/.work/parameters`; checked-in examples and the SAL source tree remain
untouched. The runner writes generated PVS files and its log under that same
extension-local directory.

For the full upstream example inventory and exhaustive per-module run, see
[`../../tests/corpus.md`](../../tests/corpus.md).
