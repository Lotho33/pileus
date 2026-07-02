import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_scale.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_event.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../widgets/ambient_glow_background.dart';
import '../widgets/pileus_spinner.dart';

// SVG viewBox aspect ratios (width/height) — potrace's traced output, see
// assets/branding/*.svg's own <svg viewBox> — used to size each mark from a
// single height rather than hardcoding both dimensions.
const double _kIconAspect = 1516.099470 / 1229.844208;
const double _kWordmarkAspect = 1578.305115 / 708.277230;

const _kCloseDuration = Duration(milliseconds: 380);

// Reveals [fraction] (0..1) of [child]'s left edge, clipping the rest to
// nothing — used to wipe the wordmark in from behind the icon's right edge.
// A pixel-exact clip rect (rather than e.g. Align's widthFactor, which
// silently gets overridden back to the parent's full tight width under a
// stretching Column) so at fraction 0 the wordmark is guaranteed fully
// invisible instead of just "behind" a same-sized opaque box that used to
// leave whatever didn't fit under that box showing through immediately.
//
// A per-letter staged reveal was tried here (and reverted twice — a
// continuous ease per letter read as one ripple, a hard per-letter step
// still read as an unroll) since the wordmark is one traced SVG mark, not
// individual glyphs — cutting it into even letter-width chunks doesn't
// actually land on real letter boundaries, so it never stopped looking
// like a wipe no matter how the timing was tuned. Back to what it visibly
// is: one continuous wipe of the whole word. A real per-letter effect
// would need separate per-letter art (or an SGS font asset laid out here
// letter by letter) to cut cleanly — worth doing later, not a timing fix.
class _LeftRevealClipper extends CustomClipper<Rect> {
  final double fraction;
  const _LeftRevealClipper(this.fraction);
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);
  @override
  bool shouldReclip(covariant _LeftRevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  // Separate from _ctrl: the reveal timeline below is fixed-length, but
  // AuthBloc's lookup can take longer — this plays a short "done" fade once
  // a route is actually ready, driven by the real auth result rather than a
  // fixed point on the reveal's own clock.
  late final AnimationController _closeCtrl;
  bool _closing = false;
  late final AuthBloc _authBloc = getIt<AuthBloc>();
  // Dead-man's switch: AppStartedEvent chains several RPCs (host resolve,
  // device auth, plugin prefetch) with no single overall deadline. If none
  // of them ever resolves to a routable AuthState — unreachable server, a
  // hung stream — the splash would spin forever. Bounce to /discovery so
  // the user can re-scan or re-enter the address.
  Timer? _bootTimeout;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: AuthBloc.minSplashDuration);
    _ctrl.forward();
    _closeCtrl = AnimationController(vsync: this, duration: _kCloseDuration);
    // Dispatched exactly once here, not from build() — build() re-running
    // (the outgoing crossfade transition alone can trigger that while this
    // screen is still in the tree) used to re-fire AppStartedEvent, which
    // reset AuthBloc back to AuthLoading.
    _authBloc.add(const AppStartedEvent());
    _bootTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_closing) _finishAndGo('/discovery');
    });
  }

  @override
  void dispose() {
    _bootTimeout?.cancel();
    _ctrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  void _finishAndGo(String route) {
    if (_closing) return;
    _closing = true;
    _bootTimeout?.cancel();
    _closeCtrl.forward().whenComplete(() async {
      // A beat of stillness after the lockup has actually finished fading,
      // not a cut the instant it does — otherwise the handoff to the next
      // screen's own crossfade reads as chasing this one's tail rather than
      // a deliberate finish.
      await Future.delayed(const Duration(milliseconds: 220));
      if (mounted) context.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Timeline (fractions of _kSplashDuration):
    //  0.05–0.42  the icon fades/scales in with a gentle overshoot
    //             (easeOutBack) — the one deliberately "alive" beat in an
    //             otherwise calm sequence.
    //  0.40–0.64  the wordmark wipes in left-to-right from its resting spot
    //             flush against the icon's right edge — fully hidden at 0
    //             (see _LeftRevealClipper), so it reads as emerging from
    //             behind the icon rather than sliding as a solid block.
    //  0.66–0.86  a thin accent rule draws in under the wordmark, left to
    //             right — the "premium lockup" touch that ties the mark
    //             together.
    //  0.88–1.0   a small spinner fades in under the lockup — AuthBloc is
    //             using this hold to prefetch the home screen's own data
    //             (see AuthBloc._onAppStarted's authenticated branch) so it's
    //             genuinely loading something past this point now, not just
    //             holding for the animation's own sake — then _finishAndGo
    //             plays the whole-lockup fade below.
    final iconFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.05, 0.30, curve: Curves.easeOut),
    );
    final iconScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.05, 0.42, curve: Curves.easeOutBack),
    );
    final wordmarkSlide = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.40, 0.64, curve: Curves.easeOutCubic),
    );
    final rulePhase = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.66, 0.86, curve: Curves.easeOut),
    );
    final spinnerFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.88, 1.0, curve: Curves.easeOut),
    );
    final closeFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _closeCtrl, curve: Curves.easeIn));
    final closeScale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _closeCtrl, curve: Curves.easeIn));

    final iconH = AppScale.space(context, 176);
    final iconW = iconH * _kIconAspect;
    final wordmarkH = AppScale.space(context, 148);
    final wordmarkW = wordmarkH * _kWordmarkAspect;
    final gap = AppScale.space(context, 26);
    final lockupW = iconW + gap + wordmarkW;
    final ruleGap = AppScale.space(context, 12);
    final wordmarkColH = wordmarkH + ruleGap + 3;
    final spinnerGap = AppScale.space(context, 40);
    final spinnerSize = AppScale.spinnerL(context);
    final iconScaleTween =
        Tween<double>(begin: 0.72, end: 1.0).animate(iconScale);

    return BlocProvider.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is ServerDiscoveryRequired) {
            _finishAndGo('/discovery');
          } else if (state is DevicePairingRequired) {
            _finishAndGo('/pairing');
          } else if (state is ProfileSelectionRequired) {
            _finishAndGo('/profiles');
          } else if (state is AuthenticatedState) {
            _finishAndGo('/home');
          } else if (state is AuthError) {
            // Nothing actionable on the splash itself — send the user to
            // discovery, which surfaces the error and offers a re-scan.
            _finishAndGo('/discovery');
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.bg,
          body: AmbientGlowBackground(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _closeCtrl]),
                builder: (context, _) {
                  // Every mark below is placed with an explicit
                  // Positioned(left/top) computed from known pixel sizes —
                  // deliberately not left to Stack/Row implicit sizing,
                  // which previously let the whole lockup drift to the
                  // top-left instead of staying centered.
                  return FadeTransition(
                    opacity: closeFade,
                    child: ScaleTransition(
                      scale: closeScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: lockupW,
                            height: iconH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Wordmark sits at its final resting spot the
                                // whole time — flush against the icon's right
                                // edge — and is revealed by clipping its own
                                // width open left-to-right, so it visibly
                                // "emerges" from that edge instead of arriving
                                // as a translating block (which, since the
                                // wordmark is wider than the icon, used to leave
                                // the excess sticking out and visible from
                                // frame one — the reported overlap bug).
                                Positioned(
                                  left: iconW + gap,
                                  top: (iconH - wordmarkColH) / 2,
                                  child: ClipRect(
                                    clipper:
                                        _LeftRevealClipper(wordmarkSlide.value),
                                    child: SizedBox(
                                      width: wordmarkW,
                                      height: wordmarkColH,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/branding/pileus_wordmark.svg',
                                            height: wordmarkH,
                                            width: wordmarkW,
                                            colorFilter: const ColorFilter.mode(
                                                Colors.white, BlendMode.srcIn),
                                          ),
                                          SizedBox(height: ruleGap),
                                          ClipRect(
                                            clipper: _LeftRevealClipper(
                                                rulePhase.value),
                                            child: Container(
                                              height: 3,
                                              width: wordmarkW,
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: FadeTransition(
                                    opacity: iconFade,
                                    child: ScaleTransition(
                                      scale: iconScaleTween,
                                      child: SvgPicture.asset(
                                        'assets/branding/pileus_icon.svg',
                                        height: iconH,
                                        width: iconW,
                                        colorFilter: const ColorFilter.mode(
                                            Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: spinnerGap),
                          FadeTransition(
                            opacity: spinnerFade,
                            child: PileusSpinner(size: spinnerSize),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
