import '../../domain/entities/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.roomId,
    required super.senderId,
    required super.senderName,
    super.senderAvatar,
    required super.content,
    super.type,
    super.status,
    super.mediaUrl,
    super.thumbnailUrl,
    super.mediaSize,
    super.mimeType,
    super.metadata,
    required super.createdAt,
    super.editedAt,
    super.isDeleted,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? json['message_id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? json['sender']?['display_name'] ?? '',
      senderAvatar: json['sender_avatar'] ?? json['sender']?['avatar_url'],
      content: json['content'] ?? '',
      type: _parseType(json['type']),
      status: _parseStatus(json['status']),
      mediaUrl: json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      mediaSize: json['media_size'],
      mimeType: json['mime_type'],
      metadata: json['metadata'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      editedAt: json['edited_at'] != null 
          ? DateTime.parse(json['edited_at']) 
          : null,
      isDeleted: json['is_deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'type': type.name,
      'status': status.name,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'media_size': mediaSize,
      'mime_type': mimeType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  Message toEntity() => Message(
        id: id,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        senderAvatar: senderAvatar,
        content: content,
        type: type,
        status: status,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        mediaSize: mediaSize,
        mimeType: mimeType,
        metadata: metadata,
        createdAt: createdAt,
        editedAt: editedAt,
        isDeleted: isDeleted,
      );
}
