#!/usr/bin/env bash
# Points packaging/linux/io.github.lotho33.Pileus.yml at a published
# release's Linux tarball — run once linux.yml's run for that tag has
# finished (see scripts/release.sh, which dispatches it).
#
#   scripts/update-flatpak-manifest.sh 1.5.3
#
# Downloads the tarball, computes its sha256, and rewrites the manifest's
# <TARBALL_URL>/<TARBALL_SHA256> placeholders in place. Also bumps the
# <release version> line in the appstream metainfo so Flathub's own
# validation sees a matching version.
#
# What this does NOT do (one-time setup, not per-release — see
# packaging/README.md):
#   - pin/build the libmpv module (still a stub in the manifest)
#   - the actual Flathub submission/update, which happens in a SEPARATE
#     git repo Flathub hosts once your app is accepted there, never in
#     this one — see https://docs.flathub.org/docs/for-app-authors/submission
#     for first-time submission, and packaging/README.md for how an
#     update push normally looks once accepted.
set -euo pipefail

ver=${1:-}
if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 X.Y.Z   (e.g. $0 1.5.3)" >&2
  exit 2
fi

repo_dir="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$repo_dir"

manifest="packaging/linux/io.github.lotho33.Pileus.yml"
metainfo="packaging/linux/io.github.lotho33.Pileus.metainfo.xml"
asset="pileus-${ver}-linux-x64.tar.gz"
url="https://github.com/Lotho33/pileus/releases/download/v${ver}/${asset}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "downloading $url …"
if command -v gh >/dev/null 2>&1; then
  gh release download "v${ver}" -p "$asset" -D "$tmp"
else
  curl -fsSL "$url" -o "$tmp/$asset"
fi

sha256="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
echo "sha256: $sha256"

# Replace whichever placeholder/previous value is currently there — matches
# both the pristine <TARBALL_URL>/<TARBALL_SHA256> template and a prior
# run's already-filled-in values, so this is safe to re-run on every
# release.
python3 - "$manifest" "$url" "$sha256" <<'PY'
import re, sys
path, url, sha256 = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
text = re.sub(r"url: .*", f"url: {url}", text, count=1)
text = re.sub(r"sha256: .*", f"sha256: {sha256}", text, count=1)
open(path, "w", encoding="utf-8").write(text)
PY

today="$(date -u +%Y-%m-%d)"
python3 - "$metainfo" "$ver" "$today" <<'PY'
import re, sys
path, ver, today = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
text = re.sub(
    r'<release version="[^"]*" date="[^"]*"/>',
    f'<release version="{ver}" date="{today}"/>',
    text, count=1,
)
open(path, "w", encoding="utf-8").write(text)
PY

echo
echo "updated $manifest and $metainfo for v$ver."
echo

if command -v flatpak-builder >/dev/null 2>&1; then
  echo "validating with flatpak-builder (this also needs the libmpv module"
  echo "filled in — see the manifest's header — to actually succeed):"
  echo "  flatpak-builder --user --install --force-clean build-dir $manifest"
else
  echo "flatpak-builder not found here — validate on a machine that has it:"
  echo "  flatpak-builder --user --install --force-clean build-dir $manifest"
fi

echo
echo "git diff shows the change; commit it, then (once accepted on Flathub)"
echo "push the equivalent manifest update to Flathub's own repo for this"
echo "app — that push is what actually triggers Flathub's rebuild, not"
echo "anything in this repo. See packaging/README.md."
