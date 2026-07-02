import 'package:equatable/equatable.dart';

import '../../../core/db/models/local_profile.dart';

sealed class ProfileMgmtState extends Equatable {
  const ProfileMgmtState();
  @override
  List<Object?> get props => [];
}

class ProfileMgmtInitial extends ProfileMgmtState {
  const ProfileMgmtInitial();
}

class ProfileMgmtLoading extends ProfileMgmtState {
  const ProfileMgmtLoading();
}

class ProfileMgmtLoaded extends ProfileMgmtState {
  final LocalProfile profile;
  final bool isOnlyProfile;
  final bool isDefault;
  /// Name of whichever OTHER profile currently holds the "default" slot, or
  /// null if it's free (or held by this profile). The settings screen uses
  /// it to block setting this profile as default and tell the user which
  /// one to clear first.
  final String? otherDefaultName;
  const ProfileMgmtLoaded(this.profile,
      {required this.isOnlyProfile,
      required this.isDefault,
      this.otherDefaultName});
  @override
  List<Object?> get props => [profile.profileId, profile.profileName, profile.avatarUrl,
      profile.isChildProfile, isOnlyProfile, isDefault,
      otherDefaultName];
}

class ProfileMgmtError extends ProfileMgmtState {
  final String message;
  const ProfileMgmtError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Terminal state — the active profile was deleted. The screen reacts by
/// navigating back to /profiles; there is no "current profile" to show
/// anymore.
class ProfileMgmtDeleted extends ProfileMgmtState {
  const ProfileMgmtDeleted();
}
