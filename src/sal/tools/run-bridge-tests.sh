#!/bin/sh
# All writable state is deliberately confined to this extension.
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
: "${PVS_BIN:=$bridge_dir/../../pvs}"
: "${SAL_HOME:?Set SAL_HOME to a working SAL installation}"
test -x "$PVS_BIN" || { echo "PVS_BIN is not executable: $PVS_BIN" >&2; exit 1; }
mkdir -p "$bridge_dir/.work/tmp" "$bridge_dir/.work/cache" "$bridge_dir/.work/tests"
export TMPDIR="$bridge_dir/.work/tmp"
export XDG_CACHE_HOME="$bridge_dir/.work/cache"
export PVS_LOG_DIR="$bridge_dir/.work"
export SAL_BRIDGE_DIR="$bridge_dir"
export SAL_BRIDGE_TEST_OUTPUT="$(mktemp -d "$bridge_dir/.work/tests/run.XXXXXX")/"
export PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
log="$bridge_dir/.work/tests/bridge-tests.log"
cd "$bridge_dir/.work/tests"
"$PVS_BIN" -raw -q -E '(load (merge-pathnames "tests/run.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))' \
  </dev/null >"$log" 2>&1
cat "$log"
if ! grep -q '^SAL-BRIDGE-TESTS-PASSED$' "$log"; then
  echo "Bridge validation failed; see $log" >&2
  exit 1
fi
replay_log="$bridge_dir/.work/tests/replay.log"
"$PVS_BIN" -raw -q -E '(load (merge-pathnames "tests/replay.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))' \
  </dev/null >"$replay_log" 2>&1
cat "$replay_log"
if ! grep -q '^SAL-BRIDGE-REPLAY-PASSED$' "$replay_log"; then
  echo "Fresh-process replay failed; see $replay_log" >&2
  exit 1
fi
