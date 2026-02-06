import 'package:equatable/equatable.dart';

/// 用户实体
class User extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.isActive = true,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        username,
        displayName,
        avatarUrl,
        email,
        isActive,
        createdAt,
      ];
}
