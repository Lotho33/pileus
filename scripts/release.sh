#!/usr/bin/env bash
# Cuts a new Pileus release.
#
#   scripts/release.sh 1.0.5     # bump + commit + tag v1.0.5 + push
#   scripts/release.sh 1.0.5 -n  # dry-run: show what it would do, nothing else
#
# Pushing the vX.Y.Z tag triggers .github/workflows/release.yml, which
# builds the signed Android APKs and the web bundle and attaches them to
# the GitHub Release (the sideload/Obtainium channel). This script then
# dispatches every other per-platform workflow for the same tag via `gh` —
# linux.yml (desktop tarball), windows.yml (installer + portable zip), and
# store.yml (signed AAB + per-ABI APKs for Play/Amazon) — so "cut a
# release" covers every build target in one run instead of a manual trip
# to the Actions tab per platform. Each is individually skippable (see
# env overrides below) for a release that genuinely doesn't need one of
# them (e.g. no store submission is due this cycle).
#
# GitHub Pages (the privacy policy / docs site, lotho33.github.io/pileus)
# needs nothing here — it's GitHub's own branch-deploy from /docs on
# main, not a workflow this repo defines; it redeploys on its own the
# moment the version-bump commit below lands on main.
#
# Once linux.yml's run finishes and the tarball is attached to the
# release, run `scripts/update-flatpak-manifest.sh X.Y.Z` to point the
# Flatpak manifest (packaging/linux/) at it — see that script and
# packaging/README.md for the remaining (one-time, not per-release)
# Flathub submission steps.
#
# Override via env:
#   PILEUS_RELEASE_REMOTE      git remote to push to       (default: origin)
#   PILEUS_RELEASE_BRANCH      branch to push               (default: main)
#   PILEUS_ACTIONS_URL         "follow the build" URL printed at the end
#   PILEUS_SKIP_LINUX_BUILD    set to 1 to skip the linux.yml dispatch
#   PILEUS_SKIP_WINDOWS_BUILD  set to 1 to skip the windows.yml dispatch
#   PILEUS_SKIP_STORE_BUILD    set to 1 to skip the store.yml dispatch
set -euo pipefail

REMOTE=${PILEUS_RELEASE_REMOTE:-origin}
BRANCH=${PILEUS_RELEASE_BRANCH:-main}
ACTIONS_URL=${PILEUS_ACTIONS_URL:-}
SKIP_LINUX=${PILEUS_SKIP_LINUX_BUILD:-0}
SKIP_WINDOWS=${PILEUS_SKIP_WINDOWS_BUILD:-0}
SKIP_STORE=${PILEUS_SKIP_STORE_BUILD:-0}

ver=${1:-}
dry=false
[[ "${2:-}" == "-n" || "${2:-}" == "--dry-run" ]] && dry=true

if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 X.Y.Z [-n]   (e.g. $0 1.0.5)" >&2
  exit 2
fi
tag="v$ver"

cd "$(git rev-parse --show-toplevel)"

# --- checks ------------------------------------------------------------------
cur_branch=$(git branch --show-current)
[[ "$cur_branch" == "$BRANCH" ]] || { echo "on '$cur_branch', not '$BRANCH'." >&2; exit 1; }

git fetch -q "$REMOTE" --tags || true
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || \
   git ls-remote --exit-code --tags "$REMOTE" "$tag" >/dev/null 2>&1; then
  echo "tag $tag already exists (local or on $REMOTE)." >&2
  exit 1
fi

# Only pubspec.yaml may already be modified among tracked files (untracked
# files never block a release).
dirty=$(git status --porcelain --untracked-files=no | grep -v ' pubspec.yaml$' || true)
[[ -z "$dirty" ]] || { echo "working tree is dirty:"; echo "$dirty"; exit 1; }

# --- version bump --------------------------------------------------------
# Android versionCode is the part after '+'. Kept at 0: the pipeline passes
# --build-number=<run number> and overrides it regardless.
new_line="version: ${ver}+0"
old_line=$(grep -E '^version:' pubspec.yaml)
echo "pubspec: '$old_line'  ->  '$new_line'"
echo "commit + tag $tag, then push '$BRANCH' and '$tag' to '$REMOTE'"

if $dry; then echo "(dry-run, nothing done)"; exit 0; fi

sed -i -E "s/^version:.*/${new_line}/" pubspec.yaml

git add pubspec.yaml
git commit -m "$tag"
git tag -a "$tag" -m "$tag"

git push "$REMOTE" "$BRANCH"
git push "$REMOTE" "$tag"

echo
echo "done."
if [[ -n "$ACTIONS_URL" ]]; then
  echo "follow the build:  $ACTIONS_URL"
else
  echo "follow the build on the '$REMOTE' remote's Actions page."
fi

# --- also dispatch every other per-platform workflow for this tag ----------
# $1: workflow file (e.g. linux.yml)  $2: skip flag's value  $3: what it
# produces, for the success message.  $4: the env var that controls $2, for
# the skip message.
dispatch_workflow() {
  local workflow="$1" skip="$2" produces="$3" skip_var="$4"
  if [[ "$skip" == "1" ]]; then
    echo
    echo "skipping $workflow ($skip_var=1)."
    return
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo
    echo "gh (GitHub CLI) not found — trigger $workflow by hand from the Actions" >&2
    echo "tab (tag: $tag) to publish $produces." >&2
    return
  fi
  echo
  echo "dispatching $workflow for $tag …"
  if gh workflow run "$workflow" -f "tag=$tag"; then
    echo "dispatched — will produce $produces once it finishes."
  else
    echo "gh workflow run failed — trigger $workflow by hand from the Actions tab instead." >&2
  fi
}

dispatch_workflow linux.yml "$SKIP_LINUX" \
  "pileus-${ver}-linux-x64.tar.gz, attached to the $tag release (then: scripts/update-flatpak-manifest.sh $ver)" \
  PILEUS_SKIP_LINUX_BUILD
dispatch_workflow windows.yml "$SKIP_WINDOWS" \
  "the Windows installer + portable zip, attached to the $tag release" \
  PILEUS_SKIP_WINDOWS_BUILD
dispatch_workflow store.yml "$SKIP_STORE" \
  "the signed AAB + per-ABI APKs for Play/Amazon, as a downloadable workflow artifact (pileus-${ver}-store)" \
  PILEUS_SKIP_STORE_BUILD
