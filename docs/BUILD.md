# Build / run / package — per target

Il Flutter SDK vive nel **devcontainer** (`.devcontainer/`), non sull'host:
`docker exec <container> flutter …` sul workspace montato (il nome del
container cambia ai riavvii — `docker ps`).

Gate sempre verdi prima di un merge: `flutter analyze` (0 issue) e
`flutter test`. Li applica anche la CI (`.forgejo/workflows/ci.yml`,
`.github/workflows/ci.yml`).

## Matrice

| Target | Run (dev) | Package | Workflow CI |
|---|---|---|---|
| **Android TV / Fire TV** | `flutter run --flavor tv` | `flutter build apk --release --flavor tv --split-per-abi --target-platform android-arm,android-arm64` | `release.yml` (su tag `vX.Y.Z`, verde da 14+ release consecutive) · `store.yml` (AAB, manuale, **mai eseguita con successo — nessun AAB firmato è mai stato prodotto**) |
| **Mobile** | `flutter run --flavor mobile -t lib/main_mobile.dart` | `flutter build appbundle --release --flavor mobile -t lib/main_mobile.dart` | `store.yml` (accanto a `tv`, stesso stato: mai eseguita con successo) |
| **Desktop — Linux** | `flutter run -d linux -t lib/main_desktop.dart` | `flutter build linux --release -t lib/main_desktop.dart` | `linux.yml` (manuale, allega tarball) — **esiste ma non ha mai completato una run in tutta la storia del repo (Forgejo o GitHub)** |
| **Desktop — Windows** | `flutter run -d windows -t lib/main_desktop.dart` | `flutter build windows --release -t lib/main_desktop.dart` | `.github/workflows/windows.yml` (GitHub-hosted, manuale) + `.forgejo/workflows/windows.yml` (self-hosted, mai registrato) — **entrambi esistono nel repo ma non hanno mai completato una run**, trattare il primo lancio come uno smoke test |
| **Web / PWA** | `flutter run -d chrome -t lib/main_web.dart` | `flutter build web --release -t lib/main_web.dart --base-href /` | `web.yml` su Forgejo (manuale, mai eseguita); **su GitHub `release.yml` builda e allega il tarball web ad ogni release da v1.2.6** — quello è il percorso che conta oggi |

## Flag Android (`tv` e `mobile`)

Spenti di default (un mis-strip si vede solo a runtime), **accesi in CI** su
tutti i canali:

| Flag Gradle | Effetto |
|---|---|
| `-PpileusExcludeMpv=true` | rimuove `libmpv.so` + helper (~12 MB/ABI). Android usa sempre ExoPlayer; `_MpvPlayerEngine` lancia se costruito |
| `-PpileusR8=true` | R8 code shrink + `shrinkResources` (`android/app/proguard-rules.pro`) |
| `-PpileusRequireSigning=true` | il build fallisce se manca `android/key.properties` invece di ripiegare sulle chiavi di debug (pipeline store) |

Offuscamento Dart (`--obfuscate --split-debug-info`) attivo nei workflow CI;
simboli + `mapping.txt` R8 archiviati con la release.

APK `tv` arm64 release con i flag ≈ **24 MB** (vs ~36 senza). Mobile ≈ 23.5 MB.

## `--dart-define` di build

| Define | Uso |
|---|---|
| `PILEUS_FORGEJO_URL` / `PILEUS_FORGEJO_REPO` | istanza + `owner/repo` per il check "nuova versione" in-app |
| `PILEUS_MYCELIUM_HOST` | host Mycelium di default compilato nel binario (per TV dove `mycelium.local` non risolve) |
| `PILEUS_STORE_BUILD=true` | disattiva il check aggiornamento e non compila alcun host personale (build per gli store) |

Runtime: `MYCELIUM_HOST` è letta all'avvio come override.

> Per le build store i define `PILEUS_FORGEJO_*` / `PILEUS_MYCELIUM_HOST`
> vanno **omessi**: il binario non contatta host personali.

## Approfondimenti

- Processo di rilascio (tag, firma, store): [`../RELEASE.md`](../RELEASE.md)
- Specifiche del target web e cosa manca lato server:
  [`WEB.md`](WEB.md)
- Architettura del core condiviso: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Self-hosting del backend: [`SELF_HOSTING.md`](SELF_HOSTING.md)
