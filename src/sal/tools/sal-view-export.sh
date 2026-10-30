#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: sal-view-export.sh INPUT MODULE [QUALIFIED-SELECTOR], or INPUT --context/--source/--manifest [QUALIFIED-SELECTOR]" >&2
  exit 2
fi
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [[ -z ${SAL_HOME:-} || ! -x "$SAL_HOME/bin/salenv" ]]; then
  echo "Set SAL_HOME to a SAL installation containing bin/salenv." >&2
  exit 2
fi
input_dir=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)
input_file="$input_dir/$(basename -- "$1")"
exec "$SAL_HOME/bin/salenv" "$script_dir/sal-view-export.scm" "$input_file" "${@:2}"
