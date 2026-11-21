import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/grpc/clients/media_client.dart' show PluginInfo;
import 'package:pileus/desktop/desktop_search_screen.dart';

/// Desktop/web search starts on the plugin the home shows, not on the first
/// one in the order.
void main() {
  final plugins = [
    PluginInfo(pluginId: 'a', isReady: false),
    PluginInfo(pluginId: 'b', isReady: true),
    PluginInfo(pluginId: 'c', isReady: true),
  ];
  String? pick({String? current, String? home}) =>
      resolveSearchPlugin(plugins, current: current, home: home)?.pluginId;

  test('starts on the home plugin', () {
    expect(pick(home: 'c'), 'c');
  });

  test('a plugin picked in the search dropdown wins', () {
    expect(pick(current: 'b', home: 'c'), 'b');
  });

  test('unknown ids fall back to the first ready plugin', () {
    expect(pick(home: 'gone'), 'b');
    expect(pick(current: 'gone', home: 'gone'), 'b');
    expect(pick(), 'b');
  });

  test('no plugins', () {
    expect(resolveSearchPlugin(const []), isNull);
  });
}
