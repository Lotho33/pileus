#!/usr/bin/env bash
# Builds the Samsung Tizen package of the TV web UI (lib/main_web_tv.dart).
#
#   scripts/build-tizen.sh               # build/tizen/app/ + build/tizen/Pileus.wgt
#   scripts/build-tizen.sh --install     # same, then installs + launches it on the
#                                        # first `sdb devices` target (emulator or a
#                                        # dev-mode TV); TIZEN_TARGET=<serial> to pick one
#
# Uses flutter directly when it's on PATH (CI), otherwise through `devc`
# (devcontainer). The Tizen CLI comes from TIZEN_STUDIO (default
# ~/tizen-studio) and signs with its active certificate profile
# (TIZEN_PROFILE to override). Output lives in its own build/tizen/ so the
# Android/PWA/webOS builds never leak into the package (they share build/web).
# Fix-ups after `flutter build web` — same reasons as scripts/build-webos.sh,
# see docs/TIZEN_WEBOS.md:
#   - <base href="./">: a packaged app loads from file://;
#   - --no-web-resources-cdn: CanvasKit from the package, not www.gstatic.com;
#   - $WEBAPIS/webapis/webapis.js: Samsung's `webapis` object (TV's own IP for
#     discovery) only exists if the page loads it, and only a Tizen package can;
#   - config.xml version synced from pubspec.yaml + icon copied in.
set -euo pipefail

cd "$(dirname "$0")/.."

INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

TIZEN_STUDIO=${TIZEN_STUDIO:-$HOME/tizen-studio}
TIZEN=$TIZEN_STUDIO/tools/ide/bin/tizen
SDB=$TIZEN_STUDIO/tools/sdb
[ -x "$TIZEN" ] || { echo "Tizen CLI not found at $TIZEN" >&2; exit 1; }

VERSION=$(sed -n 's/^version: *\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' pubspec.yaml)
[ -n "$VERSION" ] || { echo "no version in pubspec.yaml" >&2; exit 1; }

OUT=build/tizen
APP=$OUT/app
FLUTTER_ARGS="-t lib/main_web_tv.dart --release --base-href / --no-web-resources-cdn"
[ -n "${PILEUS_BUILD_NUMBER:-}" ] && FLUTTER_ARGS="$FLUTTER_ARGS --build-number=$PILEUS_BUILD_NUMBER"

echo "==> flutter build web (TV UI) $VERSION"
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

echo "==> Tizen fix-ups"
sed -i 's|<base href="/">|<base href="./">|' "$APP/index.html"
grep -q '<base href="./">' "$APP/index.html" \
  || { echo "base href not rewritten" >&2; exit 1; }
sed -i 's|</head>|  <script src="$WEBAPIS/webapis/webapis.js"></script>\n</head>|' "$APP/index.html"
grep -q 'webapis/webapis.js' "$APP/index.html" \
  || { echo "webapis.js not injected" >&2; exit 1; }
cp packaging/tizen/icon.png "$APP/"
sed "0,/^        version=\"[^\"]*\"/s//        version=\"$VERSION\"/" \
  packaging/tizen/config.xml > "$APP/config.xml"
grep -q "version=\"$VERSION\"" "$APP/config.xml" \
  || { echo "config.xml version not synced" >&2; exit 1; }

echo "==> tizen package"
SIGN=()
[ -n "${TIZEN_PROFILE:-}" ] && SIGN=(-s "$TIZEN_PROFILE")
# The .wgt is written inside the packaged folder itself; move it out.
"$TIZEN" package -t wgt "${SIGN[@]}" -- "$PWD/$APP"
mv "$APP"/*.wgt "$OUT/Pileus.wgt"
ls -1 "$OUT/Pileus.wgt"

if [ "$INSTALL" = 1 ]; then
  TARGET=${TIZEN_TARGET:-$("$SDB" devices | awk 'NR>1 && $1 {print $1; exit}')}
  [ -n "$TARGET" ] || { echo "no sdb target (start the emulator or sdb connect <tv-ip>)" >&2; exit 1; }
  APP_ID=$(sed -n 's/.*tizen:application id="\([^"]*\)".*/\1/p' packaging/tizen/config.xml)
  echo "==> install + launch on $TARGET"
  "$TIZEN" install -s "$TARGET" -n Pileus.wgt -- "$PWD/$OUT"
  "$TIZEN" run -s "$TARGET" -p "$APP_ID"
fi
