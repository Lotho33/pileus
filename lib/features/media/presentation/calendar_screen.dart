import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
// ignore: deprecated_member_use, material_ui migration pending (docs/FLUTTER_UPGRADE.md)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;

import '../../../core/di/injection.dart';
import '../../../core/grpc/clients/media_client.dart'
    show CalendarEntry, CalendarResponse, PluginInfo;
import '../../../core/grpc/grpc_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_sizing.dart';
import '../../../shared/widgets/open_catalog_item.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../calendar.dart';
import '../data/media_repository.dart';
import 'widgets/plugin_nav.dart' show pluginLabel;

/// "Calendario": what comes out in the next [kCalendarDays] days, every
/// plugin together (like La mia lista), grouped by day. Filters: "Solo le
/// mie" (the series this profile follows — asked to the server) and one
/// plugin (on what came back). One layout for every platform: rows are
/// D-pad stops on a TV and plain taps elsewhere.
///
/// [embedded]: a tab of the phone's bottom bar — no back button.
class CalendarScreen extends StatefulWidget {
  final bool embedded;
  const CalendarScreen({super.key, this.embedded = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = getIt<MediaRepository>();
  final _firstRowFn = FocusNode();
  final _mineFn = FocusNode();

  CalendarResponse? _data;
  Object? _error;
  bool _loading = false;
  bool _followedOnly = false;
  String _plugin = ''; // '' = every plugin
  Map<String, String> _pluginNames = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _repo.listPlugins().then((ps) {
      if (mounted) {
        setState(() => _pluginNames = {
              for (final PluginInfo p in ps) p.pluginId: pluginLabel(p)
            });
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _firstRowFn.dispose();
    _mineFn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _repo.getCalendar(
          days: kCalendarDays, followedOnly: _followedOnly);
      if (!mounted) return;
      setState(() {
        _data = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toggleMine() {
    _followedOnly = !_followedOnly;
    _load();
  }

  String _name(String pluginId) => _pluginNames[pluginId] ?? pluginId;

  void _open(CalendarEntry e) {
    final target = calendarOpenTarget(e);
    if (target != null) {
      openCatalogItem(context, e.pluginId, target);
      return;
    }
    final day = calendarReleaseTime(e);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(day == null
            ? 'Non ancora disponibile'
            : 'Previsto ${calendarDayLabel(day, DateTime.now()).toLowerCase()}'
                '${calendarTimeLabel(e).isEmpty ? '' : ' alle ${calendarTimeLabel(e)}'}: '
                'non ancora disponibile'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // One unit for every platform: 1080p px scaled to the screen, kept
    // readable on a phone and not oversized on a big monitor.
    final u = (size.height / 1080).clamp(0.45, 0.75);
    final hPad = (size.width * 0.04).clamp(16.0, 72.0);

    final entries = [
      for (final e in _data?.entries ?? const <CalendarEntry>[])
        if (_plugin.isEmpty || e.pluginId == _plugin) e
    ];
    final plugins = {
      for (final e in _data?.entries ?? const <CalendarEntry>[]) e.pluginId
    }.toList();
    final days = groupCalendar(entries);
    final failed = _data?.failedPlugins ?? const <String>[];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(hPad, 28 * u, hPad, 12 * u),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (!widget.embedded) ...[
              _Chip(
                u: u,
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
                onDown: () => _firstRowFn.requestFocus(),
              ),
              SizedBox(width: 16 * u),
            ],
            Text('Calendario',
                style: TextStyle(
                    color: AppTheme.textHigh,
                    fontSize: 40 * u,
                    fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 16 * u),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              _Chip(
                u: u,
                focusNode: _mineFn,
                label: 'Solo le mie',
                icon: _followedOnly
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                selected: _followedOnly,
                onTap: _toggleMine,
                onDown: () => _firstRowFn.requestFocus(),
              ),
              if (plugins.length > 1) ...[
                SizedBox(width: 20 * u),
                _Chip(
                  u: u,
                  label: 'Tutti',
                  selected: _plugin.isEmpty,
                  onTap: () => setState(() => _plugin = ''),
                  onDown: () => _firstRowFn.requestFocus(),
                ),
                for (final p in plugins) ...[
                  SizedBox(width: 10 * u),
                  _Chip(
                    u: u,
                    label: _name(p),
                    selected: _plugin == p,
                    onTap: () => setState(() => _plugin = p),
                    onDown: () => _firstRowFn.requestFocus(),
                  ),
                ],
              ],
            ]),
          ),
        ],
      ),
    );

    Widget body;
    if (_loading && _data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _data == null) {
      final old = _error is GrpcError &&
          (_error as GrpcError).code == StatusCode.unimplemented;
      body = _Message(
        u: u,
        text: old
            ? 'Questo server non ha ancora il calendario delle uscite.'
            : grpcMessage(_error!),
        action: old ? null : 'Riprova',
        onAction: old ? null : _load,
      );
    } else if (days.isEmpty) {
      body = _Message(
        u: u,
        text: _followedOnly
            ? 'Nessuna uscita in arrivo per le serie che segui.'
            : 'Nessuna uscita nei prossimi giorni.',
      );
    } else {
      var first = true;
      final now = DateTime.now();
      body = ListView(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 40 * u),
        children: [
          for (final d in days) ...[
            Padding(
              padding: EdgeInsets.only(top: 20 * u, bottom: 10 * u),
              child: Text(calendarDayLabel(d.day, now),
                  style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 28 * u,
                      fontWeight: FontWeight.w700)),
            ),
            for (final e in d.entries)
              _Row(
                u: u,
                entry: e,
                pluginName: _plugin.isEmpty && plugins.length > 1
                    ? _name(e.pluginId)
                    : '',
                focusNode: () {
                  if (!first) return null;
                  first = false;
                  return _firstRowFn;
                }(),
                autofocus: e == days.first.entries.first,
                onUp: e == days.first.entries.first
                    ? () => _mineFn.requestFocus()
                    : null,
                onTap: () => _open(e),
              ),
          ],
          if (failed.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 24 * u),
              child: Text(
                  'Non hanno risposto: ${failed.map(_name).join(', ')}.',
                  style: TextStyle(color: AppTheme.textLow, fontSize: 20 * u)),
            ),
        ],
      );
    }

    return TvFocusable(
      canRequestFocus: false,
      onEsc: widget.embedded ? null : () => context.pop(),
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, Expanded(child: body)],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final double u;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDown;
  final FocusNode? focusNode;
  final bool autofocus;
  const _Chip({
    required this.u,
    required this.onTap,
    this.label = '',
    this.icon,
    this.selected = false,
    this.onDown,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        onActivate: onTap,
        onDown: onDown,
        builder: (context, focused) => Container(
          padding: EdgeInsets.symmetric(
              horizontal: (label.isEmpty ? 12 : 22) * u, vertical: 12 * u),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: focused ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(40 * u),
            border: Border.all(
              color: focused
                  ? AppTheme.primary
                  : (selected ? AppTheme.primary : Colors.transparent),
              width: 2,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null)
              Icon(icon, size: 26 * u, color: AppTheme.textHigh),
            if (icon != null && label.isNotEmpty) SizedBox(width: 10 * u),
            if (label.isNotEmpty)
              Text(label,
                  style: TextStyle(
                      color: AppTheme.textHigh,
                      fontSize: 22 * u,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  final double u;
  final CalendarEntry entry;
  final String pluginName;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onUp;
  final VoidCallback onTap;
  const _Row({
    required this.u,
    required this.entry,
    required this.pluginName,
    required this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final episode = calendarLandscapeThumb(e);
    // A phone: no time column (the time leads the small line) and
    // "Previsto" under the text instead of at the far right.
    final compact = MediaQuery.sizeOf(context).width < 600;
    // An episode's still is landscape; a film's poster portrait.
    final thumbH = (compact ? 84 : 96) * u;
    final thumbW = episode ? thumbH * 16 / 9 : thumbH * 2 / 3;
    final time = calendarTimeLabel(e);
    final sub = calendarSubtitle(e);
    final dim = !e.available;
    final previsto = Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * u, vertical: 6 * u),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textLow),
        borderRadius: BorderRadius.circular(20 * u),
      ),
      child: Text('Previsto',
          style: TextStyle(color: AppTheme.textMid, fontSize: 19 * u)),
    );
    final small = [if (compact) time, sub, pluginName]
        .where((s) => s.isNotEmpty)
        .join('  ·  ');
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * u),
      child: TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        onActivate: onTap,
        onUp: onUp,
        builder: (context, focused) => Container(
          padding: EdgeInsets.all(10 * u),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: focused ? 0.10 : 0.04),
            borderRadius: BorderRadius.circular(12 * u),
            border: Border.all(
                color: focused ? AppTheme.primary : Colors.transparent,
                width: 2),
          ),
          child: Row(children: [
            if (!compact)
              SizedBox(
                width: 90 * u,
                child: Text(time,
                    style: TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 24 * u,
                        fontWeight: FontWeight.w600)),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8 * u),
              child: SizedBox(
                width: thumbW,
                height: thumbH,
                child: e.item.posterUrl.isEmpty
                    ? const ColoredBox(color: AppTheme.surface2)
                    : Opacity(
                        opacity: dim ? 0.55 : 1,
                        child: CachedNetworkImage(
                          imageRenderMethodForWeb:
                              ImageRenderMethodForWeb.HttpGet,
                          imageUrl: posterSrc(
                              e.item.posterUrl, cacheWidthFor(context, thumbW),
                              proxy: true),
                          memCacheWidth: cacheWidthFor(context, thumbW),
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppTheme.surface2),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: AppTheme.surface2),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 18 * u),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    if (e.followed) ...[
                      Icon(Icons.bookmark_rounded,
                          size: 24 * u, color: AppTheme.primary),
                      SizedBox(width: 6 * u),
                    ],
                    Flexible(
                      child: Text(calendarTitle(e),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppTheme.textHigh,
                              fontSize: 26 * u,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if (small.isNotEmpty) ...[
                    SizedBox(height: 4 * u),
                    Text(
                      small,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: AppTheme.textMid, fontSize: 21 * u),
                    ),
                  ],
                  if (dim && compact) ...[
                    SizedBox(height: 8 * u),
                    previsto,
                  ],
                ],
              ),
            ),
            if (dim && !compact) ...[
              SizedBox(width: 12 * u),
              previsto,
            ],
          ]),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final double u;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Message(
      {required this.u, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_rounded, size: 56 * u, color: AppTheme.textLow),
          SizedBox(height: 14 * u),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMid, fontSize: 24 * u)),
          if (action != null) ...[
            SizedBox(height: 18 * u),
            _Chip(u: u, label: action!, autofocus: true, onTap: onAction!),
          ],
        ]),
      );
}
