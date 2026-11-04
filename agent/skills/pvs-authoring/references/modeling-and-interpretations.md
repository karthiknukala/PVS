# Modeling and theory interpretations

## Contents

1. Type design
2. Operational theory layering
3. Theory parameters
4. Theory interpretations
5. Known interpretation hazards
6. Integration and composition

## Type design

Use PVS's type system to encode latent requirements at the declaration site.

```pvs
Octet: TYPE = uint8
FrameNumber: TYPE = {n: uint8 | n <= 7}
NonemptyBytes: TYPE = {xs: aseq[Octet] | length(xs) > 0}

Frame: TYPE =
  [# number: FrameNumber,
     payload: {xs: NonemptyBytes | length(xs) <= 240},
     checksum: uint8 #]
```

Prefer:

- predicate subtypes for ranges, admissibility, and semantic classifications;
- dependent record fields when a later field is constrained by an earlier one;
- dependent function domains such as `below(length(xs))` for safe indexing;
- datatypes for protocol phases, events, alternatives, and disjoint message
  classes;
- record predicates for cross-field invariants that are awkward in field
  dependencies; and
- total transition functions whose rejected-input behavior is explicit.

Do not hide an invariant only in prose or a theorem if it can make an invalid
constructor ill-typed. Conversely, do not force temporal or relational
properties into a local subtype when they belong in a transition or contract.

## Operational theory layering

A document-backed product generally needs:

1. types and constants;
2. framing/messages and operational functions;
3. workflow/state transitions;
4. a product umbrella; and
5. a proof-only refinement that interprets reusable contracts.

Keep algorithms in layers 1–4. The refinement may contain thin adapters and
uninterpreted hooks for genuinely unfinished boundaries, but must not become a
second executable model.

Separate control and data planes without changing a sufficiently abstract
interface by giving the concrete state dependent control/data components and
mapping their externally visible transition, message, and safety behavior into
the unchanged contract. Add a new abstract contract only when the split itself
has properties that existing state/input/output or protocol/bus contracts
cannot express.

## Theory parameters

Use type/value parameters for small signatures:

```pvs
BoundedQueue[T: TYPE, capacity: posnat]: THEORY
BEGIN
  Queue: TYPE = {q: aseq[T] | length(q) <= capacity}
END BoundedQueue
```

Use a formal theory parameter when the implementation depends on a coherent
family of types and operations:

```pvs
Serial[L: THEORY protocols@Protocol_Language]: THEORY
BEGIN
  Symbol: TYPE = L.Label
  code(x: Symbol): uint8 = L.label_code(x)
END Serial
```

Formal theory parameters are powerful for language-dependent transports and
orthogonal device/bus capabilities, but current PVS2C versions may fail on
`FORMAL-THEORY-DECL`. Preserve the parameterized semantic theory and report
the generator defect; do not clone it into a hand-specialized implementation
unless the user explicitly chooses that tradeoff.

## Theory interpretations

Interpret an abstract contract by mapping each uninterpreted declaration:

```pvs
My_Device: THEORY = classes@Device_Contract{{
  DState := ConcreteState,
  DInput := ConcreteInput,
  DOutput := ConcreteOutput,
  initial_state := concrete_initial,
  transition(s: ConcreteState, i: ConcreteInput) := concrete_step(s, i),
  device_output(s: ConcreteState, i: ConcreteInput) := concrete_emit(s, i),
  safe_state?(s: ConcreteState) := concrete_safe?(s),
  admissible_input?(s: ConcreteState, i: ConcreteInput) :=
    concrete_admissible?(s, i)
}}
```

Abstract axioms become mapped-axiom TCCs. That is the point of the
interpretation: it converts generic requirements into concrete proof
obligations.

Use qualified library targets at mapping sites. Keep mappings close to the
concrete model, give them stable names, and adapt concrete definitions with
small typed functions when direct mapping causes elaboration ambiguity.

Only declarations owned and uninterpreted by the target theory can be mapped.
Aliases inherited through `IMPORTING` are not mapping slots. If public
signatures must be mapped across libraries, define a small facade theory that
owns the signature rather than attempting to map imported aliases.

## Known interpretation hazards

Treat these as version-sensitive diagnostics, not language laws:

- Directory basenames are PVS library names. Two directories named `classes`
  collide as `classes@`; expose uniquely located facade theories when needed.
- Explicitly importing an interpretation target and then qualifying the same
  target in a mapping can produce “bound variable ... outside of context” in
  some builds. Remove the redundant import and retain the qualified target.
- Immediately passing a locally interpreted theory as a formal theory actual
  to a refinement in another library can trigger internal assertions. A flat
  facade or local statement of the intended obligations can preserve the
  verification boundary.
- Deeply parameterized mapped declarations, especially dependent roster
  carriers, can trip typechecker failures. Flatten the interpretation
  boundary: map the product once into a uniform contract, then export an
  ordinary value for heterogeneous storage.
- Theories are modules, not first-class runtime values. Normalize heterogeneous
  components through an interpretation and store a common `ComponentSpec`-like
  record.

When a typechecker failure appears to be a tool bug:

1. Preserve the meaningful source theory.
2. Remove unrelated declarations until the failure remains.
3. Put the minimal reproducer in a separate folder.
4. Record the exact PVS command, version/build if known, and full error.
5. Clearly label any reformulation as a workaround and verify it generates the
   same intended TCC class.

## Integration and composition

Treat device classes, protocol classes, and bus properties as orthogonal
contracts:

- Device: state, input, output, admissibility, safe transition.
- Protocol: message/wire validity, encode/decode, canonicalization.
- Bus: endpoints, frames, send/deliver, pending/delivered, connectivity.
- Optional capabilities: real-time, input-sensitive, asynchronous,
  closed-loop, reliable, correlated, pub/sub, multi-rate.
- Cross-layer adapters: protocol-over-bus framing, command/telemetry mapping,
  discovery and compatibility.
- Composition: local transition relation, expected environment, ownership,
  capacity, local/global invariants, environment discharge.

For multiple plugins on one physical fabric, represent the shared bus once.
Map device ports into that fabric and state sender/receiver compatibility,
protocol coherence, ownership, capacity, timing, and interference constraints.
Do not duplicate a shared bus as private state inside every component.

Use lazy/open composition to preserve each component's assumptions, then
close the system only after peers or the environment discharge them. A closed
system claim requires more than a roster typecheck: it needs environment
elimination and global invariant/refinement obligations.
