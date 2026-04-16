#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-macos-pkg.sh \
  --bundle-dir <dir> \
  --output-dir <dir> \
  --pkg-name <name.pkg> \
  --pkg-identifier <identifier> \
  --pkg-version <version> \
  [--install-base </Applications>]

Required environment variables:
  MACOS_INSTALLER_SIGN_IDENTITY

Optional environment variables for notarization:
  MACOS_NOTARY_KEY_FILE
  MACOS_NOTARY_KEY_ID
  MACOS_NOTARY_ISSUER_ID
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

bundle_dir=
output_dir=
pkg_name=
pkg_identifier=
pkg_version=
install_base=/Applications

while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle-dir)
      bundle_dir=$2
      shift 2
      ;;
    --output-dir)
      output_dir=$2
      shift 2
      ;;
    --pkg-name)
      pkg_name=$2
      shift 2
      ;;
    --pkg-identifier)
      pkg_identifier=$2
      shift 2
      ;;
    --pkg-version)
      pkg_version=$2
      shift 2
      ;;
    --install-base)
      install_base=$2
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

[[ -n $bundle_dir ]] || fail "--bundle-dir is required"
[[ -n $output_dir ]] || fail "--output-dir is required"
[[ -n $pkg_name ]] || fail "--pkg-name is required"
[[ -n $pkg_identifier ]] || fail "--pkg-identifier is required"
[[ -n $pkg_version ]] || fail "--pkg-version is required"
[[ -d $bundle_dir ]] || fail "bundle directory not found: $bundle_dir"
[[ -n ${MACOS_INSTALLER_SIGN_IDENTITY:-} ]] || fail "MACOS_INSTALLER_SIGN_IDENTITY is required"

mkdir -p "$output_dir"

stage_root=$(mktemp -d "${TMPDIR:-/tmp}/pvs-pkg-stage.XXXXXX")
cleanup() {
  rm -rf "$stage_root"
}
trap cleanup EXIT

mkdir -p "$stage_root$install_base"
cp -R "$bundle_dir" "$stage_root$install_base/"

pkg_stem=${pkg_name%.pkg}
unsigned_pkg="$output_dir/$pkg_stem-unsigned.pkg"
signed_pkg="$output_dir/$pkg_name"

echo "Building unsigned package $unsigned_pkg"
pkgbuild \
  --root "$stage_root" \
  --identifier "$pkg_identifier" \
  --version "$pkg_version" \
  --install-location "/" \
  "$unsigned_pkg"

echo "Signing installer package $signed_pkg"
productsign \
  --sign "$MACOS_INSTALLER_SIGN_IDENTITY" \
  "$unsigned_pkg" \
  "$signed_pkg"

rm -f "$unsigned_pkg"

echo "Checking installer package signature"
pkgutil --check-signature "$signed_pkg"

notarized=false
if [[ -n ${MACOS_NOTARY_KEY_FILE:-} && -n ${MACOS_NOTARY_KEY_ID:-} && -n ${MACOS_NOTARY_ISSUER_ID:-} ]]; then
  echo "Submitting $signed_pkg for notarization"
  xcrun notarytool submit \
    "$signed_pkg" \
    --key "$MACOS_NOTARY_KEY_FILE" \
    --key-id "$MACOS_NOTARY_KEY_ID" \
    --issuer "$MACOS_NOTARY_ISSUER_ID" \
    --wait
  echo "Stapling notarization ticket"
  xcrun stapler staple "$signed_pkg"
  notarized=true
fi

echo "Assessing installer package"
spctl -a -t install -vv "$signed_pkg"

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  {
    echo "pkg_path=$signed_pkg"
    echo "pkg_notarized=$notarized"
    echo "pkg_install_path=$install_base/$(basename "$bundle_dir")"
  } >> "$GITHUB_OUTPUT"
fi

echo "Created installer package: $signed_pkg"
