# PVS agent interface: implementation plan

Implemented 2026-10-30 under `agent/` on `codex-interface`. Implementation baseline: `e185d56e328f69a929100821400875df479a3736`, SBCL 2.6.5-85913ede1. The existing raw/batch skill and core source files are unchanged. Setup and current operating limits are in [README.md](README.md).

Build a thin, persistent agent interface over PVS's existing APIs. Reuse native proof sessions, commands, JSON states, strategy loading, evaluator sessions, proof alternatives, saving, and replay. Add loadable Lisp patches for the demonstrated defects. Keep all implementation and maintained skill sources in **`agent/`**, without editing PVS core files or its build configuration.

The working loop is: open a named proof once, inspect its state, issue commands, undo/navigate, try strategies or evaluator expressions, then save the selected native proof and verify it in a fresh process.

## What PVS already provides

| Need | Existing mechanism to reuse |
|---|---|
| Persistent proofs | `prove-formula`, `proof-command`, native session IDs and thread queues |
| State and navigation | JSON proofstates; ordinary `undo`, `postpone`, immediate `(undo undo)`, and replay commands |
| Help and specification information | `proof-help`, `find-declaration`, formula `names-info`, `show-tccs`, and existing prover inspection functions |
| Strategy development | `defstep`, expanded `$` execution, `defstrat`, `defhelper`, and strategy-file loading |
| Ground evaluation | `pvsio-start`, `pvsio-eval`, native evaluator sessions |
| Proof records and persistence | `all-proofs-of-formula`, `mark-proof-as-default`, `save-all-proofs`, proof-status and replay facilities |

PVS already supports overlapping proof/evaluator threads. The investigation demonstrated overlap, but also shared mutable proof caches and incorrect proof-status/dependency attribution. Fix and test those defects before enabling concurrent execution by default. No new prover or session model is needed.

## One implementation folder

Implemented layout (additional focused regression files accompany `test_sessions.py`):

```text
agent/
  PLAN.md
  README.md                    # Setup, supported builds, patch inventory
  load.lisp                    # Explicit, ordered extension loader
  support.lisp                 # Small runtime bookkeeping in native PVS package
  compatibility.lisp           # Source fingerprints for overridden paths
  patches/
    proof-records.lisp         # Status/dependencies belong to the right proof
    proof-runtime.lisp         # Private caches and workspace-cache handling
    sessions.lisp              # Construction, queues, termination, interruption
    evaluator.lisp             # PVSio cleanup and evaluation policy
  interface.lisp               # Only the small helpers missing from native RPCs
  pyproject.toml
  server.py                    # Thin MCP client; owns persistent connections
  tests/
    test_sessions.py
    fixtures/                 # Small PVS theories
    *-probe.lisp              # Native cache/metadata/lifecycle probes
  skills/
    pvs-prover/                # Updated skill and its references/scripts
    pvs-authoring/             # Updated skill and its references/scripts
```

Do not add implementation files under `src/`, `python/`, `pvs-patches/`, or other repository directories. Compiled patch artifacts belong under `agent/.cache/` or a temporary directory. Test contexts are temporary. Ordinary user proof outputs still belong in their PVS contexts.

Populate the skill packages from the existing skills, preserving unrelated guidance. Installation copies or links these maintained sources into the normal Codex skill location; it is a deployment step, not a second source tree to maintain. Document it in `agent/README.md`.

## Loading the Lisp patches

PVS already uses files that redefine existing functions for [patch distribution](../pvs-patches/README.md). Use that technique, with an explicit `agent/load.lisp` entry point rather than the date-filtered global patch loader.

1. Start a dedicated PVS process, finish ordinary PVS initialization, then load the extension before opening proof/evaluator sessions or accepting agent commands. Load support, proof-record helpers, proof-runtime patches, session patches, evaluator patches, then interface helpers. Start the existing WebSocket service on loopback.
2. Check the supported PVS/Lisp build, required symbols/methods, and the baseline of overridden definitions. Record upstream source locations and relevant source fingerprints in the patch inventory. Reject an unknown combination with a clear diagnostic rather than silently applying stale replacements. A Git SHA alone does not account for local edits.
3. Redefine functions in their owning package; replace CLOS methods using their original qualifiers, specializers, and compatible lambda lists. Prefer a small wrapper/dynamic binding when sufficient. Where an embedded write must change, include the replacement definition in the patch file with its upstream attribution and a short explanation of the delta.
4. **Macro and inline changes need their callers rebuilt.** Redefining `init-if-rec` alone will not change previously compiled callers. Prefer binding fresh tables around existing code; where that is insufficient, redefine/recompile the affected callers from patch definitions in this folder. Maintain one owning patch for each replaced definition so fixes do not overwrite one another by load order.
5. Avoid changes to core `defcl` layouts and generated persistence/copy methods. Use existing native objects plus extension-owned dynamic variables or a small session-keyed table. If a layout change proves unavoidable, revisit it explicitly; do not quietly require generated core-file edits.
6. Loading the same extension version twice before sessions start must be harmless. Updating engine patches requires a fresh process; do not patch running proof stacks. A partial load failure stops startup. Starting without the extension restores stock behavior; no runtime unpatch mechanism is required.

Preserve existing RPC parameter lists and response shapes. The extension may report its own loaded version and supported concurrency/evaluation features through one small helper.

## Focused PVS fixes

### Proof status and dependencies

In `save-proof-info`, the script is stored in a session-named `prf-info`, but status is written through the declaration's default proof. The earlier Q.E.D. path also writes status and dependencies to that default. Fix both paths and related timeout/error paths.

- Associate each proof session with one **native `prf-info` record**. Ensure script, status, dependencies, timing, and decision-procedure metadata all describe that same attempt.
- Keep other alternatives and the selected default intact. Do not temporarily write another proof's status/dependencies and repair them afterward.
- Preserve ordinary serial/batch behavior and nested proof calls. Do not globally change the meaning of `proof-status(decl)`.
- Reuse native alternative selection and saving. Do not introduce a candidate-artifact subsystem or a new proof-file format. Do not expose `dont-save?` as a guarantee unless its currently incomplete behavior is fixed and tested.
- A recoverable command error or interruption leaves the proof usable where PVS supports recovery. It must not permanently finalize the proof record. Fresh replay remains the delivered-proof acceptance check.

### Proof-thread isolation

`init-if-rec` can clear and reuse the same match, automatic-rewrite, subtype, and translation tables across top-level proofs. `prove-decl` also temporarily swaps the workspace's substitution-cache slot.

- Bind fresh mutable tables per native session while preserving recursive-proof behavior. Include beta/pseudo-normalization caches and substitution tables that are cleared during startup or cleanup.
- Replace the shared workspace-slot swap with session-local cache handling. Patch the affected access paths from this folder; a shallow workspace copy is not sufficient.
- Scope the work to state reached by the supported proof/evaluation workflow. Test enabled decision-procedure backends separately; retain serial or separate-process execution for unqualified backends or attachments.

### Session and evaluator lifecycle

- Construct the final proof/PVSio session before starting its thread. Bind the current session in the worker and acknowledge readiness after initialization, eliminating the current start-then-`change-class` race.
- Protect registry updates and admit one command at a time per session. Preserve queued outputs. Do not hold registry locks during proof execution or queue waits.
- Guard implicit startup loads too: opening a proof can reload strategy files, and opening PVSio reloads attachments. Route these through the same process-wide idle/setup boundary as explicit loading, or reuse prepared definitions and report changed files. Opening another session must not redefine code while a command is executing.
- Make completion independent of a client draining the output queue. Wake waiting callers on failure and clean up timers in `unwind-protect`.
- Reject missing, dead, or wrong-kind evaluator sessions promptly. Remove exited evaluators from the active registry. Make proof-only shutdown skip evaluators.
- Reuse proof interruption and add an evaluator-appropriate recovery boundary. A cancellation request is not completed cancellation; report the actual recovered state or closed session. Do not claim rollback of arbitrary Lisp/attachment effects.
- Enable TCC reporting for agent evaluations and stop before execution on unresolved TCCs by default. This is an agent-path option; preserve legacy evaluator behavior. Keep evaluation errors recoverable where possible.

## Thin agent interface

One small MCP server keeps PVS and its connections alive across tool calls. Adapt the repository's [WebSocket examples](../python/websocket-examples/README.org); do not create a separate broker service. Use native session IDs, an in-memory session table, the latest returned states, and an ordinary transcript.

| Agent operation | Implementation |
|---|---|
| Connect/start and list sessions | Initialize the patched process and prepared context; use native status plus minimal evaluator bookkeeping |
| Open proof | `prove-formula` on a fully resolved named declaration |
| Command | `proof-command`; undo, postpone, and redo remain ordinary command strings |
| Inspect/help | Cached native JSON, `proof-help`, declaration lookup, and small session-scoped helpers where needed |
| Load strategy | Existing strategy loading at an idle boundary; return diagnostics and retain the loaded source for replay |
| Open/evaluate/close evaluator | Existing PVSio APIs with patched lifecycle and TCC handling |
| Interrupt/close proof | Existing proof interruption/quit paths with corrected cleanup |
| Save and verify | Select the explicit native proof ID, save through PVS, then force replay in a fresh process |

Use a connection per concurrently active session plus a control connection: existing WebSocket dispatch waits for a request to finish. Correlate replies by JSON-RPC ID and handle intervening messages. Serialize commands within each proof; separate agents get separate proof sessions or inspect the same returned state. No distributed ownership leases are needed.

Return the focused sequent, branch label, native session status, intermediate-state summaries, commentary, and errors. Preserve full native responses for detail. Distinguish current-node status from whole-proof completion; do not interpret `num-subgoals` as a global goal count. Label truncated output and provide access to the complete text.

A small process-generation/state counter can reject stale references without a persistent operation database. A tool wait timeout does not cancel native work. Never automatically resend a command with an uncertain outcome; query the session or restart/replay explicitly. Initial recovery can be manual and transcript-based.

## Inspection, strategies, and parallel evaluation

Start with the information PVS already exposes: sequents, hidden formulas, identifier/declaration metadata, Skolem types, TCC explanations, enabled rewrites, command help, and native traces. Add only the wrappers needed to make this usable by agents.

Capture computed inspection on the owning proof thread at an idle boundary. A query must refer to the requested state, not silently inspect a newer state. Use the prepared context; avoid file-level helpers that implicitly typecheck during a proof. Existing `term-at` does not provide all instantiated type information; enrich selected-term inspection only where needed. `show-expanded-sequent` qualifies names rather than unfolding definitions. Active tracing accompanies an explicit proof command, not a supposedly read-only inspection. General lemma search and uniform DP explanation/model APIs are deferred.

**Keep strategy development live.** Load definitions when all affected sessions are idle; prefer new strategy names while experimenting. Record the files used, explain that proof undo does not undo strategy redefinition, and reload the saved definitions for final replay. A partial load failure is reported as such; do not pretend it rolled back. Provide forced retry or clear the failed file's recorded load timestamp so the native loader does not skip it; verification must reject strategy-load errors. No replacement-worker migration is required. This facility changes automation, never the PVS specification.

After the isolation/lifecycle tests pass, use native threads for independent proofs and a PVSio session alongside them. Prepare/typecheck the context and load attachments serially first; coordinate lazy evaluator compilation too. Initially support ordinary concrete evaluation with the tested attachment/backend profile. Stateful or unqualified attachments use a separate persistent process with an isolated writable context.

PVSio values and random-test results are diagnostic evidence. Symbolic Skolem constants need explicit concrete substitutions; a proposed counterexample must satisfy the relevant hypotheses. Return generated obligations and errors alongside values. Evaluation never establishes proof completion.

## Save and verify

Reuse PVS's native alternatives and persistence APIs. Name the selected proof explicitly, save it, inspect the resulting entry, and force replay in a fresh PVS process with the same patch version and saved strategy files. Run verification against an isolated temporary copy of the saved specification/proofs and any writable imports, preserving library resolution. Alternatively, close the original process before replaying in place; leaving it idle is insufficient protection against later stale saves. Report the named declarations and actual verification scope, including required TCC/proof-chain status. An in-memory Q.E.D. is distinct from a saved, freshly replayed proof.

Use one writer for a context; preserve unrelated proofs and check for external changes before saving. Do not run multiple PVS processes against the same writable library context. Keep an ordinary transcript and `.prf`; defer transactional publication and immutable proof bundles.

## Skill updates

Maintain both updated skill packages under `agent/skills/`:

- **`pvs-prover`:** prefer persistent interaction; teach the small interface, sequent-driven reasoning, native ancestor undo/sibling navigation, live strategy loading, and evaluator caveats. Add `references/interactive-sessions.md`. Keep the existing batch driver for fallback and fresh verification, and warn that loading it changes noninteractive settings—it is not interactive initialization.
- **`pvs-authoring`:** prepare/typecheck specifications before sessions start. Keep its rule against concurrent processes writing a shared library, while allowing tested native proof/evaluator threads in one prepared context. Source changes require ending affected sessions and preparing/reopening the context.
- Preserve semantic-integrity and fresh-replay requirements. If the agent extension is unavailable, retain the existing serial/raw/batch workflow with a clear diagnostic.

## Implementation order and acceptance tests

| Step | Deliverable | Acceptance |
|---|---|---|
| 1. Reuse and reproduce | Folder-local loader, minimal persistent client, tiny fixtures | Open once, split, inspect, postpone, undo, recover from a bad command; reproduce the wrong-default status/dependency bug |
| 2. Correct proof records | `proof-records.lisp` and required dependent definitions | Two attempts finish in either order with distinct scripts/dependencies; an existing default is unchanged; explicit selection/save/fresh replay succeeds |
| 3. Repair concurrency | Runtime, session, and evaluator patches | Private-cache sentinels survive another proof's start/finish; interleaved results match serial references; two proofs plus PVSio overlap correctly; changed strategy/attachment files cannot bypass the load boundary when a second session opens; quit/dead IDs and disconnect do not hang |
| 4. Expose the small interface | MCP operations, compact state, limited inspection and live strategies | Complete the interactive workflow; query the correct context; load a strategy mid-proof and replay with its saved source; cancellation followed by continued proof/Q.E.D. works where recovery is supported |
| 5. Package and update skills | Folder-local skill sources, setup instructions, regression command | Fresh installation/load works; repeated loading does not stack wrappers; unsupported builds fail clearly; serial fallback and fresh verification work |

All five deliverables are implemented. Final validation: `agent/.venv/bin/python -m pytest agent/tests -q` — **34 passed in 66.75s** on 2026-10-30; both skill packages also validate. Steps 1–2 provide useful serial interaction with one live proof per process; merely serializing commands across several live proofs does not fix their shared caches. Step 3 enables the tested native parallel configuration; it is required before presenting that configuration as supported. Keep performance measurements secondary to correctness. Include a deliberately false goal in concurrency tests so another session's stronger hypotheses cannot accidentally close it.

## Implemented profile

- Persistent stdio MCP and JSON-lines interfaces reuse the existing WebSocket service.
- Native proof records, private caches, correlated requests, owner-thread inspection,
  recoverable interruption, and terminal status are patched at startup.
- Concurrent proofs use Shostak. Prepared exact PVSio expressions can execute while
  proofs run; first-time parsing/typechecking/compilation requires idle operations.
- Verification reuses native proof-chain replay in a fresh disposable context and
  reports the target and its replayed dependencies. Axioms and empty scopes are rejected.
- Automatic replay copying supports local imports. External/library-qualified imports
  and symlinked contexts require explicitly isolated full dependency copies.
- Source fingerprints reject changed specifications. Proof-file changes by another
  writer are rejected before saving; this is a conflict check, not a transaction
  or permission to run multiple writers.
- Both maintained skill packages are in this folder. Installation into the user's
  skills directory remains an explicit deployment step.

## Boundaries

**Live declaration changes are out of scope:** no adding/replacing definitions, changing signatures, reparsing/retypechecking changed specifications underneath a proof, or transporting proofstates across specification versions. Core Lisp fixes load at process startup; live proof-strategy development is a separate supported activity.

Also defer durable operation journals, leases/fencing, crash reconciliation, transactional publication, candidate bundles, general checkpoint cloning, worker migration for strategy edits, semantic lemma search, advanced DP models, and a new GUI. The deliverable is the existing PVS interactive workflow made convenient for agents, with targeted correctness fixes and updated skills.

## Source pointers

- [Native RPCs](../src/interface/pvs-json-methods.lisp) and [session runtime](../src/pvs-threads.lisp).
- [Proof engine and metadata writes](../src/prover/eproofcheck.lisp), [cache macro](../src/prover/checker-macros.lisp), and [substitution caches](../src/subst-mod-params.lisp).
- [PVSio](../src/PVSio/pvsio.lisp), [strategy definitions](../src/prover/strategies.lisp), and [strategy loading](../src/context.lisp).
- [Patch loading](../src/pvs.lisp), [class-generation behavior](../src/defcl.lisp), and [proof metadata accessors](../src/utils.lisp).


## CMR workload follow-up (2026-10-30)

The original 34-test baseline exposed additional shared-state failures under
proof-producing bitvector strategies. Local `bdd.lisp`, `parser.lisp`,
`traversal.lisp`, and `session-output.lisp` patches address the observed foreign
BDD manager, parser positions, AST memo-table corruption, and background debugger
problems. The same process still owns independent proof sessions; only native
parser and BDD transactions are serialized. See `cmr98/README.md` for the precise
algorithm, checked laws, validation evidence, and remaining scope limits. Live
declaration mutation remains excluded.

## CMR-driven interface revision

Implemented locally under `agent/`:

1. Add compact agent-only open/step RPCs over `prover-init`/`prover-step`; defer
   native rendering and tooltips. Preserve authoritative status on render errors.
2. Expose the native open-goal tree, selected typed AST node, bounded command
   sequences, native `postpone` navigation, and explicit PVSio preparation.
3. Add read-only candidate preview providers; CMR reuses its certificate compiler.
   Report checking obligations and lemma dependencies before execution.
4. Report changed strategy definitions and source fingerprints. Preserve local
   relative strategy paths during fresh replay; helper-only dependencies still
   require a complete local context.
5. Update only the separate MCP skill. Exercise the tools through public stdio
   MCP while proving CMR normalization/canonical completeness and partition
   metatheory. Save and freshly replay the native proofs without custom Lisp.

Validation includes same-formula session-ID isolation, branch navigation,
read-only typed inspection, stop-on-error batches, lazy full metadata, strategy
reload, preview execution, concurrent proofs plus prepared PVSio, and injected
renderer failure after Q.E.D. All concurrency patches stay enabled.


## Follow-up concurrency repair (0.2.1)

The intermittent CMR failure was reproduced under eight native proof sessions
and a prepared evaluator. Keep the scope under `agent/`:

- Bind Shostak `*canon-hash*` and the native typechecker's `*expression-types*` /
  `*empty-expression-types*` privately in the existing runtime wrapper.
- Pin their native source dependencies; do not redefine the compiled macro or
  serialize whole proofs.
- Force both races with queue barriers, check nested restoration, and retain a
  repeatable positive/negative CMR stress driver with optional startup diagnostics.
- Prefer the persistent skill for interactive use; preserve the old batch skill
  and distinguish skill installation from MCP server registration.

See [VALIDATION.md](VALIDATION.md) for reproduction evidence and final results.
Live declaration changes remain excluded.
