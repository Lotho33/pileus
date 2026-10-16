import 'app_exit_io.dart' if (dart.library.js_interop) 'app_exit_web.dart'
    as impl;

/// Closes the app. Native: `SystemNavigator.pop()`. Web: that call is a
/// no-op, so a packaged TV app (webOS/Tizen) goes through the
/// `pileusExitApp` hook in web/index.html instead.
void exitApp() => impl.exitApp();
