#!/usr/bin/env bash
# Cuts a new Pileus release.
#
#   scripts/release.sh 1.0.5     # bump + commit + tag v1.0.5 + push
#   scripts/release.sh 1.0.5 -n  # dry-run: show what it would do, nothing else
#
# Pushing the vX.Y.Z tag triggers .github/workflows/release.yml, which
# builds the signed Android APKs and the web bundle and attaches them to
# the GitHub Release (the sideload/Obtainium channel). This script also
# dispatches linux.yml (the desktop Linux tarball) right after, via `gh` —
# so "cut a release" covers Android + web + desktop Linux in one run
# instead of needing a second manual trip to the Actions tab. The store
# build (signed AAB) and the Windows installer stay separate,
# manually-triggered workflows — store.yml / windows.yml — a store
# submission and a Windows build aren't something every release needs.
#
# Once linux.yml's run finishes and the tarball is attached to the
# release, run `scripts/update-flatpak-manifest.sh X.Y.Z` to point the
# Flatpak manifest (packaging/linux/) at it — see that script and
# packaging/README.md for the remaining (one-time, not per-release)
# Flathub submission steps.
#
# Override via env:
#   PILEUS_RELEASE_REMOTE   git remote to push to       (default: origin)
#   PILEUS_RELEASE_BRANCH   branch to push               (default: main)
#   PILEUS_ACTIONS_URL      "follow the build" URL printed at the end
#   PILEUS_SKIP_LINUX_BUILD set to 1 to skip the linux.yml dispatch below
set -euo pipefail

REMOTE=${PILEUS_RELEASE_REMOTE:-origin}
BRANCH=${PILEUS_RELEASE_BRANCH:-main}
ACTIONS_URL=${PILEUS_ACTIONS_URL:-}
SKIP_LINUX=${PILEUS_SKIP_LINUX_BUILD:-0}

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

# --- also build the desktop Linux tarball -----------------------------------
if [[ "$SKIP_LINUX" != "1" ]]; then
  if command -v gh >/dev/null 2>&1; then
    echo
    echo "dispatching linux.yml for $tag …"
    if gh workflow run linux.yml -f "tag=$tag"; then
      echo "dispatched — attaches pileus-${ver}-linux-x64.tar.gz to the $tag release once it finishes."
      echo "once it's done: scripts/update-flatpak-manifest.sh $ver"
    else
      echo "gh workflow run failed — trigger linux.yml by hand from the Actions tab instead." >&2
    fi
  else
    echo
    echo "gh (GitHub CLI) not found — trigger linux.yml by hand from the Actions tab" >&2
    echo "(Actions -> linux -> Run workflow, tag: $tag) to publish the desktop build." >&2
  fi
fi
