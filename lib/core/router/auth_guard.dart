import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../grpc/auth_interceptor.dart';

/// Shared `redirect:` for all 4 routers (TV `app_router.dart`,
/// `mobile_router.dart`, `desktop_router.dart`, `web_router.dart`) — was
/// byte-identical in each of them, copy-pasted rather than shared, so a
/// future change to the auth-guard logic (a new pre-login route, a new
/// session state) needed 4 synchronized edits with no compiler help if one
/// was missed.
///
/// The auth flow (`/splash` bootstraps, the other three run pre-login by
/// design) is always reachable; everything else requires a live device
/// session. `AuthInterceptor` holds the JWT in memory only — it's empty on
/// every cold start until the bootstrap re-authenticates — so a deep link /
/// web refresh / process-death restore onto a protected route with no
/// session lands on `/splash`, which re-runs the bootstrap and routes
/// correctly, instead of building an unauthenticated screen that then fires
/// empty RPCs. Screens still drive their own live navigation via
/// BlocListener; this only closes the entry-point hole.
String? authGuardRedirect(GoRouterState state) {
  const authFlow = {'/splash', '/discovery', '/pairing', '/profiles'};
  final path = state.uri.path;
  if (authFlow.contains(path)) return null;
  if (!getIt<AuthInterceptor>().hasCredentials) return '/splash';
  return null;
}
