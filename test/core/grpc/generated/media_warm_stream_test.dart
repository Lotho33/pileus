import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';

/// Guards the hand-edited protobuf Dart for WarmStream (media.proto's
/// WarmStreamRequest / WarmStreamResponse) — protoc-gen-dart isn't re-run for
/// these (see lib/core/grpc/generated/README.md). Checked against the raw
/// wire bytes, not only a round-trip: a wrong tag number would round-trip
/// fine here and still be read as the wrong field by mycelium.
void main() {
  // tag(field 1, LEN) = 0x0A, tag(field 2, LEN) = 0x12.
  List<int> wire(String a, String b) =>
      [0x0A, a.length, ...a.codeUnits, 0x12, b.length, ...b.codeUnits];

  test('WarmStreamRequest: plugin_id = 1, stream_id = 2', () {
    final req = WarmStreamRequest(pluginId: 'movies', streamId: '123:it');
    expect(req.writeToBuffer(), wire('movies', '123:it'));
    final back = WarmStreamRequest.fromBuffer(wire('p', 's'));
    expect(back.pluginId, 'p');
    expect(back.streamId, 's');
  });

  test('WarmStreamResponse: outcome = 1, reason = 2', () {
    final resp = WarmStreamResponse.fromBuffer(wire('skipped', 'disabled'));
    expect(resp.outcome, 'skipped');
    expect(resp.reason, 'disabled');
    expect(WarmStreamResponse(outcome: 'started').writeToBuffer(),
        [0x0A, 7, ...'started'.codeUnits]);
  });
}
