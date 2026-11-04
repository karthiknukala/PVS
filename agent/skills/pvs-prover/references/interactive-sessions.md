# Persistent PVS sessions

Use this workflow when the folder-local PVS agent MCP extension is available.
The native PVS engine owns proof states, alternatives, navigation, and saving.
Use batch fallback when the extension is absent; do not repeatedly restart PVS
for individual exploratory steps.

## Start and reason

1. `pvs_start(context, file)` prepares a fixed context and starts a persistent
   patched worker. Use an explicit `file.pvs#Theory#formula` reference with
   `pvs_proof_open`.
2. Read the returned sequent. Identify the obstruction before choosing a
   short `pvs_command`; use `pvs_help` for authoritative command syntax.
3. `pvs_inspect(session_id, kind="full")` retrieves native states and identifier metadata.
   Additional views include `locals`, `dependencies`, `rewrites`, `expanded`,
   and `tcc`. `expanded` disambiguates names; it does not unfold definitions.
4. Use ordinary `(undo)`, `(postpone)`, and immediate `(undo undo)` commands.
   Undo follows the current goal's ancestors, not chronological sibling edits.
5. A returned `running` flag means the command continues. Poll `pvs_inspect`;
   `pvs_interrupt` only requests interruption. Wait for an authoritative state
   before continuing. Do not resend a command after an uncertain connection loss.

One agent owns each mutable proof cursor. Other agents may inspect its returned
state or open independent attempts. Native concurrent proof/evaluator use
requires the extension's tested Shostak proof profile and prepared-expression
evaluator profile. Separate processes must
have isolated writable contexts, including imported libraries.

## Strategies and diagnostic evaluation

Load saved strategy source with `pvs_load_strategy` while operations are idle.
Prefer a new strategy name for an experiment. Expanded `defstep` execution
(the `$` form) is useful for diagnosis. Undo does not reverse a redefinition.
A failed load may leave some definitions installed; correct and reload it.
Final replay must load the exact successful source, and loading errors invalidate
verification. Keep strategy code separate from PVS declaration changes.

Open `pvs_evaluator_open("/path/file.pvs#Theory")` and pass its returned
`session_id` to `pvs_evaluate(session_id, "inc(41)")`. Check
`native.pvsResult`, `native.errOut`, and `native.tccMsg`, not the input text.
New expressions require idle preparation; already prepared exact expressions
can execute alongside proof commands. If setup is busy, wait for idle and retry.
Do not add a trailing REPL semicolon. Generated TCCs, errors, and attachment
behavior are part of the result. Managed evaluation stops on unresolved TCCs.
Skolem names require explicit concrete substitutions before ground evaluation;
a proposed counterexample must satisfy all relevant hypotheses. Values and
random tests never establish a theorem.

## Save and verify

Finish or close all attempts of this declaration. Use `pvs_proofs(formula)`
to find the record whose `id` is the successful proof's session ID and whose
status is `proved`. Use `pvs_save(formula, proof_id)` to select that alternative.
If saving reports an external proof/context-file change, restart and prepare
the context to load that writer’s artifacts; do not overwrite them from stale
in-memory proof records.
Then use `pvs_verify` with the required declaration/theory/importchain scope.
Report the returned replay result and scope, not just in-memory Q.E.D.
Declaration verification also replays the dependencies found by PVS’s native
proof-chain API and requires proof-chain completeness.
Automatic isolated replay currently rejects external/library-qualified imports
that it cannot mirror safely. In that case use an explicitly isolated copy of
the full dependency closure and the batch replay workflow.

Source edits require closing affected sessions and preparing/reopening the
context. Live declaration insertion, replacement, and retypechecking changed
source underneath a proof are outside this interface.


For a small finishing strategy, save this file:

```lisp
(in-package :pvs)
(defstep finish-arithmetic () (grind)
  "Finish arithmetic" "Finishing arithmetic")
```

Call `pvs_load_strategy(path)`, then
`pvs_command(session_id, "(finish-arithmetic)")`. Inspect `proof_result` for
whole-proof completion; the node `status` may only describe one branch.
