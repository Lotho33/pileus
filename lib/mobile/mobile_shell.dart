import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import 'mobile_home_screen.dart';
import 'mobile_search_screen.dart';
import 'mobile_settings_screen.dart';

/// The app's home destination: a bottom-nav shell over Home / Cerca /
/// Impostazioni. Each tab keeps its state (IndexedStack). Replaces the old
/// AppBar + hamburger + Drawer.
class MobileShell extends StatefulWidget {
  final int initialTab;
  const MobileShell({super.key, this.initialTab = 0});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  late int _tab = widget.initialTab;
  DateTime? _lastBack;

  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    // Back from another tab lands on Home first.
    if (_tab != 0) {
      setState(() => _tab = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null &&
        now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Premi di nuovo per uscire'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: IndexedStack(
          index: _tab,
          children: const [
            MobileHomeScreen(),
            MobileSearchScreen(),
            MobileSettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppTheme.surface,
            indicatorColor: AppTheme.primary.withValues(alpha: .20),
            labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: s.contains(WidgetState.selected)
                      ? AppTheme.textHigh
                      : AppTheme.textLow,
                )),
          ),
          child: NavigationBar(
            height: 62,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: AppTheme.textMid),
                selectedIcon:
                    Icon(Icons.home_rounded, color: AppTheme.textHigh),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded, color: AppTheme.textMid),
                selectedIcon:
                    Icon(Icons.search_rounded, color: AppTheme.textHigh),
                label: 'Cerca',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: AppTheme.textMid),
                selectedIcon:
                    Icon(Icons.settings_rounded, color: AppTheme.textHigh),
                label: 'Impostazioni',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
