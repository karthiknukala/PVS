# Running, Saving, and Replaying PVS Proofs

## Contents

1. Locate PVS and establish a context
2. Raw-mode commands
3. Named-declaration proof driver
4. Replay and status
5. Emacs/PVS commands
6. `.prf` persistence and stale state
7. Completion checklist

For uncertain proof development, prefer the persistent workflow in
[interactive-sessions.md](interactive-sessions.md). This reference covers
batch verification and fallback. Loading the bundled driver sets global
noninteractive options, so use it only in a separate batch process.

## 1. Locate PVS and establish a context

Prefer the executable selected by the repository or user. Common choices are:

```sh
PVS_BIN="${PVS_BIN:-$HOME/git/PVS/pvs}"
SKILL_DIR="${SKILL_DIR:-$HOME/.codex/skills/pvs-prover}"
```

Run PVS with the theory's directory as both the shell working directory and
the PVS context. Use absolute paths in Lisp strings. Set `PVS_LOG_DIR` to a
writable temporary directory if the configured log directory is unavailable:

```sh
PVS_LOG_DIR=/tmp/pvslog "$PVS_BIN" -raw -E '...'
```

The commands below target current raw PVS builds. If an installed version has
a different API, inspect its `doc/prover/`, `doc/user-guide/`, and
`src/pvs.lisp` rather than guessing.

## 2. Raw-mode commands

### Typecheck and list proof status

```sh
"$PVS_BIN" -raw -E \
'(progn
   (in-package :pvs)
   (setq *proceed-without-asking* t)
   (change-context "/absolute/context")
   (typecheck-file "file")
   (status-proof-theory "Theory"))'
```

Use the file base name without `.pvs`. A source file may contain several
theories, so keep `file` and `Theory` separate.

### Replay a theory

```sh
"$PVS_BIN" -raw -E \
'(progn
   (in-package :pvs)
   (setq *proceed-without-asking* t)
   (change-context "/absolute/context")
   (typecheck-file "file")
   (prove-theory "Theory" t nil nil t)
   (save-context nil t))'
```

The second argument to `prove-theory` requests retrying existing scripts.
The final `t` requests proof saving in PVS versions with the five-argument
interface.

### Replay an import chain

```sh
"$PVS_BIN" -raw -E \
'(progn
   (in-package :pvs)
   (setq *proceed-without-asking* t)
   (change-context "/absolute/context")
   (typecheck-file "file")
   (prove-importchain "Theory" t nil nil t)
   (save-context nil t))'
```

Use `status-proof-importchain` when the acceptance criterion includes all
transitively imported theories.

Shell quoting around Lisp is fragile. Put complicated orchestration in a
`.lisp` file loaded with `-L`; keep `-E` short.

## 3. Named-declaration proof driver

`prove-formula-decl` is useful for proving a scratch formula in the context of
a theory. Do not assume that this attaches the resulting proof to an existing
named declaration or writes the matching `.prf`.

Use the bundled driver to typecheck, locate the actual declaration (including
a generated TCC), install a strategy, prove it, and save only a Q.E.D. result:

```sh
"$PVS_BIN" -raw \
  -L "$SKILL_DIR/scripts/pvs-proof-driver.lisp" \
  -E '(pvs::pvs-skill-prove-one
        "/absolute/context"
        "file"
        "Theory"
        "formula_or_TCC"
        "(then (skosimp*) (grind))"
        t)'
```

Arguments:

1. absolute context directory;
2. PVS file base name;
3. theory name;
4. exact formula/TCC declaration name;
5. strategy as a Lisp string or form;
6. whether to save a completed proof.

Use `nil` for the last argument during exploration. A failed attempt then
cannot overwrite the saved `.prf`. The driver prints:

```text
PVS-SKILL RESULT Theory.formula STATUS !
```

`!` is PVS's internal complete-proof flag. The proof output should also contain
`Q.E.D.`.

The strategy may be either a strategy expression:

```lisp
"(then (skosimp*) (grind))"
```

or an editable proof-script form:

```lisp
'("" (SKOSIMP*) (GRIND))
```

### Driver replay helpers

```sh
"$PVS_BIN" -raw \
  -L "$SKILL_DIR/scripts/pvs-proof-driver.lisp" \
  -E '(pvs::pvs-skill-replay-theory "/absolute/context" "file" "Theory")'
```

```sh
"$PVS_BIN" -raw \
  -L "$SKILL_DIR/scripts/pvs-proof-driver.lisp" \
  -E '(pvs::pvs-skill-status-importchain "/absolute/context" "file" "Theory")'
```

Available functions are:

- `pvs-skill-prove-one`
- `pvs-skill-replay-theory`
- `pvs-skill-replay-importchain`
- `pvs-skill-status-theory`
- `pvs-skill-status-importchain`

## 4. Replay and status

Use replay to check the script and status to inspect the recorded state.
Neither substitutes for the other.

- `prove-theory`: replay proof scripts in one theory.
- `prove-pvs-file`: replay a file's theories.
- `prove-importchain`: replay the transitive `IMPORTING` closure.
- `status-proof-theory`: report declarations in one theory.
- `status-proof-pvs-file`: report declarations in a file.
- `status-proof-importchain`: report declarations across imports.
- `status-proofchain*`: check dependencies used by proofs and detect incomplete
  or circular proof chains.

Interpret statuses:

- `proved - complete`: a complete proof is recorded.
- `unfinished`: an attempted proof still has open branches.
- `untried`: no proof attempt is recorded.
- `unchecked`: a former proof has not been revalidated since relevant changes.

Always run the scope named by the user's acceptance criterion. A theory can be
3/3 while its import chain still contains unfinished proofs.

## 5. Emacs/PVS commands

Common commands:

| Emacs command | Short form | Purpose |
|---|---|---|
| `M-x prove` | `M-x pr` | Prove formula at cursor |
| `M-x step-proof` | | Replay interactively |
| `M-x prove-theory` | `M-x prt` | Replay theory |
| `M-x prove-pvs-file` | `M-x prf` | Replay current file |
| `M-x prove-importchain` | `M-x pri` | Replay import chain |
| `M-x status-proof-theory` | `M-x spt` | Theory proof status |
| `M-x status-proof-importchain` | `M-x spi` | Import-chain proof status |
| `M-x edit-proof` | `M-x show-proof` | Edit a declaration's script |
| `M-x install-proof` | | Attach edited proof |
| `M-x install-pvs-proof-file` | | Reload an externally changed `.prf` |
| `M-x help-pvs-prover` | | Browse prover commands |

A prefix argument usually means “include/retry already proved formulas,” for
example `C-u M-x prove-theory`.

At `Rule?`:

- `(help command)` shows installed command syntax;
- `(undo)` backs up;
- `(postpone)` moves to a sibling;
- `(quit)` abandons the attempt and may offer to save a partial proof;
- `C-c C-c`, followed by `(restore)` at the Lisp break, interrupts a long
  command and returns to the prover.

## 6. `.prf` persistence and stale state

Each `.pvs` file normally has a sibling `.prf` containing proof scripts for
all its theories. PVS stores proof trees, not necessarily the exact commands
typed interactively.

Important consequences:

1. Seeing Q.E.D. does not prove the `.prf` was written. Check its timestamp,
   entry, and a fresh status process.
2. PVS loads a proof file while parsing/typechecking and may retain it in
   memory. An already-running Emacs session can ignore external `.prf` edits
   and later overwrite them.
3. After an external source change, end affected proofs before forcing a
   typecheck and reopening them. After an external proof-file change, coordinate
   stale writers and run `M-x install-pvs-proof-file`.
4. Save proof scripts with `save-all-proofs` and proof status with
   `save-context` in batch workflows.
5. Never hand-edit `.pvscontext` or compiled `pvsbin` objects. Do not remove
   them merely to clear staleness without understanding and authorization.
6. A proof loaded from cache is not sufficient validation. Force a fresh
   replay with retry enabled.

## 7. Completion checklist

- Source typechecks.
- Every target declaration prints Q.E.D.
- The corresponding `.prf` contains each exact declaration name.
- A new PVS process replays the requested theory/file/import chain.
- Status reports `proved - complete` for every target.
- Proof-chain status is clean when sound dependency closure is required.
- The working-tree diff contains only intended source/proof changes.
- No temporary driver, edited proof buffer, or stale live session can overwrite
  the delivered result.
