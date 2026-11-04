# TCCs and validation

## Contents

1. Invocation
2. Library paths
3. Reading typecheck results
4. TCC discipline
5. Process hazards
6. Validation checklist

## Invocation

The common local binary is:

```sh
~/git/PVS/pvs -raw -E '(tc "TheoryName" t)'
~/git/PVS/pvs -raw -E '(show-tccs "TheoryName")'
```

Run from the directory containing the theory. Use an absolute binary or set
`PVS_BIN` when invoking the bundled `scripts/pvs-theory`.

Keep typechecking and TCC inspection separate when diagnosing a failure. This
makes it clear whether parsing/typechecking failed or only the wrapper around a
later Lisp expression reported an error.

## Library paths

`PVS_LIBRARY_PATH` entries are directories whose child directory basenames
become PVS library names. Set the path from the theory's working directory:

```sh
PVS_LIBRARY_PATH='../..:..' \
  ~/git/PVS/pvs -raw -E '(tc "Product_Refinement" t)'
```

If PVS reports `protocols is an unknown library`, a dependency path is absent
or the command is being run from the wrong directory. Do not “fix” theory
qualifiers before checking the working directory and library path.

Inspect nearby README commands and imports to derive the correct path. Avoid
global path changes that accidentally select another directory with the same
basename.

## Reading typecheck results

Look for the theory-specific result:

```text
TheoryName typechecked in ...: 21 TCCs, 0 proved, 4 subsumed,
17 unproved
```

Classifications:

- `unproved`: visible proof work remains.
- `trivial`: PVS classified the obligation as immediate but no project proof
  should be claimed.
- `subsumed`: an equivalent/stronger TCC accounts for it.
- `proved`: a proof is recorded.

Imported theories may print their own counts. Attribute counts to the right
theory and report named theorems separately.

PVS's shell/Lisp wrapper can return exit status 0 even after a semantic error.
Conversely, a final raw-evaluation message may refer to the result value of a
compound expression after successful theory output. Judge success from the
theory-specific parse/typecheck lines and any following diagnostic, not the OS
exit status or the last line alone.

Permission warnings for `~/.pvslog` in a sandbox do not invalidate an explicit
successful typecheck line. Do not suppress more meaningful errors as “just a
log warning.”

## TCC discipline

Expected TCC sources include:

- predicate-subtype membership;
- array bounds;
- bounded integer overflow and underflow;
- dependent record/function compatibility;
- recursive termination measures;
- existence of values for dependent/uninterpreted functions; and
- abstract axioms turned into concrete mapped-axiom obligations.

Use TCCs as a specification review surface. An overflow TCC may reveal a
missing saturation/wrap/rejection branch. An existence TCC may reveal that a
configuration subtype is empty. A mapped-axiom TCC may reveal that an adapter
cannot preserve the abstract safety or round-trip law.

Do not automatically:

- widen a bounded type;
- replace a dependent type with an unconstrained carrier;
- add an axiom asserting the desired result;
- delete an interpretation;
- weaken safety/admissibility to `TRUE`; or
- prove obligations when the task is still transcription/audit.

If the user wants TCCs retained and unproved, never invoke proof commands.
`show-tccs` is read-only inspection.

## Process hazards

Run PVS serially inside a library. Multiple PVS processes can write the same
binary `.pvscontext` concurrently, leading to transient EOF, bad-dependency,
or corrupt-context symptoms. After an accidental race:

1. stop concurrent processes;
2. rerun the same typechecks serially;
3. avoid deleting user context unless necessary and authorized; and
4. report the race separately from source errors.

The `.pvscontext` file is generated state, not specification source. Do not
commit or manually patch it.

PVS may cache imports. Use `(tc "Theory" t)` for a forced typecheck in
validation work, after closing affected proofs. The agent extension permits
qualified native proof/evaluator threads within one fixed context; it does not
permit independent processes to share writable library state. Evaluation TCCs
are validity conditions for a computation, not proof completion.

## Validation checklist

For a leaf-to-system change:

1. Parse/typecheck edited leaf theories.
2. Typecheck all importers affected by changed declarations.
3. Typecheck the product umbrella.
4. Typecheck every interpretation/refinement.
5. Typecheck deployment/composition examples.
6. Run `show-tccs` serially for each changed public theory.
7. Confirm no proof scripts or proofs were introduced unintentionally.
8. Scan for stale theory/file names and broken library qualifiers.
9. Run the repository's diff/whitespace check.
10. Record exact counts and gaps in the relevant status document.

For large families, script the serial loop but keep each theory's working
directory and `PVS_LIBRARY_PATH` explicit.
