---
name: pvs-prover-mcp
description: Default interactive PVS proof workflow through the registered pvs MCP server, including native threaded proof sessions, sequent inspection, undo and branch navigation, live strategies, PVSio evaluation, and saved-proof replay. Use for the agent/ integration in kn-pvs; retain pvs-prover for the existing raw or batch workflow.
---

# PVS Prover MCP

Use the registered `pvs` MCP server as the default for interactive PVS proof
development. Prefer direct tools over terminal transport when they are available.
Keep one patched PVS process alive throughout the development.
PVS owns the proof states, native session threads, proof alternatives, and
persistence. Keep session IDs across tool calls; do not restart PVS for each
proof step.

This skill is separate from the existing `pvs-prover` skill. Use the latter
for its established raw/batch workflow when appropriate. Do not load its batch
driver into a live interactive worker: it changes noninteractive settings.

## Connect and prepare

Discover the available tools by their `pvs_*` names and descriptions; an MCP
provider may prefix their names. Use the installed schemas for exact arguments.
The integration is implemented by `agent/server.py` and `agent/load.lisp`.
Read [the integration README](../../README.md) for installation, supported
builds, library configuration, and patch details.

Call `pvs_sessions` if already connected. Otherwise call
`pvs_start(context="/absolute/context", file="file_base")` once. Startup
typechecks the fixed context. Identify the actual filename, theory, and
declaration separately: a file can contain multiple differently named theories.
The fully resolved reference is `/absolute/file.pvs#Theory#declaration`.

If the MCP tools are unavailable but the extension is installed, the same
client has a persistent JSON-lines transport:

```sh
/path/to/kn-pvs/agent/.venv/bin/python /path/to/kn-pvs/agent/server.py repl
```

Keep that command running in one interactive terminal session. Send JSON input
through that session's stdin and read each response, reusing its terminal ID:

```json
{"operation":"start","context":"/absolute/context","file":"example"}
{"operation":"proof_open","formula":"/absolute/context/example.pvs#Example#lemma"}
{"operation":"command","session_id":"RETURNED_ID","command":"(skosimp*)"}
{"operation":"inspect","session_id":"RETURNED_ID","kind":"full"}
```

Use the returned native ID in place of `RETURNED_ID`. EOF shuts down the
managed process; do not pipe one command and close stdin between steps.
For MCP transport, launch the same program with `mcp` instead of `repl`.
The local server is registered as `pvs` in `~/.codex/config.toml`. A running
chat may need its MCP connections refreshed before new tools appear; check
discovery rather than assuming registration refreshed its catalog. Creating or
discovering a copy of this skill on another host does not register that server.
If neither transport is available, report that and use the existing batch
workflow rather than claiming a persistent session.

## Live proof viewer

MCP startup opens a local read-only proof explorer automatically. Use the `dashboard`
URL returned by `pvs_start`/`pvs_sessions`, or `pvs_dashboard()` to retrieve it;
keep the MCP worker alive while the user watches. An already-running pre-viewer
worker needs one restart and MCP catalog refresh to load this capability.

Supply concise `label` and `actor` values on `pvs_command` when they add meaning,
for example `label="Project equal columns", actor="Normalizer"`. These are display
annotations, not PVS commands or checked mathematical claims. Separate native
sessions are separate panes. Commands appear as nested blocks: clicking opens
resulting subgoals; **Primitive steps** opens a derived command's implementation.
Commands continuing on the same goal are flat consecutive lines; only branches
and strategy subproofs add indentation. Those subtrees stay lazy until requested. Hover or keyboard focus shows the recorded
pre-command sequent, full command and native command description in the popup.
Completed branches are green throughout, with QED checkmarks at closed leaves. **Earlier attempts** separates undo
history; **Retained history** groups missing-ancestry fragments by enclosing goal numbers.
The agent/thread panel and **Follow** open the ancestry to the exact current step,
including needed primitive boundaries, and track cursor changes. Unrelated branches
remain folded. Click **Following**, scroll manually, or collapse steps to pause.
There is no graph or zoom. All viewing is
read-only and leaves native proof cursors untouched.

Selecting a thread also opens its read-only `*pvs*` panel: current proof command,
native sequent, command output, and an expandable recent transcript. The latest
command stays in a fixed header while the sequent/transcript scroll underneath.
Toggle it
with the thread's `*pvs*` button. Evaluators show expression/result text there.
While running, the sequent is the last returned state; capture is bounded and
reports truncation. Commands completed before capture was installed have no
recoverable output. Viewing never claims a proof cursor.

The HTTP viewer stays available across native socket failures and automatically
reconnects to its configured endpoint. A stable worker identity preserves history
on transient reconnect and clears it for a replacement worker, even when native
session IDs repeat. Use server CLI `--port PORT` when a managed worker must restart
at the same native address. The viewer process must stay alive; it does not follow
arbitrary new ports or restart a terminated MCP host. It never replays proof
commands or restores control-session ownership automatically. Share one HTTP
observer among browser tabs: native node draining remains single-consumer.
`agent/buffers.lisp` alone can be installed at an idle setup boundary as an
observational update; never live-reload the full core/runtime patch set.

Keep using native status and fresh replay for correctness; this bounded display
is not a proof certificate or exhaustive trace. Long sequents and older history
may be truncated explicitly. Strategy inventory refreshes at idle session-open
and strategy-load boundaries. Source declaration editing remains out of scope.
`--viewer headless` (or `PVS_AGENT_VIEWER=headless`) serves without opening a
browser; `--viewer off` disables automatic observation. Tests and isolated replay
workers should remain headless/off. The old CLI skill is still available.

## Reason and manipulate the proof

Open a declaration with `pvs_proof_open(formula)`. Preserve its `session_id`.
Read the sequent and identify the obstruction before choosing a short command.
Antecedents have negative formula numbers; succedents have positive numbers.
Use `pvs_help(command)` for installed command syntax and `pvs_lookup(identifier)`
for exact-name declaration lookup.

| Operation | Tool or native command |
|---|---|
| Individual step | `pvs_command(session_id, command)` |
| Latest compact state | `pvs_inspect(session_id)` |
| Full native responses and identifier metadata | `pvs_inspect(session_id, kind="full")` |
| Types of Skolem constants | `kind="locals"` |
| Proof dependencies, rewrites, TCC explanation | `kind="dependencies"`, `"rewrites"`, `"tcc"` |
| Qualified names in sequent | `kind="expanded"`; this does not unfold definitions |
| Split, visit another open branch | `(split)`, `(postpone)` |
| Undo, immediately undo that undo | `(undo)`, `(undo undo)` |
| Diagnose transport/output history | `kind="transcript"` with `since`/`limit` pagination |

Full native sequents include hidden formulas. Undo follows the focused goal's
ancestry; it is not chronological undo across siblings. Immediate `(undo undo)`
is not a general redo stack. Inspection does not introduce a proof step.
Use `expected_revision` on commands when acting on an earlier returned state.

Read `proof_result` for whole-proof completion. A node's `status` can indicate
only that one branch closed; `num-subgoals` is not a global remaining-goal count.
A proof is not complete because a command returned, a branch closed, or a
session was quit.

## Threads, waits, and recovery

Give each mutable proof cursor one command owner. Open separate native proof
sessions for independent attempts, including attempts of the same declaration.
The supported concurrent proof backend is Shostak. Use the loaded extension's
reported capabilities; do not assume stock PVS or another backend has the same
isolation guarantees. Parser and native BDD transactions are serialized; AST
traversal caches are private per call. Shostak canonicalization and expression
typechecking scratch tables are private per proof/evaluator runtime. The proof
sessions themselves remain concurrent. After changing startup patches, launch a
new worker once; live strategy reload does not update those runtime bindings.

Proof commands in different sessions can overlap. A short `wait` returns
`running: true` when execution continues; inspect until it settles. One command
at a time is admitted per session. New-session setup, strategy/attachment loads,
saving, and initial evaluator preparation require idle operations. Idle means
commands have settled, not that the process or every proof session must close.

Commands and evaluations have a separate `time_limit` (default 60 seconds;
0 disables it). `wait` only controls tool latency. A deadline requests native
interruption; it does not kill the process or promise instantaneous cancellation.
Choose a larger explicit limit for an intentionally long solver call.

Use `pvs_recover(session_id, wait=5)` for a stuck command. It returns `restored`,
`settled`, `pending`, `unresponsive`, `runtime_failed`, `idle`, or `uncertain`.
Only `restored` confirms that this command acknowledged interruption. Inspect the
returned sequent/open goals before continuing: native `restore` abandons the
interrupted step, while keeping the earlier proof. `settled` may mean the command
finished before interruption; read its proof result. `pvs_interrupt` is the same
bounded path with a one-second wait. Lisp-level `break`/debugger entry in a running
session automatically uses the native restore/evaluator restart. Neither path
rolls back arbitrary Lisp or attachment side effects.

Do not repeatedly poll `pending` as though it were recovery. Inspect
`pvs_inspect(kind="health")` for runtime output and the persistent recovery folder.
An unacknowledged interrupt blocks later commands on that cursor, preventing a
late interrupt from affecting new work. A fatal SBCL memory fault/LDB entry is
**not** a PVS debugger: its heap is unsafe, and `restore` cannot repair it.
The adapter reports failure and uncertain outcomes; it never force-continues LDB,
restarts, or replays automatically. A new worker and explicit reconstruction are
needed for runtime failure. Startup patches require a new worker to take effect.

Each new client keeps `events.jsonl` and an atomic `checkpoint.json` under the
returned `recovery_dir` (normally `agent/.recovery/`; override with
`PVS_AGENT_RECOVERY_DIR`). These survive client close. They contain acknowledged
states, command inputs/results and runtime output, **not** a native saved proof.
The last in-flight command is explicitly uncertain. Use the journal to reconstruct
only reviewed steps in a new worker; never blindly rerun it or claim QED from a
snapshot. After successful restoration, close the attempt, select its record and
use `pvs_save` to persist partial native work. Fresh verification is still required
for completeness. Keep the journal when diagnosing a crash; remove old folders
when no longer needed.

`pvs_close(session_id)` closes that session, not the whole managed PVS process.
Close finished attempts when their cursors are no longer needed: retaining their
connections indefinitely exhausts the native server's connection limit. Closing
a session does not erase its proof record. The old CLI skill remains available.

## Develop strategies without restarting

Write strategy definitions to a saved file, then use
`pvs_load_strategy(path)` while operations are idle:

```lisp
(in-package :pvs)
(defstep/lazy finish-arithmetic () (grind)
  "Finish arithmetic" "Finishing arithmetic")
```

Run `(finish-arithmetic)`; use the viewer disclosure to inspect its primitive
steps. The `$` spelling of marked strategies also retains the lazy boundary. Prefer new names for experiments. Undo does not undo strategy
definitions. A load failure can leave partial definitions installed: fix the
file and explicitly reload it. The client retains successfully loaded explicit
source for fresh replay. A replay load error invalidates verification.

## Mark derived strategies for lazy display

Define new derived strategies with `defstep/lazy`, using the same arguments as
native `defstep`, as in the example above. This is the default for solver
certificates, normalization pipelines, and other compound automation in agentic
proof development.

For existing `defstep` definitions, place `(lazy-strategies my-solver my-normalizer)`
after their definitions. Reapply that marker after redefining them. To group an
individual compound command, use `(lazy-step (then (skosimp*) (grind)) "Arithmetic")`.
Load these definitions through `pvs_load_strategy` at an idle boundary. The forms
are installed by `agent/lazy-strategies.lisp`; an older live worker can load that
strategy-only file without restarting PVS. The accompanying
`patches/apply-justification.lisp` persistence fix loads at startup; restart an
older worker before relying on portable saves of these compound proofs.

Both normal and `$` invocations of marked steps retain a native `apply` boundary.
The prover still executes and checks their primitive steps immediately, and
native expanded justifications remain available for replay. Laziness applies to
presentation: the viewer creates nested blocks for the primitive
implementation after **Primitive steps**, or when explicitly enabled **Follow**
needs to reveal the active step inside it. Other implementations remain folded. Resulting open goals remain visible
outside the boundary; expanding is read-only and does not rerun the command.
Nested derived steps stay folded until individually opened. The bounded observer
still captures immutable sequent snapshots during execution; this is not deferred
proof execution or on-demand native sequent serialization.

Prefer meaningful MCP `label` values for the compound mathematical argument.
Do not split a generated certificate into many top-level primitive MCP commands
merely to animate the viewer: that discards its compound boundaries. Use primitive
commands directly when intentionally investigating an individual proof step.
The unmodified `pvs-prover` CLI skill remains available.

## Evaluate while proving

`pvs_evaluator_open("/absolute/file.pvs#Theory")` returns its own session ID.
Use `pvs_evaluate(session_id, expression="inc(41)")` without a trailing
REPL semicolon. Inspect `native.pvsResult`, `native.errOut`, and `native.tccMsg`.
The agent path reports TCCs and stops before execution on unresolved obligations.

A new expression requires idle parsing, typechecking, and compilation. Once
prepared, the exact expression can execute on its evaluator thread while proof
commands run. If preparation reports busy, wait for idle and retry; no evaluation
ran. Attachment loading invalidates prepared entries. Stateful or unqualified
attachments are outside the tested concurrent profile and require isolation.

Use concrete substitutions for symbolic Skolem constants. A proposed
counterexample must satisfy the hypotheses. Evaluated values and random tests
are diagnostic evidence, never proof completion.

## Save and independently verify

1. Finish or close every attempt of the declaration being saved.
2. Inspect `pvs_proofs(formula)` and select the explicit native record ID.
   Completion order does not select a default.
3. Call `pvs_save(formula, proof_id)`. Confirm the saved record and inspect the
   resulting proof-file change.
4. Call `pvs_verify(formula, scope="declaration")`, or `"theory"` / `"importchain"`
   when that broader scope is required. Require `native.verified == true` and
   check the reported status rows and scope.

Fresh verification uses a separate temporary patched PVS process and copied
context, leaving the interactive process alive. It forces native proof-chain
replay and checks completeness. An in-memory Q.E.D. or a saved script alone
does not establish a verified result. Report precisely what was saved and
freshly verified.

Automatic copying supports local imports. External/library-qualified imports
and symlinked contexts are refused; use an explicitly isolated copy of the full
dependency closure and the existing replay workflow for those cases.
Keep one writer per writable context, including imported libraries. If saving
detects external proof/context-file changes, restart and prepare to read that
writer's state; do not overwrite from stale in-memory records.

## Preserve the specification

Do not weaken statements or add assumptions, axioms, or auxiliary declarations
to close a goal without a user-requested specification change.
Live declaration insertion, replacement, and retypechecking changed source
under an active proof are out of scope. Source changes require closing affected
sessions, preparing the context, and reopening proofs. Core Lisp patches load
at startup; changing those patches requires restarting the worker. Live
strategy development changes proof automation only.

## Proof-producing solver development

The [CMR example](../../cmr98/README.md) demonstrates this workflow over prelude
bitvectors. Use `IMPORTING cmr98_bv`, load its `pvs-strategies`, and invoke
`(cmr98-bv$)` for a checked certificate with lazy viewer boundaries. `(cmr98-solved-form$)`
after `(skosimp*)` reports a candidate only; fresh representatives are existential.
The solver's concrete-width fragment and column resource bound are documented
there. Unsupported inputs and exhausted bounds must leave goals open.

Keep search/planning untrusted: propose local identities with checking branches,
instantiate proved semantic lemmas, and let ordinary PVS steps discharge them.
Check dependencies and replay expanded saved scripts with the custom solver
code absent. Include false goals and deliberately incorrect certificates in tests.
If a native command reports an error after execution, inspect whole-proof status
before deciding what to do; a rendering failure can follow a completed proof.
Do not silently retry the command or treat the error as evidence of completion.

## Compact interaction tools

Ordinary commands now avoid native identifier metadata generation. Responses
include `proofstate_id`, the global `open_goals` count, signed formula `delta`,
`elapsed_ms`, and `outcome`. Commentary is bounded; `commentary_omitted_chars`
reports truncation. Request `kind="full"` only when needed: it performs native
rendering, including identifier metadata, and may be substantially larger.
`render_error` is separate from `command_error` and whole-proof completion.
A rendering failure after Q.E.D. does not invalidate the proof or authorize a retry.

- `pvs_batch(session_id, commands, expected_revision, expected_label)` runs at
  most 32 commands. It retains each result and stops on failure, completion,
  interruption, uncertainty, the wait budget, or a changed expected label.
  It reserves that client's proof cursor between steps. Omit `expected_label`
  only when intentional branch changes are part of the sequence. A running
  final command continues; inspect it, never resend the sequence.
- `pvs_inspect(kind="tree", since=0, limit=100)` gives open native leaves and
  focused ancestry. `pvs_navigate(goal_id, expected_revision)` uses native
  `postpone`, currently within the first 100 leaves. Goal IDs are scoped to the
  session; pair them with a revision. A target may close during native navigation.
- `pvs_expression(session_id, fnum, path, expected_revision)` reads the stored
  typed AST. The empty path selects the formula; returned child indices extend
  it. Applications expose operator/argument, tuples their components, binders
  their body. Atom children are empty. Types and resolved declaration/theory
  instances are available without reparsing. This is a shallow selected-node view.
- `pvs_preview(session_id, provider="cmr98", expected_revision=...)` returns
  the loaded provider's candidate script, case obligations, and lemma references.
  First expose the CMR equations with `(skosimp*)`. No proof is executed.
  Run the returned script with its returned `expected_revision`; PVS checks it.
  A preview is untrusted and is not a reusable certificate across strategy reloads.
- `pvs_evaluator_prepare(session_id, expression)` explicitly prepares without
  execution. Run this while idle, then evaluate that exact expression alongside
  proof commands. Inspect preparation errors and TCC text before executing.
- `pvs_obligations(theory)` inventories declarations and generated TCC statuses
  in a prepared theory. It requires idle operations and does not prove them.

Strategy loading reports changed native strategy entries, their source origins,
and fingerprints. Nested strategy definitions have their own origins. Helper-only
Lisp loads are not inferred as a dependency manifest: keep the complete source
closure inside the prepared context. Local explicit strategy reloads retain their
relative paths during isolated replay. Undo does not undo these definitions.

For quantified metatheory, try `grind :if-match nil` when automatic instantiation
chooses poor witnesses; then instantiate the visible quantifiers explicitly.
Use `decompose-equality` for antecedent function equality and
`apply-extensionality` for a function-equality goal. Check installed command help.

Nested strategy trials use PVS's `apply-parent-proofstate` relationship. Click a
node's **Primitive steps** disclosure to render those internal
steps on demand; explicit **Follow** also opens boundaries on the active path. Observer IDs are stable object identities; native label/depth
IDs remain unchanged for agent navigation. The viewer retains immutable sequent
snapshots so strategy reparenting cannot overwrite a different historical node.
