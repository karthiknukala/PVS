#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: publish-github-release.sh \
  --tag <tag> \
  --title <title> \
  --asset <path> \
  [--asset-name <name>] \
  [--keep-asset-name <name>] \
  [--notes <text>] \
  [--target <sha>] \
  [--repo <owner/repo>] \
  [--prerelease] \
  [--move-tag]

Publishes or updates a GitHub Release and uploads a single asset with a stable
display name. When --move-tag is supplied, the tag is force-moved to --target.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

tag=
title=
asset=
asset_name=
keep_asset_names=()
notes=
target=
repo=${GITHUB_REPOSITORY:-}
prerelease=false
move_tag=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tag)
      tag=$2
      shift 2
      ;;
    --title)
      title=$2
      shift 2
      ;;
    --asset)
      asset=$2
      shift 2
      ;;
    --asset-name)
      asset_name=$2
      shift 2
      ;;
    --keep-asset-name)
      keep_asset_names+=("$2")
      shift 2
      ;;
    --notes)
      notes=$2
      shift 2
      ;;
    --target)
      target=$2
      shift 2
      ;;
    --repo)
      repo=$2
      shift 2
      ;;
    --prerelease)
      prerelease=true
      shift
      ;;
    --move-tag)
      move_tag=true
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

[[ -n ${GH_TOKEN:-} ]] || fail "GH_TOKEN is required"
[[ -n $tag ]] || fail "--tag is required"
[[ -n $title ]] || fail "--title is required"
[[ -n $asset ]] || fail "--asset is required"
[[ -f $asset ]] || fail "asset not found: $asset"
[[ -n $repo ]] || fail "--repo is required or GITHUB_REPOSITORY must be set"

contains_asset_name() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

release_asset_names() {
  gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name'
}

delete_release_asset() {
  local asset_id=$1
  local asset_name=$2
  local current_assets

  if gh api --method DELETE "repos/$repo/releases/assets/$asset_id" >/dev/null 2>&1; then
    return 0
  fi

  if ! current_assets=$(release_asset_names); then
    echo "error: failed to refresh release assets after deletion error for $asset_name" >&2
    return 1
  fi

  if ! printf '%s\n' "$current_assets" | grep -Fx -- "$asset_name" >/dev/null 2>&1; then
    echo "Skipping already-removed asset $asset_name"
    return 0
  fi

  echo "error: failed to delete release asset $asset_name" >&2
  return 1
}

if [[ -z $target ]]; then
  target=${GITHUB_SHA:-$(git rev-parse HEAD)}
fi

if [[ -z $asset_name ]]; then
  asset_name=$(basename "$asset")
fi

if [[ -z $notes ]]; then
  notes=$(cat <<EOF
Automated release published from GitHub Actions.

- Tag: \`$tag\`
- Commit: \`$target\`
EOF
)
fi

notes_file=$(mktemp "${TMPDIR:-/tmp}/pvs-release-notes.XXXXXX")
cleanup() {
  rm -f "$notes_file"
}
trap cleanup EXIT
printf '%s\n' "$notes" > "$notes_file"

if [[ $move_tag == true ]]; then
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git tag -f "$tag" "$target"
  git push --force origin "refs/tags/$tag"
fi

release_flags=(--title "$title" --notes-file "$notes_file")
if [[ $prerelease == true ]]; then
  release_flags+=(--prerelease)
fi

if gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  gh release edit "$tag" -R "$repo" "${release_flags[@]}"
else
  if ! gh release create "$tag" -R "$repo" --verify-tag "${release_flags[@]}"; then
    gh release edit "$tag" -R "$repo" "${release_flags[@]}"
  fi
fi

gh release upload "$tag" -R "$repo" "$asset#$asset_name" --clobber

if [[ ${#keep_asset_names[@]} -gt 0 ]]; then
  while IFS=$'\t' read -r asset_id existing_asset; do
    [[ -n $asset_id ]] || continue
    [[ -n $existing_asset ]] || continue
    if ! contains_asset_name "$existing_asset" "${keep_asset_names[@]}"; then
      delete_release_asset "$asset_id" "$existing_asset"
    fi
  done < <(gh release view "$tag" -R "$repo" --json assets --jq '.assets[] | "\(.id)\t\(.name)"')
fi
