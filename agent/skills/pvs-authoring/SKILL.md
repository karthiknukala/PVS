---
name: pvs-authoring
description: Author, refactor, audit, and validate PVS specifications and libraries, including predicate and dependent types, theory parameters and interpretations, mapped-axiom TCCs, document-traceable requirements, executable tests, parser specifications, modular cyber-physical integrations, and PVS2C-oriented operational models. Use for `.pvs` theory work, PVS library/path failures, TCC inspection or proof planning, formalization from manuals or standards, abstract-to-concrete refinement, parser/serializer modeling, PVS2C preparation and generator bug reduction, or reviews of whether a PVS development makes justified assurance claims.
---

# PVS authoring

Build one coherent semantic development: document-backed operational theories,
abstract contracts imposed by interpretation, visible proof obligations, and
validation evidence proportionate to the requested phase.

## Route the task

1. Identify whether the request is to author, refactor, diagnose, audit, prove,
   generate C, or only explain.
2. Inspect repository instructions, nearby theories, library layout, manuals,
   status files, and existing uncommitted work.
3. Read only the references needed:
   - For PVS types, modules, theory parameters, interpretations, or composition,
     read [references/modeling-and-interpretations.md](references/modeling-and-interpretations.md).
   - For typechecking, TCCs, library paths, or PVS process behavior, read
     [references/tcc-and-validation.md](references/tcc-and-validation.md).
   - For executable specifications, `_TEST_`, or PVS2C, read
     [references/pvs2c.md](references/pvs2c.md).
   - For specifications derived from manuals, audits, or LTEDPEG parsers, read
     [references/document-backed-and-parsing.md](references/document-backed-and-parsing.md).
4. State the intended semantic boundary before editing: which theory owns
   operational behavior, which contract owns each property, and which
   interpretation must expose concordance obligations.
5. Implement, typecheck serially, inspect TCCs, and report precisely what was
   and was not established.

## Preserve one semantic basis

Put executable definitions, defensive control flow, invariants, and tests in
the actual concrete theory. Do not create a second `*_PVS2C.pvs` implementation
or otherwise detach generated code from the semantics being verified.

Use a `*_Refinement.pvs` overlay only to:

- interpret abstract device, protocol, bus, timing, safety, or composition
  contracts;
- adapt concrete names and carriers to contract signatures; and
- retain mapped-axiom TCCs that state concordance.

Do not duplicate checksums, parsers, transitions, retry behavior, or other
operational algorithms in the overlay.

Write each requirement at the lowest layer that owns its meaning:

- field shapes and bounds in types;
- codec laws and wire validity in protocols or format parsers;
- delivery, ordering, and timing in bus contracts;
- admissibility and safety in device contracts;
- adapters at cross-layer integration boundaries; and
- environment assumptions and global invariants in composition theories.

## Model aggressively but operationally

Prefer predicate subtypes and dependent records that make malformed states
uninhabitable. Use dependent function domains to make indexes, lengths,
configuration choices, and state transitions explicit. Retain the generated
TCCs as design feedback.

For runtime-facing theories, prefer fixed-width integer types, bounded
`aseq[T]` values, total functions, explicit overflow/underflow branches, and
structural finite storage. Keep mathematical `nat`, `integer`, `set`, and
`finite_sequence` in proof-only layers unless generation support has been
verified and their runtime representation is intentional.

Avoid filling documentation gaps with plausible behavior. Represent a missing
CRC, codec, timing rule, or workflow as a named hook or explicit gap, then
generate an obligation at the appropriate interpretation boundary.

## Treat TCCs as specification output

Typechecking establishes well-formedness and emits obligations; it does not
prove the device safe, the codec correct, or the integration conformant.

- Run `tc` before `show-tccs`.
- Inspect subtype, termination, existence, and mapped-axiom TCCs.
- Do not weaken types, add axioms, or refactor obligations away merely to
  reduce their count.
- Do not prove TCCs or named formulas unless the user requests the proof phase.
- Distinguish unproved, trivial, subsumed, and proved counts in reports.
- Treat named `THEOREM`/`LEMMA` declarations separately from PVS's TCC count.

Use [scripts/pvs-theory](scripts/pvs-theory) for serial `tc`, `show-tccs`, or
both when its simple interface fits. Always inspect the complete PVS output;
do not infer success from the process exit code alone.

## Validate in layers

1. Typecheck directly edited leaf theories.
2. Typecheck importing umbrella theories.
3. Typecheck refinement and composition theories with the correct
   `PVS_LIBRARY_PATH`.
4. Run `show-tccs` and preserve obligations.
5. Run source scans for forbidden runtime constructs, stale companion paths,
   missing citations, or unintended uninterpreted hooks.
6. Run the repository's whitespace/diff checks.
7. Invoke PVS2C only when authorized and only after reading
   [references/pvs2c.md](references/pvs2c.md).

Run independent PVS processes serially within a writable library context.
Concurrent invocations can race on `.pvscontext` and create misleading EOF or
dependency failures. This differs from tested native proof/evaluator threads
inside one prepared agent worker, which the extension coordinates. Prepare and
typecheck before opening those sessions. Source edits require ending affected
sessions and preparing/reopening the context; live declaration updates and
retypechecking changed source underneath proofs are outside the agent workflow.

## Report assurance honestly

Lead with the achieved state, then state:

- theories changed and semantic ownership;
- typecheck results and retained TCC classes/counts;
- tests added and their provenance;
- unresolved hooks, assumptions, and document gaps;
- whether proofs were attempted;
- whether PVS2C was attempted and whether usable C was actually produced; and
- minimal reproducers for tool failures.

Never equate “typechecks,” “PVS2C emitted files,” or “tests are declared” with
a completed proof or production-ready interoperability claim.
