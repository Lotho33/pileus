import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/server_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/grpc/remote_server_connect.dart';
import '../../../core/grpc/server_address.dart';
import '../../../core/theme/app_scale.dart';
import '../../../shared/widgets/on_screen_keyboard.dart';
import '../../../shared/widgets/on_screen_text_display.dart';
import '../../../shared/widgets/pileus_spinner.dart';
import '../../../shared/widgets/tv_focusable.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart' show AppStartedEvent;
import '../bloc/auth_state.dart';
import '../data/auth_repository.dart';

// dart:io's Platform throws at runtime on web the moment any member is
// touched, so kIsWeb must short-circuit before Platform.isAndroid — same
// landmine as main.dart's _isDesktop/Platform.isAndroid guards.
bool get _isAndroid => !kIsWeb && Platform.isAndroid;

class ServerDiscoveryScreen extends StatefulWidget {
  const ServerDiscoveryScreen({super.key});

  @override
  State<ServerDiscoveryScreen> createState() => _ServerDiscoveryScreenState();
}

class _ServerDiscoveryScreenState extends State<ServerDiscoveryScreen> {
  static const _port = ServerPorts.http;
  static const _timeout = Duration(seconds: 2);

  // Optionally baked in at build time so a device on a LAN with no other
  // way to auto-detect the server — common on Android TV / Fire TV —
  // still auto-connects instead of forcing manual entry:
  //   flutter build ... --dart-define=PILEUS_MYCELIUM_HOST=<server-ip>
  // Empty by default (public builds): the user enters the address once.
  static const _bakedHost =
      String.fromEnvironment('PILEUS_MYCELIUM_HOST', defaultValue: '');

  // 'mycelium.local' used to be a candidate here — dropped alongside
  // mycelium-core's own mDNS responder for it (see _saveHost's
  // doc): with nothing left to answer for that name, it could never
  // resolve, so keeping it only cost a probe slot every scan.
  static List<String> get _candidates => [
        if (_bakedHost.isNotEmpty) _bakedHost,
        '127.0.0.1',
        if (_isAndroid) '10.0.2.2',
      ];

  _ScanState _scanState = _ScanState.scanning;
  String? _foundHost;
  // Live LAN-sweep progress (for the scanning screen's subtitle).
  int _sweepDone = 0;
  int _sweepTotal = 0;
  bool _sweeping = false;
  final _manualController = TextEditingController();
  final _manualFocusNode = FocusNode();
  final _keyboardKey = GlobalKey<OnScreenKeyboardState>();
  final _connettiFocusNode = FocusNode();
  final _retryFocusNode = FocusNode();
  final _continuaFocusNode = FocusNode();
  final _useDifferentFocusNode = FocusNode();
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _manualController.dispose();
    _manualFocusNode.dispose();
    _connettiFocusNode.dispose();
    _retryFocusNode.dispose();
    _continuaFocusNode.dispose();
    _useDifferentFocusNode.dispose();
    super.dispose();
  }

  /// Null if `host` isn't a reachable Mycelium instance. Otherwise carries
  /// the TLS pinning fingerprint alongside the yes/no — grpc_tls_fingerprint
  /// is empty when the server reports TLS off (grpc_tls: false) — and the
  /// real gRPC port (`grpc_port`; null on an older server that
  /// doesn't report it, in which case ServerPorts.grpc is the fallback).
  Future<_ProbeResult?> _probe(String host, {Duration? timeout}) async {
    try {
      final res = await http
          .get(Uri.http('$host:$_port', '/pileus/info'))
          .timeout(timeout ?? _timeout);
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['name'] != 'Mycelium') return null;
      final fingerprint = json['grpc_tls_fingerprint'] as String?;
      final grpcPort = (json['grpc_port'] as num?)?.toInt();
      return _ProbeResult(
        tlsFingerprint: (fingerprint != null && fingerprint.isNotEmpty)
            ? fingerprint
            : null,
        grpcPort: (grpcPort != null && grpcPort > 0) ? grpcPort : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _scan() async {
    setState(() {
      _scanState = _ScanState.scanning;
      _error = null;
    });
    final completer = Completer<({String host, _ProbeResult result})?>();
    var pending = _candidates.length;
    for (final host in _candidates) {
      _probe(host).then((result) {
        if (result != null && !completer.isCompleted) {
          completer.complete((host: host, result: result));
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete(null);
      });
    }
    var found = await completer.future;

    // Nothing on the well-known hosts (the norm — there's no mDNS/well-known
    // hostname to fall back to) — sweep the local /24 and let whichever
    // address answers /pileus/info win.
    if (found == null && mounted) {
      found = await _sweepLan();
    }

    if (!mounted) return;
    if (found != null) {
      await _saveHost(found.host, found.result);
      if (!mounted) return;
      setState(() {
        _scanState = _ScanState.found;
        _foundHost = found!.host;
      });
    } else {
      setState(() {
        _scanState = _ScanState.notFound;
        // Was _manualFocusNode (the address display field) — read-only,
        // same reasoning as settings_text_dialog.dart's own field: typing
        // only happens through OnScreenKeyboard below.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _keyboardKey.currentState?.firstFocusNode.requestFocus();
        });
      });
    }
  }

  /// Probes every host on this device's local /24 (`x.x.x.1‥254`) in
  /// parallel, bounded, short timeout. Returns the first that identifies as
  /// Mycelium, or null. No mDNS, no server-side support needed — just the
  /// `/pileus/info` endpoint that's already the liveness check.
  Future<({String host, _ProbeResult result})?> _sweepLan() async {
    if (kIsWeb) return null;
    final prefixes = await _localV24Prefixes();
    if (prefixes.isEmpty) return null;

    final hosts = <String>[
      for (final p in prefixes)
        for (var i = 1; i <= 254; i++) '$p.$i',
    ];
    if (mounted) {
      setState(() {
        _sweeping = true;
        _sweepDone = 0;
        _sweepTotal = hosts.length;
      });
    }

    const concurrency = 48;
    const sweepTimeout = Duration(milliseconds: 700);
    final completer = Completer<({String host, _ProbeResult result})?>();
    var index = 0;
    var active = 0;
    var launched = 0;

    void pump() {
      while (active < concurrency &&
          index < hosts.length &&
          !completer.isCompleted) {
        final host = hosts[index++];
        active++;
        launched++;
        _probe(host, timeout: sweepTimeout).then((result) {
          active--;
          if (mounted && !completer.isCompleted) {
            setState(() => _sweepDone++);
          }
          if (result != null && !completer.isCompleted) {
            completer.complete((host: host, result: result));
            return;
          }
          if (launched >= hosts.length &&
              active == 0 &&
              !completer.isCompleted) {
            completer.complete(null);
          }
          pump();
        });
      }
    }

    pump();
    final res = await completer.future;
    if (mounted) setState(() => _sweeping = false);
    return res;
  }

  /// Private-range /24 prefixes for every up, non-loopback IPv4 interface
  /// (e.g. `192.168.1`). /24 covers essentially every home network.
  Future<List<String>> _localV24Prefixes() async {
    final out = <String>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          final isPrivate = ip.startsWith('10.') ||
              ip.startsWith('192.168.') ||
              RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
          if (!isPrivate) continue;
          final dot = ip.lastIndexOf('.');
          final prefix = ip.substring(0, dot);
          if (!out.contains(prefix)) out.add(prefix);
        }
      }
    } catch (_) {}
    return out;
  }

  Future<void> _connectManual() async {
    final input = _manualController.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    final parsed = parseServerAddressInput(input);
    // Remote server mode (see server_address.dart): a mycelium
    // published on the public internet — http(s):// URL, a domain, or a
    // public IP — instead of a LAN address. The scan above never finds
    // these (no UDP broadcast, no /24 sweep reaches the public internet),
    // so this manual field is the only way in.
    if (parsed.remote) {
      final result = await connectToRemoteServer(parsed);
      if (!mounted) return;
      if (result.ok) {
        setState(() {
          _scanState = _ScanState.found;
          _foundHost = parsed.host;
          _connecting = false;
        });
      } else {
        setState(() {
          _connecting = false;
          _error = result.error;
        });
      }
      return;
    }
    final result = await _probe(parsed.host);
    if (!mounted) return;
    if (result != null) {
      await _saveHost(parsed.host, result);
      setState(() {
        _scanState = _ScanState.found;
        _foundHost = parsed.host;
        _connecting = false;
      });
    } else {
      setState(() {
        _connecting = false;
        _error = 'Server non trovato su ${parsed.host}:$_port';
      });
    }
  }

  /// Bails out of the auto-found result into the manual-entry UI — reuses
  /// `_ScanState.notFound`'s screen without re-running `_scan()` (a fresh
  /// scan would almost certainly just land back on the same auto-found
  /// server, since nothing about the network changed). Needed because
  /// `_scan()` always runs on every entry to this screen, including from
  /// "Cambia server" elsewhere in the app — on a LAN with more than one
  /// Mycelium reachable (or just not the one the user actually wants right
  /// now), landing in `_ScanState.found` used to be a dead end: "Continua"
  /// was the only option.
  void _switchToManual() {
    setState(() {
      _scanState = _ScanState.notFound;
      _error = null;
    });
    // Same fix as _scan()'s own notFound branch above — focus the
    // keyboard's first key, not the read-only address display field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardKey.currentState?.firstFocusNode.requestFocus();
    });
  }

  Future<void> _saveHost(String host, _ProbeResult result) async {
    await getIt<AuthRepository>().saveHostInfo(host, result.tlsFingerprint,
        grpcPort: result.grpcPort);
    await rebuildGrpcClients(host,
        tlsFingerprint: result.tlsFingerprint, grpcPort: result.grpcPort);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is DevicePairingRequired) context.go('/pairing');
        if (state is ProfileSelectionRequired) context.go('/profiles');
        if (state is AuthenticatedState) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 1.0,
                    colors: [Color(0x287C6AF7), Color(0x000D0D1A)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppScale.space(context, 32),
                            horizontal: AppScale.space(context, 16)),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: AppScale.space(context, 480)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Pileus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AppScale.space(context, 62),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              SizedBox(height: AppScale.space(context, 8)),
                              Text(
                                'Connessione a Mycelium',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: AppScale.label(context)),
                              ),
                              SizedBox(height: AppScale.space(context, 40)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppScale.space(context, 40),
                                    vertical: AppScale.space(context, 36)),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141428),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF2A2A4A)),
                                ),
                                child: _buildBody(),
                              ),
                              SizedBox(height: AppScale.space(context, 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_scanState) {
      _ScanState.scanning => _buildScanning(),
      _ScanState.found => _buildFound(),
      _ScanState.notFound => _buildManual(),
    };
  }

  Widget _buildScanning() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PileusSpinner(
              size: AppScale.spinnerL(context), color: const Color(0xFF7C6AF7)),
          SizedBox(height: AppScale.space(context, 28)),
          Text(
            'Ricerca server Mycelium…',
            style: TextStyle(
                color: Colors.white70, fontSize: AppScale.label(context)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppScale.space(context, 8)),
          Text(
            _sweeping
                ? 'Scansione della rete locale… ($_sweepDone/$_sweepTotal)'
                : 'Verifica indirizzi noti…',
            style: TextStyle(
                color: Colors.white38, fontSize: AppScale.caption(context)),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildFound() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_rounded,
              color: const Color(0xFF4ADE80), size: AppScale.iconXL(context)),
          SizedBox(height: AppScale.space(context, 20)),
          Text(
            _foundHost ?? '',
            style: TextStyle(
                color: Colors.white,
                fontSize: AppScale.space(context, 22),
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppScale.space(context, 6)),
          Text(
            'Server trovato',
            style: TextStyle(
                color: Colors.white54, fontSize: AppScale.caption(context)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppScale.space(context, 32)),
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final busy = state is AuthLoading;
              return _GradientButton(
                autofocus: true,
                focusNode: _continuaFocusNode,
                loading: busy,
                label: busy ? '' : 'Continua',
                onDown: busy ? null : () => _useDifferentFocusNode.requestFocus(),
                // splashFloor: false — this is a direct button press, not a
                // cold start, so skip the 2 s splash hold. The button stays
                // in its loading state until the bloc resolves and the
                // BlocListener above navigates, so the hop to /pairing is a
                // clean transition instead of a dead couple of seconds.
                onPressed: busy
                    ? null
                    : () => getIt<AuthBloc>()
                        .add(const AppStartedEvent(splashFloor: false)),
              );
            },
          ),
          SizedBox(height: AppScale.space(context, 12)),
          _TextActionButton(
            focusNode: _useDifferentFocusNode,
            onUp: () => _continuaFocusNode.requestFocus(),
            label: 'Usa un altro indirizzo',
            onPressed: _switchToManual,
          ),
        ],
      );

  Widget _buildManual() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: const Color(0xFFFB923C), size: AppScale.iconXL(context)),
          SizedBox(height: AppScale.space(context, 16)),
          Text(
            'Server non trovato automaticamente',
            style: TextStyle(
                color: Colors.white70, fontSize: AppScale.space(context, 18)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppScale.space(context, 28)),
          Text(
            'Indirizzo server',
            style: TextStyle(
                color: Colors.white70,
                fontSize: AppScale.caption(context),
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: AppScale.space(context, 4)),
          // Remote server mode (see server_address.dart) — an
          // IP address here means "on my network" (LAN mode); anything else
          // (a domain, a full https:// URL) means "reach it over the
          // internet" (remote/HTTPS mode). Spelled out since nothing else
          // on this screen signals that the same field now does two
          // different things depending on what's typed into it.
          Text(
            'Un IP (rete locale) o un dominio/https:// (server remoto)',
            style: TextStyle(
                color: Colors.white38,
                fontSize: AppScale.caption(context) * 0.85),
          ),
          SizedBox(height: AppScale.space(context, 10)),
          // Ancestor-only catcher — arrowDown is free to bubble up here and
          // hand off to the on-screen keyboard below. hostAddressOnly (see
          // on_screen_keyboard.dart) covers both an IP (192.168.1.10) and a
          // hostname — digits, lowercase, '.', '-', no space — where before
          // there was no D-pad-native way to type anything into this field
          // at all, stranding a user whose network has no other way to
          // auto-discover the server.
          TvFocusable(
            canRequestFocus: false,
            onDown: () =>
                _keyboardKey.currentState?.firstFocusNode.requestFocus(),
            builder: (context, _) => OnScreenTextDisplay(
              controller: _manualController,
              focusNode: _manualFocusNode,
              hintText: '192.168.1.10 o https://dominio',
              hintStyle: TextStyle(
                  color: Colors.white24, fontSize: AppScale.space(context, 18)),
              style: TextStyle(
                  color: Colors.white, fontSize: AppScale.label(context)),
              fillColor: const Color(0xFF0D0D1A),
              borderColor: const Color(0xFF2A2A4A),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: AppScale.space(context, 20),
                  vertical: AppScale.space(context, 18)),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: AppScale.space(context, 6)),
            Text(
              _error!,
              style: TextStyle(
                  color: Colors.redAccent, fontSize: AppScale.caption(context)),
            ),
          ],
          SizedBox(height: AppScale.space(context, 14)),
          OnScreenKeyboard(
            key: _keyboardKey,
            controller: _manualController,
            hostAddressOnly: true,
            onSubmit: _connectManual,
            onNavigateUp: () => _manualFocusNode.requestFocus(),
            // This was never wired up — Down from the keyboard's last row had
            // nowhere to go and just did nothing, making "Connetti" completely
            // unreachable by D-pad.
            onNavigateDown: () => _connettiFocusNode.requestFocus(),
          ),
          SizedBox(height: AppScale.space(context, 20)),
          _GradientButton(
            focusNode: _connettiFocusNode,
            onUp: () => _keyboardKey.currentState?.focusLastRow(),
            onDown: () => _retryFocusNode.requestFocus(),
            label: _connecting ? '' : 'Connetti',
            onPressed: _connecting ? null : _connectManual,
            loading: _connecting,
          ),
          SizedBox(height: AppScale.space(context, 12)),
          _TextActionButton(
            focusNode: _retryFocusNode,
            onUp: () => _connettiFocusNode.requestFocus(),
            label: 'Riprova scansione automatica',
            onPressed: _scan,
          ),
        ],
      );
}

// ── shared button widgets ──────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.autofocus = false,
    this.focusNode,
    this.onUp,
    this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onActivate: onPressed,
      onUp: onUp,
      onDown: onDown,
      onFocusChange: (focused) {
        if (!focused || !context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 150), alignment: 0.5);
          }
        });
      },
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: AppScale.space(context, 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [Color(0xFF3A3A5A), Color(0xFF3A3A5A)])
              : LinearGradient(
                  colors: focused
                      ? [const Color(0xFF9D8FFF), const Color(0xFF7C6AF7)]
                      : [const Color(0xFF7C6AF7), const Color(0xFF5A4FD4)],
                ),
          boxShadow: focused && onPressed != null
              ? AppScale.focusGlow(const Color(0xFF7C6AF7),
                  alpha: 0x55 / 255, blur: 20)
              : [],
        ),
        alignment: Alignment.center,
        child: loading
            ? PileusSpinner(
                size: AppScale.spinnerS(context), color: Colors.white)
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppScale.label(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onUp;
  const _TextActionButton({
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      onUp: onUp,
      onFocusChange: (focused) {
        if (!focused || !context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Scrollable.ensureVisible(context,
                duration: const Duration(milliseconds: 150), alignment: 0.5);
          }
        });
      },
      builder: (context, focused) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppScale.space(context, 12)),
        child: Text(
          label,
          style: TextStyle(
            color: focused ? Colors.white : Colors.white38,
            fontSize: AppScale.caption(context),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

enum _ScanState { scanning, found, notFound }

class _ProbeResult {
  final String? tlsFingerprint;
  final int? grpcPort;
  const _ProbeResult({this.tlsFingerprint, this.grpcPort});
}
