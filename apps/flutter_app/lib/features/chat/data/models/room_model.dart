import '../../domain/entities/room.dart';
import 'member_model.dart';
import 'message_model.dart';

class RoomModel extends Room {
  const RoomModel({
    required super.id,
    required super.name,
    super.description,
    super.avatarUrl,
    super.type,
    super.lastMessage,
    super.unreadCount,
    super.members,
    super.creatorId,
    super.isMuted,
    super.isPinned,
    super.retentionHours,
    required super.createdAt,
    super.updatedAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] ?? json['room_id'],
      name: json['name'] ?? '',
      description: json['description'],
      avatarUrl: json['avatar_url'],
      type: _parseType(json['type']),
      lastMessage: json['last_message'] != null 
          ? MessageModel.fromJson(json['last_message']).toEntity() 
          : null,
      unreadCount: json['unread_count'] ?? 0,
      members: json['members'] != null 
          ? (json['members'] as List)
              .map((m) => MemberModel.fromJson(m).toEntity())
              .toList()
          : [],
      creatorId: json['creator_id'],
      isMuted: json['is_muted'] ?? false,
      isPinned: json['is_pinned'] ?? false,
      retentionHours: json['retention_hours'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'type': type.name,
      'unread_count': unreadCount,
      'creator_id': creatorId,
      'is_muted': isMuted,
      'is_pinned': isPinned,
      'retention_hours': retentionHours,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static RoomType _parseType(String? type) {
    switch (type) {
      case 'direct':
        return RoomType.direct;
      case 'channel':
        return RoomType.channel;
      default:
        return RoomType.group;
    }
  }

  Room toEntity() => Room(
        id: id,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        type: type,
        lastMessage: lastMessage,
        unreadCount: unreadCount,
        members: members,
        creatorId: creatorId,
        isMuted: isMuted,
        isPinned: isPinned,
        retentionHours: retentionHours,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
