import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/downloads/device/device_files_io.dart';

/// Copy onto the device: resumed with Range after a dropped connection,
/// verified against the server's size before it becomes playable.
void main() {
  late HttpServer server;
  late Directory dir;
  final body = Uint8List.fromList(List.generate(100000, (i) => i % 251));
  var rangeSupported = true;
  final ranges = <String?>[];

  setUp(() async {
    rangeSupported = true;
    ranges.clear();
    dir = await Directory.systemTemp.createTemp('pileus_dl');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final m = RegExp(r'bytes=(\d+)-').firstMatch(range ?? '');
      if (rangeSupported && m != null) {
        final from = int.parse(m.group(1)!);
        if (from >= body.length) {
          req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        } else {
          req.response.statusCode = HttpStatus.partialContent;
          req.response.add(body.sublist(from));
        }
      } else {
        req.response.add(body);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  String url() => 'http://127.0.0.1:${server.port}/downloads/file.mkv?sig=x';

  Future<void> fetch({int? expected}) => fetchToFile(
        url: url(),
        partPath: '${dir.path}/d.part',
        finalPath: '${dir.path}/d.mkv',
        expectedBytes: expected ?? body.length,
        onProgress: (_) {},
        cancelled: () => false,
      );

  test('fresh copy', () async {
    await fetch();
    expect(await File('${dir.path}/d.mkv').readAsBytes(), body);
    expect(File('${dir.path}/d.part').existsSync(), isFalse);
    expect(ranges, [null]);
  });

  test('resumes from the partial file', () async {
    await File('${dir.path}/d.part').writeAsBytes(body.sublist(0, 40000));
    await fetch();
    expect(ranges, ['bytes=40000-']);
    expect(await File('${dir.path}/d.mkv').readAsBytes(), body);
  });

  test('a server ignoring Range restarts cleanly', () async {
    rangeSupported = false;
    await File('${dir.path}/d.part').writeAsBytes(body.sublist(0, 40000));
    await fetch();
    expect(await File('${dir.path}/d.mkv').readAsBytes(), body);
  });

  test('already complete .part is just finalized', () async {
    await File('${dir.path}/d.part').writeAsBytes(body);
    await fetch();
    expect(ranges, isEmpty);
    expect(await File('${dir.path}/d.mkv').readAsBytes(), body);
  });

  test('a size mismatch never becomes a playable file', () async {
    await expectLater(fetch(expected: body.length + 10), throwsStateError);
    expect(File('${dir.path}/d.mkv').existsSync(), isFalse);
    expect(File('${dir.path}/d.part').existsSync(), isTrue);
  });
}
