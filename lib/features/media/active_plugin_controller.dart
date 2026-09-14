import 'package:flutter/foundation.dart';

/// Which plugin is "active" across the mobile shell's tabs (Home, Cerca).
///
/// Before this, Home and Cerca each kept their own local `_activeId`/
/// `_pluginId` field, seeded independently the first time plugins loaded —
/// both defaulted to `plugins.firstWhere((p) => p.isReady, ...)`. Since
/// `MobileShell` keeps every tab alive in an `IndexedStack`, switching the
/// plugin on Home never touched Cerca's own field: opening Cerca always
/// landed back on the first plugin regardless of what was picked on Home
/// (reported 2026-09-14). A single shared value fixes that by construction —
/// there's only one "active plugin" for both screens to read and write.
///
/// Lives here (not under lib/mobile/) alongside PluginBloc since it's the
/// same kind of cross-cutting plugin-selection state, even though only the
/// mobile flavor currently has more than one screen that needs to agree on
/// it. Registered as a lazy singleton (see injection.dart), same lifetime as
/// the mobile session — a lazy singleton never instantiates at all on
/// TV/desktop/web, which don't have this problem (their quick search is
/// inline in the same screen/state as the plugin switch, not a separate
/// persistent tab).
class ActivePluginController extends ValueNotifier<String?> {
  ActivePluginController() : super(null);
}
