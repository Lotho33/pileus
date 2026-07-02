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
  const DevicePairingRequired();
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
