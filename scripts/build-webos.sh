#!/usr/bin/env bash
# Builds the LG webOS package of the TV web UI (lib/main_web_tv.dart).
#
#   scripts/build-webos.sh               # build/webos/app/ + build/webos/*.ipk
#   scripts/build-webos.sh --simulator   # same, then opens it in the webOS TV 26 Simulator
#   scripts/build-webos.sh --debug       # inspectable app (DevTools on a dev-mode TV)
#   scripts/build-webos.sh --720p        # 1280x720 package (build/webos-720p/) — LG's
#                                        # Seller Lounge wants one per resolution; the UI
#                                        # itself is resolution-independent
#
# Uses flutter / ares-package directly when they're on PATH (CI); otherwise
# flutter through `devc` (devcontainer) and ares-* through the
# fedora-toolbox-44 toolbox (local Aurora host). Output lives in its own build/webos/ so the
# Android/PWA/Tizen builds never leak into the package (they share build/web).
# What it fixes up after `flutter build web`, each of which otherwise ships a
# broken app — see docs/TIZEN_WEBOS.md:
#   - <base href="./">: a packaged app loads from file://, "/" resolves every
#     asset against the filesystem root (endless boot spinner);
#   - --no-web-resources-cdn: CanvasKit from the package, not www.gstatic.com
#     (no internet = no start, and a slower cold start on TV);
#   - appinfo.json version synced from pubspec.yaml (LG wants it to grow on
#     every upload) + icons copied in.
set -euo pipefail

cd "$(dirname "$0")/.."

SIMULATOR=0
DEBUG=0
RESOLUTION=1920x1080
OUT=build/webos
for arg in "$@"; do
  case "$arg" in
    --simulator) SIMULATOR=1 ;;
    --debug) DEBUG=1 ;;
    --720p) RESOLUTION=1280x720; OUT=build/webos-720p ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

VERSION=$(sed -n 's/^version: *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' pubspec.yaml)
[ -n "$VERSION" ] || { echo "no version in pubspec.yaml" >&2; exit 1; }

APP=$OUT/app
FLUTTER_ARGS="-t lib/main_web_tv.dart --release --base-href / --no-web-resources-cdn"
[ -n "${PILEUS_BUILD_NUMBER:-}" ] && FLUTTER_ARGS="$FLUTTER_ARGS --build-number=$PILEUS_BUILD_NUMBER"

echo "==> flutter build web (TV UI) $VERSION $RESOLUTION"
if command -v flutter >/dev/null 2>&1; then
  rm -rf "$OUT"
  mkdir -p "$APP"
  # shellcheck disable=SC2086
  flutter build web $FLUTTER_ARGS -o "$PWD/$APP"
else
  # The container runs as root, so what it wrote last time is root-owned.
  devc rm -rf "$OUT"
  mkdir -p "$APP"
  # -o must be absolute and is resolved inside the container, hence $PWD there.
  devc bash -c "flutter build web $FLUTTER_ARGS -o \"\$PWD/$APP\" \
    && chown -R $(id -u):$(id -g) \"$OUT\""
fi

echo "==> webOS fix-ups"
sed -i 's|<base href="/">|<base href="./">|' "$APP/index.html"
grep -q '<base href="./">' "$APP/index.html" \
  || { echo "base href not rewritten" >&2; exit 1; }
cp packaging/webos/icon.png packaging/webos/largeIcon.png "$APP/"
python3 - "$VERSION" "$DEBUG" "$RESOLUTION" packaging/webos/appinfo.json "$APP/appinfo.json" <<'PY'
import json, sys
version, debug, resolution, src, dst = sys.argv[1], sys.argv[2] == "1", *sys.argv[3:]
info = json.load(open(src))
info["version"] = version
info["inspectable"] = debug
info["resolution"] = resolution
json.dump(info, open(dst, "w"), indent=2)
PY

ares() {
  # ares-* are node scripts: on PATH without node (the Aurora host sees the
  # toolbox's ~/.npm-global/bin) they can't run, so go through the toolbox.
  if command -v node >/dev/null 2>&1 && command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    toolbox run -c fedora-toolbox-44 "$@"
  fi
}

echo "==> ares-package"
ares ares-package "$APP" -o "$OUT"
ls -1 "$OUT"/*.ipk

if [ "$SIMULATOR" = 1 ]; then
  echo "==> webOS TV 26 Simulator"
  ares ares-launch -s 26 \
    -sp "$HOME/.local/share/webos-tv-simulator" "$PWD/$APP"
fi
