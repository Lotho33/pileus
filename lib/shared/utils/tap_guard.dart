import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App-wide double-tap guard for anything that *opens* something — a page,
/// a bottom sheet, a dialog.
///
/// A second tap landing while the first one's route/sheet is still animating
/// in used to push the same page twice (two details pages stacked, two
/// sheets on top of each other, two "new profile" prompts…): the old screen
/// keeps receiving taps for the ~300 ms of the transition. One shared
/// timestamp rather than a per-widget flag, because the second tap often
/// lands on a *different* widget (the neighbouring card, the same card in
/// another row) and should be swallowed all the same.
///
/// Harmless on TV — a double OK press on the remote had the same effect.
class TapGuard {
  TapGuard._();

  static DateTime? _last;

  /// Covers a double tap (typically 100–300 ms apart) and the start of the
  /// route/sheet entry animation, while staying short enough that the first
  /// deliberate tap *inside* a sheet that was just opened (long-press →
  /// "Riproduci") is never eaten.
  static const window = Duration(milliseconds: 350);

  /// True (and takes the slot) when nothing was opened within [window];
  /// false means "this is the double tap — ignore it".
  static bool acquire() {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < window) return false;
    _last = now;
    return true;
  }
}

extension GuardedNavigation on BuildContext {
  /// [GoRouter.push] behind [TapGuard]. Returns null when swallowed.
  Future<T?>? pushGuarded<T extends Object?>(String location,
      {Object? extra}) {
    if (!TapGuard.acquire()) return null;
    return GoRouter.of(this).push<T>(location, extra: extra);
  }
}

/// AppBar back button that pops at most once. A quick double tap on the
/// stock [BackButton] popped *two* routes: the first pop leaves the route
/// "not present" while it animates out, so the second `maybePop` closes the
/// page underneath as well. Use as `AppBar(leading: const GuardedBackButton())`
/// on pages that are always pushed on top of another one.
class GuardedBackButton extends StatefulWidget {
  const GuardedBackButton({super.key});

  @override
  State<GuardedBackButton> createState() => _GuardedBackButtonState();
}

class _GuardedBackButtonState extends State<GuardedBackButton> {
  bool _popped = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (_popped) return;
        _popped = true;
        Navigator.maybePop(context);
      },
    );
  }
}

/// Pops the sheet/dialog [ctx] belongs to — only if it's still the route on
/// top. A double tap on a sheet's or dialog's button used to pop twice: the
/// sheet, then the page underneath (or the whole app shell). The route being
/// dismissed stops being "current" the moment the first pop lands, so the
/// second one is a no-op. Returns false when it didn't pop — callers that
/// act after closing should then do nothing either.
bool popIfCurrent<T extends Object?>(BuildContext ctx, [T? result]) {
  final route = ModalRoute.of(ctx);
  if (route != null && !route.isCurrent) return false;
  Navigator.of(ctx).pop<T>(result);
  return true;
}
