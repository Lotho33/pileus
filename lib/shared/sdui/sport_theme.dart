import 'package:flutter/material.dart';

/// Sport-category accent color and icon, shared by the home hero, the live
/// carousel cards and the live event popup — one mapping so the accent
/// strip / gradient / chip read as one consistent visual language.
Color sportAccentColor(String cat) {
  switch (cat) {
    case 'football':
      return const Color(0xFF2E7D32);
    case 'basketball':
      return const Color(0xFFE65100);
    case 'tennis':
      return const Color(0xFF558B2F);
    case 'baseball':
      return const Color(0xFF1565C0);
    case 'hockey':
    case 'ice-hockey':
      return const Color(0xFF0277BD);
    case 'rugby':
    case 'rugby-league':
    case 'rugby-union':
      return const Color(0xFF4E342E);
    case 'motor-sports':
      return const Color(0xFFB71C1C);
    case 'american-football':
      return const Color(0xFF4527A0);
    case 'cycling':
      return const Color(0xFF00695C);
    case 'golf':
      return const Color(0xFF33691E);
    case 'boxing':
    case 'fight':
    case 'mma':
      return const Color(0xFF880E4F);
    case 'cricket':
      return const Color(0xFF1A237E);
    case 'volleyball':
      return const Color(0xFF006064);
    case 'darts':
      return const Color(0xFF37474F);
    case 'afl':
      return const Color(0xFF4E342E);
    default:
      return const Color(0xFF1A237E);
  }
}

/// Material icon per sport category. Replaces an emoji-based version: the
/// Linux desktop build ships no colour-emoji font (Android's system font
/// has them), so the emoji rendered as tofu there. Material Icons are part
/// of every Flutter build and tree-shaken, so this costs nothing extra and
/// renders identically on both platforms.
IconData sportIcon(String cat) {
  switch (cat) {
    case 'football':
      return Icons.sports_soccer;
    case 'basketball':
      return Icons.sports_basketball;
    case 'tennis':
      return Icons.sports_tennis;
    case 'baseball':
      return Icons.sports_baseball;
    case 'hockey':
    case 'ice-hockey':
      return Icons.sports_hockey;
    case 'rugby':
    case 'rugby-league':
    case 'rugby-union':
    case 'afl':
      return Icons.sports_rugby;
    case 'motor-sports':
      return Icons.sports_motorsports;
    case 'american-football':
      return Icons.sports_football;
    case 'cycling':
      return Icons.directions_bike;
    case 'golf':
      return Icons.sports_golf;
    case 'boxing':
    case 'fight':
    case 'mma':
      return Icons.sports_mma;
    case 'cricket':
      return Icons.sports_cricket;
    case 'volleyball':
      return Icons.sports_volleyball;
    case 'darts':
      return Icons.my_location;
    default:
      return Icons.sports;
  }
}
