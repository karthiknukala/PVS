#!/bin/sh
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
: "${PVS_BIN:=$HOME/git/PVS/pvs}"
: "${SAL_HOME:?Set SAL_HOME}"
: "${SAL_XMLS_SOURCE:?Set SAL_XMLS_SOURCE}"
mkdir -p "$bridge_dir/.work/tests" "$bridge_dir/.work/tmp" "$bridge_dir/.work/cache"
export SAL_BRIDGE_DIR="$bridge_dir/"
export SAL_BRIDGE_TEST_OUTPUT="$(mktemp -d "$bridge_dir/.work/tests/editor.XXXXXX")/"
export TMPDIR="$bridge_dir/.work/tmp" XDG_CACHE_HOME="$bridge_dir/.work/cache"
export PVS_LOG_DIR="$bridge_dir/.work" PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
cd "$SAL_BRIDGE_TEST_OUTPUT"
for phase in prove replay; do
  export SAL_EDITOR_PHASE="$phase"
  "$PVS_BIN" -raw -q -E '(load (merge-pathnames "tests/editor.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_BRIDGE_DIR"))))' \
    </dev/null >"$phase.log" 2>&1 || { tail -n 100 "$phase.log"; exit 1; }
  rg -a '^SAL-EDITOR-(TESTS|REPLAY)-PASSED' "$phase.log"
done
echo "Evidence: $SAL_BRIDGE_TEST_OUTPUT"
