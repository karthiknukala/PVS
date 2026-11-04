# Reading PVS Sequents and Building Proofs

## Contents

1. Sequent semantics
2. Formula numbers and change markers
3. A diagnostic loop
4. Core command map
5. Common proof shapes
6. Robustness and failure diagnosis

## 1. Sequent semantics

PVS displays a proof goal as a sequent:

```text
{-1} A
[-2] B
  |-------
{1} C
[2] D
```

Read this as `(A AND B) IMPLIES (C OR D)`.

- Formulas above the line are **antecedents**: facts available to the proof.
- Formulas below the line are **consequents**: alternatives, any one of which
  is enough to close the branch.
- A branch closes when an antecedent matches a consequent, an antecedent is
  false, a consequent is true, or a sound decision procedure establishes the
  sequent.
- Every generated branch must close. “No current goal” is meaningful only
  when PVS prints Q.E.D.; `quit` and `postpone` can also remove the current
  prompt without proving it.

The side of a connective determines the useful rule:

| Shape | Typical action |
|---|---|
| Consequent `A IMPLIES B` | `flatten` moves `A` to the antecedents |
| Consequent `A AND B` | `split` creates a branch for each conjunct |
| Consequent `FORALL x: P(x)` | `skolem!` or `skosimp*` introduces arbitrary `x!1` |
| Consequent `EXISTS x: P(x)` | `inst` supplies a witness |
| Antecedent `A AND B` | `flatten` exposes both facts |
| Antecedent `A OR B` | `split` creates cases |
| Antecedent `FORALL x: P(x)` | `inst` specializes the hypothesis |
| Antecedent `EXISTS x: P(x)` | `skolem!` or `skosimp*` introduces a witness |

## 2. Formula numbers and change markers

- Negative numbers (`-1`, `-2`) select antecedents.
- Positive numbers (`1`, `2`) select consequents.
- `-` selects all antecedents, `+` all consequents, and `*` all formulas when
  a command accepts an `fnums` argument.
- Curly braces, such as `{-1}`, mark formulas new or changed since the parent
  goal.
- Square brackets, such as `[-1]`, mark formulas unchanged from the parent.
  Braces do not mean “selected,” “true,” or “proved.”

Prefer side selectors or labels when possible. Formula numbers shift after
flattening, deleting, copying, or introducing lemmas. When an exact number is
necessary, re-read the current sequent instead of relying on an earlier one.

Generated names such as `x!1` are scoped to the current proof state and may
change after small edits. Let `skosimp*` choose names when subsequent commands
do not need to mention them; otherwise give explicit names with `skolem`.

## 3. A diagnostic loop

After every non-closing step:

1. **Translate the sequent.** Say what the antecedents jointly assume and what
   the consequents ask for.
2. **Classify the obstruction.**
   - Boolean structure still hidden
   - universal variable not introduced
   - quantified hypothesis not instantiated
   - existential witness absent
   - definition or `IF` blocking normalization
   - subtype constraint missing
   - record/tuple/function equality not decomposed
   - arithmetic or congruence residue
   - lemma or induction hypothesis needed
   - statement apparently false
3. **Apply one exposing command.**
4. **Compare the new sequent.** Keep the step only if it makes the obstruction
   smaller or more explicit.
5. **Finish locally.** Use decision procedures after the relevant facts and
   structure are visible.

Do not respond to a stubborn goal by blindly adding definitions to `grind`.
An unchanged or more complicated residual sequent is evidence about what PVS
cannot infer.

## 4. Core command map

Use `(help command-name)` at the `Rule?` prompt for the installed PVS version.
Use `M-x help-pvs-prover` or `M-x x-prover-commands` for browsable help.

### Structure and navigation

| Command | Purpose |
|---|---|
| `(flatten)` | Simplify disjunctive structure: implications, useful conjunctions, and disjunctions according to sequent side |
| `(split)` | Split conjunctive obligations/cases into subgoals |
| `(prop)` / `(bddsimp)` | Propositional simplification |
| `(hide fnums)` / `(reveal fnums)` | Temporarily remove or restore distracting formulas |
| `(copy fnum)` | Duplicate a formula before destructive specialization |
| `(delete fnums)` | Remove formulas; use sparingly |
| `(undo)` | Return to an earlier proof state |
| `(postpone)` | Move to a sibling subgoal |
| `(quit)` | End the attempt, normally leaving an unfinished proof |

### Quantifiers

| Command | Purpose |
|---|---|
| `(skolem! ...)` | Introduce constants for universal consequents or existential antecedents, choosing fresh names |
| `(skosimp*)` | Repeatedly skolemize and simplify surrounding structure |
| `(inst fnum "term" ...)` | Specialize a universal antecedent or provide witnesses for an existential consequent |
| `(inst? fnum)` | Ask PVS to infer an instantiation |
| `(generalize "term")` | Replace a term with a quantified variable when a more general goal is useful |

If `inst` targets a hypothesis that will be needed more than once, copy it
first or use an instantiation variant that preserves it.

### Definitions, lemmas, and rewriting

| Command | Purpose |
|---|---|
| `(expand "name" fnums)` | Unfold a definition at selected formulas |
| `(expand* "a" "b")` | Expand several definitions |
| `(lemma "name" ...)` | Add a lemma instance to the sequent |
| `(use "name" ...)` | Introduce and simplify/instantiate a lemma |
| `(rewrite "name" fnums)` | Rewrite selected formulas using a lemma |
| `(forward-chain fnum)` | Derive consequences from an antecedent implication |

Expand the outermost blocking definition first. Large-scale unfolding often
hides the conceptual step and produces brittle proofs.

### Types and equality

| Command | Purpose |
|---|---|
| `(typepred "expr")` or `(typepred fnum)` | Make subtype constraints explicit |
| `(all-typepreds)` | Expose all relevant type predicates; can be noisy |
| `(replace fnum)` | Substitute using an equality |
| `(case-replace "lhs = rhs")` | Split on a proposed equality and replace in the equality branch |
| `(decompose-equality)` | Reduce structured equality to component equalities |
| `(extensionality)` | Reduce function/set equality to pointwise membership/equality |
| `(replace-eta)` / `(apply-eta)` | Normalize eta-equivalent functions |

For dependent records and tuples, equality may need a component-wise proof
plus an eta conversion. Re-read the generated component goals; their types can
depend on earlier fields.

### Automation

| Command | Purpose |
|---|---|
| `(assert)` | Normalize and use equality/arithmetic decision procedures |
| `(ground)` | Combine propositional simplification with decision procedures |
| `(grind)` | Skolemization, rewriting, simplification, and decision procedures |
| `(grind :defs ("d1" "d2"))` | Add selected definitions to `grind` |
| `(reduce)` / `(simplify)` | Controlled simplification variants |

Use automation as a probe and finisher. If `(grind)` leaves a goal, inspect
that goal before changing the strategy.

### Strategy control

| Form | Meaning |
|---|---|
| `(then s1 s2 ...)` | Apply steps sequentially to every subgoal produced |
| `(then@ s1 s2 ...)` | Continue only down the main/first branch |
| `(spread step (s1 s2 ...))` | Apply a distinct strategy to each generated subgoal |
| `(branch step (s1 ...))` | Like `spread`, reusing the last strategy for extra branches |
| `(try first success no-effect)` | Branch on whether a step changes the goal |
| `(repeat step)` / `(repeat* step)` | Repeat on one/all branches; avoid with steps that always report progress |

Use `spread!` during proof development when an exact branch count is an
important invariant.

## 5. Common proof shapes

### Introduce variables, unfold, decide

```lisp
(then
 (skosimp*)
 (expand "definition")
 (assert))
```

### Specialize a hypothesis

```lisp
(then
 (skosimp*)
 (inst -1 "x!1")
 (assert))
```

Verify `-1` is the intended universal antecedent in the current sequent.

### Supply an existential witness

```lisp
(then
 (skosimp*)
 (inst 1 "candidate")
 (grind))
```

### Split cases with branch-specific work

```lisp
(spread
 (case "condition")
 ((then (assert) (rewrite "lemma_true"))
  (then (assert) (rewrite "lemma_false"))))
```

### Prove structured equality

```lisp
(then
 (decompose-equality)
 (replace-eta)
 (assert))
```

Exact ordering depends on the type and the residual sequent.

### Expose a subtype TCC

```lisp
(then
 (typepred "x")
 (expand "subtype_predicate")
 (grind))
```

If the required predicate still has no derivation, audit the declaration:
the TCC may be exposing a real semantic gap.

## 6. Robustness and failure diagnosis

- Prefer named lemmas and explicit instantiations over coincidental formula
  ordering.
- Avoid relying on generated Skolem suffixes across unrelated branches.
- Keep semantic steps visible; let `assert` or `grind` handle only residue.
- A proof that succeeds only after unrelated hypotheses are present may be
  overspecified or accidentally dependent. Check the proof chain.
- An `unfinished` proof has a saved partial script but an open branch.
- An `unchecked` proof succeeded previously but changed source may invalidate
  it. Replay it.
- An `untried` formula has no attempt; a status line alone does not prove it.
- If a simple expected fact is absent, inspect type predicates, imported
  theory instances, actual parameters, and definition expansion before
  assuming the decision procedure is weak.
- If no command can bridge the remaining sequent, try to construct a concrete
  model of the antecedents with all consequents false. A counterexample or
  missing premise is a specification result, not a prover failure.


## Interactive diagnostic tools

When persistent agent tools are available, inspect the relevant local types,
hidden formulas, TCC origin, or enabled rewrites before repeating a failed
automation attempt. Native command help is authoritative. Active rewrite or
strategy tracing accompanies an explicit command and can change the proof;
cached state inspection does not. Retain a useful step, undo an unhelpful step,
or use an independent native attempt. Preserve final fresh replay.
