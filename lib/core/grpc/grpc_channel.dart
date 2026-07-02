// Platform dispatch: native IO vs browser gRPC-web.
// Dart compiles both files but only links the selected one, so
// web-only imports (package:grpc/grpc_web.dart) never reach native builds.
//
// `dart.library.js_interop` (not the legacy `dart.library.html`) so this also
// resolves to the web file under `flutter build web --wasm`, where
// `dart.library.html` is undefined and the old key silently fell through to
// the `dart:io` native file — a wasm compile error.
export 'grpc_channel_io.dart'
    if (dart.library.js_interop) 'grpc_channel_web.dart';
