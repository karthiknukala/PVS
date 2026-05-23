#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: resolve-release-policy.sh [--config <path>]

Resolves whether the current GitHub Actions run should publish a stable release,
a nightly prerelease, or no release at all.
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

config_file=.github/release-config.env

while [[ $# -gt 0 ]]; do
  case $1 in
    --config)
      config_file=$2
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

[[ -f $config_file ]] || fail "release config file not found: $config_file"

# shellcheck disable=SC1090
source "$config_file"

stable_branch=${PVS_RELEASE_STABLE_BRANCH:-}
nightly_branch=${PVS_RELEASE_NIGHTLY_BRANCH:-}

[[ -n $stable_branch ]] || fail "PVS_RELEASE_STABLE_BRANCH must be set in $config_file"
[[ -n $nightly_branch ]] || fail "PVS_RELEASE_NIGHTLY_BRANCH must be set in $config_file"
[[ -n ${GITHUB_REF_TYPE:-} ]] || fail "GITHUB_REF_TYPE is required"
[[ -n ${GITHUB_REF_NAME:-} ]] || fail "GITHUB_REF_NAME is required"
[[ -n ${GITHUB_SHA:-} ]] || fail "GITHUB_SHA is required"

publish=false
channel=none
release_tag=
release_title=
prerelease=false
move_tag=false
release_date=

case ${GITHUB_REF_TYPE} in
  branch)
    if [[ ${GITHUB_REF_NAME} == "$nightly_branch" ]]; then
      release_date=$(date -u +%Y%m%d)
      publish=true
      channel=nightly
      release_tag="nightly-${release_date}"
      release_title="Nightly ${release_date}"
      prerelease=true
      move_tag=true
    fi
    ;;
  tag)
    git fetch --no-tags --depth=1 origin \
      "refs/heads/${stable_branch}:refs/remotes/origin/${stable_branch}" >/dev/null 2>&1 || {
      fail "unable to fetch stable branch origin/${stable_branch} for tag validation"
    }
    if git merge-base --is-ancestor "$GITHUB_SHA" "refs/remotes/origin/${stable_branch}"; then
      publish=true
      channel=stable
      release_tag=${GITHUB_REF_NAME}
      release_title=${GITHUB_REF_NAME}
      prerelease=false
      move_tag=false
    fi
    ;;
esac

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
  {
    echo "stable_branch=$stable_branch"
    echo "nightly_branch=$nightly_branch"
    echo "publish=$publish"
    echo "channel=$channel"
    echo "release_tag=$release_tag"
    echo "release_title=$release_title"
    echo "prerelease=$prerelease"
    echo "move_tag=$move_tag"
    echo "release_date=$release_date"
  } >> "$GITHUB_OUTPUT"
else
  printf 'stable_branch=%s\n' "$stable_branch"
  printf 'nightly_branch=%s\n' "$nightly_branch"
  printf 'publish=%s\n' "$publish"
  printf 'channel=%s\n' "$channel"
  printf 'release_tag=%s\n' "$release_tag"
  printf 'release_title=%s\n' "$release_title"
  printf 'prerelease=%s\n' "$prerelease"
  printf 'move_tag=%s\n' "$move_tag"
  printf 'release_date=%s\n' "$release_date"
fi
