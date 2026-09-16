import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injection.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_event.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/media/bloc/plugin_bloc.dart';
import '../features/media/bloc/plugin_event.dart';
import '../features/media/data/media_repository.dart';
import '../features/media/data/plugin_prefs.dart';
import '../features/media/presentation/widgets/plugin_nav.dart'
    show pluginLabel;
import '../features/settings/bloc/profile_management_cubit.dart';
import '../features/settings/bloc/profile_management_state.dart';
import '../features/settings/data/settings_repository.dart';
import '../core/grpc/clients/media_client.dart' show PluginInfo;
import '../shared/widgets/text_prompt_dialog.dart';
import '../shared/widgets/default_avatars.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;

/// Native desktop settings: a left section list + the section content on the
/// right. Migrated from the mobile Preferenze / Plugin / Profilo screens.
class DesktopSettingsPane extends StatefulWidget {
  const DesktopSettingsPane({super.key});

  @override
  State<DesktopSettingsPane> createState() => _DesktopSettingsPaneState();
}

enum _Section { playback, subtitles, plugins, profile, advanced }

class _DesktopSettingsPaneState extends State<DesktopSettingsPane> {
  _Section _sel = _Section.playback;

  static const _labels = {
    _Section.playback: ('Riproduzione', Icons.play_circle_outline),
    _Section.subtitles: ('Sottotitoli', Icons.subtitles_outlined),
    _Section.plugins: ('Plugin', Icons.extension_outlined),
    _Section.profile: ('Profilo', Icons.person_outline),
    _Section.advanced: ('Avanzate', Icons.tune),
  };

  @override
  Widget build(BuildContext context) {
    final activeId = switch (context.read<AuthBloc>().state) {
      AuthenticatedState(:final activeProfileId) => activeProfileId,
      _ => '',
    };

    return BlocProvider(
      create: (_) => getIt<ProfileManagementCubit>()..load(activeId),
      child: Row(
        children: [
          Container(
            width: 220,
            color: AppTheme.surface.withValues(alpha: .4),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text('Impostazioni',
                      style: TextStyle(
                          color: AppTheme.textHigh,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                ),
                for (final s in _Section.values)
                  _NavRow(
                    label: _labels[s]!.$1,
                    icon: _labels[s]!.$2,
                    selected: _sel == s,
                    onTap: () => setState(() => _sel = s),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: AppTheme.border),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
                  child: switch (_sel) {
                    _Section.playback => const _PlaybackSection(),
                    _Section.subtitles => const _SubtitleSection(),
                    _Section.plugins => const _PluginSection(),
                    _Section.profile => const _ProfileSection(),
                    _Section.advanced => const _AdvancedSection(),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? AppTheme.primary.withValues(alpha: .2)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppTheme.textHigh : AppTheme.textMid),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  color: selected ? AppTheme.textHigh : AppTheme.textMid,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                )),
          ],
        ),
      ),
    );
  }
}

// ── shared bits ────────────────────────────────────────────────────────────

Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(t,
          style: const TextStyle(
              color: AppTheme.textHigh,
              fontSize: 22,
              fontWeight: FontWeight.w800)),
    );

class _SliderRow extends StatelessWidget {
  final String label;
  final String value;
  final double v;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.v,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textHigh)),
              Text(value, style: const TextStyle(color: AppTheme.textMid)),
            ],
          ),
          Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ── Riproduzione ───────────────────────────────────────────────────────────

class _PlaybackSection extends StatefulWidget {
  const _PlaybackSection();
  @override
  State<_PlaybackSection> createState() => _PlaybackSectionState();
}

class _PlaybackSectionState extends State<_PlaybackSection> {
  final _s = getIt<SettingsRepository>();
  late int _vod = _s.getPlayerBufferMiB();
  late int _live = _s.getLiveBufferMiB();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Riproduzione'),
        _SliderRow(
          label: 'Buffer video (on demand)',
          value: '$_vod MiB',
          v: _vod.toDouble(),
          min: SettingsRepository.playerBufferMiBMin.toDouble(),
          max: SettingsRepository.playerBufferMiBMax.toDouble(),
          onChanged: (x) => setState(() {
            _vod = x.round();
            _s.setPlayerBufferMiB(_vod);
          }),
        ),
        _SliderRow(
          label: 'Buffer live',
          value: '$_live MiB',
          v: _live.toDouble(),
          min: SettingsRepository.liveBufferMiBMin.toDouble(),
          max: SettingsRepository.liveBufferMiBMax.toDouble(),
          onChanged: (x) => setState(() {
            _live = x.round();
            _s.setLiveBufferMiB(_live);
          }),
        ),
        const SizedBox(height: 6),
        const Text('Si applica alla prossima riproduzione.',
            style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
      ],
    );
  }
}

// ── Sottotitoli ────────────────────────────────────────────────────────────

class _SubtitleSection extends StatefulWidget {
  const _SubtitleSection();
  @override
  State<_SubtitleSection> createState() => _SubtitleSectionState();
}

class _SubtitleSectionState extends State<_SubtitleSection> {
  final _s = getIt<SettingsRepository>();
  late double _size = _s.getSubtitleFontSize();
  late Color _color = _s.getSubtitleColor();
  late bool _bg = _s.getSubtitleBgEnabled();
  late double _pad = _s.getSubtitleBottomPadding();

  static const _swatches = <Color>[
    Colors.white,
    Color(0xFFFFEB3B),
    Color(0xFF00E5FF),
    Color(0xFF69F0AE),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Sottotitoli'),
        _SliderRow(
          label: 'Dimensione',
          value: _size.round().toString(),
          v: _size,
          min: 16,
          max: 48,
          onChanged: (x) => setState(() {
            _size = x;
            _s.setSubtitleFontSize(x);
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Colore', style: TextStyle(color: AppTheme.textMid)),
            const SizedBox(width: 18),
            for (final c in _swatches)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _color = c;
                    _s.setSubtitleColor(c);
                  }),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.toARGB32() == c.toARGB32()
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _bg,
          onChanged: (v) => setState(() {
            _bg = v;
            _s.setSubtitleBgEnabled(v);
          }),
          title: const Text('Sfondo dietro il testo',
              style: TextStyle(color: AppTheme.textHigh)),
        ),
        _SliderRow(
          label: 'Distanza dal fondo',
          value: _pad.round().toString(),
          v: _pad,
          min: 0,
          max: 200,
          onChanged: (x) => setState(() {
            _pad = x;
            _s.setSubtitleBottomPadding(x);
          }),
        ),
      ],
    );
  }
}

// ── Plugin ─────────────────────────────────────────────────────────────────

class _PluginSection extends StatefulWidget {
  const _PluginSection();
  @override
  State<_PluginSection> createState() => _PluginSectionState();
}

class _PluginSectionState extends State<_PluginSection> {
  final _repo = getIt<MediaRepository>();
  List<PluginInfo> _all = const [];
  PluginPrefs _prefs = const PluginPrefs();
  List<String> _order = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _repo.listAllPlugins();
      final prefs = await _repo.loadPluginPrefs();
      if (!mounted) return;
      setState(() {
        _all = all;
        _prefs = prefs;
        _order = all.map((p) => p.pluginId).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  // `_order` is seeded from `_all` and only ever permuted, so today every id
  // resolves — but guard anyway: a future path that seeds `_order` from a
  // saved server order could carry an id for a since-removed plugin, and an
  // unguarded firstWhere would throw StateError and take down the whole list.
  PluginInfo? _byId(String id) =>
      _all.where((p) => p.pluginId == id).firstOrNull;

  void _reorder(int oldI, int newI) {
    setState(() {
      if (newI > oldI) newI--;
      _order.insert(newI, _order.removeAt(oldI));
    });
    _repo.savePluginOrder(_order);
    getIt<PluginBloc>().add(const RefreshPluginsEvent(force: true));
  }

  void _toggleHidden(String id) {
    setState(
        () => _prefs = _prefs.withPluginHidden(id, !_prefs.isPluginHidden(id)));
    _repo.savePluginPrefs(_prefs);
    getIt<PluginBloc>().add(const RefreshPluginsEvent(force: true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Plugin'),
        const Text(
          'Trascina per riordinare. L\'occhio nasconde un plugin dalla home '
          'e dalla ricerca.',
          style: TextStyle(color: AppTheme.textLow, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _order.length,
          // onReorder->onReorderItem migration is post-release churn.
          // ignore: deprecated_member_use
          onReorder: _reorder,
          itemBuilder: (context, i) {
            final id = _order[i];
            final p = _byId(id);
            // Unknown id (see _byId) — render an empty keyed slot so
            // ReorderableListView's child count still matches _order.length.
            if (p == null) return SizedBox.shrink(key: ValueKey(id));
            final hidden = _prefs.isPluginHidden(id);
            return Container(
              key: ValueKey(id),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: i,
                  child:
                      const Icon(Icons.drag_indicator, color: AppTheme.textLow),
                ),
                title: Text(
                  pluginLabel(p),
                  style: TextStyle(
                    color: hidden ? AppTheme.textLow : AppTheme.textHigh,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: hidden ? AppTheme.textLow : AppTheme.textMid,
                  ),
                  onPressed: () => _toggleHidden(id),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Profilo ────────────────────────────────────────────────────────────────

class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileManagementCubit, ProfileMgmtState>(
      listener: (context, state) {
        if (state is ProfileMgmtDeleted) {
          getIt<AuthBloc>().add(const SwitchProfileEvent());
        }
        if (state is ProfileMgmtError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (state is ProfileMgmtLoading || state is ProfileMgmtInitial) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state is! ProfileMgmtLoaded) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text('Profilo non disponibile',
                style: TextStyle(color: AppTheme.textMid)),
          );
        }
        final cubit = context.read<ProfileManagementCubit>();
        final p = state.profile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Profilo'),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: _Avatar(url: p.avatarUrl),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.profileName,
                          style: const TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Rinomina'),
                        onPressed: () async {
                          final name = await showTextPrompt(context,
                              title: 'Rinomina profilo',
                              initial: p.profileName,
                              confirmLabel: 'Salva');
                          if (name != null &&
                              name.isNotEmpty &&
                              name != p.profileName) {
                            cubit.rename(name);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.isDefault,
              onChanged: state.otherDefaultName != null && !state.isDefault
                  ? null
                  : (v) => cubit.setDefault(v),
              title: const Text('Profilo predefinito',
                  style: TextStyle(color: AppTheme.textHigh)),
              subtitle: state.otherDefaultName != null && !state.isDefault
                  ? Text('Predefinito attuale: ${state.otherDefaultName}',
                      style: const TextStyle(
                          color: AppTheme.textLow, fontSize: 12))
                  : const Text('Entra direttamente con questo profilo',
                      style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
            ),
            const Divider(color: AppTheme.border, height: 32),
            if (!state.isOnlyProfile)
              TextButton.icon(
                icon:
                    const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
                label: const Text('Elimina profilo',
                    style: TextStyle(color: Color(0xFFFF6B6B))),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      title: const Text('Eliminare il profilo?'),
                      content:
                          Text('Verrà rimosso "${p.profileName}" da questo '
                              'dispositivo.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annulla')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Elimina')),
                      ],
                    ),
                  );
                  if (ok == true) cubit.delete();
                },
              ),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    if (isDefaultAvatarUrl(url)) {
      return DefaultAvatarView(index: defaultAvatarIndex(url), size: 88);
    }
    if (url.isEmpty) return const ColoredBox(color: AppTheme.surface2);
    return CachedNetworkImage(
      // Web-only, no-op on every other platform — see image_sizing.dart's
      // "ImageRenderMethodForWeb.HttpGet" section for why every
      // CachedNetworkImage call site in the app sets this.
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      imageUrl: url,
      memCacheWidth: 200,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const ColoredBox(color: AppTheme.surface2),
    );
  }
}

// ── Avanzate ───────────────────────────────────────────────────────────────

class _AdvancedSection extends StatefulWidget {
  const _AdvancedSection();
  @override
  State<_AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<_AdvancedSection> {
  final _s = getIt<SettingsRepository>();
  late bool _diag = _s.getDiagnostics();

  void _confirm(String title, String body, VoidCallback onYes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onYes();
              },
              child: const Text('Conferma')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Avanzate'),
        Card(
          color: AppTheme.surface,
          child: ListTile(
            leading: const Icon(Icons.dns_outlined, color: AppTheme.textMid),
            title: const Text('Cambia server',
                style: TextStyle(color: AppTheme.textHigh)),
            subtitle: const Text('Rifà discovery e abbinamento',
                style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
            onTap: () => _confirm(
                'Cambiare server?',
                'Dovrai rifare discovery e abbinamento.',
                () => getIt<AuthBloc>().add(const ChangeServerEvent())),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppTheme.surface,
          child: ListTile(
            leading: const Icon(Icons.delete_sweep_outlined,
                color: AppTheme.textMid),
            title: const Text('Svuota cache catalogo',
                style: TextStyle(color: AppTheme.textHigh)),
            onTap: () async {
              await getIt<MediaRepository>().clearCatalogCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache svuotata')));
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _diag,
          onChanged: (v) => setState(() {
            _diag = v;
            _s.setDiagnostics(v);
          }),
          title: const Text('Diagnostica',
              style: TextStyle(color: AppTheme.textHigh)),
          subtitle: const Text('Log di performance. Richiede il riavvio.',
              style: TextStyle(color: AppTheme.textLow, fontSize: 12)),
        ),
      ],
    );
  }
}
