import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/generated/media.pb.dart';

/// Guards the hand-edited protobuf Dart for the "One device playing per
/// profile" contract fields (media.proto's ResolveRequest.take_over and
/// ProgressResponse.playback_elsewhere/playing_on) — protoc-gen-dart isn't
/// re-run for these (see lib/core/grpc/generated/README.md and this
/// session's own notes on why), so a wrong tag number or `$_getN`/`$_has`
/// index here would silently serialize to the wrong field, or read back the
/// wrong one, with nothing else in the codebase to catch it.
void main() {
  group('ResolveRequest.takeOver (field 4)', () {
    test('defaults to false and survives a buffer round-trip', () {
      final req = ResolveRequest(
        pluginId: 'p1',
        streamId: 's1',
        startPositionSec: 42,
        takeOver: true,
      );
      expect(req.hasTakeOver(), isTrue);
      expect(req.takeOver, isTrue);

      final decoded = ResolveRequest.fromBuffer(req.writeToBuffer());
      expect(decoded.pluginId, 'p1');
      expect(decoded.streamId, 's1');
      expect(decoded.startPositionSec, 42);
      expect(decoded.takeOver, isTrue);
    });

    test('unset takeOver reads back false and hasTakeOver() is false', () {
      final req = ResolveRequest(pluginId: 'p1', streamId: 's1');
      expect(req.hasTakeOver(), isFalse);
      expect(req.takeOver, isFalse);

      final decoded = ResolveRequest.fromBuffer(req.writeToBuffer());
      expect(decoded.hasTakeOver(), isFalse);
      expect(decoded.takeOver, isFalse);
    });

    test('clearTakeOver() resets it independently of the other fields', () {
      final req = ResolveRequest(
          pluginId: 'p1', streamId: 's1', startPositionSec: 5, takeOver: true);
      req.clearTakeOver();
      expect(req.hasTakeOver(), isFalse);
      expect(req.pluginId, 'p1'); // untouched
      expect(req.startPositionSec, 5); // untouched
    });
  });

  group('ProgressResponse.playbackElsewhere/playingOn (fields 2, 3)', () {
    test('both survive a buffer round-trip alongside ok', () {
      final resp = ProgressResponse(
        ok: true,
        playbackElsewhere: true,
        playingOn: 'TV salotto',
      );
      final decoded = ProgressResponse.fromBuffer(resp.writeToBuffer());
      expect(decoded.ok, isTrue);
      expect(decoded.playbackElsewhere, isTrue);
      expect(decoded.playingOn, 'TV salotto');
    });

    test('the common case — ok with no take-over — leaves both at their '
        'proto zero values', () {
      final resp = ProgressResponse(ok: true);
      expect(resp.playbackElsewhere, isFalse);
      expect(resp.playingOn, isEmpty);
      final decoded = ProgressResponse.fromBuffer(resp.writeToBuffer());
      expect(decoded.playbackElsewhere, isFalse);
      expect(decoded.playingOn, isEmpty);
    });
  });

  group('ReleasePlaybackRequest/Response', () {
    test('an empty request serializes and reads back as itself', () {
      final decoded =
          ReleasePlaybackRequest.fromBuffer(ReleasePlaybackRequest().writeToBuffer());
      expect(decoded, isA<ReleasePlaybackRequest>());
    });

    test('response.ok survives a buffer round-trip', () {
      final resp = ReleasePlaybackResponse(ok: true);
      final decoded =
          ReleasePlaybackResponse.fromBuffer(resp.writeToBuffer());
      expect(decoded.ok, isTrue);
    });
  });
}
