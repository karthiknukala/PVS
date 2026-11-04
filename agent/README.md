# Interactive PVS agent extension

This folder contains the complete implementation: startup-loaded Lisp patches,
a thin MCP/JSON-lines client, regression tests, and updated skill sources.
It reuses PVS's native session, proof, strategy, evaluator, and persistence APIs.
No core PVS source or build files need editing.

## Setup

From the repository root:

```sh
python3 -m venv agent/.venv
agent/.venv/bin/python -m pip install -e ./agent pytest pyyaml
agent/.venv/bin/python agent/server.py mcp
```

Configure your MCP client to run the last command with absolute paths. The
server keeps its PVS process alive across calls. It defaults to this checkout's
`pvs` and `agent/load.lisp`; `--pvs` and `--loader` select explicit paths.
`--library-path` is an explicit library configuration. Managed startup defaults
to an empty library path and uses `-q -patchlevel none` to avoid unrelated
startup overrides. It binds the PVS WebSocket listener to loopback.

### Codex registration and default routing

On this host, `pvs` is enabled in `~/.codex/config.toml` with absolute paths to
this checkout's Python environment, server, PVS executable, and startup loader.
Startup timeout is 30 seconds; tool timeout is 240 seconds to allow fresh replay.
Codex's desktop app and CLI share this registration
([official MCP configuration documentation](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)).

For another installation, use its absolute paths:

```sh
codex mcp add pvs -- /absolute/kn-pvs/agent/.venv/bin/python /absolute/kn-pvs/agent/server.py mcp --pvs /absolute/kn-pvs/pvs --loader /absolute/kn-pvs/agent/load.lisp --library-path ""
codex mcp get pvs --json
```

Set `startup_timeout_sec = 30` and `tool_timeout_sec = 240` in that server's
`[mcp_servers.pvs]` table. Verify tool discovery; a running chat may need its MCP
connections refreshed or the chat reopened before its catalog includes new tools.
Registration alone is not evidence that a particular active turn has loaded them.

The installed `pvs-prover-mcp` skill and user `~/.codex/AGENTS.md` select direct
MCP tools as the default interactive path. The old `pvs-prover` skill remains
available for explicit raw/batch work and replay. Each chat's MCP server owns its
worker: independent chats still need separate writable contexts to avoid competing
saves. For parallel attempts in one context, use native sessions in one worker.

Validate the **saved registration**, rather than a separately assembled launch:

```sh
PVS_MCP_CONFIG="$HOME/.codex/config.toml" agent/.venv/bin/python -m pytest -q -s agent/tests/test_mcp.py agent/tests/test_interaction.py::test_cmr_compact_interaction
```

The opt-in `PVS_MCP_CONFIG` setting reads `mcp_servers.pvs` command, arguments,
working directory and explicit environment. Without it, the tests use their
ordinary isolated checkout configuration. All requests traverse MCP stdio; none
of these workflow tests call the Python PVS client directly.

For a command-line session, run `agent/.venv/bin/python agent/server.py repl`.
Each input line is one JSON object, for example:

```json
{"operation":"start","context":"/absolute/context","file":"example"}
{"operation":"proof_open","formula":"/absolute/context/example.pvs#Example#lemma"}
```

Use the returned `session_id` in subsequent `command` and `inspect` requests.
EOF closes the managed process. The same Python client powers both transports.

The initial supported build is this checkout at
`e185d56e328f69a929100821400875df479a3736` with SBCL; the tested runtime is
SBCL 2.6.5-85913ede1. `compatibility.lisp` checks the relevant source
fingerprints before loading replacements. Review changed upstream definitions
before updating that manifest. Other Lisp implementations/backends are not
qualified for concurrent use.

`load.lisp` loads patches only before sessions begin. Loading the same extension
again is harmless. Updating patch code requires restarting the managed process;
ordinary live strategy loading does not. Omitting the loader gives stock PVS.

## Interactive workflow

1. `pvs_start("/absolute/context", "file")` typechecks the fixed context.
2. `pvs_proof_open("/absolute/context/file.pvs#Theory#lemma")` returns a
   `session_id`. Reuse it for `pvs_command(session_id, "(skosimp*)")` and
   subsequent native commands.
3. Inspect the focused sequent; use `pvs_inspect(session_id, "full")` for native
   metadata, or `locals`, `dependencies`, `rewrites`, `expanded`, and `tcc` views.
   `pvs_help` provides installed command syntax; `pvs_lookup` is exact-name lookup.
4. Use `(split)`, `(postpone)`, `(undo)`, and immediate `(undo undo)` as native
   commands. Undo follows the focused branch's ancestry.
5. Finish or close the attempts of a declaration, inspect `pvs_proofs(formula)`,
   and pass the desired native record ID to `pvs_save(formula, proof_id)`.
6. Run `pvs_verify(formula, scope="declaration")`, or request `theory` or
   `importchain`. Check `native.verified` and the detailed status list.

`proof_result` comes from PVS's session status. A proof-node `status` flag is
kept separately; closing one branch is not whole-proof completion. A tool wait
timeout returns `running: true` without cancelling work. Inspect again or use
`pvs_recover(session_id, wait=5)` and inspect its explicit recovery status before issuing another command.
Unknown connection outcomes are never automatically retried.

Each proof cursor has one command owner. Independent sessions can run on native
threads. The supported concurrent proof profile uses Shostak; other selected
backends are rejected. Setup, source preparation, strategy/attachment loading,
and saving use a brief admission boundary that requires idle operations.

## Strategies and evaluation

A strategy file can contain:

```lisp
(in-package :pvs)
(defstep finish-arithmetic () (grind)
  "Finish this arithmetic goal" "Finishing arithmetic")
```

Load it with `pvs_load_strategy("/absolute/finish.lisp")` while operations are
idle, then run `(finish-arithmetic)` or `(finish-arithmetic$)`. Prefer new names
for experiments. Undo does not undo strategy definitions. Load errors propagate;
a partial load can leave definitions installed and can be retried. Saved source
is retained for isolated replay.

`pvs_evaluator_open("/absolute/context/file.pvs#Theory")` returns an evaluator
session. `pvs_evaluate(id, "inc(41)")` returns native `pvsResult`, `errOut`,
`tccMsg`, and output fields. Do not append a REPL semicolon. Agent evaluation
generates TCCs and stops before execution if obligations remain.

New expressions require an idle preparation boundary for parsing, typechecking,
and lazy compilation. A session-local cache lets an already prepared exact
expression execute while proof commands run. If preparation is busy, wait until
operations are idle and retry; no evaluation ran. Attachment loading invalidates
prepared entries. Stateful/unqualified attachments require isolation and are
outside the tested concurrent profile. Evaluation is diagnostic evidence,
including when it returns an apparent counterexample.

## Saving, replay, and limits

Saving reuses native alternatives, default selection, `.prf` writing, and context
persistence. Saving refuses proof artifacts changed by another writer since preparation
or the last successful save. Verification starts a fresh patched process against a disposable
copy, forces native replay of the saved script and its proof dependencies, and
checks proof-chain completeness. Its detail rows include dependencies traversed
by native proof-chain replay. The separate completeness check can also fail on
additional assumptions/judgement obligations; these may require inspecting the
native theory/TCC status to locate. It never
accepts the current process's Q.E.D. or cached status as independent replay.

Automatic copying supports local import closures. External/library-qualified
imports, symlinks, and unaccounted external automatic strategy files are refused
with an explanation. Use an explicitly isolated copy of the full dependency
closure for those developments; do not start independent writers in one library
context. The verifier reports the actual requested scope, including failures.

Live declaration changes are excluded. Changing prepared source invalidates
commands until affected sessions close and the context is prepared again.
Core Lisp patches run at startup; live strategy development only changes proof
automation. The extension is trusted developer code, not a Lisp sandbox.

## Patch inventory

| File | Native behavior repaired |
|---|---|
| `proof-records.lisp` | Formula metadata setters and save allocation target the same native per-session record; the prior default stays intact |
| `proof-runtime.lisp` | Fresh proof/DP/normalization, Shostak canonicalization and expression-typechecking caches; dynamically private workspace substitution-cache access; nested restoration |
| `bdd.lisp` | Serialize process-global native BDD transactions |
| `parser.lisp` | Serialize parser/lexer transactions shared by proof commands and tooltip rendering |
| `traversal.lisp` | Per-call AST traversal and substitution memo tables, including nested calls |
| `session-output.lisp` | Report native conditions without blocking in a background debugger |
| `sessions.lisp` | Typed construction before worker startup, current-session binding, correlated queues, setup admission, owner-thread queries, terminal status, interruption and cleanup |
| `evaluator.lisp` | Typed/liveness checks, strict TCC policy, prepared-expression caching, evaluator cancellation and shutdown |
| `interface.lisp` | Native inspection/save/replay wrappers, explicit strategy loading, retryable implicit loads, source-staleness checks and loopback startup |

Functions, macros, and captured function objects differ: redefining a macro does
not rewrite compiled callers, and an old hook may still hold its original
function object. The patches use dynamic cache bindings, replace affected
methods, and explicitly redirect the old input hook. They do not change core
class layouts or generated persistence methods.

## Tests and skills

```sh
agent/.venv/bin/python -m pytest agent/tests -q
```

See [the validation report](VALIDATION.md) for the current regression results,
concurrency reproductions, and assurance limits. To exercise eight native proof
threads alongside a prepared PVSio evaluator in one process:

```sh
agent/.venv/bin/python agent/tests/stress_cmr.py --rounds 100 --fanout 8
```

`--diagnose` additionally installs test-only SBCL assertion/hash-error hooks at
startup. On failure, the driver writes compact/full native state and transport
history to a temporary diagnostic file; in an interactive terminal it retains the
worker for JSON-lines inspection. It does not retry failed proof commands. The
barrier regressions in `test_canon_isolation.py` and `test_typecheck_isolation.py`
force the cache interference without depending on a scheduler's timing.

Tests use the real PVS executable and temporary contexts. They exercise proof
metadata/default preservation, cache isolation and nested unwind, branching,
undo/redo, inspection, live strategies, cancellation, evaluator TCC/error
recovery, parallel execution, saving, and fresh positive/negative replay.
Transport/MCP tests also check notification routing, wait/retry semantics, bounded
shutdown, and a real MCP proof/save/replay workflow. Loader tests reject a stale
source baseline before applying patches.

The maintained skill packages are `agent/skills/pvs-prover`,
`agent/skills/pvs-authoring`, and the separate `agent/skills/pvs-prover-mcp`. Install by copying/linking them through your normal
skill installation workflow, preserving any local customizations. Tests and
implementation here do not overwrite the globally installed skills.

## Proof-producing bitvector example

[CMR composition/extraction strategies](cmr98/README.md) exercise live strategy
development, concurrent proofs and PVSio, checked certificates, and independent
replay with the implementation absent. The specification is
[`cmr98_bv.pvs`](cmr98/cmr98_bv.pvs).

## Compact agent views (October 2026)

`interaction.lisp` adds agent-only RPCs; the original PVS RPC schemas are unchanged.
The client negotiates the compact endpoints and retains the legacy fallback.
Ordinary steps print existing typed formulas without `pp-with-view` or identifier
tooltips. Whole-proof status survives a rendering error. Full native responses
are generated lazily by `pvs_inspect(kind="full")`; transport history is paginated.

The new public tools are `pvs_batch`, `pvs_expression`, `pvs_navigate`,
`pvs_preview`, `pvs_evaluator_prepare`, and `pvs_obligations`. See the
[maintained MCP skill](skills/pvs-prover-mcp/SKILL.md#compact-interaction-tools)
for contracts, limits, and recovery rules. Tree navigation calls native
`postpone`; expression inspection reads existing typed ASTs; preparation reuses
the existing PVSio cache. Strategy feedback compares native registry entries.

CMR registers an optional preview provider using the same compiler as its
strategy. Other trusted local strategy files can register a zero-argument
function in `pvs::*agent-preview-providers*`; it returns a candidate native
strategy expression on the owning proof thread. The interface reports its case
obligations and lemma references. Preview providers must be read-only. The
interface does not expose arbitrary Lisp evaluation as a tool.

All normal development retains the worker. Updating `interaction.lisp` itself
requires startup, just like the core patches. Live declaration changes remain
out of scope. The supported concurrency profile is unchanged: native proof and
prepared evaluator threads, private caches, serialized parser and BDD transactions.

## Live proof trees

MCP startup now opens the viewer in the default browser once per worker. No
registration change is needed. Refresh an existing MCP connection once to pick
up the startup patches and new tool schema. `pvs_start` returns `dashboard.url`;
`pvs_sessions` includes the URL, and `pvs_dashboard()` retrieves/starts it.
The MCP process owns both PVS and the viewer, so keep it running.

The page stacks collapsible proof threads beside an agent/thread navigation panel. Hover a node or edge
for its sequent and outgoing command; click to pin it, Escape to release. The bottom-right inspector includes native command docstrings. Labels supplied to `pvs_command`
are prominent on edges; `actor` names identify command owners. These optional
annotations carry no logical authority. Older branches remain dashed after undo.
PVSio sessions display expressions and results alongside proofs. Scroll panes
independently; new activity does not steal the reading position.

`--viewer auto` is the MCP default (`PVS_AGENT_VIEWER` can override it).
`--viewer headless` serves the page without launching a browser, and `--viewer off` disables automatic observation. The Python client and independent replay
workers default to off. A viewer failure does not change proof completion.

`observer.lisp` wraps the existing primitive `rule-apply` boundary, copying
sequents on their owning native threads. A separate observer RPC connection
drains immutable snapshots every 100ms during work (400ms idle). SSE pushes
updates to the page; pointer movement never calls the prover. Native capture
is bounded at 2048 pending events, 16K sequent characters, and 1024 cached states
per runtime. The web store retains at most 6000 nodes / 24MiB serialized node data
and 1024 events / 8MiB event data. Gaps/truncation are visible; this is a bounded
exploration view, not a durable proof log. Long primitive calls publish at their
boundaries, not from inside decision procedures. Whole-proof status remains the
native result; saved proofs still require independent replay.

The HTTP server binds only to 127.0.0.1 with an unpredictable URL token, validates
Host, serves a fixed set of assets, and exposes GET-only snapshot/event endpoints.
It has no command execution endpoint. Slow/disconnected viewers cannot back up
the proof thread. All code and native overrides live under `agent/`.

Nested strategy trials use PVS's `apply-parent-proofstate` relationship. Click a
node's disclosure arrow to expand those internal steps; they start collapsed to keep the main
proof readable. Observer IDs are stable object identities; native label/depth
IDs remain unchanged for agent navigation. The viewer retains immutable sequent
snapshots so strategy reparenting cannot overwrite a different historical node.

The agent/thread panel lists the sessions owned by this MCP worker and their
current commands. Selecting a row reveals the active ancestry, scrolls to that
subtree, and follows subsequent cursor updates. Click it again or manually scroll
to stop following. All command subtrees can be collapsed, including expanded BV
strategies. Closed native leaves are marked green with ✓ QED; historical failed
or abandoned branches are not inferred complete from a whole-proof result.
Node hover updates a fixed bottom-right sequent/command/documentation inspector;
click pins it. The persistent strategy search sidebar has been removed.

The viewer is a nested proof construction explorer. Each command block expands
into its resulting goals; named compound steps have a separate **Primitive steps**
disclosure. Undo history lives under **Earlier attempts**, and fragments with missing ancestry are organized by a nested PVS goal-label
outline under **Retained history** (or directly when no complete root remains).
These goal groups organize recorded states; they do not reconstruct missing
commands. Child parent pointers are used even when a parent edge snapshot is absent.
Commands continuing on the same goal form consecutive lines at one indentation
level. A split indents its branches; derived strategy implementations and earlier
attempts remain separate lazy disclosures. Only opened subtrees are rendered. There is no SVG graph, zoom,
or edge layout. Command labels are prominent;
hover or keyboard focus shows the recorded pre-command sequent and full command
with its documentation in the bottom-right inspector. Completed branches are green throughout their command sequence, nested checked
construction and goal groups, with QED checkmarks at closed leaves. Completion
uses native status or all current children closing; old attempts and missing
children do not establish completion. Undo recomputes the coloring. Rows are 24px high. Commands use one-line ellipsis, goal numbers omit the
repeated theorem name, and the popup retains the captured command text. Deep
rows keep a minimum readable width; indentation overflows horizontally inside
the explorer, independently of the `*pvs*` pane. Follow also scrolls horizontally
to keep the current step and its disclosure reachable, including after resizing.

Thread headers collapse entire attempts. The agent panel unfolds and follows the
current step by opening only its display ancestry, including required primitive,
history and goal-group disclosures. **Follow** stays enabled as the cursor moves;
click **Following**, manually scroll, or select **Collapse steps** to pause it.
Unrelated branches stay folded. Pagination grows just enough to reveal the cursor.
**Collapse steps** folds the construction within one attempt. Each thread renders at most 200 visible
rows initially, with **Show more steps** available; captured hidden descendants
are indexed but never laid out or formatted as DOM elements until requested.

The `*pvs*` panel keeps its most recent command in a fixed header above the
independently scrolling native sequent, output and transcript. A just-submitted
running command takes precedence over an older buffer snapshot. These controls
remain observational and never issue prover commands.

### Lazy derived steps

Define derived automation with `defstep/lazy` (native `defstep` arguments), or
mark existing steps with `(lazy-strategies my-solver my-normalizer)` after their
definitions. For an individual compound command, use
`(lazy-step (then (skosimp*) (grind)) "Arithmetic")`.
The forms live in `lazy-strategies.lisp`, load at extension startup, and can also
be installed through the MCP strategy loader at an idle boundary. The existing
CMR strategies are marked automatically when the agent extension is present;
raw/CLI use remains supported without it.

Both ordinary and `$` calls retain native APPLY boundaries. Computation, primitive
checking, and proof completion still happen immediately. The viewer constructs
nested blocks for an implementation only when **Primitive steps**
is selected or explicit **Follow** needs that boundary to reach the active step.
Unrelated nested boundaries stay folded independently. Remaining result
goals stay visible outside the folded implementation. Native immutable snapshots
are still captured within the existing retention limits; this is lazy rendering,
not on-demand native sequent serialization. Old fully expanded histories cannot
retroactively recover compound boundaries that were never recorded.

`patches/apply-justification.lisp` preserves native CURRENT-XRULE when an APPLY
immediately closes a goal (the stock cached justification is built before that
update), and serializes checked expanded justifications for agent-owned proof
records through PVS's native serializer. The live proof tree retains its named
commands. This startup patch requires a new worker; loading strategy definitions
alone does not install it. New tests save lazy CMR proofs and force replay in a
fresh context with the CMR Lisp and custom strategy definitions absent.

### Interrupted commands and runtime failures (0.3.1)

`pvs_command` and `pvs_evaluate` default to a 60-second execution limit, separate
from their response `wait`. Set `time_limit=0` to disable it, or supply a longer
limit. Expiry requests native interruption; it never kills the process.
`pvs_recover` waits at most 30 seconds (default 5) and distinguishes restoration,
ordinary completion, pending interruption, an unresponsive control channel, and
a fatal runtime failure. An unacknowledged request blocks later commands on that
cursor so a delayed interrupt cannot hit the next command.

Native owner-thread recovery uses PVS's `restore` and the existing evaluator
abort restart. A session-local SBCL debugger hook catches Lisp `break` as well as
unhandled Lisp debugger entry. The timer reads its bound session state without
acquiring the registry lock and targets the current native request sequence.
Earlier branches survive restoration; the aborted step is discarded according
to PVS's native semantics. Arbitrary Lisp/attachment side effects are not rolled
back. Partial proofs can then be closed and saved through existing APIs.

Process output is drained in chunks, including prompts without newlines. Fatal
SBCL/LDB output and process exit invalidate pending operations and report unknown
outcomes instead of an indefinitely running command. The original runtime memory
fault's underlying cause is not repaired by this change: a corrupted heap cannot
be safely restored. No automatic restart, replay, debugger input, or forced
thread destruction is used for recovery.

The startup result and `pvs_inspect(kind="health")` expose a persistent
`recovery_dir`, defaulting to `agent/.recovery/` (override
`PVS_AGENT_RECOVERY_DIR` for installed/read-only deployments). A JSONL journal
records requests, replies, output and deadlines; an atomic, flushed checkpoint
records acknowledged states before each command and after settlement. Client
shutdown leaves these files intact. They are diagnostic/reconstruction evidence,
not `.prf` files or proof certificates. Inspect uncertain in-flight commands
before reconstructing an attempt. Disk write failures are reported; old recovery
folders can be removed when no longer needed. Restart the MCP worker to load the
Python and native startup changes; retain the old worker's evidence first.

A viewer can also observe sessions started by another client of the same native
worker. It discovers session lifecycle through read-only `agent-info` polling;
primitive node snapshots still originate on the proof's owning thread. It does
not acquire command ownership or move proof cursors. Attaching later captures
subsequent steps, not previously unobserved history. Native disconnect errors
remain visible after reloading the page.

### Automatic viewer reconnection and thread buffers (0.3.2)

The observer keeps its HTTP/SSE server and viewer URL alive when the native PVS
socket disconnects. It retries the configured WebSocket endpoint with bounded
backoff (0.25–5 seconds). A worker identity distinguishes a transient disconnect
from a replacement process: the same worker retains display history; a new worker
starts a fresh display generation, including when native session IDs are reused.
The viewer never restarts PVS, replays commands, or transfers command ownership.
Restart a managed worker with the same `--port PORT` to retain its native address;
the default remains an ephemeral port. The viewer process must remain running.
It does not discover arbitrary replacement ports or revive a stopped MCP host.

Selecting a thread opens its read-only `*pvs*` panel beside the tree. The `*pvs*`
button toggles it independently. It shows the current command, native printed
sequent, command output, and expandable recent transcript. PVSio sessions show
expression/results in the same panel. While a command runs, the sequent is the
last returned state, explicitly labeled; output can arrive before completion.

`buffers.lisp` captures immutable text on the owning native session thread and
exposes nonconsuming `agent-observer-state(since)` updates. The viewer does not
claim proof cursors or request proof rendering from another thread. Storage is
bounded to 128 recent sessions, 64K characters each for sequent/transcript, 32K
for output, and 8K for command, with explicit truncation reporting. Earlier output
is unavailable when capture is installed after a command completed. Only this
observational module may be installed at an idle setup boundary in an existing
worker; full core patches/runtime binding changes still require startup.

The node event queue retains its existing single-observer drain semantics;
multiple independent viewers should share one HTTP observer. Buffer updates are
nonconsuming, but this change does not make that node queue multi-subscriber.
