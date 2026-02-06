import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/media_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/mark_as_read_usecase.dart';
import 'chat_room_event.dart';
import 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetMessagesUseCase _getMessagesUseCase;
  final SendMessageUseCase _sendMessageUseCase;
  final MarkAsReadUseCase _markAsReadUseCase;
  final ChatRepository _repository;
  
  String? _currentRoomId;
  StreamSubscription<Message>? _messageSubscription;
  static const _pageSize = 50;

  ChatRoomBloc({
    required GetMessagesUseCase getMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required ChatRepository repository,
  })  : _getMessagesUseCase = getMessagesUseCase,
        _sendMessageUseCase = sendMessageUseCase,
        _markAsReadUseCase = markAsReadUseCase,
        _repository = repository,
        super(const ChatRoomInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<NewMessageReceived>(_onNewMessageReceived);
    on<MarkMessagesRead>(_onMarkMessagesRead);
    on<DeleteMessage>(_onDeleteMessage);
    on<RetryMessage>(_onRetryMessage);

    _messageSubscription = _repository.messageStream.listen((message) {
      if (message.roomId == _currentRoomId) {
        add(NewMessageReceived(message));
      }
    });
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    emit(const ChatRoomLoading());
    
    try {
      final messages = await _getMessagesUseCase(
        roomId: event.roomId,
        limit: _pageSize,
      );
      
      final room = await _repository.getRoom(event.roomId);
      
      // 按时间正序排序（最旧的在前，最新的在后）
      final sortedMessages = List<Message>.from(messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      emit(ChatRoomLoaded(
        room: room,
        messages: sortedMessages,
        hasMoreMessages: messages.length >= _pageSize,
      ));
      
      add(const MarkMessagesRead());
    } catch (e) {
      emit(ChatRoomError(message: e.toString()));
    }
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMoreMessages ||
        _currentRoomId == null) {
      return;
    }
    
    emit(currentState.copyWith(isLoadingMore: true));
    
    try {
      final oldestMessage = currentState.messages.isNotEmpty
          ? currentState.messages.first
          : null;
      
      final messages = await _getMessagesUseCase(
        roomId: _currentRoomId!,
        limit: _pageSize,
        beforeId: oldestMessage?.id,
      );
      
      // 合并消息并按时间正序排序
      final updatedMessages = [...messages, ...currentState.messages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      emit(currentState.copyWith(
        messages: updatedMessages,
        isLoadingMore: false,
        hasMoreMessages: messages.length >= _pageSize,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSendTextMessage(
    SendTextMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    // 创建临时消息并立即显示
    final tempMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      roomId: _currentRoomId!,
      senderId: 'current_user_id', // 当前用户ID
      senderName: '我',
      content: event.content,
      type: MessageType.text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    
    // 立即将临时消息添加到列表末尾并更新UI
    final messagesWithTemp = [...currentState.messages, tempMessage];
    emit(currentState.copyWith(
      messages: messagesWithTemp,
      isSending: true,
      sendingError: null,
    ));
    
    try {
      await _sendMessageUseCase(
        roomId: _currentRoomId!,
        content: event.content,
        type: MessageType.text,
      );
      
      // 发送成功，等待 _onNewMessageReceived 替换临时消息
      emit(currentState.copyWith(
        messages: messagesWithTemp,
        isSending: false,
      ));
    } catch (e) {
      // 发送失败，更新临时消息状态为失败
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) {
          return failedMessage;
        }
        return m;
      }).toList();
      
      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
        sendingError: e.toString(),
      ));
    }
  }

  Future<void> _onSendMediaMessage(
    SendMediaMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }

    // 创建临时消息
    final tempMessage = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      roomId: _currentRoomId!,
      senderId: 'current_user_id',
      senderName: '我',
      content: event.caption ?? '发送文件中...',
      type: event.type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    // 立即显示临时消息
    final messagesWithTemp = [...currentState.messages, tempMessage];
    emit(currentState.copyWith(
      messages: messagesWithTemp,
      isSending: true,
      sendingError: null,
    ));

    try {
      // 上传文件
      final mediaService = getIt<MediaService>();
      final file = File(event.filePath);
      final mediaInfo = await mediaService.upload(
        file,
        roomId: _currentRoomId!,
      );

      // 发送媒体消息
      await _sendMessageUseCase(
        roomId: _currentRoomId!,
        content: mediaInfo.originalName,
        type: event.type,
        metadata: {
          'media_url': mediaInfo.downloadUrl,
          'thumbnail_url': mediaInfo.thumbnailUrl,
          'media_size': mediaInfo.size,
          'mime_type': mediaInfo.mimeType,
        },
      );

      emit(currentState.copyWith(
        messages: messagesWithTemp,
        isSending: false,
      ));
    } catch (e) {
      // 发送失败，更新临时消息状态
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) return failedMessage;
        return m;
      }).toList();

      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
        sendingError: e.toString(),
      ));
    }
  }

  void _onNewMessageReceived(
    NewMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final currentState = state;
    if (currentState is! ChatRoomLoaded) return;
    
    final existingIndex = currentState.messages
        .indexWhere((m) => m.id == event.message.id);
    
    List<Message> updatedMessages;
    if (existingIndex != -1) {
      // 已存在相同ID的消息，更新它
      updatedMessages = List.from(currentState.messages);
      updatedMessages[existingIndex] = event.message;
    } else {
      // 查找临时消息（匹配内容和发送者）
      final tempIndex = currentState.messages
          .indexWhere((m) => m.id.startsWith('temp_') && 
                            m.content == event.message.content &&
                            m.senderId == event.message.senderId);
      
      if (tempIndex != -1) {
        // 用真实消息替换临时消息
        updatedMessages = List.from(currentState.messages);
        updatedMessages[tempIndex] = event.message;
      } else {
        // 新消息，添加到列表
        updatedMessages = [...currentState.messages, event.message];
      }
    }
    
    // 按时间正序排序
    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    emit(currentState.copyWith(messages: updatedMessages));
  }

  Future<void> _onMarkMessagesRead(
    MarkMessagesRead event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (_currentRoomId == null) return;
    
    try {
      await _markAsReadUseCase(_currentRoomId!);
    } catch (_) {}
  }

  Future<void> _onDeleteMessage(
    DeleteMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    try {
      await _repository.deleteMessage(_currentRoomId!, event.messageId);
      
      final updatedMessages = currentState.messages
          .where((m) => m.id != event.messageId)
          .toList();
      
      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(sendingError: '删除失败: ${e.toString()}'));
    }
  }

  Future<void> _onRetryMessage(
    RetryMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    final updatedMessages = currentState.messages
        .where((m) => m.id != event.messageId)
        .toList();
    emit(currentState.copyWith(messages: updatedMessages));
    
    add(SendTextMessage(event.content));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    return super.close();
  }
}
