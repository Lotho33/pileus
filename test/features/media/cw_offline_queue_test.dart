import 'package:fixnum/fixnum.dart' show Int64;
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart'
    show ProgressRequest;
import 'package:pileus/features/media/data/cw_offline_queue.dart';
import 'package:pileus/features/player/cw_advance.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProgressRequest _upd(String media, int pos, {String parent = 'show'}) =>
    ProgressRequest(
        pluginId: 'p',
        mediaId: media,
        parentId: parent,
        currentPosition: Int64(pos));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CwOfflineQueue q;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    q = CwOfflineQueue(await SharedPreferences.getInstance());
  });

  test('keeps only the latest write per row, in order', () async {
    await q.addUpdate('pr', _upd('e1', 10));
    await q.addUpdate('pr', _upd('e2', 5));
    await q.addUpdate('pr', _upd('e1', 600));
    final ops = q.read('pr');
    expect(ops.map((o) => (o as CwQueuedUpdate).request.mediaId), ['e2', 'e1']);
    expect((ops.last as CwQueuedUpdate).request.currentPosition.toInt(), 600);
  });

  test('per profile', () async {
    await q.addUpdate('a', _upd('e1', 10));
    expect(q.isEmpty('b'), isTrue);
    expect(q.read('a'), hasLength(1));
  });

  test('finished offline: update, then the move to the next episode', () async {
    await q.addUpdate('pr', _upd('e12', 1400));
    await q.addAdvance(
        'pr',
        const CwAdvanceRequest(
            pluginId: 'p', seriesId: 'show', currentCwId: 'e12'));
    final ops = q.read('pr');
    expect(ops[0], isA<CwQueuedUpdate>());
    expect((ops[1] as CwQueuedAdvance).request.currentCwId, 'e12');
  });

  test('watching the next episode offline obsoletes the pending move',
      () async {
    await q.addAdvance(
        'pr',
        const CwAdvanceRequest(
            pluginId: 'p', seriesId: 'show', currentCwId: 'e12'));
    await q.addUpdate('pr', _upd('e21', 300));
    final ops = q.read('pr');
    expect(ops.single, isA<CwQueuedUpdate>());
  });

  test('a delete replaces the row\'s pending update and vice versa', () async {
    await q.addUpdate('pr', _upd('m1', 100, parent: ''));
    await q.addDelete('pr', 'p', 'm1');
    expect(q.read('pr').single, isA<CwQueuedDelete>());
    await q.addUpdate('pr', _upd('m1', 5, parent: ''));
    expect(q.read('pr').single, isA<CwQueuedUpdate>());
  });

  test('dropSuperseded: a write the server took directly wins', () async {
    await q.addUpdate('pr', _upd('e1', 10));
    await q.addAdvance(
        'pr',
        const CwAdvanceRequest(
            pluginId: 'p', seriesId: 'show', currentCwId: 'e0'));
    await q.dropSuperseded('pr', 'p', 'e1', 'show');
    expect(q.isEmpty('pr'), isTrue);
  });
}
