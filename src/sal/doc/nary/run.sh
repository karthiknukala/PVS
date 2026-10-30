#!/bin/sh
# Generate, prove, and freshly replay the worked composition example.
set -eu
doc_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
mkdir -p "$doc_dir/.demo" "$doc_dir/.build"
export SAL_NARY_OUTPUT="$(mktemp -d "$doc_dir/.demo/nary-run.XXXXXX")/"
for phase in prove replay; do
  export SAL_NARY_PHASE="$phase"
  log="$doc_dir/.build/nary-$phase.log"
  "$doc_dir/run-demo.sh" >"$log" 2>&1 <<'LISP'
(load (merge-pathnames "nary/demo.lisp" *sal-doc-directory*))
(uiop:quit)
LISP
  if [ "$phase" = prove ]; then marker=SAL-NARY-DEMO-PASSED; else marker=SAL-NARY-REPLAY-PASSED; fi
  if ! grep -q "^$marker$" "$log"; then
    cat "$log" >&2
    exit 1
  fi
  echo "$marker: $log"
done
echo "Saved proofs and contexts: $SAL_NARY_OUTPUT"
