#!/bin/sh
# Interactive PVS tutorial; all writable contexts are under src/sal.
set -eu
doc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
: "${PVS_BIN:?Set PVS_BIN to a working pvs executable}"
: "${SAL_HOME:?Set SAL_HOME to a working SAL installation}"
: "${SAL_XMLS_SOURCE:?Set SAL_XMLS_SOURCE to the existing xmls.lisp source}"
test -x "$PVS_BIN"
mkdir -p "$doc_dir/.demo" "$doc_dir/.build/tmp" "$doc_dir/.build/cache"
export SAL_DOC_DIR="$doc_dir/"
export TMPDIR="$doc_dir/.build/tmp"
export XDG_CACHE_HOME="$doc_dir/.build/cache"
export PVS_LOG_DIR="$doc_dir/.build"
export PVS_LIBRARY_PATH=''
export PVSPATH="$(CDPATH= cd -- "$(dirname -- "$PVS_BIN")" && pwd -P)/"
cd "$doc_dir/.demo"
exec "$PVS_BIN" -raw -q -E '(load (merge-pathnames "demo.lisp" (uiop:ensure-directory-pathname (uiop:getenv "SAL_DOC_DIR"))))'
