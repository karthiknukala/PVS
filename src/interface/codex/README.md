# Codex PVS Driver

This folder contains a Codex-oriented stdio driver for PVS. It is meant to be
the single machine-facing entry point for:

- workspace changes
- parse and typecheck
- TCC inspection
- interactive proof sessions
- `pvs2c` translation

## Why this exists

The existing prover machinery already exposes structured proof sessions, but
the main machine-facing entry point is the websocket JSON-RPC server. There are
also many useful non-proof commands in raw PVS, but driving them with ad hoc
`pvs -raw -E ...` calls is awkward for Codex and loses session state.

This driver keeps everything in one long-lived JSON-RPC-over-stdio session, so
Codex can change context, typecheck, read TCCs, run proofs, interrupt proofs,
and call `pvs2c` without leaving the same interface.

## Files

- `proof-driver.lisp`
  - Runs inside PVS.
  - Exposes the existing JSON-RPC methods over stdin/stdout.
  - Adds Codex convenience requests for parse/typecheck/TCC/pvs2c.
- `proof_driver.py`
  - Starts a headless PVS subprocess.
  - Loads the Lisp driver.
  - Proxies JSON-RPC messages over its own stdin/stdout, filtering out normal
    PVS startup chatter.

## Running it

From the repository root:

```bash
python3 src/interface/codex/proof_driver.py
```

The proxy prints a `proxy-ready` notification once the underlying PVS process
is ready. After that, send one JSON-RPC request per line on stdin.

## Recommended requests

The raw PVS JSON methods remain available, but for Codex these are the
recommended entry points:

- `change-context`
  - Switch the current workspace.
- `parse-file`
  - Parse a file and return structured theories plus a compact summary.
- `typecheck-file`
  - Typecheck a file and return structured theories plus a compact summary.
- `show-tccs-file`
  - Return TCCs plus proved/unproved counts.
- `prove-formula`
  - Start an interactive proof session.
- `proof-command`
  - Run a prover command in an existing proof session.
- `interrupt-proof`
  - Interrupt a long-running proof command and restore the session.
- `pvs2c-theory`
  - Run `pvs2c` on a theory and return generated artifact paths plus warnings.
- `shutdown`
  - Exit the proxy and its headless PVS subprocess.

`driver-info` returns the full available request list plus a short description
of the recommended workflow-oriented requests above.

## Notifications

Besides ordinary JSON-RPC responses, the proxy may emit notifications:

- `proxy-ready`
  - The Python proxy is ready.
- `ready`
  - The underlying PVS Lisp bridge is ready.
- `info`, `warning`, `buffer`
  - Structured PVS-side notifications from the usual hooks.
- `log`
  - Raw non-JSON output that escaped through stdout.

For `pvs2c-theory`, the Codex wrapper captures most direct stdout chatter and
returns it in the response as `messages`, which is easier for Codex to consume
than a loose stream of console lines.

## Example session

```json
{"jsonrpc":"2.0","id":"1","method":"ping","params":[]}
{"jsonrpc":"2.0","id":"2","method":"change-context","params":["/Users/me/git/PVS/Examples"]}
{"jsonrpc":"2.0","id":"3","method":"parse-file","params":["sum"]}
{"jsonrpc":"2.0","id":"4","method":"typecheck-file","params":["sum",null,false]}
{"jsonrpc":"2.0","id":"5","method":"show-tccs-file","params":["sum"]}
{"jsonrpc":"2.0","id":"6","method":"prove-formula","params":["/Users/me/git/PVS/Examples/sum#sum#closed_form"]}
{"jsonrpc":"2.0","id":"7","method":"proof-command","params":["closed_form-0","(induct \"n\")"]}
```

The proof requests return the same structured proof-state payloads produced by
`src/interface/pvs-json-methods.lisp`.

## Parse and typecheck

`parse-file` and `typecheck-file` wrap the existing structured JSON results and
add a small summary envelope:

- `operation`
- `input`
- `file`
- `theoryCount`
- `theoryIds`
- `theorySummaries`
- `theories`

Examples:

```json
{"jsonrpc":"2.0","id":"10","method":"parse-file","params":["sum"]}
{"jsonrpc":"2.0","id":"11","method":"typecheck-file","params":["sum",null,true]}
```

`typecheck-file` takes:

- `filename`
- optional `content`
  - If non-empty, the driver writes that content to `filename` before typechecking.
- optional `force?`

If you prefer the original raw JSON method names, `parse` and `typecheck` are
still available too.

## TCCs

`show-tccs-file` wraps the existing `show-tccs` data and adds summary counts:

- `theoryId`
- `file`
- `tccCount`
- `provedCount`
- `unprovedCount`
- `tccs`

Example:

```json
{"jsonrpc":"2.0","id":"20","method":"show-tccs-file","params":["sum"]}
```

The original `show-tccs` request is still available if you want the bare list.

## pvs2c

`pvs2c-theory` did not previously have a Codex-friendly wrapper here. It now
returns:

- `theoryId`
- `file`
- optional `libraryPath`
- `result`
  - The direct Lisp return value from `pvs2c-theory`
- `artifacts`
  - One entry per imported theory plus the requested theory
- `warningCount`
- `warnings`
- `messages`

Each artifact entry may include:

- `theoryId`
- `file`
- `headerFile`
- `cFile`
- `depsFile`
- `testMainFile`
- `warningCount`
- `warnings`

Example:

```json
{"jsonrpc":"2.0","id":"30","method":"pvs2c-theory","params":["sum",true,null]}
```

Parameters are:

- `theoryref`
- optional `force?`
- optional `library-path`
  - If present, generated header/body/dependency files are reported relative to
    that pvs2c library root.

## Interrupts and shutdown

- Use `interrupt-proof` with the proof-session id to interrupt a long-running
  proof command.
- The Codex driver handles requests concurrently, so `interrupt-proof` can be
  sent while a `proof-command` request is still in flight.
- Internally this uses PVS's existing `interrupt-session` / `prover-abort`
  path, which is the same restore mechanism exposed to Lisp as `(restore)`.
- Use `shutdown` to terminate both the proxy and the underlying headless PVS
  subprocess.

## Request ordering

Independent requests may be handled concurrently. For dependent operations,
wait for the earlier response before sending the next request. For example,
send `change-context`, wait for its response, then `typecheck-file`, then
`show-tccs-file` or `prove-formula`.
