import 'package:equatable/equatable.dart';

import '../../../core/db/models/local_profile.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class ServerDiscoveryRequired extends AuthState {
  const ServerDiscoveryRequired();
}

class DevicePairingRequired extends AuthState {
  // Set only when this is reached via SessionExpiredEvent (a session that
  // was valid dying mid-use) rather than a cold start with no/expired stored
  // session, or an explicit LogoutEvent — those don't need an explanation,
  // this one does: without it, a token expiring while the user is deep in
  // Settings/the player silently teleports them to /pairing with no context
  // ("why am I here? what happened to my change?"). Each app root's
  // top-level AuthBloc listener (main.dart, mobile_app.dart,
  // desktop_app.dart, web_app.dart) shows it as a SnackBar right after
  // navigating.
  final String? reason;
  const DevicePairingRequired({this.reason});
  @override
  List<Object?> get props => [reason];
}

class ProfileSelectionRequired extends AuthState {
  final List<LocalProfile> profiles;
  const ProfileSelectionRequired(this.profiles);
  @override
  List<Object?> get props => [profiles];
}

class AuthenticatedState extends AuthState {
  final String jwt;
  final String activeProfileId;
  const AuthenticatedState({required this.jwt, required this.activeProfileId});
  @override
  List<Object?> get props => [jwt, activeProfileId];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}
