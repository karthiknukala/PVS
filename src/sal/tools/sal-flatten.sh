#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") INPUT.sal [DECLARATION [OUTPUT]] [CONTEXT-DIR ...]" >&2
  exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
input_file=$1
declaration=${2-}
output_file=${3:--}
if [[ $# -gt 2 ]]; then shift 3
elif [[ $# -gt 1 ]]; then shift 2
else shift
fi

exec "$script_dir/sal-transform.sh" flatten "$input_file" "$declaration" \
  lsal "$output_file" "$@"
