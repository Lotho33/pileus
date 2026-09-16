import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/grpc/grpc_errors.dart';
import '../../auth/data/auth_repository.dart';
import 'profile_management_state.dart';

class ProfileManagementCubit extends Cubit<ProfileMgmtState> {
  final AuthRepository _repo;
  final void Function()? onSessionExpired;
  String? _profileId;

  ProfileManagementCubit(this._repo, {this.onSessionExpired})
      : super(const ProfileMgmtInitial());

  Future<void> load(String profileId) async {
    _profileId = profileId;
    emit(const ProfileMgmtLoading());
    await _reload();
  }

  Future<void> _reload() async {
    final id = _profileId;
    if (id == null) return;
    try {
      final profiles = await _repo.getLocalProfiles();
      // A Cubit's emit() (unlike a Bloc's) throws StateError if the cubit
      // was already closed — real here: BlocProvider closes this
      // synchronously the moment the screen is popped (e.g. Back while an
      // await above is still in flight), independent of whether the
      // gRPC call it's waiting on has actually finished yet.
      if (isClosed) return;
      final profile = profiles.where((p) => p.profileId == id).firstOrNull;
      if (profile == null) {
        emit(const ProfileMgmtError('Profilo non trovato'));
        return;
      }
      final session = await _repo.getStoredSession();
      if (isClosed) return;
      final defaultId = session?.lastActiveProfileId;
      final otherDefault = (defaultId != null && defaultId != id)
          ? profiles.where((p) => p.profileId == defaultId).firstOrNull
          : null;
      emit(ProfileMgmtLoaded(profile,
          isOnlyProfile: profiles.length == 1,
          isDefault: defaultId == id,
          otherDefaultName: otherDefault?.profileName));
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isClosed) return;
      emit(ProfileMgmtError(e.toString()));
    }
  }

  /// Runs [action] against the repo; on failure, surfaces the error via
  /// [ProfileMgmtError] (the screen's BlocConsumer shows it as a snackbar)
  /// and then falls back to [_reload] so the form reappears afterward
  /// instead of leaving the screen stuck on a spinner.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return;
      }
      if (isClosed) return;
      emit(ProfileMgmtError(e.toString()));
      await _reload();
    }
  }

  Future<void> rename(String newName) async {
    final id = _profileId;
    if (id == null) return;
    await _guard(() => _repo.renameProfile(id, newName));
  }

  Future<void> updateAvatarUrl(String url) async {
    final id = _profileId;
    if (id == null) return;
    await _guard(() => _repo.updateAvatarUrl(id, url));
  }

  /// Sets or clears this profile as the one auto-selected on the next cold
  /// start (see AuthBloc._onAppStarted / AuthRepository.setLastActiveProfile).
  /// There's only ever one default at a time (a single lastActiveProfileId
  /// field): setting it is REFUSED here when another profile already holds
  /// it — the settings screen shows a blocking dialog instead of silently
  /// stealing it, and the user must clear the other one first.
  Future<void> setDefault(bool value) async {
    final id = _profileId;
    if (id == null) return;
    final session = await _repo.getStoredSession();
    final previousDefaultId = session?.lastActiveProfileId;
    if (value && previousDefaultId != null && previousDefaultId != id) {
      // Occupied — no-op. The UI gates this and explains why.
      return;
    }
    await _guard(() => value
        ? _repo.setLastActiveProfile(id)
        : _repo.clearLastActiveProfile());
  }

  /// Deletes the profile. Returns false (with the real error surfaced via
  /// ProfileMgmtError) if a network/server error prevented completing the
  /// deletion.
  Future<bool> delete() async {
    final id = _profileId;
    if (id == null) return false;
    try {
      await _repo.deleteProfileRemote(id);
      if (isClosed) return true;
      emit(const ProfileMgmtDeleted());
      return true;
    } catch (e) {
      if (isUnauthenticated(e)) {
        onSessionExpired?.call();
        return false;
      }
      if (isClosed) return false;
      emit(ProfileMgmtError(e.toString()));
      await _reload();
      return false;
    }
  }
}
