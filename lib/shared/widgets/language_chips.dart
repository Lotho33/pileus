import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/grpc/clients/media_client.dart' show StreamSource;
import '../../core/theme/app_theme.dart';
import '../../features/media/data/media_repository.dart';
import '../../features/player/source_preference.dart';
import '../../features/player/stream_warmer.dart';

/// The language versions of a title, on its details screen (mobile,
/// desktop, web) — the choice that used to be a dialog at every Play. The
/// one the Play rule would pick (choosePlaySource) starts selected, so the
/// common case is still one tap on Play; picking another reports it through
/// [onChanged] (the screen passes it to resolveAndPlay as the explicit
/// label) and warms that stream instead.
///
/// Draws nothing until the sources are known, and nothing when there's a
/// single version or the sources aren't language versions (a live event's
/// nodes).
class LanguageChips extends StatefulWidget {
  final String pluginId;
  final String mediaId;
  final ValueChanged<StreamSource> onChanged;

  const LanguageChips({
    super.key,
    required this.pluginId,
    required this.mediaId,
    required this.onChanged,
  });

  @override
  State<LanguageChips> createState() => _LanguageChipsState();
}

class _LanguageChipsState extends State<LanguageChips> {
  List<StreamSource> _sources = const [];
  StreamSource? _selected;
  WarmTicket? _warm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _warm?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Cached by the repository — the screen's own warm-up asked already.
      final res = await getIt<MediaRepository>()
          .getStreams(widget.pluginId, widget.mediaId);
      if (!mounted) return;
      final versions =
          res.sources.where((s) => languageOfLabel(s.label) != null).length;
      if (versions < 2) return;
      setState(() {
        _sources = res.sources;
        _selected = choosePlaySource(res.sources, pluginId: widget.pluginId);
      });
    } catch (_) {
      // No chips — Play still picks by the rule.
    }
  }

  void _pick(StreamSource s) {
    if (identical(s, _selected)) return;
    setState(() => _selected = s);
    widget.onChanged(s);
    _warm?.cancel();
    _warm = getIt<StreamWarmer>().schedule(widget.pluginId, () async => s.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_sources.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Lingua',
              style: TextStyle(
                  color: AppTheme.textLow,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          for (final s in _sources)
            ChoiceChip(
              label: Text(s.label.isNotEmpty ? s.label : 'Sorgente'),
              selected: identical(s, _selected),
              onSelected: (_) => _pick(s),
              selectedColor: AppTheme.primary.withValues(alpha: 0.28),
              backgroundColor: AppTheme.surface2,
              side: const BorderSide(color: AppTheme.border),
              labelStyle: const TextStyle(color: AppTheme.textHigh),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
