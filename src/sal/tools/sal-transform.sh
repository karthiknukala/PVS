#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") OP INPUT.sal [DECLARATION [SYNTAX [OUTPUT]]] [CONTEXT-DIR ...]
  OP          preprocess, simplify, or flatten
  SYNTAX      sal or lsal (default: lsal)
  OUTPUT      output file, or - for stdout (default: -)
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 2
fi

operation=$1
input_file=$2
shift 2

case "$operation" in
  preprocess|simplify|flatten) ;;
  *)
    echo "sal-transform: unknown operation: $operation" >&2
    usage
    exit 2
    ;;
esac

if [[ ! -f "$input_file" ]]; then
  echo "sal-transform: input file not found: $input_file" >&2
  exit 1
fi

input_dir=$(CDPATH= cd -- "$(dirname -- "$input_file")" && pwd)
input_file="$input_dir/$(basename -- "$input_file")"

declaration=${1-}
if [[ $# -gt 0 ]]; then shift; fi
syntax=${1:-lsal}
if [[ $# -gt 0 ]]; then shift; fi
output_file=${1:--}
if [[ $# -gt 0 ]]; then shift; fi

case "$syntax" in
  sal|lsal) ;;
  *)
    echo "sal-transform: syntax must be sal or lsal: $syntax" >&2
    exit 2
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sal_root=${SAL_HOME:-$(CDPATH= cd -- "$script_dir/.." && pwd)}
salenv="$sal_root/bin/salenv"
driver="$script_dir/sal-transform.scm"

if [[ ! -x "$salenv" ]]; then
  echo "sal-transform: salenv not found or not executable: $salenv" >&2
  echo "Set SAL_HOME when running these scripts outside a SAL installation." >&2
  exit 1
fi

if [[ ! -f "$driver" ]]; then
  echo "sal-transform: Scheme driver not found: $driver" >&2
  exit 1
fi

exec "$salenv" "$driver" "$operation" "$input_file" "$input_dir" \
  "$declaration" "$syntax" "$output_file" "$@"
