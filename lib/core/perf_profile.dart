/// Process-wide "hardware modesto" flag.
///
/// Set once at startup from `SettingsRepository.getLowPowerMode()` (see
/// `main.dart`), and again by the Preferenze toggle. Read by leaf widgets
/// that would otherwise make a weak TV-box GPU compile an expensive Skia
/// shader on first use — blur `BoxShadow`s (`AppScale.focusGlow`),
/// `BackdropFilter`, logo glow — and by places that can shed per-frame
/// compositing work (route transition scale). The player also reads it to
/// keep its demux buffer small on low-RAM boxes.
///
/// A plain mutable global on purpose: `AppScale` is `static`, and dozens of
/// small widgets read this — threading it through `BuildContext`/settings
/// everywhere would be far more churn than it's worth for a value that only
/// changes when the user flips one setting (which already triggers a full
/// rebuild via the Preferenze screen).
library;

bool lowPowerUi = false;

/// Set once at startup from `DeviceProfile.isTv` (see `main.dart`) — true
/// only on real Android TV/Fire TV firmware, false on every other platform
/// including Android phones/tablets. `main.dart`'s `MaterialApp.router`
/// builder reads this to decide whether the system density already
/// normalizes the logical canvas (TV only) or whether this device needs the
/// same readability text-scale boost desktop/web get.
bool isAndroidTv = false;
