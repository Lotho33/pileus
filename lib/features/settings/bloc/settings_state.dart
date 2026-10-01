import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsData extends Equatable {
  final double subtitleFontSize;
  final Color subtitleColor;
  final bool subtitleBgEnabled;
  final double subtitleBottomPadding;

  const SettingsData({
    required this.subtitleFontSize,
    required this.subtitleColor,
    required this.subtitleBgEnabled,
    required this.subtitleBottomPadding,
  });

  @override
  List<Object?> get props => [
        subtitleFontSize,
        subtitleColor,
        subtitleBgEnabled,
        subtitleBottomPadding,
      ];
}

sealed class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoaded extends SettingsState {
  final SettingsData data;
  const SettingsLoaded(this.data);
  @override
  List<Object?> get props => [data];
}
