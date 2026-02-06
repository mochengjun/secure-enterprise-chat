part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String username;
  final String password;
  final String? deviceId;
  final String? deviceName;
  final String? deviceType;

  const LoginRequested({
    required this.username,
    required this.password,
    this.deviceId,
    this.deviceName,
    this.deviceType,
  });

  @override
  List<Object?> get props => [username, password, deviceId, deviceName, deviceType];
}

class RegisterRequested extends AuthEvent {
  final String username;
  final String password;
  final String? phoneNumber;
  final String? email;
  final String? displayName;

  const RegisterRequested({
    required this.username,
    required this.password,
    this.phoneNumber,
    this.email,
    this.displayName,
  });

  @override
  List<Object?> get props => [username, password, phoneNumber, email, displayName];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class MFAVerifyRequested extends AuthEvent {
  final String username;
  final String password;
  final String code;
  final String? deviceId;

  const MFAVerifyRequested({
    required this.username,
    required this.password,
    required this.code,
    this.deviceId,
  });

  @override
  List<Object?> get props => [username, password, code, deviceId];
}
