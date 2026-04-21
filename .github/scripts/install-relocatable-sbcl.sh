#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-relocatable-sbcl.sh --prefix DIR [options]

Options:
  --prefix DIR        Installation prefix for the built SBCL.
  --version VERSION   SBCL source version to build. Default: 2.6.3
  --host-sbcl PATH    Bootstrap SBCL executable to use. Default: first sbcl on PATH
  --github-env FILE   Append SBCL_HOME and PVS_SBCL_BIN exports to this env file
  --help              Show this help text
EOF
}

version="2.6.3"
prefix=""
host_sbcl=""
github_env=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    --version)
      version="${2:-}"
      shift 2
      ;;
    --host-sbcl)
      host_sbcl="${2:-}"
      shift 2
      ;;
    --github-env)
      github_env="${2:-}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$prefix" ]; then
  echo "--prefix is required" >&2
  usage >&2
  exit 1
fi

if [ -z "$host_sbcl" ]; then
  host_sbcl="$(command -v sbcl || true)"
fi

if [ -z "$host_sbcl" ] || [ ! -x "$host_sbcl" ]; then
  echo "Could not find an executable bootstrap SBCL. Install sbcl first or pass --host-sbcl." >&2
  exit 1
fi

archive="sbcl-${version}-source.tar.bz2"
url="https://downloads.sourceforge.net/project/sbcl/sbcl/${version}/${archive}"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/pvs-sbcl.XXXXXX")"

cleanup() {
  rm -rf "$build_root"
}
trap cleanup EXIT

echo "Downloading SBCL ${version} source"
curl -fsSL "$url" -o "$build_root/$archive"

echo "Extracting SBCL ${version} source"
tar -xjf "$build_root/$archive" -C "$build_root"

srcdir="$build_root/sbcl-${version}"
xc_host="${host_sbcl} --disable-debugger --no-userinit --no-sysinit"

echo "Building SBCL ${version} with relocatable static space"
(
  cd "$srcdir"
  sh make.sh \
    --prefix="$prefix" \
    --with-immobile-space \
    --with-relocatable-static-space \
    --xc-host="$xc_host"
  sh install.sh
)

sbcl_bin="$prefix/bin/sbcl"
if [ ! -x "$sbcl_bin" ]; then
  echo "Expected installed SBCL executable at $sbcl_bin" >&2
  exit 1
fi

run_sbcl="$(find "$prefix" -type f -name run-sbcl.sh -print -quit)"
if [ -z "$run_sbcl" ]; then
  echo "Could not locate run-sbcl.sh under $prefix" >&2
  exit 1
fi
sbcl_home="$(dirname "$run_sbcl")"

echo "Verifying relocatable static space support"
"$sbcl_bin" --noinform --non-interactive \
  --eval '(unless (member :immobile-space *features*)
             (error "SBCL was built without :immobile-space"))' \
  --eval '(unless (member :relocatable-static-space *features*)
             (error "SBCL was built without :relocatable-static-space"))'

if [ -n "$github_env" ]; then
  {
    echo "SBCL_HOME=$sbcl_home"
    echo "PVS_SBCL_BIN=$sbcl_bin"
  } >> "$github_env"
fi

echo "Installed relocatable SBCL at $prefix"
echo "SBCL_HOME=$sbcl_home"
