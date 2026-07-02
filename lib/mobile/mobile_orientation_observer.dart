import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Re-asserts portrait + edge-to-edge whenever navigation lands on a real
/// screen that isn't the player. The player screen deliberately goes
/// landscape/immersive and restores on dispose; this observer is the safety
/// net for the case that dispose is skipped or races (platform-view
/// teardown), so the rest of the app never gets stuck sideways.
///
/// Only [PageRoute]s count — a bottom sheet / dialog / popup (the player's
/// track selector, confirm dialogs, …) pushes a non-page route and must NOT
/// trigger an orientation change, or opening the settings sheet mid-playback
/// would yank the player back to portrait.
class MobileOrientationObserver extends NavigatorObserver {
  static const _portrait = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  bool _isRealPage(Route<dynamic>? r) => r is PageRoute;

  bool _isPlayer(Route<dynamic>? r) {
    final name = r?.settings.name ?? '';
    return name == 'player' || name.startsWith('/player');
  }

  void _portraitMode() {
    SystemChrome.setPreferredOrientations(_portrait);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isRealPage(route) && !_isPlayer(route)) _portraitMode();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Landing back on a real screen that isn't the player → portrait.
    // Popping a sheet/dialog back onto the player leaves it landscape.
    if (_isRealPage(previousRoute) && !_isPlayer(previousRoute)) {
      _portraitMode();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isRealPage(previousRoute) && !_isPlayer(previousRoute)) {
      _portraitMode();
    }
  }
}
