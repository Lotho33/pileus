#!/usr/bin/env bash
# Polls the Forgejo releases API and installs the newest Linux tarball over
# INSTALL_DIR when the tag changes. Meant to run from a systemd timer.
#
# Configure via /etc/default/pileus-update or by editing the defaults below.
set -euo pipefail

FORGEJO_URL="${FORGEJO_URL:-https://YOUR-FORGEJO}"
REPO="${REPO:-OWNER/pileus-player}"
INSTALL_DIR="${INSTALL_DIR:-/opt/pileus}"
STATE_FILE="${STATE_FILE:-/var/lib/pileus/installed-tag}"
# Set to 1 to also accept pre-release (beta) tags.
ALLOW_PRERELEASE="${ALLOW_PRERELEASE:-1}"

api="${FORGEJO_URL}/api/v1/repos/${REPO}/releases?limit=10"
json="$(curl -fsSL -H 'Accept: application/json' "$api")"

# Pick the newest non-draft (optionally non-prerelease) release with a
# linux tarball asset.
read -r tag asset_url < <(
  echo "$json" | python3 - "$ALLOW_PRERELEASE" <<'PY'
import json, sys
allow_pre = sys.argv[1] == "1"
for rel in json.load(sys.stdin):
    if rel.get("draft"): continue
    if rel.get("prerelease") and not allow_pre: continue
    for a in rel.get("assets", []):
        n = a.get("name", "")
        if n.startswith("pileus-") and n.endswith("-linux-x64.tar.gz"):
            print(rel["tag_name"], a["browser_download_url"])
            sys.exit(0)
sys.exit(0)
PY
)

[ -n "${tag:-}" ] || { echo "no linux release found"; exit 0; }

mkdir -p "$(dirname "$STATE_FILE")"
current="$(cat "$STATE_FILE" 2>/dev/null || true)"
if [ "$tag" = "$current" ]; then
  echo "already on $tag"
  exit 0
fi

echo "updating: ${current:-none} -> $tag"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$asset_url" -o "$tmp/pileus.tar.gz"

# Atomic-ish swap: unpack next to the old dir, then rename.
rm -rf "${INSTALL_DIR}.new"
mkdir -p "${INSTALL_DIR}.new"
tar xzf "$tmp/pileus.tar.gz" -C "${INSTALL_DIR}.new"
rm -rf "${INSTALL_DIR}.old"
[ -d "$INSTALL_DIR" ] && mv "$INSTALL_DIR" "${INSTALL_DIR}.old"
mv "${INSTALL_DIR}.new" "$INSTALL_DIR"
rm -rf "${INSTALL_DIR}.old"

echo "$tag" > "$STATE_FILE"
echo "installed $tag in $INSTALL_DIR"
