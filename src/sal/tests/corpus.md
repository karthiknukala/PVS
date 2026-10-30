# SAL example corpus regression

`tools/run-corpus-tests.sh` discovers the current example tree on every fresh run. It
does not maintain a hand-picked list of examples that happen to translate.
Every native-accepted module declaration is checked, including parameterized
modules. A file with no modules gets a context-only check. Each target has an
isolated PVS context under `src/sal/.work/corpus/`.

```sh
SAL_HOME=/path/to/kn-sal \
PVS_BIN=/path/to/pvs/pvs \
SAL_XMLS_SOURCE=/path/to/xmls/xmls.lisp \
src/sal/tools/run-corpus-tests.sh
```

Use `SAL_CORPUS_ROOT` to choose another example tree. `--select substring` makes
an explicitly partial diagnostic run; the generated `cases.json` records that
selection. All output directories must stay below this extension.

The run has four stages:

1. Native SAL parses and well-formedness checks every `.sal`, `.lsal`, and `.xml`
   source candidate. Other files such as translated VMT/HYS models, papers and
   traces are listed separately in `native/manifest.json`.
2. `cases.json` and `cases.lisp` enumerate every module in the accepted contexts,
   plus context-only libraries. The two documented TTA template instances are
   generated locally without executing the original `run.sh` scripts.
3. PVS elaborates and typechecks serial batches of 12 cases in fresh processes.
   An ordinary error is recorded and subsequent cases continue. A process
   crash or timeout is recorded against the interrupted target; unstarted
   targets are requeued in a fresh process. Progress and automatic theorem
   registration are disabled for this frontend coverage pass. The generated
   ordinary PVS TCCs remain in each output context.
4. `summary.json` distinguishes native rejection, frontend error, missing case,
   typechecked target and fully typechecked source. The command fails if a case
   fails or is missing, or if there is a new/unrecognized native rejection.
   It also checks the complete native inventory against the current source
   tree and rejects missing inventory targets, changed sources, and duplicate
   or unexpected result rows. Native rejections must match the inventory;
   documented template targets cannot be omitted, and their original source,
   substitution recipe, and generated instance hashes must remain current.
   Accepted source files and generated template instances have separate
   success counts, so a successful instance never relabels its raw template as
   a parsed source file.

Each run writes canonical `results.tsv` and retains every batch log, raw result
file, and process status under `batches/`. Resume an interrupted run without
repeating completed targets:

```sh
SAL_HOME=/path/to/kn-sal \
src/sal/tools/run-corpus-tests.sh --resume /absolute/path/to/src/sal/.work/corpus/run.XXXXXX
```

Set `SAL_CORPUS_RETRY_ERRORS=1` when resuming after frontend fixes to rerun
recorded errors while retaining successful targets. `SAL_CORPUS_BATCH_SIZE`
changes the batch size (`1` gives a fresh PVS process for every case), and
`SAL_CORPUS_BATCH_TIMEOUT` sets each batch's wall-clock limit in seconds
(default `600`). A timeout terminates the launcher and its child Lisp process
before the next batch starts. A process failure is a coverage failure, never a
successful translation. A resumed report can contain results from different
frontend revisions; it is useful for diagnosis but does not revalidate prior
successes after code changes. Use a fresh run for final validation after code
changes. Duplicate or mismatched prior rows are rejected before a resume can
consolidate them away.

`python3 src/sal/tests/corpus-driver.py` checks crash attribution, continuation,
resume/retry behavior, and report integrity using a fake executable; it does
not launch PVS or SAL. If a standalone `sbcl` is available, it also runs the
actual corpus result writer with frontend stubs and verifies that a completed
TSV row survives SIGTERM during the next case. Each row closes its own append
stream before the success marker is printed, avoiding deletion by Lisp abort
cleanup of a long-lived superseding stream.

The optional `run-corpus-export.py CASES.json OUTPUT` runs only native
normalization/XML serialization. Its `exported` result is not PVS typechecking
and is not counted as successful frontend coverage.

At the initial inventory, the tree contains 181 `.sal`, 31 `.lsal`, and four XML
files: 216 source-format entries. Native SAL accepts 210, containing 355 modules
and 15 library-only contexts. Two additional representative TTA template models
bring the frontend set to **372 targets over 212 source/template families**.
The original six native rejections remain explicit in the manifest:

- Three bakery XML files are empty artifacts.
- `BSubSpor/BSubSpor78.sal` uses a legacy `INVARIANT`/`INITFORMULA` dialect that
  the installed SAL 3.3 parser rejects. Its different `BSubSpor78ABS.sal` example
  is tested independently; it is not used as a substitute for the rejected file.
- The two TTA `.sal` files contain `@par_*` template markers. Their sibling
  scripts specify substitutions. The corpus checks one documented instance of
  each, and records the complete documented parameter matrices, source hashes,
  recipe hashes and generated paths in the template provenance artifacts.

`corpus-native-baseline.json` records exact hashes, failure kinds, diagnostic
fragments, and reasons for these native
rejections. It does not turn a rejection into a successful translation. If a
new SAL version accepts a formerly rejected file, discovery includes its real
declarations automatically. A different failure or changed rejected source needs
review instead of disappearing from the coverage denominator.

Typechecking emits obligations; this corpus pass does not prove them. The
separate bridge regression suite exercises proofs, source-level obligation
display, stale-source refusal and fresh-process proof replay.

The coverage unit is a module declaration or a library-only context, not every
possible concrete instantiation or every theorem in the source tree. Context
and module parameters remain symbolic in this pass. The two template matrices
are documented, but only their two selected representative instances are run.
Source properties associated with a selected module without module formals are emitted
with its view; a parameterized module's concrete-instance assertions require an
explicit matching selector. The corpus does not invoke the model checkers,
prove all source properties, or claim support for the rejected legacy dialect.

The focused `run-parameter-tests.sh` suite complements this enumeration with
concrete type/value/module actuals, different instances of the same library,
transitive and diamond imports, selector-only dependencies, dependency TCC
origins, source mutation guards, and generic progress/causality companions.
Ordinary PVS proofs check distinct-instance transition behavior. These checks
exercise semantic preservation at specific boundaries; the corpus typecheck
count alone is not a general translation-correctness proof.

Validation on 2026-10-23 completed a fresh run of **372/372 targets**, covering
all 210 native-accepted source files and both documented template instances,
with no missing targets or frontend failures. Frontend source hashes remained
unchanged throughout the run. The bridge suite and 13 parameter regression
groups also passed, including fresh-process replay of their saved semantic
proofs. The largest model typechecked in 158 seconds. Local logs, source hashes,
and the full corpus report are indexed by `../.work/validation.json`.
