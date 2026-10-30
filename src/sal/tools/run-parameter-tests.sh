#!/bin/sh
# Parameter and dependency regressions; no files are written outside src/sal.
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
: "${PVS_BIN:=$bridge_dir/../../pvs}"
: "${SAL_HOME:?Set SAL_HOME to a working SAL installation}"
test -x "$PVS_BIN" || { echo "PVS_BIN is not executable: $PVS_BIN" >&2; exit 1; }
mkdir -p "$bridge_dir/.work/tmp" "$bridge_dir/.work/cache" "$bridge_dir/.work/parameters"
export TMPDIR="$bridge_dir/.work/tmp"
export XDG_CACHE_HOME="$bridge_dir/.work/cache"
export PVS_LOG_DIR="$bridge_dir/.work"
export SAL_BRIDGE_DIR="$bridge_dir"
export SAL_BRIDGE_TEST_OUTPUT="$(mktemp -d "$bridge_dir/.work/parameters/run.XXXXXX")/"
export PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
log="$SAL_BRIDGE_TEST_OUTPUT/pvs.log"
cd "$SAL_BRIDGE_TEST_OUTPUT"
"$PVS_BIN" -raw -q -E '(load (merge-pathnames "tests/parameters.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))' \
  </dev/null >"$log" 2>&1
cat "$log"
if ! grep -q '^SAL-PARAMETER-TESTS-PASSED$' "$log"; then
  echo "Parameter validation failed; see $log" >&2
  exit 1
fi
replay_log="$SAL_BRIDGE_TEST_OUTPUT/replay.log"
"$PVS_BIN" -raw -q -E '(load (merge-pathnames "tests/parameters-replay.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))' \
  </dev/null >"$replay_log" 2>&1
cat "$replay_log"
if ! grep -q '^SAL-PARAMETER-REPLAY-PASSED$' "$replay_log"; then
  echo "Parameter proof replay failed; see $replay_log" >&2
  exit 1
fi
