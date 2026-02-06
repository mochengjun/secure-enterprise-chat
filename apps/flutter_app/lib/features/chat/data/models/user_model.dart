import '../../domain/entities/user.dart';

/// 用户数据模型
class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.isActive = true,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'],
      email: json['email'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'email': email,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User toEntity() {
    return User(
      id: id,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      email: email,
      isActive: isActive,
      createdAt: createdAt,
    );
  }

  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      email: user.email,
      isActive: user.isActive,
      createdAt: user.createdAt,
    );
  }
}
