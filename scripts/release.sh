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
# linux.yml then chains flatpak.yml: the Flatpak is built from that
# tarball, signed, and published to the self-hosted repo on GitHub Pages
# (lotho33.github.io/pileus/flatpak/, deployed by pages.yml, which also
# serves docs/ — the privacy policy the stores link to). Nothing to do by
# hand. (Not on Flathub: its generative-AI policy rules this project out —
# see packaging/README.md.)
#
# Store publishing is per target and only for what this release changed
# (scripts/release-targets.py — shown below before anything is pushed, also
# on a dry-run): tv -> Amazon + Play TV, mobile -> Play mobile, webos -> two
# .ipk on the GitHub Release for a manual LG Seller Lounge upload (no API).
# The uploads themselves happen in release.yml on the tag push; to publish
# an unchanged target anyway, re-run it: Actions > release > Run workflow,
# tag + force=tv,mobile,webos (or all).
#
# Vega OS (pileus-vega, a separate repo): when it has commits since its last
# tag, this script releases it first — tests, version bump (patch, or
# PILEUS_VEGA_VERSION), a release .vpkg with a fresh build number, commit +
# tag + push, and the .vpkg on pileus-vega's GitHub Release. Run it where
# the Vega CLI and gh are (the fedora-toolbox-44 toolbox). Amazon's App
# Submission API takes no VPKG yet (Amazon staff, Dec 2025), so the .vpkg
# goes into the Amazon version by hand: the tag then says "vega: X.Y.Z" and
# release.yml's amazon-submit only uploads the APK, without submitting, so
# APK and VPKG go to review together from the Developer Console.
#
# Override via env:
#   PILEUS_RELEASE_REMOTE      git remote to push to       (default: origin)
#   PILEUS_RELEASE_BRANCH      branch to push               (default: main)
#   PILEUS_ACTIONS_URL         "follow the build" URL printed at the end
#   PILEUS_SKIP_LINUX_BUILD    set to 1 to skip the linux.yml dispatch
#   PILEUS_SKIP_WINDOWS_BUILD  set to 1 to skip the windows.yml dispatch
#   PILEUS_SKIP_STORE_BUILD    set to 1 to skip the store.yml dispatch
#   PILEUS_VEGA_DIR            pileus-vega checkout   (default: ~/Dev/ReactNative/pileus-vega)
#   PILEUS_VEGA_VERSION        Vega version to release (default: last tag's patch + 1)
#   PILEUS_SKIP_VEGA           set to 1 to leave Vega out of this release
set -euo pipefail

REMOTE=${PILEUS_RELEASE_REMOTE:-origin}
BRANCH=${PILEUS_RELEASE_BRANCH:-main}
ACTIONS_URL=${PILEUS_ACTIONS_URL:-}
SKIP_LINUX=${PILEUS_SKIP_LINUX_BUILD:-0}
SKIP_WINDOWS=${PILEUS_SKIP_WINDOWS_BUILD:-0}
SKIP_STORE=${PILEUS_SKIP_STORE_BUILD:-0}
VEGA_DIR=${PILEUS_VEGA_DIR:-$HOME/Dev/ReactNative/pileus-vega}
SKIP_VEGA=${PILEUS_SKIP_VEGA:-0}

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

# --- which stores this release touches --------------------------------------
echo
targets_out=$(mktemp)
trap 'rm -f "$targets_out"' EXIT
GITHUB_OUTPUT="$targets_out" python3 -I scripts/release-targets.py --github-output
target() { grep -q "^$1=true$" "$targets_out"; }
echo
target tv && echo "  -> Amazon Appstore + Play (Android TV): build, upload, submit for review"
target mobile && echo "  -> Play (mobile): build, upload, submit for review"
target webos && echo "  -> LG webOS: .ipk on the GitHub Release, upload by hand to the Seller Lounge"
target tv || target mobile || target webos || echo "  -> no store target changed: GitHub Release only"

# --- Vega OS (pileus-vega) ---------------------------------------------------
vega_ver=""
if [[ "$SKIP_VEGA" != 1 && -d "$VEGA_DIR/.git" ]]; then
  vega_last=$(git -C "$VEGA_DIR" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)
  if [[ -z "$vega_last" ]] || [[ $(git -C "$VEGA_DIR" rev-list --count "$vega_last..HEAD") -gt 0 ]]; then
    if [[ -n "${PILEUS_VEGA_VERSION:-}" ]]; then
      vega_ver=$PILEUS_VEGA_VERSION
    else
      # Patch + 1 over the last tag, or over manifest.toml's version (the
      # one the store has) before the first tag.
      base=${vega_last#v}
      [[ -n "$base" ]] || base=$(sed -nE '0,/^version = "(.*)"/s//\1/p' "$VEGA_DIR/manifest.toml")
      IFS=. read -r va vb vc <<<"$base"
      vega_ver="${va:-1}.${vb:-0}.$(( ${vc:-0} + 1 ))"
    fi
    [[ "$vega_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "bad Vega version '$vega_ver'." >&2; exit 1; }
    git -C "$VEGA_DIR" rev-parse -q --verify "refs/tags/v$vega_ver" >/dev/null && \
      { echo "pileus-vega: tag v$vega_ver already exists." >&2; exit 1; }
    [[ $(git -C "$VEGA_DIR" branch --show-current) == main ]] || { echo "pileus-vega: not on 'main'." >&2; exit 1; }
    # Only the files the bump rewrites may already be modified.
    vdirty=$(git -C "$VEGA_DIR" status --porcelain --untracked-files=no \
      | grep -vE ' (manifest\.toml|package\.json|package-lock\.json|README\.md)$' || true)
    [[ -z "$vdirty" ]] || { echo "pileus-vega working tree is dirty:"; echo "$vdirty"; exit 1; }
    echo "  -> Vega OS ${vega_last:-(no tag)} -> v$vega_ver: build .vpkg, commit + tag + push pileus-vega,"
    echo "     .vpkg on its GitHub Release; Amazon: APK uploaded as draft, add the .vpkg and submit by hand"
  else
    echo "  -> Vega OS: no commits since $vega_last, not released"
  fi
fi

if $dry; then echo "(dry-run, nothing done)"; exit 0; fi

# Vega first: if its tests or build fail, nothing of this release is pushed.
if [[ -n "$vega_ver" ]]; then
  echo
  echo "== Vega OS v$vega_ver =="
  (
    cd "$VEGA_DIR"
    npx tsc --noEmit
    npx jest --silent
    npm version "$vega_ver" --no-git-tag-version --allow-same-version >/dev/null
    sed -i -E "0,/^version = \".*\"/s//version = \"$vega_ver\"/" manifest.toml
    sed -i -E "s/\*\*Version [0-9]+\.[0-9]+\.[0-9]+\*\*/**Version $vega_ver**/" README.md
    vpkg=build/armv7-release/pileus-vega_armv7.vpkg
    rm -f "$vpkg" # never ship the one a previous deploy.sh left there
    # The store rejects a build number that doesn't grow: epoch seconds do.
    npx react-native build-vega --build-type Release --target armv7 --build-number "$(date +%s)" \
      | grep -E "created:|ERROR" || true
    test -f "$vpkg"
    out="build/pileus-vega-$vega_ver-armv7.vpkg"
    cp "$vpkg" "$out"
    ( cd build && sha256sum "$(basename "$out")" > "pileus-vega-$vega_ver-SHA256SUMS.txt" )
    git add manifest.toml package.json package-lock.json README.md
    git commit -m "v$vega_ver"
    git tag -a "v$vega_ver" -m "v$vega_ver"
    git push origin main
    git push origin "v$vega_ver"
    gh release create "v$vega_ver" -R "$(git remote get-url origin | sed -E 's#.*github.com[:/](.*)\.git$#\1#')" \
      --title "v$vega_ver" --notes "Pileus for Vega OS $vega_ver (armv7). Upload the .vpkg in the Amazon Developer Console." \
      "$out" "build/pileus-vega-$vega_ver-SHA256SUMS.txt"
    echo "Vega .vpkg: $VEGA_DIR/$out"
  )
fi

sed -i -E "s/^version:.*/${new_line}/" pubspec.yaml

git add pubspec.yaml
git commit -m "$tag"
# "vega: X.Y.Z" tells release.yml's amazon-submit not to submit the edit:
# the .vpkg still has to be added to it by hand.
tag_msg="$tag"
[[ -n "$vega_ver" ]] && tag_msg="$tag"$'\n\n'"vega: $vega_ver"
git tag -a "$tag" -m "$tag_msg"

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
  "pileus-${ver}-linux-x64.tar.gz + the Flatpak (bundle on the $tag release, repo on lotho33.github.io/pileus/flatpak/)" \
  PILEUS_SKIP_LINUX_BUILD
dispatch_workflow windows.yml "$SKIP_WINDOWS" \
  "the Windows installer + portable zip, attached to the $tag release" \
  PILEUS_SKIP_WINDOWS_BUILD
# store.yml only produces downloadable AAB/APKs for a manual upload — with
# release.yml's play/amazon-submit jobs that's a fallback, so only when an
# Android target changed.
if ! target tv && ! target mobile; then SKIP_STORE=1; fi
dispatch_workflow store.yml "$SKIP_STORE" \
  "the signed AAB + per-ABI APKs for Play/Amazon, as a downloadable workflow artifact (pileus-${ver}-store)" \
  PILEUS_SKIP_STORE_BUILD

if [[ -n "$vega_ver" ]]; then
  echo
  echo "Amazon (Fire TV + Vega OS): the App Submission API takes no VPKG yet."
  if target tv; then
    echo "Once release.yml's amazon-submit job finishes, the APK is in an open"
    echo "Amazon edit, NOT submitted. In the Developer Console open that version,"
  else
    echo "No Fire TV change in this release: in the Developer Console add a new version,"
  fi
  echo "upload $VEGA_DIR/build/pileus-vega-${vega_ver}-armv7.vpkg (Vega OS), then submit."
fi

if target webos; then
  echo
  echo "LG webOS changed: once release.yml's webos job finishes, download"
  echo "pileus-${ver}-webos-1080p.ipk and -720p.ipk from the $tag release and"
  echo "upload them in the LG Seller Lounge (File Ver. ${ver})."
fi
