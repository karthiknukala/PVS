# CMR-driven interface validation — 2026-10-30

Checkout: `codex-interface`, PVS baseline `e185d56`, SBCL 2.6.5-85913ede1.
All changes are in `agent/`; the existing raw/batch skill is unchanged. The
installed `pvs-prover-mcp` skill links to the updated maintained source here.

## Delivered behavior

- Compact native open/step responses skip tooltip generation and reparsing.
  They expose whole-proof outcome, focused sequent, signed changes, open-goal
  count, proof-node ID, elapsed time, bounded commentary, and separate errors.
- Full native metadata is lazy. Open-goal pages/ancestry, typed selected ASTs,
  bounded sequences, and navigation reuse existing PVS proof objects/commands.
- Candidate preview uses the same CMR compiler as execution, reporting its
  checking obligations and lemmas. It grants no proof authority.
- Strategy reload reports changed registry definitions and source fingerprints.
  Fresh replay preserves local relative strategy paths.
- Explicit evaluator preparation reuses PVSio's existing cache without executing.
  Obligation inventory reads already typechecked declarations only.

The implementation caught and fixed a session/node-ID collision on repeated
attempts, inconsistent full/close envelopes, a navigation end check, and relative
strategy replay. Render failure after Q.E.D. is covered by startup fault injection.

## Proof results

`cmr98_metatheory.pvs` contains 15 proved results: 5 on normalization, canonical
completeness, and prelude semantics, plus 10 on partitions and solved forms.
All 9 distinct TCCs are proved; 9 other generated TCCs are subsumed. Both theories
freshly replayed all 24 recorded obligations without CMR Lisp or strategy files.
No axioms, trust rules, or status manipulation were introduced.

The partition result is conditional on the mathematical specification of least
equivalence closure. It does not prove that the Lisp interval/union-find code
implements that specification. Nor does it establish the paper's complexity bound
or every clause of its normalizer theorem. Actual solver answers remain checked
by primitive PVS proof steps and the earlier semantic lemmas.

## Tests and concurrency

- Final full regression: **42 passed in 116.84 s**, including lifecycle,
  proof-status, cache isolation and concurrency tests, CMR positives/negatives,
  public MCP workflow, renderer fault injection, and metatheory replay.
- Final focused barrier tests: **2 passed in 2.30 s**. The extended existing
  runtime probe also passed in the full suite.
- Heavy stress: **800 proof attempts passed in one persistent worker** (PID
  72891), across 100 rounds with eight native proof sessions and one prepared
  PVSio evaluator. All **640 positive goals proved**, all **160 deliberately
  false goals remained open**, and all **100 evaluations returned TRUE**.
  No command retries or whole-proof serialization were used. Test-only native
  diagnostic hooks captured no new hash/type/assertion failure.
- Finalized diagnostic stress-driver smoke test: **16 proof attempts plus two
  prepared evaluations passed**, in one worker, in 11.71 s.
- Skill schema validation passed. The unchanged pure solver's earlier validation
  passed 630 exhaustive equation-system checks, projection provenance/target
  separation, wide intervals, and explicit resource-bound checks.

An intermediate full run had 41 passes and one expected version-mismatch
rejection because the extension version was bumped while a live-session test
was starting its fresh verifier. The final full run used stable 0.2.1 sources
throughout. The rejection guard was not bypassed.

### Follow-up: reproduced shared scratch-table races

The earlier unexplained open `overlap` proof led to two concrete isolation defects.
An eight-proof stress run captured SBCL's unsafe-concurrent-hash error with two
native proof threads growing the **same** table through `CANON-HASH`. Shostak's
`canon` also clears that table on entry. `*canon-hash*` was process-global despite
the other runtime cache bindings.

After isolating that cache, concurrent CMR checking still produced hash-growth
assertions, missing candidate types in `typecheck*`, and an "Incompatible types"
message whose found and expected types both printed as `boolean`. Native stacks
located the missing-type assertions in mid-proof `case` typechecking. The native
`protect-types-hash` macro lends `*empty-expression-types*` to `*expression-types*`
and replaces the spare on unwind. Both scratch tables were shared across proof
runtimes. A second barrier test reproduced interference through the native
`types` accessor in overlapping `protect-types-hash` scopes.

`patches/proof-runtime.lisp` now dynamically binds fresh `*canon-hash*`,
`*expression-types*`, and `*empty-expression-types*` tables for each native proof
or evaluator runtime. Nested runtimes restore their caller's bindings. No native
source files changed, no failed command is retried, and no global proof lock was
introduced. The compatibility manifest now also pins the native canonicalizer
and typechecker sources used by these fixes.

Both deterministic tests failed before their respective fixes (`CANON-CACHE-CLOBBERED`
and `TYPE-CACHE-CLOBBERED`) and passed afterward. Their queue barriers require
actual overlapping proof commands; serializing whole proofs would deadlock the
test. The existing runtime probe additionally checks all three new bindings on
nested error/unwind and concurrent initialization. The reproducible stress driver
is `tests/stress_cmr.py`; optional `--diagnose` startup instrumentation stays out
of production `load.lisp`.

Concurrency remains enabled. Parser and C BDD transactions retain their targeted
locks; supported proofs use Shostak. These results qualify the tested profile,
not arbitrary decision-procedure backends or stateful Lisp attachments. No
incorrect theorem completion was observed in the reproductions.

Interactive workers persisted across commands, undo, branch navigation,
inspection, strategy reload, and evaluator use. Startup-code changes required
worker restarts during implementation; fresh verification uses disposable workers.

## Performance measurement

`cmr98/benchmark_interface.py` alternates compact and legacy native stepping in
one process, with 20 warm `(skip)` samples per mode on the same skolemized
`false_overlap` goal. It includes command transport and status refresh:

| Path | Median wall time | Median native response size |
|---|---:|---:|
| Compact | 1.388 ms | 523 bytes |
| Native JSON | 3.728 ms | 6,037 bytes |

This is about 2.7× less interface latency and 11.5× less response data in this
small warm example. It is not a claim about theorem-proving speed, cold startup,
large sequents, or an MCP client's scheduling overhead.

## Experience and remaining opportunities

Most helpful: persistent cursors; independent proof threads; native undo and
branch switching; typed selected-node inspection; explicit quantifier witnesses;
compact global goal counts; and primitive-script replay independent of the planner.
The new preview exposes exactly which identities and projected equations PVS
will check. Bounded sequences save round trips while retaining intermediate states.

Still wanted: explanation of automatic quantifier matches and why a match was
chosen; structured strategy-internal failures instead of mixed commentary;
certificate-step-to-obligation provenance; better dependency capture for
helper-only nested Lisp loads. General decision-procedure models/traces remain
native-specific.
Navigation currently targets the first 100 open leaves, expression inspection is
shallow, previews must be regenerated after strategy reload, and live declaration
changes remain excluded.

## Workflow recommendation

Use the persistent interface for interactive development in this checkout: it
retains proof cursors, supports concurrent attempts and prepared evaluation,
and gives compact feedback without restarting PVS for each experiment. The
installed MCP skill now says this explicitly. Keep the original raw/batch skill
for reproducible scripts and independent replay.

### Registered MCP validation

The follow-up registration is now complete: `~/.codex/config.toml` enables the
`pvs` stdio server with absolute checkout paths, a 30-second startup timeout and a
240-second tool timeout. User `~/.codex/AGENTS.md` now selects direct MCP tools for
interactive PVS work; the maintained MCP skill agrees. The old CLI skill was not
modified or disabled. These host configuration changes are separate from PVS
implementation patches, which remain under `agent/`.

Codex's installed app-server was initialized without creating a chat or invoking
a model. Its `mcpServerStatus/list` request for `pvs` launched the saved registration
and returned **22 tools, with no tools error**. `codex mcp get pvs --json` confirms
the enabled command and timeouts.

With `PVS_MCP_CONFIG=/Users/e35480/.codex/config.toml`, the real stdio MCP workflow
tests passed: **2 passed in 16.23 s**. The ordinary checkout configuration also
passed the same two tests in **16.48 s**, and the updated skill schema validated. They used the saved command/arguments rather
than a handcrafted alternative. Coverage includes start/prepare, proof open,
sequent and typed AST inspection, native undo and branch navigation, failed-command
batch stopping, strategy loading, CMR candidate preview, concurrent primitive
certificate execution and prepared PVSio, explicit proof-record save, and fresh
isolated replay. Independent proof/evaluator sessions retained the same worker
generation throughout. The original false equality remained open during manipulation.

The current desktop turn did not dynamically acquire the new `pvs_*` tools.
The app's control-socket proxy was unavailable, and computer use cannot operate
the Codex app; no app restart or active-chat interruption was attempted. Thus the
observed evidence is Codex discovery plus real MCP wire-level workflow validation
against the saved registration, not a claim that this existing turn called newly
injected tools. Refresh/reopen the chat's MCP connections if its catalog remains
stale; new discovery sees the registered tools.


### Live proof viewer (0.3.0, 2026-10-30)

All changes are contained in `agent/` on `codex-interface`. MCP startup opens a
local viewer automatically; explicit dashboard lookup, headless/off modes, and
optional command labels/actor names are exposed through the thin client. The
existing CLI skill is unchanged. An existing MCP connection needs one refresh
for the updated startup code and tool schemas.

The observer reuses `rule-apply`, `children`, `apply-parent-proofstate`, native
sequents, and strategy registries. It copies data on the owning proof thread,
then streams cached data over a separate read-only connection. Browser hovers
never call a proof operation. Nested strategy trials are expandable; pinned
sequents and scroll position are retained during live updates. Current activity,
undo history, branch splits, labeled commands, strategy signatures/docstrings,
and evaluator results were checked in the rendered browser.

Two display defects were found through real CMR use and fixed: numeric native
status flags could throw while rendering, and native `unique-ps-id` values are
label/depth paths which change or collide during strategy reparenting/undo.
Stable observer-only weak object IDs now preserve distinct historical states;
native IDs used for proof control are unchanged. Nested apply-proofstates use
the existing apply-parent relation rather than appearing as disconnected roots.
Tests check original sequents survive subsequent strategy expansion unchanged.

Validation:

- Full agent + CMR regression: **45 passed**, 111.44 seconds.
- Actual saved MCP registration (`PVS_MCP_CONFIG=~/.codex/config.toml`): **1 passed**,
  including dashboard discovery, labels/actors, proof completion, save, fresh replay.
- Observer integration checks auto-launch once, initial state, concurrent CMR
  proofs, branch/undo, strategy inventory, historical sequent identity, SSE
  attach/disconnect, unchanged native cursor revisions, Host/path checks, and
  bounded node/byte/edge retention.
- A persistent MCP SDK console drove parallel `propagate`, `overlap`, an active
  `false_equality` exploration, and prepared PVSio evaluation. Both true goals
  finished; the false goal remained open after undo; PVSio returned TRUE. The
  process generation remained 1 throughout. This used actual MCP stdio tools,
  not a raw prover command transport. The chat's previously connected tool
  catalog predates the new viewer schema, so a fresh MCP client was used.
- Browser checks covered desktop and narrow layouts, initial sequents, labeled
  edge inspection, strategy search/docstrings, pinned inspection during live
  proof updates, expansion controls, evaluator results, and no JavaScript errors.
- An observer-enabled 80-attempt/10-evaluation stress run with eight proofs per
  round passed in 37.16 seconds, compared with 35.73 seconds for the same workload
  with observation off (~4% difference). This is a small local timing sample,
  not a performance guarantee. Heavy histories intentionally evict old nodes;
  explicit gap notices distinguish this from a complete proof trace.

Final delivery stress also passed: 80 proof attempts and 10 PVSio evaluations,
37.47 seconds, one PID throughout, no capture errors. The 6000-node retention
limit evicted 3944 historical states as designed. Long primitive
calls publish at boundaries, not continuously from inside decision procedures.
The viewer is read-only, bounded, and ephemeral; saved native proofs plus fresh
replay remain the correctness record. Live declaration editing is out of scope.

After trimming redundant state payloads from cursor events, the focused observer
and real-MCP transport regression also passed (4 tests).

### Agent navigation / command inspector revision (2026-10-30)

Frontend-only changes in `web/` replace the persistent strategy search rail with
an agent/thread panel and a fixed bottom-right inspector. Command subtrees,
including expanded CMR/BV commands and undone branches, can collapse/reopen.
Collapsed nodes retain their command label. Native `!` leaves are green with
checkmarks and QED; whole-proof completion is not propagated to abandoned nodes.
Clicking an agent/session reveals its active ancestry and follows subsequent
cursor updates; scrolling, touching, or interacting with the tree stops follow.

Validated in the actual browser against retained CMR snapshots: collapsing the
BV root leaves two accessible buttons (node + disclosure), reopening restores
the tree, 27 visible closed leaves show QED with green fill, the inspector shows
the CMR command and its native docstring, session selection changes the follow
state and scrolls to the exploratory tree, and the old search element is absent.
No browser JavaScript errors. `node --check agent/web/app.js` passed and observer
integration/regression tests passed (3 tests, 7.27 seconds).

After reconnecting, the registered direct tools reported version 0.3.0 and
exposed the dashboard and actor/label schema. The direct-tool live demo passed
on 2026-10-30, without a terminal proof transport:

- Started one worker (generation 1), with parallel proofs and evaluator enabled
  under Shostak; the same worker served the entire demo and live viewer.
- Submitted expanded CMR commands for `propagate-5` and `overlap-5`, together
  with a prepared PVSio evaluation, using concurrent direct tool calls. Both
  proof calls returned running before settling to native `proved`; PVSio
  returned TRUE for `(bvec0[8] o bvec1[8])(0)`, with no errors or unresolved TCCs.
- `false_equality-4`: skosimp, case split (two open goals), postpone to the
  second branch, undo to the original symbolic goal (one open goal). It
  correctly remains active rather than proved, at revision 4.
- The browser followed the selected session as MCP events arrived. Collapsing
  the CMR root retained its label; reopening restored primitive commands.
  The inspector displayed the sequent, `(cmr98-bv$)`, and native docstring.
  There were 27 displayed QED markers and retained dashed history after undo;
  the agent panel showed both completed proofs, the exploratory session, and
  the PVSio TRUE result. No proof-page refresh was needed.

These were interactive proof completions; this demo did not save or independently
replay new proof records. Earlier independent replay coverage is reported above.

### Collapsible threads and tree navigation (2026-10-30)

Frontend changes replace the horizontal strip of large canvases with a vertical
stack of independently collapsible threads. Completed sessions start folded on
page load. Collapse all / expand all / collapse completed controls operate only
on the display. Hidden trees keep receiving events and resume rendering on open.
Per-thread controls provide zoom, 100% reset, fit whole tree, fit width, and follow;
double-clicking an overview region zooms into that location. Session navigation
unfolds the selected thread and aligns it below the sticky overview controls.
Evaluator diagnostics remain available in a disclosure beside the result.

Browser validation used the existing ten-session CMR worker, without restarting
PVS: collapse all left zero expanded threads; selecting Shared columns opened
only that thread; whole-tree fit stayed within its viewport; double-click restored
100% zoom; fit width matched the available width; keyboard node inspection showed
the sequent and native strategy docstring. Checked narrow and desktop layouts,
restored the normal viewport, and observed no JavaScript errors. JavaScript syntax
validation passed. Existing observer regression tests: 3 passed in 6.97 seconds.

### Lazy derived-strategy boundaries (2026-10-31)

Added `defstep/lazy`, `lazy-strategies`, and `lazy-step` using native DEFSTEP,
DEFSTRAT and APPLY. Marked the CMR solver, column compiler, normalization and
foundation steps. Both normal and `$` calls retain compound boundaries. Following
no longer opens implementation ancestors. A disclosure constructs their layout
and SVG elements on demand, keeping nested boundaries folded and leaving actual
result goals outside the implementation visible. Immutable native snapshots are
still eagerly captured within the existing bounded retention policy.

Direct registered MCP validation used the existing generation-1 worker, loading
only the new strategy definitions at an idle boundary: `overlap-6` and `multi-5`
completed concurrently with no native errors and zero remaining goals. Browser
checks while following overlap showed one rendered proof node; explicit expansion
created three nodes, with both nested implementations still folded. Mouse and
keyboard disclosure work, collapse returns to one node, and Follow does not
reopen it. The inspector shows the CMR invocation and native docstring rather
than only the underlying APPLY. Unpinned hover panels no longer intercept clicks
on controls they overlap. The live worker was not restarted or core-patched.

The new persistence regression exposed two native behaviors: immediate-success
RULE-APPLY caches its justification before CURRENT-XRULE is installed, and native
PRF serialization drops XRULE. The local `patches/apply-justification.lisp`
preserves the checked expansion and uses the native serializer on copied expanded
justifications for agent-owned records. Ordinary non-agent serialization is
unchanged. This patch loads on the next worker startup; the already-running live
demo has only the strategy/viewer improvements, and its demo proofs were not saved.

Validation: 46 tests passed in 119.28 seconds (all agent tests plus CMR integration).
The new regression covers nested lazy definitions, repeated marking, two visible
result goals, undo, concurrent CMR proofs, and saving/replaying those newly created
proofs in a fresh context without the CMR Lisp or custom strategy definitions.
JavaScript syntax and MCP skill validation passed. The old CLI skill is unchanged.

## Recovery and fatal-runtime diagnosis (2026-10-31, 0.3.1)

Diagnosed the reported `ws://127.0.0.1:60173` worker without terminating or
modifying it. OS sampling placed `example_10b_2-0` in SBCL's C-level
`gencgc_handle_wp_violation -> lose -> ldb_monitor -> fgets` path. New WebSocket
handshakes timed out. The independent viewer snapshot and stack sample were
preserved under `agent/.recovery/incident-60173/`, with an incident README.
This establishes a fatal runtime stop, not its underlying memory-fault cause.
No recovery of that original unsaved native proof is claimed.

Implemented bounded native recovery, debugger-to-restore handling, per-command
execution deadlines, process-exit/fatal-output detection, and persistent journals
and checkpoints. The native timer accesses bound session state without acquiring
the registry lock and carries the native command sequence. Concurrency remains
enabled; no process/thread kill is used for proof recovery.

Validation:

- Full regression command: `agent/.venv/bin/python -m pytest -q agent/tests
  agent/cmr98/test_integration.py`: **52 passed in 133.81s**.
- Following final completed-proof and uncertain-command checkpoint guards,
  `agent/tests/test_recovery.py agent/tests/test_mcp.py`: **8 passed in 15.90s**.
  This includes one additional completed-proof regression beyond the full run.
- The MCP skill passed `skill-creator/scripts/quick_validate.py`.
- A real six-branch proof closed one branch, survived three nonterminating Lisp
  commands and a Lisp `break`, preserved the five remaining branches and their
  sequent, and retained its process generation. A second proof and prepared
  PVSio evaluation ran concurrently. Native evaluator loops/breaks also recovered.
- Deadline interruption was followed by another command to check that an old
  watchdog cannot interrupt later work. Partial native proof saving and subsequent
  completed proof fresh replay succeeded.
- Actual MCP stdio discovery exposes `pvs_recover` and `time_limit`. Tool calls
  exercised splitting, loops, debugger restoration, deadlines, completion, and a
  controlled worker exit. Exit reports uncertainty and leaves evidence accessible.
- Simulated split fatal-output chunks ending in an LDB prompt without a newline
  failed pending operations and retained the last acknowledged state. This tests
  fatal-output classification, not recovery from corrupted memory.
- Unresponsive interrupt RPCs and blocked setup admission return within their
  recovery budget. Native RPC-started work remains interruptible. Completed proofs
  remain proved when recovery is requested on an already closed cursor.

An initial full run exposed a regression in interruption of work started directly
through native RPC, outside the Python pending-task wrapper. Restoring that native
interrupt behavior resolved it; the full run above is after the correction.
The underlying original SBCL memory fault remains unresolved. Existing workers
must be replaced explicitly to load these startup changes; retain their old
Python transcripts first. The old CLI skill is unchanged.

## Viewer reattachment after worker replacement (2026-11-01)

The viewer on port 49232 still belonged to the crashed original worker, while a
replacement PVS process had reused WebSocket port 65532. Replaced only the stale
viewer client and explicitly attached a read-only observer to the replacement,
retaining the original HTTP port and token. No active proof was restarted.

The observer now inventories native sessions via `agent-info`, including sessions
owned by other clients. Primitive cursor events create missing session rows;
local owners retain their richer annotations and terminal focus. Native inventory
polling does not claim proof cursors. Disconnect errors persist in snapshots, so
browser reloads cannot erase the native connection failure. The frontend no
longer claims that proofs continue when its event stream disconnects.

`agent/tests/test_observer.py`: **5 passed in 23.45s**. The new real-worker test
attaches a separate viewer to an existing proof, observes splitting and undo,
checks that viewing does not change the revision, and verifies that disconnect
errors survive snapshot retrieval. Existing concurrent CMR and lazy expansion /
portable replay tests pass. `node --check agent/web/app.js` passes.

Live verification: the original viewer URL displayed the other client's
`reassociate-0` tree (31 retained nodes), including folded strategies and its green
QED leaf. The worker and observer reported no connection/capture errors.

Reattachment is explicit: reuse of a TCP port alone is not permission to treat a
new process as the old proof generation. A viewer attached after work has started
captures subsequent steps; it does not reconstruct earlier unobserved history.


## Automatic reconnect and per-thread native buffers (2026-11-01, 0.3.2)

Supersedes the explicit reattachment limitation above. Full regression:
`agent/.venv/bin/python -m pytest -q agent/tests agent/cmr98/test_integration.py`:
**56 passed in 152.46s**. This includes real PVS replacement on the same native
port with the viewer HTTP URL unchanged, same-worker socket reconnection, and
fresh display generations even when native session IDs repeat. Old nodes and
buffer transcripts do not leak into the replacement generation.

Native buffer tests run two proofs and PVSio concurrently and verify isolated
command/output text, native sequents, read-only inspection revisions, split/undo,
unknown-rule errors, bounded large output, and recovery from an infinite loop.
The combined focused restart/recovery suite passed **8 tests in 15.67s** before
the full run. A cancellation/connection-loss future warning found during that
run was fixed before the final full regression.

Installed the observational buffer module at an idle setup boundary in the live
worker and replaced only its independent viewer process, preserving HTTP port
49232, its token, and same-worker retained tree nodes. The native PVS process and
proofs were not restarted. Closed sessions predate capture, so their earlier
output is explicitly unavailable. Native startup workers load the module normally.
The underlying prior SBCL memory fault remains outside this change.

Browser QA on an isolated native worker displayed `(split)`, the native
`branching.1` sequent, and “Splitting conjunctions, this yields 2 subgoals” beside
the branching tree; its separate PVSio panel displayed `inc(41)` and `42`.
Final JavaScript syntax and MCP skill validation passed.


## Nested proof explorer (2026-11-02)

Replaced SVG edges, coordinates and zoom controls with lazy nested command blocks.
Resulting goals, primitive implementations, earlier attempts and disconnected
retained fragments have separate disclosures. Following highlights only the
nearest visible ancestor. The native buffer command is outside the scrolling
sequent/output/transcript body and updates independently of explorer expansion.
No Lisp or proof-control behavior changed.

Validation: `node --test agent/tests/test_explorer.cjs` passed 5 tests covering
branch/implementation/history separation, 6,000-node bounded lazy projection,
reparenting, cycles, retained fragments and latest-running-command precedence.
`pytest -q agent/tests/test_observer.py agent/tests/test_viewer_restart.py` passed
7 tests in 33.04s, including concurrent CMR, lazy strategy replay, undo, native
buffers and worker reconnection. Browser validation used a separate actual PVS
worker: expanding skosimp retained its closed primitive disclosure, expanding a
labeled split showed exactly two goal blocks, the popup showed the split's input
sequent/docstring, and the latest `(split)` remained at the top while the native
transcript scrolled. PVSio's independent buffer showed `inc(41)` and `42`.

The old independent viewer process was no longer running. Connected through the
direct MCP start tool to the existing native worker on port 65532, serving the new
assets without restarting that PVS process or changing its proof cursors.


## Dense explorer and missing-ancestry nesting correction (2026-11-02)

The earlier browser check covered a complete small proof and missed the live
large-history failure: 152 disconnected fragments in a 2,666-node attempt were
flat siblings under one disclosure. The index now honors child parent pointers
even when the corresponding edge snapshot is absent. Missing-ancestry fragments
are grouped through every enclosing PVS goal-label prefix, not flattened. These
are organizational groups, not fabricated native proof steps or sequents.

Seven Node regressions pass, including deep missing ancestry and absent parent
edges. Tested the captured live 4,436-node snapshot and the running viewer.
Browser DOM inspection confirmed nested depths 1 through 5 for root, Goal 1,
Goal 1.1, Goal 1.1.1 and its children, with approximately 24px row heights.
Removed card padding, multiline summaries and duplicate command text; full
captured commands remain in the hover inspector. No native worker changes or
proof commands were needed.


## Follow opens the active path (2026-11-02)

Explicit Follow (including selecting a thread in the agent panel) now opens the
actual display ancestry to the native observer cursor: command parents, primitive
implementations, history disclosures and retained goal-prefix groups. It extends
pagination when needed, highlights and scrolls to the current row, and repeats
on cursor updates. Unrelated branches remain folded. Following toggles off;
manual scrolling and Collapse steps also pause it. No proof commands are issued.

All 10 Node explorer regressions pass, including primitive paths, undo/history,
missing ancestry, pagination, new cursor nodes and unknown/pending IDs. Browser
validation on the live large proof exercised Collapse steps then Follow: 33
ancestors opened to the exact current row, with 26 unrelated disclosures still
collapsed. The current row was scrolled into the explorer viewport.


## Horizontal overflow with the native buffer open (2026-11-02)

Deep rows formerly shrank with each level of indentation until their contents
were clipped in narrow panes. Rows now retain at least 320px of width inside the
explorer's independent horizontal scroll area, while preserving the 24px height.
The explorer is keyboard focusable and has styled scrollbars. Follow positions
the current row horizontally, including when it is wider than the pane, and
resizes schedule a fresh position check. The native buffer stays independent.

All 10 existing explorer regressions pass. Browser validation on the live large
proof with `*pvs*` open verified horizontal overflow (878px content in a 498px
pane), manual leftward scrolling from offset 380px to zero without collapsing
branches, and Follow restoring visibility. Also tested the desktop side-by-side
layout and confirmed the current 320px-wide row was fully inside the proof pane;
the buffer remained beside it. Temporary viewport overrides were reset.


## Flat command sequences and whole-branch completion coloring (2026-11-02)

Same-goal single-child continuations now render as consecutive siblings, rather
than nested command subtrees. Branches and lazy primitive/history groups retain
indentation. Completion propagates from native QED status through all current
children; missing children and abandoned successful trials cannot close a parent.
Completed construction and its checked implementation are green throughout;
undo recomputes completion, and open sibling branches remain neutral.

All 14 Node explorer tests pass. New regressions cover flat continuation chains,
branch indentation, full-branch completion, undo, missing children, old trials,
and goal/primitive-group coloring. Browser validation on the retained live-worker
history showed consecutive commands at x=49px, child-branch commands at x=69px,
and green text (rgb 40,115,76) throughout the completed construction.

The old MCP-hosted HTTP viewer had stopped before validation. Restored only an
independent read-only observer at the same port/token, attached to the existing
native worker. Recovered immutable history only after matching the saved worker
identity; refreshed statuses and buffers from PVS. No proof cursor or native
worker was restarted. Viewer process: agent/.recovery/viewer-53241.py.
