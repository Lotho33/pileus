import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'player_ui_state.dart';

class PlayerUiCubit extends Cubit<PlayerUiState> {
  Timer? _hideTimer;

  PlayerUiCubit() : super(const PlayerUiState());

  // Chiamato al primo frame video visibile. L'overlay parte visibile di
  // default (vedi PlayerUiState) per coprire tutta la fase di caricamento —
  // una volta che il video parte davvero non ha più senso lasciarlo lì
  // ancora per 5s (il vecchio _scheduleHide()): sparisce subito, la
  // AnimatedOpacity da 300ms in playback_screen.dart lo rende comunque una
  // dissolvenza, non un taglio secco. Nessun effetto sul comportamento di
  // showOverlay()/_scheduleHide() per le riaperture successive (tap,
  // attività, ecc.), che restano invariate.
  void onVideoStarted() {
    _hideTimer?.cancel();
    if (!state.settingsOpen && state.overlayVisible) {
      emit(state.copyWith(overlayVisible: false));
    }
  }

  void showOverlay() {
    if (state.settingsOpen) return;
    _hideTimer?.cancel();
    if (!state.overlayVisible) emit(state.copyWith(overlayVisible: true));
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (isClosed || state.settingsOpen) return;
      // A ±10s skip (or seek-bar commit) from the overlay very often kicks
      // off a rebuffer; if this fired mid-buffer the overlay vanished and
      // the user had to re-summon it before they could skip again. Hold it
      // up while buffering and re-check — setBuffering(false) restarts a
      // full 5s once playback actually resumes.
      if (state.buffering) {
        _scheduleHide();
        return;
      }
      emit(state.copyWith(overlayVisible: false));
    });
  }

  void openSettings() {
    _hideTimer?.cancel();
    emit(state.copyWith(settingsOpen: true, overlayVisible: false));
  }

  void closeSettings() {
    emit(state.copyWith(settingsOpen: false));
    showOverlay();
  }

  void setBuffering(bool value) {
    if (state.buffering == value) return;
    // Riparte da zero a ogni nuovo episodio di buffering — esplicitamente,
    // non fidandosi che bufferingPercent sia già a 0 da solo. buffering e
    // bufferingPercent arrivano dall'engine senza garanzia d'ordine tra
    // loro: se il percent riporta un valore mentre buffering è già tornato
    // false (il riempimento del buffer è un dato continuo, non esclusivo
    // dei momenti in cui la UI mostra lo spinner), quel valore restava lì finché
    // non arrivava il prossimo "true", facendo ripartire il nuovo episodio
    // di buffering con la percentuale stantia del giro precedente invece che
    // da zero.
    emit(state.copyWith(
      buffering: value,
      bufferingPercent: 0,
    ));
    // Freeze the auto-hide countdown for the whole rebuffer, then give a
    // fresh full 5s once playback resumes — so the user can fire another
    // skip straight away instead of first pressing a key just to bring the
    // overlay back (see _scheduleHide).
    if (value) {
      _hideTimer?.cancel();
    } else if (state.overlayVisible && !state.settingsOpen) {
      _scheduleHide();
    }
  }

  // `value` è il riempimento del buffer (0-100) riportato dall'engine.
  // Arrotondato prima del confronto per non emettere uno stato nuovo a ogni
  // singolo decimale. Ignorato quando non si sta bufferando — l'engine
  // continua a riportare il riempimento anche durante la riproduzione
  // normale, non solo durante un vero stallo, e senza questo
  // guard quei valori si accumulavano in bufferingPercent senza che la UI
  // li mostrasse mai (nascosta finché buffering è false), solo per poi
  // riapparire come percentuale sbagliata al prossimo giro di buffering
  // (vedi il commento in setBuffering).
  void setBufferingPercent(double value) {
    if (!state.buffering) return;
    final clamped = value.clamp(0, 100).toDouble();
    if ((state.bufferingPercent - clamped).abs() < 1) return;
    emit(state.copyWith(bufferingPercent: clamped));
  }

  // Imposta i secondi rimanenti per il "prossimo episodio" banner.
  // Passa null per nasconderlo.
  void setNextEpisodeSecs(int? secs) {
    if (state.nextEpisodeSecs == secs) return;
    emit(state.copyWith(nextEpisodeSecs: secs));
  }

  @override
  Future<void> close() {
    _hideTimer?.cancel();
    return super.close();
  }
}
