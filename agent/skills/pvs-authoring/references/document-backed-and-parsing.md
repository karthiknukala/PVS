# Document-backed specifications and parsing

## Contents

1. Evidence workflow
2. Citation rules
3. Coverage and status audits
4. Parser architecture
5. Connecting parsers to device models

## Evidence workflow

Before formalizing a manual or standard:

1. Inventory documents, editions, printed page labels, and PDF page indexes.
2. Identify transport, framing, messages, configuration tables, state
   machines, timing, errors, retries, checksums, examples, and stated limits.
3. Build a requirement-to-theory map before choosing declarations.
4. Separate facts stated by the source from framework generalizations,
   conventional encodings, and engineering assumptions.
5. Model omissions as gaps; do not infer a checksum polynomial, field
   semantics, or interoperability rule merely because one is conventional.

If precise page evidence requires reading a PDF, inspect both extracted text
and rendered pages. Tables, subscripts, control characters, and page labels
often extract incorrectly.

## Citation rules

Put a source comment immediately above each declaration or group that it
supports:

```pvs
% Source: manual printed p. 2-14 (PDF p. 38): checksum covers ...
checksum(bytes: PacketBytes): uint8 = ...
```

Include:

- document/edition when multiple manuals are in scope;
- printed page and PDF page when they differ;
- section/table/figure when helpful; and
- an explicit “framework generalization” or “assumption” label when the
  declaration is not directly stated.

Cite types, constants, transitions, configuration values, validation
predicates, tests, and semantic interpretations. A file-level bibliography is
not enough to trace individual elements.

Do not cite an external standard as if the vendor manual supplied its full
contents. A statement that a device supports “ASTM” does not provide the
entire ASTM transport/application specification or guarantee arbitrary ASTM
host interoperability.

Use synthetic fixtures rather than clinical/patient data unless the source
explicitly provides a safe published example.

## Coverage and status audits

For every document-backed folder, maintain a status Markdown file covering:

- document inventory and edition ambiguity;
- theory-by-theory scope;
- implemented requirements and citations;
- intentionally uninterpreted hooks;
- assumptions and framework generalizations;
- message/field/workflow coverage gaps;
- parser/serializer and malformed-input status;
- timing, concurrency, retry, and error-model gaps;
- theory interpretation/concordance status;
- exact typecheck and TCC counts;
- `_TEST_` coverage;
- PVS2C status and generator failures;
- assurance limitations; and
- prioritized next work.

Use precise terms:

- `modeled`: represented in the theory;
- `operational`: defined by executable PVS functions/transitions;
- `hook`: deliberately uninterpreted;
- `obligation`: TCC/theorem exists but is unproved;
- `tested`: a `_TEST_` fixture exists;
- `proved`: proof is recorded; and
- `interoperable`: reserve for a justified end-to-end wire claim.

Audit not only omissions but overclaims: values accepted too broadly, abstract
message unions that erase profile restrictions, aggregate counters replacing
transaction identity, and adapters that discard framing/session/reassembly.

## Parser architecture

For LTEDPEG-based wire formats, use three layers:

1. `*_Grammar.pvs`: token DPEGs, LTEDPEG production table, and a recognized
   syntax subtype.
2. `*_AST.pvs`: deserialization plus semantic constraints such as lengths,
   delimiters, checksums, and field relationships.
3. `*_Parser.pvs`: interpretation of a generic parser contract, generating
   source-preservation and validity TCCs.

Useful utilities include:

- complete-input recognition rather than prefix-only success;
- bounded byte slicing;
- safe hexadecimal/numeric decoding;
- typed empty and singleton sequences;
- explicit AST source retention; and
- dependent fields tied to recognized source bytes.

Keep grammar acceptance separate from semantic validation. A frame can match
the byte grammar yet fail checksum, field-range, profile, or workflow
admissibility.

Place positive and negative `_TEST_` declarations beside grammar/parser
definitions, with source citations for document examples and clear labels for
synthetic boundary cases.

## Connecting parsers to device models

Do not directly identify a single-frame parser with a high-level device codec
when intermediate stages exist. Preserve the full pipeline:

```text
raw bytes
  -> frame grammar/AST
  -> link/session validation
  -> fragmentation or reassembly
  -> application message grammar/AST
  -> profile/field deserialization
  -> concrete device input
```

Interpret the abstract parse function only at the boundary actually
implemented. State source-preservation, round-trip/canonicalization,
malformed-input rejection, and intermediate invariants as explicit
obligations.

For context-sensitive byte languages, model parser state or grammar position.
The same octet may denote a label, command, control, or data value; a global
octet-to-symbol function can be unsound.
