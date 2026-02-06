import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';

abstract class ChatRoomEvent extends Equatable {
  const ChatRoomEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatRoomEvent {
  final String roomId;

  const LoadMessages(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class LoadMoreMessages extends ChatRoomEvent {
  const LoadMoreMessages();
}

class SendTextMessage extends ChatRoomEvent {
  final String content;

  const SendTextMessage(this.content);

  @override
  List<Object?> get props => [content];
}

class SendMediaMessage extends ChatRoomEvent {
  final String filePath;
  final MessageType type;
  final String? caption;

  const SendMediaMessage({
    required this.filePath,
    required this.type,
    this.caption,
  });

  @override
  List<Object?> get props => [filePath, type, caption];
}

class NewMessageReceived extends ChatRoomEvent {
  final Message message;

  const NewMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class MarkMessagesRead extends ChatRoomEvent {
  const MarkMessagesRead();
}

class DeleteMessage extends ChatRoomEvent {
  final String messageId;

  const DeleteMessage(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class RetryMessage extends ChatRoomEvent {
  final String messageId;
  final String content;

  const RetryMessage({required this.messageId, required this.content});

  @override
  List<Object?> get props => [messageId, content];
}
