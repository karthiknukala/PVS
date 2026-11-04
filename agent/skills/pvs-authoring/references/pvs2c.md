# PVS2C-oriented authoring and diagnostics

## Contents

1. Semantic policy
2. C-friendly subset
3. Tests
4. Generation workflow
5. Known generator failures
6. Minimal reproducer method

## Semantic policy

Make the actual concrete theory executable. Never maintain a more abstract
“real” theory and a detached `*_PVS2C.pvs` kernel implementing different
semantics. Apply abstract properties to the executable theory through
interpretations.

A proof-only refinement may map the concrete theory into contracts and retain
uninterpreted codecs that are genuinely unfinished. It must not reimplement
the operational device/protocol behavior.

PVS2C-friendliness does not imply verified C:

- Typechecking only establishes well-formed PVS and emits TCCs.
- `_TEST_` declarations are executable checks, not proofs.
- Generation may succeed while generated compilation or tests fail.
- Production code generation should follow proofs of required TCCs/formulas
  and an explicit review of generated behavior.

## C-friendly subset

For runtime-facing definitions, prefer:

- `uint8`, `uint16`, `uint32`, and other bounded `integertypes`;
- `aseq[T]` from `array_sequences` for bounded-length storage;
- explicit limits in predicate subtypes;
- total recursive functions with well-founded measures;
- defensive branches before indexing, subtraction, addition, and conversion;
- bit masks or bounded sequences instead of mathematical sets for finite
  runtime flags;
- typed constants for byte/sequence fixtures; and
- explicit bounded division/remainder helpers whose domains exclude zero.

Audit concrete theories for accidental runtime use of:

```text
nat  posnat  integer  finite_sequence  set[...]  prelude mod
```

These constructs remain useful in proof-only abstractions. The concern is
their executable representation and current generator support, not their PVS
semantics.

Do not refactor overflow/index TCCs away. Either handle the condition in
control flow or retain it as an explicit precondition/obligation, according to
the source specification.

## Tests

Place source-derived tests adjacent to the operational definition:

```pvs
% Source: manual printed p. 3-9 (PDF p. 33), checksum example.
printed_checksum_test: _TEST_
  encode_checksum(checksum(example_frame)) = example_checksum
```

Use tests for:

- printed checksum/CRC vectors;
- exact framing bytes;
- documented default configurations;
- retry-limit transitions;
- counter and frame-number wrap;
- boundary acceptance/rejection;
- status-bit dependencies; and
- parser positive/negative examples.

Use typed fixtures or elementwise checks at representation boundaries. Avoid
assuming an unannotated literal is generated with the same C element type as a
typed byte sequence.

## Generation workflow

Only invoke generation when the user or project phase authorizes it:

```sh
~/git/PVS/pvs -raw -E '(pvs2c-theory "TheoryName" t)'
```

Before generation:

1. typecheck the actual theory and imports;
2. inspect retained TCCs and project policy;
3. confirm the target contains no known unsupported runtime construct;
4. start with a small leaf theory; and
5. preserve the exact command/output.

After generation, separately verify generated C compilation and `_TEST_`
execution using the emitted build instructions. Do not report code generation
as successful if only `.c` files appeared.

If the user says to stop after a crash, stop all PVS2C attempts. Continue only
with ordinary typechecking, source audit, and construction of a candidate
reproducer that does not itself invoke the generator.

## Known generator failures

These failures were observed in a specific PVS build. Recheck against the
current build before treating them as active, but do not rediscover them by
repeatedly invoking PVS2C after a stop condition.

### Formal theory parameter dispatch

Generation of a theory with a formal theory parameter may fail with:

```text
There is no applicable method for PVS::PVS2C-DECL*
... FORMAL-THEORY-DECL
```

Keep the parameterized semantic theory. Isolate a tiny signature and consumer
as the reproducer.

### Array-sequence dependency

Generation using `aseq[uint8]` may fail while pushing
`array_sequences_uint8`/`aseq_add`:

```text
There is no applicable method for PVS:MODULE
when called with (`length := a`length + 1).
```

A minimal candidate needs only a byte `aseq` alias and an identity function.

### Prelude `mod`

Generated tests may report `Non-executable theory: mod`. Use guarded bounded
remainder operations for nonnegative runtime arithmetic, while documenting the
intended modulo semantics.

### Sequence literal representation

A typed byte sequence and an unannotated literal can receive incompatible C
element representations. Prefer a typed fixture or compare lengths/elements.

### Empty character string coercion

Coercing `""` to a bounded `bytestring` can introduce a broken
`finite_sequences_character` dependency. Prefer an explicitly typed empty
array sequence at runtime boundaries.

### Cross-library generated headers

PVS2C may emit dependency C/header files under one library while the consumer
make fragment expects them in its local generated directory. Treat file
staging/include-path changes as harness workarounds, not semantic fixes.

## Minimal reproducer method

For a suspected PVS2C bug:

1. Copy only the smallest failing declarations into a standalone folder.
2. Give theories and files unique names.
3. Confirm ordinary `tc` succeeds.
4. Run the exact failing `pvs2c-theory` command only if still authorized.
5. Separate generation, C compilation, and test-run failures.
6. Preserve the smallest error text sufficient to identify dispatch/type
   mismatch.
7. Document environment/library paths and any generated-file workaround.
8. Never change the main semantics merely to make the reproducer pass.
