import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/room.dart';

abstract class ChatRoomState extends Equatable {
  const ChatRoomState();

  @override
  List<Object?> get props => [];
}

class ChatRoomInitial extends ChatRoomState {
  const ChatRoomInitial();
}

class ChatRoomLoading extends ChatRoomState {
  const ChatRoomLoading();
}

class ChatRoomLoaded extends ChatRoomState {
  final Room? room;
  final List<Message> messages;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final bool isSending;
  final String? sendingError;

  const ChatRoomLoaded({
    this.room,
    required this.messages,
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.isSending = false,
    this.sendingError,
  });

  ChatRoomLoaded copyWith({
    Room? room,
    List<Message>? messages,
    bool? isLoadingMore,
    bool? hasMoreMessages,
    bool? isSending,
    String? sendingError,
  }) {
    return ChatRoomLoaded(
      room: room ?? this.room,
      messages: messages ?? this.messages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isSending: isSending ?? this.isSending,
      sendingError: sendingError,
    );
  }

  @override
  List<Object?> get props => [
        room,
        messages,
        isLoadingMore,
        hasMoreMessages,
        isSending,
        sendingError,
      ];
}

class ChatRoomError extends ChatRoomState {
  final String message;
  final List<Message>? cachedMessages;

  const ChatRoomError({
    required this.message,
    this.cachedMessages,
  });

  @override
  List<Object?> get props => [message, cachedMessages];
}
