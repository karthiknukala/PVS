#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") INPUT.sal [OUTPUT [CONTEXT-DIR ...]]" >&2
  exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
input_file=$1
output_file=${2:--}
if [[ $# -gt 1 ]]; then shift 2; else shift; fi

exec "$script_dir/sal-transform.sh" preprocess "$input_file" "" sal \
  "$output_file" "$@"
