import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String userId;
  final String username;
  final String? phoneNumber;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
  final bool mfaEnabled;
  final bool isActive;
  final DateTime createdAt;

  const User({
    required this.userId,
    required this.username,
    this.phoneNumber,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.mfaEnabled = false,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        userId,
        username,
        phoneNumber,
        email,
        displayName,
        avatarUrl,
        mfaEnabled,
        isActive,
        createdAt,
      ];
}
