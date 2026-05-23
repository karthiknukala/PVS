#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: strip-runtime-debug-info.sh --runtime-dir DIR

Strips debug metadata from native runtime binaries in a release runtime
directory. This removes compile-time source paths from Mach-O and ELF files
without touching shell launchers or SBCL core data files.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

runtime_dir=

while [[ $# -gt 0 ]]; do
  case $1 in
    --runtime-dir)
      runtime_dir=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n $runtime_dir ]] || fail "--runtime-dir is required"
[[ -d $runtime_dir ]] || fail "runtime directory not found: $runtime_dir"

strip_tool=${STRIP:-strip}
command -v "$strip_tool" >/dev/null 2>&1 || fail "strip tool not found: $strip_tool"

strip_one() {
  local path=$1
  local desc=$2

  chmod u+w "$path"
  case $desc in
    *Mach-O*)
      "$strip_tool" -S "$path" 2>/dev/null || "$strip_tool" -x "$path"
      ;;
    *ELF*)
      "$strip_tool" --strip-debug "$path" 2>/dev/null || "$strip_tool" -g "$path"
      ;;
    *)
      return 0
      ;;
  esac
}

stripped_any=false
while IFS= read -r -d '' path; do
  desc=$(file -b "$path")
  case $desc in
    *Mach-O*|*ELF*)
      echo "Stripping debug metadata from $path"
      strip_one "$path" "$desc"
      stripped_any=true
      ;;
  esac
done < <(find "$runtime_dir" -type f -print0)

if [[ $stripped_any == false ]]; then
  echo "No native runtime binaries found under $runtime_dir"
fi
