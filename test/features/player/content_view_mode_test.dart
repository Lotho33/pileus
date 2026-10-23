import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/features/media/data/continue_watching_item.dart';
import 'package:pileus/features/player/content_view_mode.dart';
import 'package:pileus/features/player/engine/video_view_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

ContinueWatchingItem _cw(String plugin, String id, {String parent = ''}) =>
    ContinueWatchingItem(
      providerID: plugin,
      playableID: id,
      parentID: parent,
      title: '',
      poster: '',
      progressTime: 0,
      totalTime: 0,
    );

void main() {
  late ContentViewModeMemory mem;
  late DateTime now;
  String profile = 'p1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({'settings.videoViewMode': 'zoom'});
    final prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 15, 12);
    profile = 'p1';
    videoViewMode.value = VideoViewMode.fit;
    mem = ContentViewModeMemory()..bind(prefs, () => profile, now: () => now);
  });

  test('a format set on one series comes back for its next episode only', () {
    final t = mem.open(pluginId: 'p1', parentId: 'show1', ids: ['ep1']);
    videoViewMode.value = VideoViewMode.ratio4x3;
    mem.close(t);
    expect(videoViewMode.value, VideoViewMode.fit);

    final other = mem.open(pluginId: 'p1', parentId: 'show2', ids: ['x1']);
    expect(videoViewMode.value, VideoViewMode.fit);
    mem.close(other);

    mem.open(pluginId: 'p1', parentId: 'show1', ids: ['ep2']);
    expect(videoViewMode.value, VideoViewMode.ratio4x3);
  });

  test('a movie reopened from Continue Watching by its stream id', () {
    final t = mem.open(pluginId: 'p1', ids: ['movie42']);
    videoViewMode.value = VideoViewMode.zoom;
    // The stream id becomes known once resolved (each CW save tracks it).
    mem.track(t, ids: ['movie42-it']);
    mem.close(t);

    mem.open(pluginId: 'p1', ids: ['movie42-it']);
    expect(videoViewMode.value, VideoViewMode.zoom);
  });

  test('a replacing instance keeps the mode across a language switch', () {
    final t = mem.open(pluginId: 'p1', ids: ['m1']);
    videoViewMode.value = VideoViewMode.stretch;
    final t2 = mem.open(pluginId: 'p1', ids: ['m1-en'], continuing: t);
    expect(videoViewMode.value, VideoViewMode.stretch);
    mem.close(t); // stale token: no effect
    expect(videoViewMode.value, VideoViewMode.stretch);
    mem.close(t2);
    mem.open(pluginId: 'p1', ids: ['m1-en']);
    expect(videoViewMode.value, VideoViewMode.stretch);
  });

  test('back to Adatta forgets the content; the old device-wide key is gone',
      () async {
    final t = mem.open(pluginId: 'p1', ids: ['m1']);
    videoViewMode.value = VideoViewMode.zoom;
    videoViewMode.value = VideoViewMode.fit;
    mem.close(t);
    expect(mem.storedFor(pluginId: 'p1', ids: ['m1']), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.videoViewMode'), isNull);
  });

  test('pruned once the content leaves Continue Watching', () {
    final a = mem.open(pluginId: 'p1', parentId: 'showA', ids: ['a1']);
    videoViewMode.value = VideoViewMode.zoom;
    mem.close(a);
    final b = mem.open(pluginId: 'p1', ids: ['movieB']);
    videoViewMode.value = VideoViewMode.ratio16x9;
    mem.close(b);

    // Within the grace period nothing is dropped.
    mem.prune([], complete: true);
    expect(mem.storedFor(pluginId: 'p1', parentId: 'showA'), isNotNull);

    now = now.add(const Duration(hours: 1));
    // A cut-off page can't prove anything is gone.
    mem.prune([], complete: false);
    expect(mem.storedFor(pluginId: 'p1', ids: ['movieB']), isNotNull);

    mem.prune([_cw('p1', 'a7', parent: 'showA')], complete: true);
    expect(
        mem.storedFor(pluginId: 'p1', parentId: 'showA'), VideoViewMode.zoom);
    expect(mem.storedFor(pluginId: 'p1', ids: ['movieB']), isNull);
  });

  test('per profile', () {
    final t = mem.open(pluginId: 'p1', ids: ['m1']);
    videoViewMode.value = VideoViewMode.zoom;
    mem.close(t);
    profile = 'p2';
    mem.open(pluginId: 'p1', ids: ['m1']);
    expect(videoViewMode.value, VideoViewMode.fit);
  });
}
