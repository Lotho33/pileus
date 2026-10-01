import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/settings_repository.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repo;

  SettingsCubit(this._repo) : super(const SettingsInitial());

  void load() {
    emit(SettingsLoaded(SettingsData(
      subtitleFontSize: _repo.getSubtitleFontSize(),
      subtitleColor: _repo.getSubtitleColor(),
      subtitleBgEnabled: _repo.getSubtitleBgEnabled(),
      subtitleBottomPadding: _repo.getSubtitleBottomPadding(),
    )));
  }

  SettingsData? get _current {
    final s = state;
    return s is SettingsLoaded ? s.data : null;
  }

  Future<void> updateSubtitleFontSize(double v) async {
    final cur = _current;
    if (cur == null) return;
    await _repo.setSubtitleFontSize(v);
    emit(SettingsLoaded(SettingsData(
      subtitleFontSize: v,
      subtitleColor: cur.subtitleColor,
      subtitleBgEnabled: cur.subtitleBgEnabled,
      subtitleBottomPadding: cur.subtitleBottomPadding,
    )));
  }

  Future<void> updateSubtitleColor(Color v) async {
    final cur = _current;
    if (cur == null) return;
    await _repo.setSubtitleColor(v);
    emit(SettingsLoaded(SettingsData(
      subtitleFontSize: cur.subtitleFontSize,
      subtitleColor: v,
      subtitleBgEnabled: cur.subtitleBgEnabled,
      subtitleBottomPadding: cur.subtitleBottomPadding,
    )));
  }

  Future<void> updateSubtitleBgEnabled(bool v) async {
    final cur = _current;
    if (cur == null) return;
    await _repo.setSubtitleBgEnabled(v);
    emit(SettingsLoaded(SettingsData(
      subtitleFontSize: cur.subtitleFontSize,
      subtitleColor: cur.subtitleColor,
      subtitleBgEnabled: v,
      subtitleBottomPadding: cur.subtitleBottomPadding,
    )));
  }

  Future<void> updateSubtitleBottomPadding(double v) async {
    final cur = _current;
    if (cur == null) return;
    await _repo.setSubtitleBottomPadding(v);
    emit(SettingsLoaded(SettingsData(
      subtitleFontSize: cur.subtitleFontSize,
      subtitleColor: cur.subtitleColor,
      subtitleBgEnabled: cur.subtitleBgEnabled,
      subtitleBottomPadding: v,
    )));
  }
}
