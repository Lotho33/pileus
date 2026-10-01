import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads a coarse hardware description from the Android host (see
/// MainActivity.kt) and decides whether this box is too weak to run the
/// default 1080p video + Flutter-compositing path — i.e. whether "hardware
/// modesto" should be on by default. Used once from `main()` when the user
/// has never set the toggle themselves.
///
/// Weak devices in scope: Amlogic S905W/S905X/S805-class TV boxes
/// (Tanix W2 & co.) — GLES2-only Mali-450, ~1–2 GB RAM. On those the
/// Vulkan/GPU path faults under heavy compositing load; the low-power UI
/// flag (blur/shader shedding) keeps them stable.
// ro.board.platform values for the pre-Vulkan Amlogic generation this
// targets. gxbb/gxl are Mali-450 (GLES2 only) — the ones that actually
// fault; gxm (S912) is Mali-T820, GLES3-only, still below the bar for
// 1080p video + Flutter. Newer platforms (txl/sm1/s4…) have Vulkan and a
// real GPU — left out on purpose, the RAM gate still catches a starved one.
const _weakBoardPlatforms = <String>[
  'gxbb', // S905
  'gxl', // S905X / S905W / S905D / S805X
  'gxm', // S912
];

// Matched against Build.HARDWARE / BOARD / SOC_MODEL joined. Narrow on
// purpose — the weak S905/S905X/S905W generation is identified far more
// reliably by its `gxbb`/`gxl` board platform above; these are just a
// backstop for ROMs that don't expose ro.board.platform. Newer, capable
// parts (S905X3 "sm1", S905X4 "s4", S922X "g12b") don't match.
const _weakSocNeedles = <String>[
  's905w',
  's905d',
  's805',
  's812',
];

class DeviceProfile {
  final String hardware;
  final String board;
  final String socModel;
  final String boardPlatform;
  final int totalRamMb;
  final bool isLowRamDevice;

  /// True on real Android TV/Fire TV firmware (FEATURE_LEANBACK or
  /// UiModeManager, checked natively — see MainActivity.kt). False on
  /// everything else, phones/tablets included, which is exactly the case
  /// `main.dart`'s "TV already normalizes the canvas" assumption used to get
  /// wrong: it treated `Platform.isAndroid` as if it meant TV.
  final bool isTv;

  const DeviceProfile({
    this.hardware = '',
    this.board = '',
    this.socModel = '',
    this.boardPlatform = '',
    this.totalRamMb = 0,
    this.isLowRamDevice = false,
    this.isTv = false,
  });

  /// True when the box should default to "hardware modesto".
  bool get isWeak {
    if (isLowRamDevice) return true;
    if (totalRamMb > 0 && totalRamMb <= 1400) return true;

    final platform = boardPlatform.toLowerCase();
    final soc = '$hardware $board $socModel $boardPlatform'.toLowerCase();
    final amlogic = platform.isNotEmpty &&
            _weakBoardPlatforms
                .any((p) => platform == p || platform.startsWith(p)) ||
        _weakSocNeedles.any(soc.contains);

    // A known-weak Amlogic SoC still counts even with 2 GB — the ceiling
    // there is the GLES2 Mali, not RAM.
    if (amlogic && (totalRamMb == 0 || totalRamMb <= 2200)) return true;

    return false;
  }

  @override
  String toString() => 'DeviceProfile(hw=$hardware board=$board '
      'soc=$socModel platform=$boardPlatform ram=${totalRamMb}MB '
      'lowRam=$isLowRamDevice weak=$isWeak tv=$isTv)';
}

const _channel = MethodChannel('pileus/device');

/// Best-effort — returns an empty profile (isWeak == false) on any failure
/// or on a non-Android platform.
Future<DeviceProfile> readDeviceProfile() async {
  if (kIsWeb || !Platform.isAndroid) return const DeviceProfile();
  try {
    final raw = await _channel.invokeMapMethod<String, dynamic>('getProfile');
    if (raw == null) return const DeviceProfile();
    return DeviceProfile(
      hardware: (raw['hardware'] as String?) ?? '',
      board: (raw['board'] as String?) ?? '',
      socModel: (raw['socModel'] as String?) ?? '',
      boardPlatform: (raw['boardPlatform'] as String?) ?? '',
      totalRamMb: (raw['totalRamMb'] as int?) ?? 0,
      isLowRamDevice: (raw['isLowRamDevice'] as bool?) ?? false,
      isTv: (raw['isTv'] as bool?) ?? false,
    );
  } catch (_) {
    return const DeviceProfile();
  }
}
