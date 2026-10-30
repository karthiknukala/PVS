#!/bin/sh
# Isolated interactive demo; leave the user's PVS/NASALib setup untouched.
set -eu
bridge_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
pvs_root=$(CDPATH= cd -- "$bridge_dir/../.." && pwd -P)
: "${PVS_BIN:=$pvs_root/pvs}"
: "${SAL_HOME:=$pvs_root/../kn-sal}"
: "${SAL_XMLS_SOURCE:?Set SAL_XMLS_SOURCE to the existing xmls.lisp file}"
test -x "$PVS_BIN" || { echo "PVS_BIN is not executable: $PVS_BIN" >&2; exit 1; }
test -x "$SAL_HOME/bin/sal-wfc" || { echo "Missing sal-wfc under SAL_HOME: $SAL_HOME" >&2; exit 1; }
test -f "$SAL_XMLS_SOURCE" || { echo "XMLS source not found: $SAL_XMLS_SOURCE" >&2; exit 1; }
mkdir -p "$bridge_dir/.work/editor-session" "$bridge_dir/.work/tmp" "$bridge_dir/.work/cache"
export SAL_HOME SAL_XMLS_SOURCE
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
export PVS_LIBRARY_PATH='' PVS_LOG_DIR="$bridge_dir/.work"
export TMPDIR="$bridge_dir/.work/tmp" XDG_CACHE_HOME="$bridge_dir/.work/cache"
# Do not inherit a different PVS image or pending startup evaluations.
unset PVSIMAGE PVSEVALLOAD PVSNONINTERACTIVE PVSPORT
cd "$bridge_dir/.work/editor-session"
exec "$PVS_BIN" -q -nobg -L "$bridge_dir/load.lisp" \
  -l "$bridge_dir/emacs/sal-pvs-demo.el" "$@"
