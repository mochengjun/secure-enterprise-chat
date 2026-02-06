import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  system,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class Message extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? mediaSize;
  final String? mimeType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaSize,
    this.mimeType,
    this.metadata,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
  });

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    MessageType? type,
    MessageStatus? status,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaSize,
    String? mimeType,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? editedAt,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaSize: mediaSize ?? this.mediaSize,
      mimeType: mimeType ?? this.mimeType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        roomId,
        senderId,
        senderName,
        senderAvatar,
        content,
        type,
        status,
        mediaUrl,
        thumbnailUrl,
        mediaSize,
        mimeType,
        metadata,
        createdAt,
        editedAt,
        isDeleted,
      ];
}
