#!/bin/sh
# Native PVS extraction, trusted proof strategies, and saved-proof replay.
# All generated contexts, checker transcripts, and caches stay under src/sal.
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
: "${PVS_BIN:=$bridge_dir/../../pvs}"
: "${SAL_HOME:?Set SAL_HOME to a working SAL installation}"
test -x "$PVS_BIN" || { echo "PVS_BIN is not executable: $PVS_BIN" >&2; exit 1; }
mkdir -p "$bridge_dir/.work/tmp" "$bridge_dir/.work/cache" "$bridge_dir/.work/reverse"
export TMPDIR="$bridge_dir/.work/tmp"
export XDG_CACHE_HOME="$bridge_dir/.work/cache"
export PVS_LOG_DIR="$bridge_dir/.work"
export SAL_BRIDGE_DIR="$bridge_dir"
export SAL_BRIDGE_TEST_OUTPUT="$(mktemp -d "$bridge_dir/.work/reverse/run.XXXXXX")/"
export PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
cd "$SAL_BRIDGE_TEST_OUTPUT"
log="$SAL_BRIDGE_TEST_OUTPUT/pvs.log"
"$PVS_BIN" -raw -q -E '(progn (load (merge-pathnames "tests/reverse.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR")))) (format t "~&SAL-REVERSE-PROCESS-COMPLETE~%"))' \
  </dev/null >"$log" 2>&1
cat "$log"
if ! grep -q '^SAL-REVERSE-TESTS-PASSED$' "$log" ||
   ! grep -q '^SAL-REVERSE-PROCESS-COMPLETE$' "$log"; then
  echo "Native PVS extraction tests failed; see $log" >&2
  exit 1
fi
replay_log="$SAL_BRIDGE_TEST_OUTPUT/replay.log"
"$PVS_BIN" -raw -q -E '(progn (load (merge-pathnames "tests/reverse-replay.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR")))) (format t "~&SAL-REVERSE-REPLAY-PROCESS-COMPLETE~%"))' \
  </dev/null >"$replay_log" 2>&1
cat "$replay_log"
if ! grep -q '^SAL-REVERSE-REPLAY-PASSED$' "$replay_log" ||
   ! grep -q '^SAL-REVERSE-REPLAY-PROCESS-COMPLETE$' "$replay_log"; then
  echo "Native PVS model-checker proof replay failed; see $replay_log" >&2
  exit 1
fi
