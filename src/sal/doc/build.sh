#!/bin/sh
# Export through built-in Org Beamer with the actual PVS/SAL font-lock modes.
set -eu
doc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
pvs_dir=$(CDPATH= cd -- "$doc_dir/../../.." && pwd -P)
: "${EMACS:=emacs}"
: "${PVS_EMACS_DIR:=$pvs_dir/emacs}"
: "${SAL_EMACS_DIR:=$pvs_dir/../kn-sal/etc}"
export PVS_EMACS_DIR SAL_EMACS_DIR
mkdir -p "$doc_dir/.build/tmp" "$doc_dir/.build/cache"
export TMPDIR="$doc_dir/.build/tmp"
export XDG_CACHE_HOME="$doc_dir/.build/cache"
cd "$doc_dir"
"$EMACS" -Q --batch -l "$doc_dir/export.el" >"$doc_dir/.build/export.log" 2>&1 || {
  cat "$doc_dir/.build/export.log" >&2
  exit 1
}
if ! grep -q 'SAL-PVS-SLIDES-EXPORTED:' "$doc_dir/.build/export.log"; then
  cat "$doc_dir/.build/export.log" >&2
  exit 1
fi
echo "Exported $doc_dir/sal-pvs-tutorial.pdf"
