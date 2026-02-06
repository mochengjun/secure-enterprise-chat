import '../entities/room.dart';
import '../entities/message.dart';
import '../entities/member.dart';
import '../entities/user.dart';

abstract class ChatRepository {
  /// 获取房间列表
  Future<List<Room>> getRooms();

  /// 获取单个房间详情
  Future<Room> getRoom(String roomId);

  /// 创建房间
  Future<Room> createRoom({
    required String name,
    String? description,
    RoomType type = RoomType.group,
    List<String>? memberIds,
    int? retentionHours,
  });

  /// 更新房间
  Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    String? avatarUrl,
    int? retentionHours,
  });

  /// 删除/离开房间
  Future<void> leaveRoom(String roomId);

  /// 获取消息列表
  Future<List<Message>> getMessages({
    required String roomId,
    int limit = 50,
    String? beforeId,
  });

  /// 发送文本消息
  Future<Message> sendMessage({
    required String roomId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  });

  /// 发送媒体消息
  Future<Message> sendMediaMessage({
    required String roomId,
    required String filePath,
    required MessageType type,
    String? caption,
  });

  /// 标记消息已读
  Future<void> markAsRead(String roomId, {String? messageId});

  /// 删除消息
  Future<void> deleteMessage(String roomId, String messageId);

  /// 获取房间成员
  Future<List<Member>> getRoomMembers(String roomId);

  /// 添加房间成员
  Future<void> addRoomMembers(String roomId, List<String> userIds);

  /// 移除房间成员
  Future<void> removeRoomMember(String roomId, String userId);

  /// 更新成员角色
  Future<void> updateMemberRole(String roomId, String userId, MemberRole role);

  /// 静音/取消静音房间
  Future<void> muteRoom(String roomId, bool muted);

  /// 置顶/取消置顶房间
  Future<void> pinRoom(String roomId, bool pinned);

  /// 搜索用户
  Future<List<User>> searchUsers(String query, {int limit = 20});

  /// 消息流（实时更新）
  Stream<Message> get messageStream;

  /// 房间更新流
  Stream<Room> get roomUpdateStream;

  /// 连接 WebSocket
  Future<void> connect();

  /// 断开 WebSocket
  Future<void> disconnect();
}
