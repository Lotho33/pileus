import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AppStartedEvent extends AuthEvent {
  /// Hold on the splash for [AuthBloc.minSplashDuration] before emitting the
  /// resolved state. True from splash_screen.dart (a cold start really is
  /// behind the splash). False when a screen fires this as a direct user
  /// action — e.g. the "Continua" button after server discovery — where a
  /// 2 s dead wait with no feedback just reads as the app hanging.
  final bool splashFloor;
  const AppStartedEvent({this.splashFloor = true});

  @override
  List<Object?> get props => [splashFloor];
}

class AuthenticateDeviceEvent extends AuthEvent {
  final String pin;
  const AuthenticateDeviceEvent(this.pin);
  @override
  List<Object?> get props => [pin];
}

class SelectProfileEvent extends AuthEvent {
  final String profileId;
  const SelectProfileEvent(this.profileId);
  @override
  List<Object?> get props => [profileId];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

// "Cambia server" from Settings: wipes the cached host + pinned TLS
// fingerprint + device pairing (all server-scoped) and drops back to server
// discovery. Heavier than LogoutEvent, which keeps the host so a mid-session
// expiry doesn't trigger a re-scan.
class ChangeServerEvent extends AuthEvent {
  const ChangeServerEvent();
}

// Distinct from LogoutEvent: goes back to the profile picker but keeps the
// device paired (no admin PIN re-entry needed), just like Netflix/Plex
// "switch profile" — LogoutEvent is the heavier "unpair this device" action.
class SwitchProfileEvent extends AuthEvent {
  const SwitchProfileEvent();
}

class CreateProfileEvent extends AuthEvent {
  final String name;
  const CreateProfileEvent({required this.name});
  @override
  List<Object?> get props => [name];
}

// Fired by any BLoC that receives a gRPC UNAUTHENTICATED error.
class SessionExpiredEvent extends AuthEvent {
  const SessionExpiredEvent();
}
