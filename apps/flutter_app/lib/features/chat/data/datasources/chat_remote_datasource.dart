import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/user.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';
import '../models/member_model.dart';
import '../models/user_model.dart';
import '../../../../core/network/dio_client.dart';

abstract class ChatRemoteDataSource {
  Future<List<Room>> getRooms();
  Future<Room> getRoom(String roomId);
  Future<Room> createRoom({
    required String name,
    String? description,
    RoomType type,
    List<String>? memberIds,
    int? retentionHours,
  });
  Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    String? avatarUrl,
    int? retentionHours,
  });
  Future<void> leaveRoom(String roomId);
  Future<List<Message>> getMessages({
    required String roomId,
    int limit,
    String? beforeId,
  });
  Future<Message> sendMessage({
    required String roomId,
    required String content,
    MessageType type,
    Map<String, dynamic>? metadata,
  });
  Future<void> markAsRead(String roomId, {String? messageId});
  Future<void> deleteMessage(String roomId, String messageId);
  Future<List<Member>> getRoomMembers(String roomId);
  Future<void> addRoomMembers(String roomId, List<String> userIds);
  Future<void> removeRoomMember(String roomId, String userId);
  Future<void> updateMemberRole(String roomId, String userId, MemberRole role);
  Future<void> muteRoom(String roomId, bool muted);
  Future<void> pinRoom(String roomId, bool pinned);
  Future<List<User>> searchUsers(String query, {int limit = 20});
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final DioClient _client;

  ChatRemoteDataSourceImpl(this._client);

  @override
  Future<List<Room>> getRooms() async {
    final response = await _client.get('/chat/rooms');
    final data = response.data['rooms'] as List? ?? response.data as List? ?? [];
    return data.map((json) => RoomModel.fromJson(json).toEntity()).toList();
  }

  @override
  Future<Room> getRoom(String roomId) async {
    final response = await _client.get('/chat/rooms/$roomId');
    return RoomModel.fromJson(response.data).toEntity();
  }

  @override
  Future<Room> createRoom({
    required String name,
    String? description,
    RoomType type = RoomType.group,
    List<String>? memberIds,
    int? retentionHours,
  }) async {
    final response = await _client.post(
      '/chat/rooms',
      data: {
        'name': name,
        if (description != null) 'description': description,
        'type': type.name,
        if (memberIds != null) 'member_ids': memberIds,
        if (retentionHours != null) 'retention_hours': retentionHours,
      },
    );
    return RoomModel.fromJson(response.data).toEntity();
  }

  @override
  Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    String? avatarUrl,
    int? retentionHours,
  }) async {
    final response = await _client.put(
      '/chat/rooms/$roomId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (retentionHours != null) 'retention_hours': retentionHours,
      },
    );
    return RoomModel.fromJson(response.data).toEntity();
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _client.post('/chat/rooms/$roomId/leave');
  }

  @override
  Future<List<Message>> getMessages({
    required String roomId,
    int limit = 50,
    String? beforeId,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      if (beforeId != null) 'before_id': beforeId,
    };
    final response = await _client.get(
      '/chat/rooms/$roomId/messages',
      queryParameters: queryParams,
    );
    final data = response.data['messages'] as List? ?? response.data as List? ?? [];
    return data.map((json) => MessageModel.fromJson(json).toEntity()).toList();
  }

  @override
  Future<Message> sendMessage({
    required String roomId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _client.post(
      '/chat/rooms/$roomId/messages',
      data: {
        'content': content,
        'type': type.name,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return MessageModel.fromJson(response.data).toEntity();
  }

  @override
  Future<void> markAsRead(String roomId, {String? messageId}) async {
    await _client.post(
      '/chat/rooms/$roomId/read',
      data: {
        if (messageId != null) 'message_id': messageId,
      },
    );
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    await _client.delete('/chat/rooms/$roomId/messages/$messageId');
  }

  @override
  Future<List<Member>> getRoomMembers(String roomId) async {
    final response = await _client.get('/chat/rooms/$roomId/members');
    final data = response.data['members'] as List? ?? response.data as List? ?? [];
    return data.map((json) => MemberModel.fromJson(json).toEntity()).toList();
  }

  @override
  Future<void> addRoomMembers(String roomId, List<String> userIds) async {
    await _client.post(
      '/chat/rooms/$roomId/members',
      data: {'user_ids': userIds},
    );
  }

  @override
  Future<void> removeRoomMember(String roomId, String userId) async {
    await _client.delete('/chat/rooms/$roomId/members/$userId');
  }

  @override
  Future<void> updateMemberRole(String roomId, String userId, MemberRole role) async {
    await _client.put(
      '/chat/rooms/$roomId/members/$userId/role',
      data: {'role': role.name},
    );
  }

  @override
  Future<void> muteRoom(String roomId, bool muted) async {
    await _client.put(
      '/chat/rooms/$roomId/mute',
      data: {'muted': muted},
    );
  }

  @override
  Future<void> pinRoom(String roomId, bool pinned) async {
    await _client.put(
      '/chat/rooms/$roomId/pin',
      data: {'pinned': pinned},
    );
  }

  @override
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    final response = await _client.get(
      '/chat/users/search',
      queryParameters: {
        'search': query,
        'limit': limit,
      },
    );
    final data = response.data['users'] as List? ?? [];
    return data.map((json) => UserModel.fromJson(json).toEntity()).toList();
  }
}
