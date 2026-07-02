# Pileus

Client Flutter per un backend di streaming **Mycelium** che l'utente ospita
per conto proprio. Un solo codebase, quattro target:

| Target | Entrypoint | Stato |
|---|---|---|
| **Android TV / Fire TV** | `lib/main.dart` | target principale — navigazione D-pad / telecomando |
| **Mobile** (telefono / tablet) | `lib/main_mobile.dart` | UI touch |
| **Desktop** (Linux / Windows) | `lib/main_desktop.dart` | backend player `media_kit`, `window_manager` |
| **Web / PWA** | `lib/main_web.dart` | spike — riusa la UI desktop, richiede un endpoint gRPC-Web sul server (vedi [`docs/WEB.md`](docs/WEB.md)) |

Il core (DI, gRPC/proto, repository, BLoC, player engine, SDUI) è condiviso;
differisce solo il layer *presentation* per target.

> **Lingua:** l'interfaccia è **solo in italiano** per ora. La
> localizzazione (`intl` + file `.arb`) è una milestone successiva; nessuna
> stringa è ancora esternalizzata.

Panoramica dell'architettura in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md);
matrice build/run/package per target in [`docs/BUILD.md`](docs/BUILD.md).

---

## Requisiti

- Un dispositivo **Android TV** o **Fire TV**
  - Fire OS gira a 32 bit → APK `armeabi-v7a`
  - Android TV moderni (Chromecast/Google TV, Shield, Sony/Philips…) →
    APK `arm64-v8a`
- Un server **Mycelium** raggiungibile, gestito dall'utente:
  - gRPC `:50051/tcp`
  - HTTP `:8000/tcp` (`/pileus/info`, proxy immagini `/img`, proxy segmenti)
  - discovery `:51900/udp`
  - stessa LAN del dispositivo, oppure raggiungibile via VPN

Le porte sono centralizzate in `lib/core/config/server_config.dart`
(`ServerPorts`).

---

## Primo avvio (utente)

1. **Discovery del server**
   - automatica: broadcast UDP `MYCELIUM_DISCOVER_V1` su `:51900`, in
     parallelo a un probe TCP dei candidati (host salvato, host compilato in
     build, `mycelium.local`, loopback, `10.0.2.2`, host VPN)
   - manuale: inserimento dell'IP del server con la tastiera a schermo
   - il vincitore viene salvato in `DeviceSession`
2. **Abbinamento del dispositivo** — inserimento di un **codice di
   abbinamento a breve scadenza** generato dalla dashboard admin di
   Mycelium (non è una password). Il campo proto si chiama ancora `pin_hash`
   per compatibilità di wire ma trasporta il codice grezzo.
3. **Profilo** — scelta o creazione di un profilo. I profili sono
   *server-wide*: seguono la persona su ogni dispositivo abbinato. L'ultimo
   profilo attivo viene riselezionato ai cold start.
4. **Home** — righe di catalogo guidate dai plugin del server, ricerca,
   Continue Watching.

Il JWT di sessione vive **solo in memoria**: a ogni avvio a freddo la rotta
`/splash` riesegue il bootstrap e ri-autentica prima di montare le schermate
protette (guard in `lib/core/router/app_router.dart`).

---

## Uso

- **Navigazione** con D-pad / telecomando; tastiera a schermo per gli input
  di testo; gestione del tasto **Back** de-duplicata su Android
  (`lib/main.dart` + `lib/shared/utils/back_dispatch.dart`).
- Le righe della home arrivano dai **plugin del server**; ordine dei plugin
  e visibilità delle singole righe sono configurabili **per profilo**.
- **Ricerca** per plugin, con filtri forniti dal server
  (`GetSearchFilters`).
- **Dettaglio → sorgenti → riproduzione**; distinzione live / on-demand.
- **Impostazioni**
  - *Account*: nome e avatar del profilo, cambia profilo, cambia server,
    logout
  - *Preferenze*: margine bordo schermo (overscan), "Modalità hardware
    modesto", dimensione buffer on-demand / live, stile sottotitoli,
    diagnostica su logcat, svuota cache catalogo
  - configurazione per singolo plugin (`GetPluginSettings` /
    `SavePluginSetting`)
- **Avviso di aggiornamento in-app**: solo notifica (nessun download né
  installazione), rate-limit 6 h — attivo solo nelle build che hanno i
  `--dart-define` Forgejo impostati (vedi `RELEASE.md`).

---

## Architettura

### Mappa dei moduli (`lib/`)

```
core/      config · db · di · grpc · router · theme · update · utils
           device_profile.dart · perf_profile.dart
features/  auth · media · player · settings
           (ognuno: bloc|cubit / data (repository) / presentation)
shared/    sdui · widgets · utils · presentation
```

### Stato e dependency injection

`flutter_bloc` + `get_it` (`lib/core/di/injection.dart`).

- `AuthBloc` è **singleton**: lo stato di auth è condiviso da tutte le
  schermate; viene "svegliato" dallo splash.
- `PluginBloc` e `ContinueWatchingBloc` sono lazy singleton (così la home li
  ritrova già caricati); azzerati con `resetLazySingleton` al logout.
- `DiscoveryBloc`, `DetailsBloc`, `PlaybackBloc`, `SettingsCubit`,
  `ProfileManagementCubit` sono factory.
- `rebuildGrpcClients()` ricrea canale e client su cambio server, spegnendo
  il canale HTTP/2 precedente.

### Trasporto (gRPC + proto)

- Servizi: `AuthService`, `MediaPipeline`, `PluginService`
  (`proto/auth.proto`, `proto/media.proto`; stub generati in
  `lib/core/grpc/generated/`, client sottili in `lib/core/grpc/clients/`).
- `AuthInterceptor` inietta `authorization: Bearer <jwt>`, `x-profile-id` e
  `x-http-host` (host con cui il server costruisce gli URL del proxy
  immagini).
- Deadline per-RPC di 20 s (`media_client.dart`).
- Canale a scelta di piattaforma: `grpc_channel_io.dart` (nativo) /
  `grpc_channel_web.dart` (gRPC-Web).
- **Pinning opzionale del fingerprint del certificato TLS** (`crypto`,
  `DeviceSession.tlsFingerprint`).

### UI guidata dal server (SDUI)

`lib/shared/sdui/` traduce i `CatalogDef` del server in view model
`CardCarouselBlock`. Contratto di forward-compat: valori non riconosciuti di
`card_layout` / `style_hint` / `section_kind` vanno ignorati, mai far
crashare. `sport_theme.dart` per il tema delle righe sportive.

> Nota: v1 costruisce di fatto solo `CardCarouselBlock`; il resto della
> gerarchia `sealed` in `sdui_block.dart` è scaffolding riservato a
> migrazioni future (dettaglio/hero).

### Player — doppio backend

Facade neutra in `lib/features/player/engine/player_engine.dart`. Le
schermate parlano solo con `PlayerEngine`, mai con i tipi dei backend.

| Piattaforma | Backend |
|---|---|
| **Android** (TV + mobile) | **ExoPlayer** via `better_player_plus` — HW decode MediaCodec→Surface zero-copy, fallback decoder reale, selezione tracce audio/sottotitoli HLS |
| **Desktop** (Linux / Windows) | libmpv via `media_kit` |
| **Web** | HTML5 `<video>` in `HtmlElementView` (+ hls.js per HLS non nativo) |

I workaround per i box Amlogic deboli sono nel manifest Android: Impeller
forzato su OpenGL ES, `EnableSurfaceControl=false` (vedi
`android/app/src/main/AndroidManifest.xml`).

> Le librerie native di libmpv (`media_kit_libs_android_video`) vengono
> comunque impacchettate nell'APK anche se su Android la riproduzione usa
> ExoPlayer — è la ragione principale per cui l'APK va splittato per ABI.

### Persistenza

Solo `SharedPreferences`. `lib/core/db/` è naming legacy in stile Isar con
classi scritte a mano (`toJson` / `readFrom` / `writeTo`). Le risposte di
catalogo sono cache-ate sotto il keyspace `layoutcache:` con TTL e wipe al
bump di versione dello schema.

### Profilo prestazioni

- `lib/core/perf_profile.dart` — `lowPowerUi`: taglia blur / shader / le
  transizioni di rotta su hardware debole.
- `lib/core/device_profile.dart` — rilevamento nativo `isTv` / `isWeak`
  (FEATURE_LEANBACK / UiModeManager).
- `lib/core/utils/perf_log.dart` — `perf()` / `installJankLogger()`, grep
  `pileus/perf` e `pileus/jank` in `adb logcat` (attivi anche in release se
  la diagnostica è abilitata).
- Cache immagini: 64 MB / 200 voci (40 MB / 140 in low-power). Ogni immagine
  di rete è decodificata alla dimensione fisica con cui è disegnata
  (`lib/core/utils/image_sizing.dart` — `cacheWidthFor`, `posterSrc`,
  `backdropSrc`).

---

## Flusso di riproduzione

```
discovery → abbinamento → profilo
  → GetCatalog (cache TTL) → GetDetails (oneof *Details tipizzato)
  → GetStreams (lista StreamSource)
  → ResolveStream (server-streaming: progress… → resolved_url + http_headers)
  → PlayerEngine.open()
```

Gli URL delle immagini dei metadata passano per la size-ladder; le immagini
fornite dai plugin nelle carousel della home passano per il proxy
`GET :8000/img?u=<base64url>` di Mycelium (transcodifica WebP, fail-open).

---

## Rendering e scaling su TV

Su Android TV il firmware normalizza qualsiasi pannello (FHD/QHD/UHD) a
~960×540 dp: il layout logico è identico su 1080p e 4K e il rendering
avviene alla risoluzione fisica via `devicePixelRatio`. Le dimensioni dei
layout sono frazioni dell'altezza schermo, baseline di design 1920×1080. Il
margine di overscan è regolabile dall'utente in Preferenze e riflette la
modifica a caldo.

> Il moltiplicatore testo per le piattaforme non-TV (`main.dart`, fisso
> `1.35` con un trim `clamp(0.85, 1.0)` sull'altezza finestra) si applica
> solo quando `isAndroidTv` è falso, cioè sui target desktop / web.

---

## Build per Android TV / Fire TV

Per il rilascio **non** usare l'APK "fat": genera un APK per architettura.

```sh
flutter build apk --release --flavor tv --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --build-name=<X.Y.Z> --build-number=<n>
```

Il progetto ha due flavor Android da un solo codebase:

| Flavor | Target | applicationId | Entrypoint | Comando |
|---|---|---|---|---|
| `tv` | Android TV / Fire TV | `com.lotho33.pileus` | `lib/main.dart` | `flutter run --flavor tv` |
| `mobile` | telefono / tablet | `com.lotho33.pileus.mobile` | `lib/main_mobile.dart` | `flutter run --flavor mobile -t lib/main_mobile.dart` |

Il codice sotto la UI (core, gRPC/proto, repository, BLoC, player engine) è
condiviso; solo il layer *presentation* differisce (`lib/mobile/`). La
mobile è portrait, landscape solo durante la riproduzione.

Il comando TV è allineato alla CI (`.forgejo/workflows/release.yml`), che
aggiunge anche i `--dart-define` di build (vedi sotto). Produce in
`build/app/outputs/flutter-apk/` (prefisso `app-tv-…`):

- `app-armeabi-v7a-release.apk` — Fire TV Stick (tutti i modelli), box
  Android TV economici
- `app-arm64-v8a-release.apk` — Android TV moderni

Note:

- `--split-per-abi` porta l'APK a circa un terzo del fat APK.
- `--target-platform android-arm,android-arm64` limita gli ABI (niente
  `x86_64`); non usare `ndk { abiFilters }`, va in conflitto con
  `--split-per-abi`.
- **`-PpileusExcludeMpv=true`** rimuove `libmpv.so` + helper (~12 MB/ABI):
  su Android la riproduzione è sempre ExoPlayer, `_MpvPlayerEngine` lancia se
  costruito. **`-PpileusR8=true`** attiva minificazione R8 + shrink risorse
  (`proguard-rules.pro`). Entrambi i flag sono **spenti di default** (un
  mis-strip si vede solo a runtime) e **accesi in CI** su tutti i canali
  Android — `release.yml` (beta) e `store.yml` (store); un comando locale
  `flutter build apk` li lascia spenti. Il tree-shaking delle icone Material
  è invece sempre attivo (default Flutter).
- L'offuscamento Dart (`--obfuscate --split-debug-info`) è attivo in
  entrambi i workflow CI; i simboli + `mapping.txt` di R8 vengono archiviati
  con la release per de-offuscare crash/ANR.

### `--dart-define` di build

| Define | Uso |
|---|---|
| `PILEUS_FORGEJO_URL` | istanza Forgejo per il check "nuova versione" in-app |
| `PILEUS_FORGEJO_REPO` | `owner/repo` per lo stesso check |
| `PILEUS_MYCELIUM_HOST` | host Mycelium di default compilato nell'APK (per TV dove `mycelium.local` non risolve) |

Runtime: la variabile d'ambiente `MYCELIUM_HOST` è letta all'avvio come
override.

> Per le build destinate agli store questi define vanno **omessi**: senza
> `PILEUS_FORGEJO_URL`/`REPO` il check di aggiornamento è un no-op silenzioso
> e l'APK non contatta host personali.

### Identità e firma

- `applicationId` = `namespace` = `com.lotho33.pileus` — **immutabile**
  (cambiarlo = app diversa, niente update sopra un'installazione esistente).
- Firma di release → `RELEASE.md`. Con `-PpileusRequireSigning=true` il
  build fallisce se manca `android/key.properties` invece di ripiegare sulle
  chiavi di debug (usato dalla pipeline store).
- `android/app/src/main/res/xml/network_security_config.xml` — permette il
  traffico cleartext (il server Mycelium su LAN è quasi sempre `http://`),
  con trust dei soli CA di sistema. Punto unico dove restringere la policy.

### Build per Play Store / Amazon Appstore

Il workflow `.forgejo/workflows/store.yml` (`workflow_dispatch`, input = tag)
produce gli artefatti store, **distinti** dagli APK del canale beta:

- **AAB firmato** (richiesto da Play) + **APK per-ABI firmati** (per Amazon)
- `--dart-define=PILEUS_STORE_BUILD=true` → check aggiornamento in-app
  compilato fuori, nessun host Forgejo/Mycelium personale nel binario
- `-PpileusRequireSigning=true` → niente fallback a firma debug
- `--obfuscate --split-debug-info` → simboli + `mapping.txt` R8 archiviati

Gli artefatti finiscono nel *generic package registry* privato del repo
Forgejo, da caricare a mano su Play Console / Amazon Developer.
Gli adempimenti lato console (privacy policy, Data Safety / IARC,
dichiarazione Foreground Service, screenshot, server demo per la review)
sono tracciati fuori dal repo pubblico.

---

## Sviluppo

- Il **Flutter SDK è nel devcontainer** (`.devcontainer/`), non
  sull'host: `docker exec <container> flutter analyze` / `flutter test` sul
  workspace montato (il nome del container cambia ai riavvii — `docker ps`).
- `flutter analyze` è pulito (0 issue).
- Test: `test/shared/sdui/sdui_parser_test.dart`.

---

## Rilascio

Vedi `RELEASE.md`.

## Licenza

**GPL-3.0-only** — vedi [`LICENSE`](LICENSE). `pubspec.yaml` ha
`publish_to: 'none'` (non è un pacchetto pub).

Il font incluso (DM Sans, `assets/fonts/DMSans/`) è sotto SIL Open Font
License 1.1 — vedi `assets/fonts/DMSans/OFL.txt`.
