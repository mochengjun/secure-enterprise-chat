import 'package:equatable/equatable.dart';

enum MemberRole {
  owner,
  admin,
  moderator,
  member,
}

class Member extends Equatable {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final MemberRole role;
  final DateTime joinedAt;
  final bool isOnline;

  const Member({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = MemberRole.member,
    required this.joinedAt,
    this.isOnline = false,
  });

  @override
  List<Object?> get props => [
        userId,
        displayName,
        avatarUrl,
        role,
        joinedAt,
        isOnline,
      ];
}
