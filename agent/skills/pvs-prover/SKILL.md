---
name: pvs-prover
description: Develop, diagnose, persist, and replay proofs in the PVS theorem prover. Use when working with PVS theories, generated TCCs, `.pvs`, `.tccs`, or `.prf` files; interpreting PVS sequents; selecting or composing prover commands and strategies; invoking PVS interactively or through `pvs -raw`; fixing unfinished or unchecked proofs; or verifying theory, file, import-chain, and proof-chain status.
---

# PVS Prover

Prove PVS declarations by treating the displayed sequent as the primary
diagnostic artifact, iterating with small proof steps, and accepting a result
only after PVS saves and replays it in a fresh process.

## Load the relevant guidance

- Read [references/proof-workflow.md](references/proof-workflow.md) whenever
  constructing a proof, diagnosing a residual sequent, or choosing commands.
- Also read
  [references/batch-and-persistence.md](references/batch-and-persistence.md)
  when invoking PVS from the shell, installing or saving `.prf` files, or
  checking proof status.
- Prefer the persistent PVS agent tools for interactive proof development.
  Read [references/interactive-sessions.md](references/interactive-sessions.md)
  when those tools are available.
- Keep [scripts/pvs-proof-driver.lisp](scripts/pvs-proof-driver.lisp) for
  repeatable batch attempts, fallback, and final replay. Do not load it into
  an interactive worker: it sets global noninteractive options.

## Guardrails

1. Read repository instructions and inspect the relevant theory, imports,
   generated TCCs, and existing proof before changing anything.
2. Do not add axioms, postulates, assumptions, auxiliary declarations, or
   weakened statements to make an obligation disappear unless the user
   explicitly requests a specification change.
3. Do not edit a definition merely because its TCC is hard. First determine
   whether the obligation follows from the declared types and hypotheses. If
   it appears false, exhibit the missing premise or counterexample and request
   authorization before changing semantics.
4. Preserve unrelated source and proof changes. Treat `.prf`, `.pvscontext`,
   and `pvsbin/` as stateful artifacts, not disposable caches.
5. Never report success from `quit`, `postpone`, an attempted status, or a
   proof that only works in the current process. Require Q.E.D. on every
   branch and a fresh replay.

## Proof workflow

### 1. Establish the context

- Locate the PVS executable. Prefer a repository-specified path, then
  `$PVS_HOME/pvs`, then `~/git/PVS/pvs`, then `pvs` on `PATH`.
- Identify the context directory, PVS file base name, theory, and exact formula
  or TCC name. Do not assume the file and theory names are identical.
- Inspect existing `.prf` entries before replacing them.
- Typecheck first. Generated TCCs and declaration shapes may change after a
  source edit.

### 2. Isolate one obligation

Attempt one named declaration with a short strategy. Start with a bounded
automation probe such as `(grind)` when appropriate, but use its residual
sequent as information rather than repeatedly trying larger automation.

With the agent tools, start once, open the exact named declaration, and keep
that session alive while applying small commands and inspecting their effects.
Use a separate native session for another agent's attempt; do not have two
agents steer one proof cursor. Undo follows the current branch's ancestry;
postpone visits another open goal. Immediate `(undo undo)` is not a general
redo stack. Do not change declarations or retypecheck changed source under
an active proof.

For batch fallback, a shell attempt that can be saved on success uses the
bundled driver:

```sh
"$PVS_BIN" -raw \
  -L "$SKILL_DIR/scripts/pvs-proof-driver.lisp" \
  -E '(pvs::pvs-skill-prove-one "/absolute/context" "file" "Theory" "formula" "(grind)" t)'
```

The final `t` means “save only if complete.” While exploring, use `nil`.

### 3. Read the residual sequent

Interpret the sequent as:

```text
all antecedents above the line  ==>  at least one consequent below the line
```

Negative formula numbers name antecedents; positive numbers name consequents.
Before issuing another command, state what logical obstruction remains:
hidden subtype facts, an unintroduced quantifier, a missing witness, an
unexpanded definition, an equality/extensionality mismatch, a needed lemma
instance, an induction hypothesis, or a genuinely missing assumption.

### 4. Apply the smallest exposing step

Prefer a short sequence of structural steps followed by automation:

- expose implications and Boolean structure;
- skolemize arbitrary variables;
- instantiate quantified hypotheses or provide existential witnesses;
- expand only the definitions blocking the goal;
- introduce subtype predicates when PVS has not made them visible;
- apply or rewrite with a specific lemma;
- decompose record, tuple, or function equality;
- finish arithmetic, equality, and propositional residue with `assert`,
  `ground`, or `grind`.

Use `undo` after a step that obscures the goal or causes an unhelpful branch
explosion. Use `postpone` only to work on a sibling, never as evidence that the
branch is proved.

### 5. Turn the successful interaction into a robust strategy

- Compose sequential work with `then`.
- Dispatch distinct subgoals with `spread` or `branch`.
- Prefer formula selectors (`-`, `+`, `*`) or labels when they suffice;
  hard-coded formula numbers and generated Skolem names are brittle.
- Use explicit witnesses and lemma instantiations when automation guessed
  them only accidentally.
- Avoid huge undifferentiated `grind :defs (...)` calls if a few controlled
  expansions make the proof clearer and more stable.

### 6. Save and verify

1. Select the intended native proof alternative explicitly and save it to the
   matching `.prf`; completion order does not select a default.
2. Start a fresh PVS process in an isolated copy of the context and writable
   imports, or close the original process before replaying in place.
3. Force replay of the theory or import chain.
4. Run the matching proof-status command.
5. Confirm every required formula says `proved - complete`.
6. Inspect the `.prf` entry and working-tree diff to ensure the proof was
   actually written and no unrelated artifact was changed.

## Completion report

Report:

- the exact declarations proved;
- whether source semantics changed, and why;
- the `.pvs` and `.prf` paths;
- the fresh replay totals;
- any remaining `unfinished`, `unchecked`, or `untried` obligations;
- any action required in an already-running Emacs/PVS session, such as forcing
  a typecheck or installing an externally changed proof file.
