#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-patched-sbcl-source.sh --prefix DIR [options]

Options:
  --prefix DIR        Installation prefix for the built SBCL
  --version VERSION   SBCL source version to build. Default: 2.6.1
  --host-sbcl PATH    Bootstrap SBCL executable to use
  --host-home DIR     SBCL_HOME for the bootstrap SBCL
  --github-env FILE   Append built SBCL exports to this env file
  --help              Show this help text
EOF
}

prefix=""
version="2.6.1"
host_sbcl=""
host_home=""
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
    --host-home)
      host_home="${2:-}"
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

if [ -z "$prefix" ] || [ -z "$host_sbcl" ]; then
  echo "--prefix and --host-sbcl are required" >&2
  usage >&2
  exit 1
fi

if [ ! -x "$host_sbcl" ]; then
  echo "Bootstrap SBCL is not executable: $host_sbcl" >&2
  exit 1
fi

archive="sbcl-${version}-source.tar.bz2"
url="https://downloads.sourceforge.net/project/sbcl/sbcl/${version}/${archive}"
build_root="$(mktemp -d "${TMPDIR:-/tmp}/pvs-sbcl-src.XXXXXX")"

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

echo "Building patched SBCL ${version}"
if ! (
  cd "$srcdir"
  SBCL_HOME="$host_home" sh make.sh \
    --prefix="$prefix" \
    --arch=arm64 \
    --with-sb-thread \
    --with-mark-region-gc \
    --with-immobile-space \
    --with-relocatable-static-space \
    --xc-host="$xc_host"
  sh install.sh
); then
  echo "SBCL source build failed in $srcdir" >&2
  if [ -f "$srcdir/local-target-features.lisp-expr" ]; then
    echo "Generated local-target-features.lisp-expr:" >&2
    sed -n '1,80p' "$srcdir/local-target-features.lisp-expr" >&2
  fi
  if [ -f "$srcdir/output/build-config" ]; then
    echo "Generated output/build-config:" >&2
    sed -n '1,80p' "$srcdir/output/build-config" >&2
  fi
  exit 1
fi

sbcl_home="$prefix/lib/sbcl"
sbcl_bin="$prefix/bin/sbcl"

if [ ! -x "$sbcl_bin" ]; then
  echo "Expected installed SBCL executable at $sbcl_bin" >&2
  exit 1
fi

SBCL_HOME="$sbcl_home" "$sbcl_bin" --noinform --non-interactive \
  --eval "(unless (string= (lisp-implementation-version) \"$version\") (error \"Unexpected SBCL version ~A\" (lisp-implementation-version)))" \
  --eval '(unless (member :immobile-space *features*)
             (error "SBCL was built without :immobile-space"))' \
  --eval '(unless (member :relocatable-static-space *features*)
             (error "SBCL was built without :relocatable-static-space"))'

mkdir -p "$prefix/bin"
wrapper="$prefix/bin/pvs-built-sbcl"
cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export SBCL_HOME="$sbcl_home"
exec "$sbcl_bin" "\$@"
EOF
chmod +x "$wrapper"

if [ -n "$github_env" ]; then
  {
    echo "PVS_BUILT_SBCL_BIN=$sbcl_bin"
    echo "PVS_BUILT_SBCL_HOME=$sbcl_home"
    echo "PVS_BUILT_SBCL_WRAPPER=$wrapper"
  } >> "$github_env"
fi

echo "Installed relocatable SBCL at $prefix"
echo "PVS_BUILT_SBCL_BIN=$sbcl_bin"
echo "PVS_BUILT_SBCL_HOME=$sbcl_home"
echo "PVS_BUILT_SBCL_WRAPPER=$wrapper"
