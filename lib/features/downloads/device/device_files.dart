// Files on this device for offline downloads — dart:io on native, no-ops on
// the web build (a browser tab can't keep a multi-GB file for later).
export 'device_files_stub.dart' if (dart.library.io) 'device_files_io.dart';
