// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/core/di/injection.dart';
import 'package:pileus/core/grpc/auth_interceptor.dart';
import 'package:pileus/features/settings/bloc/settings_cubit.dart';
import 'package:pileus/features/settings/data/settings_repository.dart';
import 'package:pileus/features/settings/presentation/preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TV Preferenze: ←/→ on a subtitle row changes the value on screen.
void main() {
  setUp(() async {
    // A profile with prefs synced from the server, as on a real TV.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await getIt.reset();
    getIt.registerSingleton<SharedPreferences>(prefs);
    final auth = AuthInterceptor()..setCredentials('jwt', 'p1');
    final repo = SettingsRepository(prefs, auth, (_, __) async {});
    await repo.cacheProfilePrefsBlob('p1',
        '{"v":1,"subtitles":{"fontSize":32,"bgEnabled":true,"bottomPadding":80}}');
    getIt.registerSingleton<SettingsRepository>(repo);
    getIt.registerFactory<SettingsCubit>(
        () => SettingsCubit(getIt<SettingsRepository>()));
  });

  testWidgets('right on Dimensione steps the size shown', (t) async {
    await t.pumpWidget(const MaterialApp(home: PreferencesScreen()));
    await t.pumpAndSettle();
    expect(find.text('32'), findsOneWidget);
    // Focus the size row: Down from the header.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(find.text('34'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(find.text('36'), findsOneWidget);
    // Let the debounced profile-prefs push fire.
    await t.pump(const Duration(seconds: 1));
  });
}
