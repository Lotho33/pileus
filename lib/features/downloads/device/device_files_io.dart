import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// Native side of device_files.dart.

bool get deviceFilesSupported => true;

/// `<app support>/offline`: private to the app, gone with it.
Future<String?> deviceDownloadsDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}offline');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir.path;
}

bool localFileExists(String path) => path.isNotEmpty && File(path).existsSync();

Future<int> localFileLength(String path) async {
  final f = File(path);
  return await f.exists() ? await f.length() : -1;
}

Future<void> deleteLocalFile(String path) async {
  if (path.isEmpty) return;
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

// No byte for this long = a dead connection (a train going into a tunnel):
// fail, the .part stays and the next try resumes from it.
const _idleTimeout = Duration(seconds: 30);

/// Fetches [url] into [partPath], resuming from what is already there
/// (Range — the server's /downloads/file serves it), then renames it to
/// [finalPath] once it holds exactly [expectedBytes] (when known). Throws
/// on any failure, leaving the partial file for the next attempt; returns
/// early, also leaving it, when [cancelled] turns true.
Future<void> fetchToFile({
  required String url,
  required String partPath,
  required String finalPath,
  required int expectedBytes,
  required void Function(int received) onProgress,
  required bool Function() cancelled,
}) async {
  final part = File(partPath);
  var have = await part.exists() ? await part.length() : 0;
  if (expectedBytes > 0 && have > expectedBytes) {
    await part.delete();
    have = 0;
  }
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = _idleTimeout;
  IOSink? sink;
  try {
    if (expectedBytes <= 0 || have < expectedBytes) {
      final req = await client.getUrl(Uri.parse(url));
      if (have > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      final res = await req.close().timeout(_idleTimeout);
      if (res.statusCode == HttpStatus.ok) {
        // No Range support (or a fresh start): from the beginning.
        have = 0;
        sink = part.openWrite(mode: FileMode.write);
      } else if (res.statusCode == HttpStatus.partialContent) {
        sink = part.openWrite(mode: FileMode.append);
      } else if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
          have > 0 &&
          (expectedBytes <= 0 || have == expectedBytes)) {
        await res.drain<void>();
      } else {
        await res.drain<void>();
        throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      }
      if (sink != null) {
        onProgress(have);
        var lastReport = DateTime.now();
        await for (final chunk in res.timeout(_idleTimeout)) {
          if (cancelled()) break;
          sink.add(chunk);
          have += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastReport) > const Duration(milliseconds: 400)) {
            lastReport = now;
            onProgress(have);
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
        onProgress(have);
        if (cancelled()) return;
      }
    }
    final size = await part.length();
    if (expectedBytes > 0 && size != expectedBytes) {
      throw StateError('file incompleto ($size di $expectedBytes byte)');
    }
    final dest = File(finalPath);
    if (await dest.exists()) await dest.delete();
    await part.rename(finalPath);
  } finally {
    try {
      await sink?.close();
    } catch (_) {}
    client.close(force: true);
  }
}
