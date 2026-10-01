# Pileus on Samsung Tizen / LG webOS

Status: **prep work done, unverified on real hardware/emulators.** This is
explicitly a "not urgent, do it later" track — everything below compiles
and analyzes clean, but nobody has actually opened it in Tizen Studio or
the webOS TV Simulator yet. Read every "unverified" note as a real gap,
not a formality.

## What this is

A third web build — alongside `lib/main_web.dart` (the desktop-styled PWA)
— that boots the real **D-pad-navigable TV UI** (`PileusApp`/`appRouter`,
the exact widget tree `lib/main.dart` runs on Android TV/Fire TV) instead
of the mouse/keyboard-oriented `lib/desktop/` screens. Packaged as a
Tizen `.wgt` (Samsung) or webOS `.ipk` (LG) app.

| Piece | TV web |
|---|---|
| UI | `lib/main.dart`'s TV screens via `appRouter` (D-pad, on-screen keyboard, TvFocusable) |
| Entry point | `lib/main_web_tv.dart` → `PileusApp` → `appRouter` |
| Transport | gRPC-Web, same as `main_web.dart` — `lib/core/grpc/grpc_channel_web.dart` |
| Discovery | `ServerDiscoveryScreen` (TV's own) — its LAN auto-scan degrades harmlessly to manual entry on web (see below); no UDP/mDNS ever runs here |
| Server modes | LAN (plain `http://`) and remote/HTTPS (`https://host[:port]`, see `lib/core/grpc/server_address.dart`) — both work from the same manual field |
| Remote-control input | standard arrows/Enter/Escape (already handled — any browser reports these normally) + a JS bridge in `web/index.html` for Tizen/webOS-specific keyCodes (Back, media transport) |

## Build

```sh
flutter build web -t lib/main_web_tv.dart --release --base-href /
```

Do **not** add `--wasm` — see "Renderer / old-Chromium compatibility"
below. The output lands in `build/web/`, same folder `main.dart`'s and
`main_web.dart`'s builds use (there's only one `web/` source directory for
the whole project — `web/index.html`, `web/manifest.json`, `web/icons/`
are shared by all three entry points; the TV-only remote-key bridge script
in `index.html` is dead code outside an actual Tizen/webOS keyCode, so it's
harmless there).

## Why the TV UI could just be reused

Reusing `appRouter` (TV screens) on web was the open question going in —
those screens have real `dart:io` calls (`Platform.isAndroid`,
`NetworkInterface.list`, `Socket.connect`, in `server_discovery_screen.dart`
mainly). Verified: `flutter build web -t lib/main_web_tv.dart` compiles
clean, because every one of those calls is already `kIsWeb`-gated
(`_isAndroid`, `_sweepLan`'s `if (kIsWeb) return null;`, `host_resolver_io.
dart`/`host_resolver_stub.dart`'s conditional-import split). `dart:io`
itself resolves fine at web-compile time (it has a web stub in the SDK);
only *calling* an unsupported member at runtime throws, and nothing
reachable on web does.

What genuinely needed fixing: a packaged app is **never** "served by
mycelium" the way a browser visiting Mycelium's own `/app/` is — there is
no same-origin host to default to, so *every* connection goes through the
manual/explicit-host path. That path existed (`WebDiscoveryScreen`'s "app
hosted somewhere else" override) but always assumed `http://` and the LAN
`:8000` port — wrong for remote/HTTPS mode. Fixed in
`grpc_channel_web.dart` (`_webOrigin`), `host_resolver.dart`
(`myceliumHttpBase`'s web branch) and `auth_interceptor.dart`
(`_httpHostHeader`/`_httpSchemeHeader`'s web branch) — all three now check
`remote`/`remotePort` (set by `setGrpcHost()`, same call every platform
already makes) before falling back to `Uri.base`.

`ServerDiscoveryScreen`'s auto-scan (candidates + `/24` sweep) still runs
first on TV-web, same as everywhere else — it's not literally skipped, but
`_sweepLan` returns immediately on web and the only candidate left
(`127.0.0.1`) fails fast, so it falls through to the manual field in under
`_timeout` (2 s) with nothing user-visible beyond a brief spinner. That
satisfies "no UDP/mDNS discovery on web" (never runs there at all — see
`host_resolver_stub.dart`) without a fourth discovery screen to maintain.

## Remote control input

Arrows, Enter/OK, Escape and standard media keys (`LogicalKeyboardKey.
mediaPlayPause`, `.mediaRewind`/`.mediaFastForward` in
`playback_screen/view.dart`) already work on **any** web build, TV or
not — a browser reports these as normal
`KeyboardEvent`s and Flutter's own web key-mapping understands them.

What's TV-remote-specific and *not* standard:

| Button | Tizen keyCode | webOS keyCode | Bridged to |
|---|---|---|---|
| Back/Return | 10009 | 461 | `Escape` (every `onEsc`/`LogicalKeyboardKey.goBack` handler in the app already also checks `.escape` — see `back_dispatch.dart`) |
| Play | 415 | — | `MediaPlay` |
| Pause | 19 | — | `MediaPause` |
| Play/Pause | 10252 | — | `MediaPlayPause` |
| Stop | 413 | — | `MediaStop` |
| Rewind | 412 | — | `MediaRewind` |
| Fast-forward | 417 | — | `MediaFastForward` |

Implemented as a small inline `<script>` in `web/index.html`, registered
**before** `flutter_bootstrap.js` loads so it's first in the window's
capture-phase listener order — it can `stopImmediatePropagation()` the raw
proprietary event and dispatch a synthetic standard one before Flutter's
own listener ever sees the original.

**Unverified.** These keyCodes are transcribed from each platform's
published remote-control reference, not confirmed against a real device —
webOS's media-key codes specifically are a guess (LG's docs are less
consistent about legacy `keyCode` than Tizen's); confirm all of them on an
actual Tizen Studio / webOS Simulator session (see below) and adjust the
`REMOTE_KEYCODE_MAP` in `web/index.html` if any are wrong. If a TV's
browser already reports a *standard* `key` string for a button (some
newer Tizen/webOS versions do, for media keys especially), the bridge is
simply redundant for that one — harmless, not double-handled, since it
only intercepts keyCodes explicitly listed in the map.

## HLS playback

Already handled, nothing new needed: `web_playback_screen.dart` checks
`video.canPlayType('application/vnd.apple.mpegurl')` and falls back to the
bundled `web/hls.min.js` whenever it's not `'probably'` (true for every
Chromium-based browser, Tizen/webOS included — only Safari plays HLS
natively) — see its own extensive doc comment for the exact decision.
The bundled `hls.min.js` is already an ES5-transpiled build (verified: no
arrow functions/`class`/
`async` in it), which is what makes it runnable on an old TV's Chromium in
the first place — no need to swap in an older hls.js major version.

**Unverified**: MSE (Media Source Extensions, what hls.js needs) has been
in Chromium since ~M23/2013, so any Tizen (Chromium-based since ~4.0,
2018) or webOS (Chromium-based since ~3.0, 2017) generation should have
it — but "should" isn't "confirmed on a real unit." Also unverified:
whether a TV's WebView enforces any additional CORS/mixed-content
restriction beyond a regular desktop browser's.

## Renderer / old-Chromium compatibility

Build **without** `--wasm` (the command above already omits it). Flutter's
default (non-wasm) web compile output needs only WebAssembly MVP (no
GC proposal) + WebGL for CanvasKit, both present since roughly Chromium 57
(2017) — comfortably covers Tizen 4.0+ (2018+, Samsung's official "Tizen
TV" web-app-capable line) and webOS 3.5+/4.0+ (2017-2018+). `--wasm`
(skwasm) needs the WasmGC proposal, which is far newer and almost
certainly absent on any TV-embedded Chromium still receiving updates
today — don't use it for this target regardless of what a future Flutter
default becomes.

**Unverified**: the actual minimum Tizen/webOS generation this runs on at
all — the range above is inferred from each platform's known Chromium
version, not measured against a real device. Older Tizen (2.x/3.0,
pre-2017, pre-Chromium or very early Chromium) almost certainly can't run
any of this; Flutter's old non-WASM "html" renderer (which needed nothing
but Canvas2D/DOM) would have been the fallback for that generation, but it
was deprecated/removed from recent Flutter releases, so it's not an option
with the SDK this project is on.

## Packaging

Templates live in `packaging/tizen/` and `packaging/webos/` — both need to
be copied into the built output (they can't live in `web/` itself: that
folder is shared with the `main.dart`/`main_web.dart` builds, which don't
want a Tizen/webOS manifest sitting in their own output).

```sh
flutter build web -t lib/main_web_tv.dart --release --base-href /

# Tizen
cp packaging/tizen/config.xml packaging/tizen/icon.png build/web/
# then open build/web/ as a Tizen Web project in Tizen Studio, or:
tizen package -t wgt -s <your-certificate-profile> -- build/web

# webOS
cp packaging/webos/appinfo.json packaging/webos/icon.png packaging/webos/largeIcon.png build/web/
ares-package build/web
```

`packaging/tizen/config.xml` has a placeholder `PLACEHOLDERAUTH` author/
package ID — Tizen requires a real author certificate (Tizen Studio >
Certificate Manager) before it'll install anywhere; replace the
placeholder with the 10-character ID that certificate generates. webOS's
`appinfo.json` has no equivalent signing requirement for sideloading onto
a developer-mode TV or the Simulator.

Both manifests declare unrestricted internet access / CORS (`access
origin="*"` on Tizen; webOS has no equivalent restriction by default) —
necessary because the actual server address is only known at runtime
(typed by whoever pairs the TV), never at build time.

**Unverified**: neither manifest has been run through the real packaging
tool yet — treat both as a first-draft starting point, not a
guaranteed-correct schema. Re-check field names/values against whichever
Tizen Studio / webOS CLI version you actually have installed; these tools
occasionally add required fields between versions.

## Testing in the emulators

Neither SDK is installed in this project's devcontainer (they're
Windows/macOS/Linux-desktop GUI installs, not something a CLI devcontainer
sanely hosts) — this is written from documentation/knowledge of the
tooling, not run-tested here. Treat every step as a starting point to
verify, not a guaranteed-working script.

### Samsung Tizen Studio

1. Install **Tizen Studio** (`tizen.org/development/tizenstudio`) with the
   **TV Extension** package (Package Manager → Extension SDK → TV).
2. **Certificate Manager** (Tools menu) → create an author certificate if
   you don't have one yet. Note the 10-character author ID it generates —
   goes into `config.xml`'s `PLACEHOLDERAUTH`.
3. **File → New → Tizen Project → Web Application → Empty** (or "Import"
   pointing at `build/web/` directly, since it's already a complete web
   app — config.xml + icon.png copied in per "Packaging" above).
4. **Tools → Emulator Manager** → create a TV emulator (pick a recent
   Tizen TV API version, 6.0+). Launch it.
5. Right-click the project → **Run As → Tizen Web Application** with the
   emulator as target. Tizen Studio builds, signs (with your certificate)
   and installs automatically.
6. The emulator's remote-control panel (usually a side toolbar) sends the
   real Tizen keyCodes, including 10009 for Back — this is what actually
   exercises `web/index.html`'s bridge script, not a regular keyboard.

### LG webOS TV Simulator

1. Install the **webOS TV SDK** (`webostv.developer.lge.com`) — includes
   the CLI (`ares-*` commands) and the **TV Simulator** app.
2. From the built+manifest-copied output (`build/web/` with `appinfo.json`
   + icons per "Packaging" above): `ares-package build/web` produces an
   `.ipk`.
3. Launch **webOS TV Simulator** (a specific version matching the webOS
   generation you're targeting — the SDK ships several).
4. `ares-install -d <simulator-device-name> <path-to>.ipk` (or drag the
   `.ipk` onto the Simulator window, if that build supports it), then
   `ares-launch -d <simulator-device-name> tv.pileus.app`.
5. The Simulator's remote-control overlay sends real webOS keyCodes
   (including 461 for Back) the same way the Tizen emulator does.

### What to actually check once it's running

- Pairing/discovery: does the manual field reach a real Mycelium (LAN IP
  *and* a `https://` remote one) and does the on-screen keyboard's `:`/`/`
  keys (for URL entry, see `on_screen_keyboard.dart`) actually produce
  those characters on the emulator's virtual keyboard input path?
- Back button: does it do a full "go back" from every screen, matching
  Android TV's hardware Back — not just Escape-closing an overlay?
- Play/Pause/FF/RW from the remote (not the on-screen player controls):
  confirmed reaching `playback_screen/view.dart`'s key handler?
- HLS playback actually starts (not just "resolves a URL and shows a
  black screen") — the first real signal of whether MSE/hls.js works on
  that specific TV's Chromium build.
- Cold-start perf: `lowPowerUi` defaults to **on** for this entry point
  (see `main_web_tv.dart`'s own doc) — if a given TV generation turns out
  capable enough that this reads as overly conservative, that's a
  settings toggle away from the user, not a code change.
