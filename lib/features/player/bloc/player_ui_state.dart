import 'package:equatable/equatable.dart';

class PlayerUiState extends Equatable {
  final bool overlayVisible;
  final bool settingsOpen;
  final bool buffering;
  // Riempimento (0-100) del buffer fisso di mpv prima che la riproduzione
  // riprenda (proprietà nativa `cache-buffering-state`); 0 quando non si
  // sta bufferando o quando mpv non ha ancora riportato un valore.
  final double bufferingPercent;
  final int? nextEpisodeSecs; // null = nascosto; >0 = countdown

  const PlayerUiState({
    this.overlayVisible = true,
    this.settingsOpen = false,
    this.buffering = false,
    this.bufferingPercent = 0,
    this.nextEpisodeSecs,
  });

  PlayerUiState copyWith({
    bool? overlayVisible,
    bool? settingsOpen,
    bool? buffering,
    double? bufferingPercent,
    Object? nextEpisodeSecs = _sentinel,
  }) {
    return PlayerUiState(
      overlayVisible: overlayVisible ?? this.overlayVisible,
      settingsOpen: settingsOpen ?? this.settingsOpen,
      buffering: buffering ?? this.buffering,
      bufferingPercent: bufferingPercent ?? this.bufferingPercent,
      nextEpisodeSecs: identical(nextEpisodeSecs, _sentinel)
          ? this.nextEpisodeSecs
          : nextEpisodeSecs as int?,
    );
  }

  @override
  List<Object?> get props =>
      [overlayVisible, settingsOpen, buffering, bufferingPercent, nextEpisodeSecs];
}

const _sentinel = Object();
