import 'package:equatable/equatable.dart';
import 'member.dart';
import 'message.dart';

enum RoomType {
  direct,
  group,
  channel,
}

class Room extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final RoomType type;
  final Message? lastMessage;
  final int unreadCount;
  final List<Member> members;
  final String? creatorId;
  final bool isMuted;
  final bool isPinned;
  final int? retentionHours;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Room({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    this.type = RoomType.group,
    this.lastMessage,
    this.unreadCount = 0,
    this.members = const [],
    this.creatorId,
    this.isMuted = false,
    this.isPinned = false,
    this.retentionHours,
    required this.createdAt,
    this.updatedAt,
  });

  Room copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    RoomType? type,
    Message? lastMessage,
    int? unreadCount,
    List<Member>? members,
    String? creatorId,
    bool? isMuted,
    bool? isPinned,
    int? retentionHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      members: members ?? this.members,
      creatorId: creatorId ?? this.creatorId,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      retentionHours: retentionHours ?? this.retentionHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        avatarUrl,
        type,
        lastMessage,
        unreadCount,
        members,
        creatorId,
        isMuted,
        isPinned,
        retentionHours,
        createdAt,
        updatedAt,
      ];
}
