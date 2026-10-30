#!/bin/sh
# Prove from source, then replay the saved proofs in a second fresh context.
set -eu
semantics_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
doc_dir=$(CDPATH= cd -- "$semantics_dir/.." && pwd -P)
mkdir -p "$doc_dir/.demo"
for phase in prove replay; do
  SAL_TYPING_CORE_OUTPUT=$(mktemp -d "$doc_dir/.demo/semantics-core.$phase.XXXXXX")
  SAL_TYPING_CORE_PHASE=$phase
  export SAL_TYPING_CORE_OUTPUT SAL_TYPING_CORE_PHASE
  "$doc_dir/run-demo.sh" >"$semantics_dir/typing-core-$phase.log" 2>&1 <<'LISP'
(load (merge-pathnames "semantics/typing-core-driver.lisp" *sal-doc-directory*))
(uiop:quit)
LISP
  case "$phase" in
    prove) marker=SAL-TYPING-CORE-PROVE-PASSED ;;
    replay) marker=SAL-TYPING-CORE-REPLAY-PASSED ;;
  esac
  if ! rg -q "$marker" "$semantics_dir/typing-core-$phase.log"; then
    cat "$semantics_dir/typing-core-$phase.log"
    exit 1
  fi
  printf '%s: %s\n' "$phase" "$SAL_TYPING_CORE_OUTPUT"
done
