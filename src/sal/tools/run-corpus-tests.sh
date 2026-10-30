#!/bin/sh
# Native inventory + exhaustive frontend typechecking; all output stays here.
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
: "${PVS_BIN:=$bridge_dir/../../pvs}"
: "${SAL_HOME:?Set SAL_HOME to an existing SAL installation}"
: "${SAL_CORPUS_ROOT:=$SAL_HOME/examples}"
mkdir -p "$bridge_dir/.work/corpus/tmp" "$bridge_dir/.work/cache"
if [ "${1:-}" = "--resume" ]; then
  test "$#" -ge 2 || { echo "--resume requires a previous run directory" >&2; exit 2; }
  export SAL_CORPUS_OUTPUT="$2/"
  shift 2
  resume=yes
else
  export SAL_CORPUS_OUTPUT="$(mktemp -d "$bridge_dir/.work/corpus/run.XXXXXX")/"
  resume=no
fi
export SAL_CORPUS_ROOT
export SAL_BRIDGE_DIR="$bridge_dir"
export TMPDIR="$bridge_dir/.work/corpus/tmp"
export XDG_CACHE_HOME="$bridge_dir/.work/cache"
export PVS_LOG_DIR="$bridge_dir/.work"
export PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
export PVS_BIN
if [ "$resume" = no ]; then
  python3 "$bridge_dir/tools/run-corpus-inventory.py" --root "$SAL_CORPUS_ROOT" \
    --output "$SAL_CORPUS_OUTPUT/native"
  python3 "$bridge_dir/tools/run-corpus-cases.py" "$SAL_CORPUS_OUTPUT/native/manifest.json" \
    "$SAL_CORPUS_OUTPUT/cases.lisp" "$@"
elif [ "$#" -ne 0 ]; then
  echo "--resume accepts only a run directory; use SAL_CORPUS_RETRY_ERRORS=1 to retry failures" >&2
  exit 2
fi
if [ "${SAL_CORPUS_RETRY_ERRORS:-0}" = 1 ]; then
  set -- --retry-errors
else
  set --
fi
python3 "$bridge_dir/tools/run-corpus-driver.py" "$SAL_CORPUS_OUTPUT" \
  --batch-size "${SAL_CORPUS_BATCH_SIZE:-12}" --timeout "${SAL_CORPUS_BATCH_TIMEOUT:-600}" "$@"
