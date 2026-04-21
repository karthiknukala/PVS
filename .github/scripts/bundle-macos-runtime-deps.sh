#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bundle-macos-runtime-deps.sh --runtime-dir <dir> [--check-only]

Copies non-system dynamic library dependencies into the given macOS runtime
directory and rewrites Mach-O load commands to use @loader_path references.

Options:
  --runtime-dir <dir>  Runtime directory containing the packaged Mach-O files
  --check-only         Audit only; fail if any non-system absolute dependency remains
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

contains_path() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

is_macho() {
  file -b "$1" | grep -q 'Mach-O'
}

is_shared_library() {
  file -b "$1" | grep -q 'dynamically linked shared library'
}

should_bundle_dependency() {
  case $1 in
    ""|/System/*|/usr/lib/*|@loader_path/*|@executable_path/*|@rpath/*)
      return 1
      ;;
    /*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_loader_path_dependency() {
  local owner=$1
  local dep=$2
  local resolved

  case $dep in
    @loader_path/*)
      resolved="$(dirname "$owner")/${dep#@loader_path/}"
      if [[ ! -e $resolved ]]; then
        echo "Missing @loader_path dependency: $owner -> $dep (expected $resolved)" >&2
        return 1
      fi
      ;;
  esac

  return 0
}

audit_runtime_dir() {
  local runtime_dir=$1
  local path dep
  local clean=true

  while IFS= read -r -d '' path; do
    is_macho "$path" || continue
    while IFS= read -r dep; do
      if ! check_loader_path_dependency "$path" "$dep"; then
        clean=false
      fi
      should_bundle_dependency "$dep" || continue
      echo "External dependency: $path -> $dep" >&2
      clean=false
    done < <(otool -L "$path" | tail -n +2 | awk '{print $1}')
  done < <(find "$runtime_dir" -type f -print0)

  [[ $clean == true ]]
}

bundle_runtime_dir() {
  local runtime_dir=$1
  local pending=()
  local seen=()
  local path dep dep_name dest
  local index=0

  while IFS= read -r -d '' path; do
    is_macho "$path" || continue
    pending+=("$path")
  done < <(find "$runtime_dir" -type f -print0)

  while [[ $index -lt ${#pending[@]} ]]; do
    path=${pending[$index]}
    index=$((index + 1))

    if [[ ${#seen[@]} -gt 0 ]]; then
      contains_path "$path" "${seen[@]}" && continue
    fi
    seen+=("$path")

    while IFS= read -r dep; do
      should_bundle_dependency "$dep" || continue
      [[ -e $dep ]] || fail "dependency $dep referenced by $path does not exist on the build machine"

      dep_name=$(basename "$dep")
      dest="$runtime_dir/$dep_name"

      if [[ ! -e $dest ]]; then
        echo "Bundling dependency $dep -> $dest"
        cp -fL "$dep" "$dest"
      fi

      chmod u+w "$path" "$dest"
      echo "Rewriting dependency in $path: $dep -> @loader_path/$dep_name"
      install_name_tool -change "$dep" "@loader_path/$dep_name" "$path"

      if is_shared_library "$dest"; then
        install_name_tool -id "@loader_path/$dep_name" "$dest"
      fi

      if is_macho "$dest" && { [[ ${#pending[@]} -eq 0 ]] || ! contains_path "$dest" "${pending[@]}"; }; then
        pending+=("$dest")
      fi
    done < <(otool -L "$path" | tail -n +2 | awk '{print $1}')
  done
}

runtime_dir=
check_only=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --runtime-dir)
      runtime_dir=$2
      shift 2
      ;;
    --check-only)
      check_only=true
      shift
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

if [[ $check_only == true ]]; then
  audit_runtime_dir "$runtime_dir" || fail "found non-system absolute dependencies under $runtime_dir"
  echo "Runtime dependencies are self-contained in $runtime_dir"
  exit 0
fi

bundle_runtime_dir "$runtime_dir"
audit_runtime_dir "$runtime_dir" || fail "failed to fully bundle runtime dependencies under $runtime_dir"
echo "Bundled runtime dependencies in $runtime_dir"
