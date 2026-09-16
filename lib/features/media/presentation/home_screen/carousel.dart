// Part of home_screen.dart — split out for readability (plan 2e). The library
// file holds the shared imports plus the _HomeFsm enum and the HomeScreen
// entry point; private identifiers are shared across all parts.
part of '../home_screen.dart';

// ── carousel strip — one catalog row, swapped by parent on ↑/↓ ──────────────

// Cards only — no header. The header lives one level up now
// (_StandardHomeShellState.build()), outside this widget's own
// AnimatedSwitcher boundary, specifically so the header's fade and this
// body's slide are two independent transitions instead of one motion.
class _CarouselBody extends StatelessWidget {
  final PluginInfo plugin;
  final int catalogIndex;
  final CatalogDef catalogDef;
  final DiscoveryBloc bloc;
  final void Function(CatalogItem) onItemFocused;
  final void Function(FocusNode) onFirstCardFocus;
  final VoidCallback onOpenNav;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final void Function(LogicalKeyboardKey key, bool isDown)?
      onNavigateHoldChanged;
  final VoidCallback? onEmpty;

  const _CarouselBody({
    super.key,
    required this.plugin,
    required this.catalogIndex,
    required this.catalogDef,
    required this.bloc,
    required this.onItemFocused,
    required this.onFirstCardFocus,
    required this.onOpenNav,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onNavigateHoldChanged,
    this.onEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CatalogSection(
          pluginId: plugin.pluginId,
          catalogDef: catalogDef,
          bloc: bloc,
          isFirstSection: true,
          onItemFocused: onItemFocused,
          onFirstCardFocus: onFirstCardFocus,
          onOpenNav: onOpenNav,
          onNavigateUp: onNavigateUp,
          onNavigateDown: onNavigateDown,
          onNavigateHoldChanged: onNavigateHoldChanged,
          onEmpty: onEmpty,
        ),
        SizedBox(height: MediaQuery.sizeOf(context).height * (24.0 / 1080.0)),
      ],
    );
  }
}

// ── hero shimmer — shown while item == null ────────────────────────────────────

// ── shimmer box — animated placeholder rectangle ──────────────────────────────

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      );
}
