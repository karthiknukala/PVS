# Ranked patch series

Apply the numbered core patches in filename order starting at `e185d56e`. Together they reproduce `../pvs-core.patch`. From the root of a clean checkout, use `git apply /absolute/path/to/series/[0-9]*.patch`. The current kn-pvs working tree already contains these changes.

Each patch includes its workload and recorded before/after measurements. They come from the original experiments and are not additive or a benchmark of every intermediate build. Rank 17 is an optional patch for an existing MCP extension and is outside the core series. The separate transcript journal change was also outside the combined core patch.

| Patch | Workload or change | Before → after |
|---|---|---|
| [01](01-sparse-lexer.patch) | Sparse Unicode lexer tables, CHERI cold `top64` | 110.51 → 43.49 s |
| [02](02-ast-walk-tables.patch) | Scope the `mapobject` visited table to each AST walk, after the lexer change | 43.49 → 18.19 s |
| [03](03-strategy-evaluation.patch) | Interpret short-lived Lisp strategy forms, five CHERI register proofs | 42.15 → 17.37 s |
| [04](04-theory-discovery.patch) | Filter theory-discovery candidates before parsing, SMT term-manager stage | 14.70 → 0.73 s |
| [05](05-library-directories.patch) | Reuse the canonical prelude directory and stop at the first eligible source when discovering libraries, NASALib `orders/top` | 41.07 → 32.63 s |
| [06](06-prelude-save.patch) | Check for prelude objects before filesystem identity queries, forced save of 39 CHERI theories | 6.05 → 1.76 s |
| [07](07-datatype-identities.patch) | Defer parsing identity maps until a generated datatype term uses them, CHERI cold `top64` | 46.58 → 42.41 s |
| [08](08-restore-active-path.patch) | Track objects on the active binary-restore path by identity, cached CHERI load | 6.37 → 3.37 s |
| [09](09-cross-references.patch) | Use bounded identity tables for large cross-reference walks, in-process CHERI rebuild | 2.68 → 0.74 s |
| [10](10-bulk-reader.patch) | Read binary words in bulk on SBCL, cached CHERI load | 7.62 → 6.59 s |
| [11](11-proof-private-cache.patch) | Start proofs with an empty private substitution cache, seven Inference Systems proofs | 1.46 → 0.92 s |
| [12](12-hash-table-sizing.patch) | Pre-size copies of linked hash tables, VSTTE12 `top` | 818 → 789 ms |
| [13](13-startup.patch) | Lazy ASDF registry setup, one prelude path resolution, and less launcher overhead, raw startup | 165 → 145 ms |
| [14](14-prelude-judgements.patch) | Skip library lookup for known prelude theories during judgement instantiation, VSTTE12 `top` | 574 → 555 ms |
| [15](15-shostak-symbols.patch) | Compare Shostak symbol names directly, full 64-variable proof | 420 → 406 ms |
| [16](16-pvsio-attachments.patch) | Resolve each PVSio attachment theory once per purge, warm evaluator reopen and check | 15.2 → 4.2 ms |
| [17](optional/17-worker-fingerprints.patch) | Hash MCP sources in chunks using a reusable buffer and deduplicate physical files, CHERI | 7.7 → 4.2 ms per validation |
| [18](18-linear-list-reader.patch) | Fill decoded lists in one pass | 57.7 → 3.54 ms |
| [19](19-identifier-interning.patch) | Avoid interning uppercase identifiers | 6,000 → 0 extra symbols |
| [20](20-fetch-buffer-cleanup.patch) | Release stale fetch references and recreate discarded buffers | About 1 MB less retained after GC |
| [21](21-workspace-recovery.patch) | Initialize library paths before workspace restoration and invalidate missing dependencies | No independent timing |
