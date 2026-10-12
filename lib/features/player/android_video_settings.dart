import '../../core/utils/perf_log.dart';
import '../settings/data/settings_repository.dart';
import 'engine/player_engine.dart';

/// Pushes the device-level Android player settings into the engine — at
/// startup and whenever Preferenze changes one. They take effect on the next
/// player created. [tvSwitches]: the software-decoder / compat-rendering
/// workarounds only exist in the TV UI; the phone UI never applies them.
void applyAndroidVideoSettings(SettingsRepository s,
    {required bool tvSwitches}) {
  PlayerEngine.configureAndroidVideo(
    softwareDecoder: tvSwitches && s.getSoftwareVideoDecoder(),
    compatSurface: tvSwitches && s.getCompatVideoSurface(),
    maxVideoHeight: s.getMaxVideoHeight(),
    stats: kPerfDiagnostics,
  );
}
