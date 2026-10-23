import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../features/media/bloc/plugin_bloc.dart';
import '../../features/media/bloc/plugin_state.dart';

/// A small pill over the home while the server isn't answering and what's
/// on screen is the last list known (PluginsLoaded.offline) — the home stays
/// usable from disk, this only says why opening things fails. Never takes
/// focus or taps. Same widget on TV, mobile, desktop and web; each shell
/// places it at the bottom centre of its content.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeFocus(
        child: BlocBuilder<PluginBloc, PluginState>(
          bloc: getIt<PluginBloc>(),
          buildWhen: (a, b) => _offline(a) != _offline(b),
          builder: (context, state) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _offline(state)
                ? Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const ValueKey('offline'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              size: 18, color: AppTheme.textMid),
                          SizedBox(width: 8),
                          Text('Server non raggiungibile — riprovo…',
                              style: TextStyle(
                                  color: AppTheme.textHigh,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('online')),
          ),
        ),
      ),
    );
  }

  static bool _offline(PluginState s) => s is PluginsLoaded && s.offline;
}
