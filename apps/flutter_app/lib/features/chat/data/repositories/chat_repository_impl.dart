import 'dart:async';
import 'dart:io';
import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/chat_local_datasource.dart';
import '../../../../core/network/websocket_client.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/media_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final ChatLocalDataSource _localDataSource;
  final WebSocketClient _webSocketClient;

  final _messageStreamController = StreamController<Message>.broadcast();
  final _roomUpdateStreamController = StreamController<Room>.broadcast();

  ChatRepositoryImpl({
    required ChatRemoteDataSource remoteDataSource,
    required ChatLocalDataSource localDataSource,
    required WebSocketClient webSocketClient,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _webSocketClient = webSocketClient {
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    _webSocketClient.messageStream.listen((data) {
      if (data['type'] == 'new_message') {
        final message = _parseMessage(data['payload']);
        _messageStreamController.add(message);
        _localDataSource.cacheMessage(message);
      } else if (data['type'] == 'room_update') {
        final room = _parseRoom(data['payload']);
        _roomUpdateStreamController.add(room);
      }
    });
  }

  Message _parseMessage(Map<String, dynamic> data) {
    return Message(
      id: data['id'],
      roomId: data['room_id'],
      senderId: data['sender_id'],
      senderName: data['sender_name'] ?? '',
      senderAvatar: data['sender_avatar'],
      content: data['content'] ?? '',
      type: _parseMessageType(data['type']),
      status: MessageStatus.sent,
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }

  Room _parseRoom(Map<String, dynamic> data) {
    return Room(
      id: data['id'],
      name: data['name'] ?? '',
      unreadCount: data['unread_count'] ?? 0,
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'file': return MessageType.file;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  @override
  Future<List<Room>> getRooms() async {
    try {
      final rooms = await _remoteDataSource.getRooms();
      await _localDataSource.cacheRooms(rooms);
      return rooms;
    } catch (_) {
      return await _localDataSource.getCachedRooms();
    }
  }

  @override
  Future<Room> getRoom(String roomId) async {
    return await _remoteDataSource.getRoom(roomId);
  }

  @override
  Future<Room> createRoom({
    required String name,
    String? description,
    RoomType type = RoomType.group,
    List<String>? memberIds,
    int? retentionHours,
  }) async {
    final room = await _remoteDataSource.createRoom(
      name: name,
      description: description,
      type: type,
      memberIds: memberIds,
      retentionHours: retentionHours,
    );
    await _localDataSource.cacheRooms([room]);
    return room;
  }

  @override
  Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    String? avatarUrl,
    int? retentionHours,
  }) async {
    return await _remoteDataSource.updateRoom(
      roomId: roomId,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      retentionHours: retentionHours,
    );
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _remoteDataSource.leaveRoom(roomId);
    await _localDataSource.clearRoomMessages(roomId);
  }

  @override
  Future<List<Message>> getMessages({
    required String roomId,
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      final messages = await _remoteDataSource.getMessages(
        roomId: roomId,
        limit: limit,
        beforeId: beforeId,
      );
      await _localDataSource.cacheMessages(messages);
      return messages;
    } catch (_) {
      return await _localDataSource.getCachedMessages(roomId, limit: limit);
    }
  }

  @override
  Future<Message> sendMessage({
    required String roomId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = Message(
      id: tempId,
      roomId: roomId,
      senderId: '',
      senderName: '',
      content: content,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    
    _messageStreamController.add(tempMessage);
    await _localDataSource.cacheMessage(tempMessage);

    try {
      final message = await _remoteDataSource.sendMessage(
        roomId: roomId,
        content: content,
        type: type,
        metadata: metadata,
      );
      
      await _localDataSource.deleteMessage(tempId);
      await _localDataSource.cacheMessage(message);
      
      return message;
    } catch (e) {
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      await _localDataSource.updateMessageStatus(tempId, 'failed');
      _messageStreamController.add(failedMessage);
      rethrow;
    }
  }

  @override
  Future<Message> sendMediaMessage({
    required String roomId,
    required String filePath,
    required MessageType type,
    String? caption,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final file = File(filePath);
    final fileName = file.path.split('/').last;
    
    final tempMessage = Message(
      id: tempId,
      roomId: roomId,
      senderId: '',
      senderName: '',
      content: caption ?? fileName,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    
    _messageStreamController.add(tempMessage);
    await _localDataSource.cacheMessage(tempMessage);

    try {
      // 上传文件
      final mediaService = getIt<MediaService>();
      final mediaInfo = await mediaService.upload(file, roomId: roomId);
      
      // 发送媒体消息
      final message = await _remoteDataSource.sendMessage(
        roomId: roomId,
        content: caption ?? mediaInfo.originalName,
        type: type,
        metadata: {
          'media_url': mediaInfo.downloadUrl,
          'thumbnail_url': mediaInfo.thumbnailUrl,
          'media_size': mediaInfo.size,
          'mime_type': mediaInfo.mimeType,
        },
      );
      
      await _localDataSource.deleteMessage(tempId);
      await _localDataSource.cacheMessage(message);
      
      return message;
    } catch (e) {
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      await _localDataSource.updateMessageStatus(tempId, 'failed');
      _messageStreamController.add(failedMessage);
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String roomId, {String? messageId}) async {
    await _remoteDataSource.markAsRead(roomId, messageId: messageId);
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    await _remoteDataSource.deleteMessage(roomId, messageId);
    await _localDataSource.deleteMessage(messageId);
  }

  @override
  Future<List<Member>> getRoomMembers(String roomId) async {
    return await _remoteDataSource.getRoomMembers(roomId);
  }

  @override
  Future<void> addRoomMembers(String roomId, List<String> userIds) async {
    await _remoteDataSource.addRoomMembers(roomId, userIds);
  }

  @override
  Future<void> removeRoomMember(String roomId, String userId) async {
    await _remoteDataSource.removeRoomMember(roomId, userId);
  }

  @override
  Future<void> updateMemberRole(String roomId, String userId, MemberRole role) async {
    await _remoteDataSource.updateMemberRole(roomId, userId, role);
  }

  @override
  Future<void> muteRoom(String roomId, bool muted) async {
    await _remoteDataSource.muteRoom(roomId, muted);
  }

  @override
  Future<void> pinRoom(String roomId, bool pinned) async {
    await _remoteDataSource.pinRoom(roomId, pinned);
  }

  @override
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    return await _remoteDataSource.searchUsers(query, limit: limit);
  }

  @override
  Stream<Message> get messageStream => _messageStreamController.stream;

  @override
  Stream<Room> get roomUpdateStream => _roomUpdateStreamController.stream;

  @override
  Future<void> connect() async {
    await _webSocketClient.connect();
  }

  @override
  Future<void> disconnect() async {
    await _webSocketClient.disconnect();
  }

  void dispose() {
    _messageStreamController.close();
    _roomUpdateStreamController.close();
  }
}
