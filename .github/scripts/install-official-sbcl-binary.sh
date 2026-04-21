#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-official-sbcl-binary.sh --prefix DIR [options]

Options:
  --prefix DIR          Installation prefix for the SBCL binary distribution
  --version VERSION     SBCL binary version to install
  --platform TAG        SBCL platform tag, for example arm64-darwin
  --github-env FILE     Append bootstrap SBCL exports to this env file
  --help                Show this help text
EOF
}

prefix=""
version=""
platform=""
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
    --platform)
      platform="${2:-}"
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

if [ -z "$prefix" ] || [ -z "$version" ] || [ -z "$platform" ]; then
  echo "--prefix, --version, and --platform are required" >&2
  usage >&2
  exit 1
fi

archive="sbcl-${version}-${platform}-binary.tar.bz2"
url="https://prdownloads.sourceforge.net/sbcl/${archive}"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/pvs-sbcl-bootstrap.XXXXXX")"

cleanup() {
  rm -rf "$build_root"
}
trap cleanup EXIT

echo "Downloading official SBCL binary ${archive}"
curl -fsSL "$url" -o "$build_root/$archive"

echo "Extracting official SBCL binary ${archive}"
tar -xjf "$build_root/$archive" -C "$build_root"

distdir="$(find "$build_root" -mindepth 1 -maxdepth 1 -type d -name "sbcl-${version}-*" -print -quit)"
if [ -z "$distdir" ] || [ ! -x "$distdir/install.sh" ]; then
  echo "Could not locate extracted SBCL distribution under $build_root" >&2
  exit 1
fi

echo "Installing SBCL binary distribution to $prefix"
(
  cd "$distdir"
  INSTALL_ROOT="$prefix" sh ./install.sh
)

sbcl_home="$prefix/lib/sbcl"
sbcl_bin="$prefix/bin/sbcl"

if [ ! -x "$sbcl_bin" ]; then
  echo "Expected installed SBCL executable at $sbcl_bin" >&2
  exit 1
fi

SBCL_HOME="$sbcl_home" "$sbcl_bin" --noinform --non-interactive \
  --eval "(unless (string= (lisp-implementation-version) \"$version\") (error \"Unexpected SBCL version ~A\" (lisp-implementation-version)))"

if [ -n "$github_env" ]; then
  {
    echo "PVS_BOOTSTRAP_SBCL_BIN=$sbcl_bin"
    echo "PVS_BOOTSTRAP_SBCL_HOME=$sbcl_home"
  } >> "$github_env"
fi

echo "Installed official SBCL bootstrap at $prefix"
echo "PVS_BOOTSTRAP_SBCL_BIN=$sbcl_bin"
echo "PVS_BOOTSTRAP_SBCL_HOME=$sbcl_home"
