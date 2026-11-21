// Web: no local copies (see device_files.dart).

bool get deviceFilesSupported => false;

Future<String?> deviceDownloadsDir() async => null;

bool localFileExists(String path) => false;

Future<int> localFileLength(String path) async => -1;

Future<void> deleteLocalFile(String path) async {}

/// Never called on the web ([deviceFilesSupported] is false).
Future<void> fetchToFile({
  required String url,
  required String partPath,
  required String finalPath,
  required int expectedBytes,
  required void Function(int received) onProgress,
  required bool Function() cancelled,
}) async =>
    throw UnsupportedError('local downloads');
