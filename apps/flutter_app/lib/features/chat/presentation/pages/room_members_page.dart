import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/websocket_client.dart';
import '../../../../core/security/secure_storage.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/chat_repository.dart';
import 'add_members_page.dart';

class RoomMembersPage extends StatefulWidget {
  final Room room;

  const RoomMembersPage({super.key, required this.room});

  @override
  State<RoomMembersPage> createState() => _RoomMembersPageState();
}

class _RoomMembersPageState extends State<RoomMembersPage> {
  late List<Member> _members;
  late Room _room;
  bool _isLoading = false;
  String? _currentUserId;
  MemberRole? _currentUserRole;
  StreamSubscription<Map<String, dynamic>>? _memberChangeSubscription;

  /// 格式化显示名称，去掉@前缀和:server后缀
  String _formatDisplayName(String name) {
    var result = name;
    // 去掉@前缀
    if (result.startsWith('@')) {
      result = result.substring(1);
    }
    // 去掉:server后缀
    final colonIndex = result.indexOf(':');
    if (colonIndex > 0) {
      result = result.substring(0, colonIndex);
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _members = widget.room.members;
    _loadCurrentUserInfo();
    _setupMemberChangeListener();
  }

  @override
  void dispose() {
    _memberChangeSubscription?.cancel();
    super.dispose();
  }

  /// 加载当前用户信息并确定角色
  Future<void> _loadCurrentUserInfo() async {
    try {
      final secureStorage = getIt<SecureStorageService>();
      final userInfo = await secureStorage.getUserInfo();
      _currentUserId = userInfo['userId'];
      
      if (_currentUserId != null && mounted) {
        // 从成员列表中找到当前用户的角色
        final currentMember = _members.cast<Member?>().firstWhere(
          (m) => m?.userId == _currentUserId,
          orElse: () => null,
        );
        setState(() {
          _currentUserRole = currentMember?.role;
        });
      }
    } catch (e) {
      debugPrint('加载当前用户信息失败: $e');
    }
  }

  /// 设置WebSocket监听成员变更
  void _setupMemberChangeListener() {
    try {
      final wsClient = getIt<WebSocketClient>();
      _memberChangeSubscription = wsClient.messageStream.listen((data) {
        final type = data['type'] as String?;
        final payload = data['payload'] as Map<String, dynamic>?;
        
        if (payload == null) return;
        
        final roomId = payload['room_id'] as String?;
        if (roomId != widget.room.id) return;
        
        if (type == 'member_removed') {
          _refreshMembers();
        } else if (type == 'kicked_from_room') {
          // 当前用户被移除，返回上一页
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('您已被移出该群组')),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('设置WebSocket监听失败: $e');
    }
  }

  /// 判断当前用户是否可以移除指定成员
  bool _canRemoveMember(Member member) {
    if (_currentUserRole == null) return false;
    if (_currentUserId == member.userId) return false; // 不能移除自己
    if (member.role == MemberRole.owner) return false; // 不能移除群主
    
    // 角色级别判断
    const roleLevel = {
      MemberRole.owner: 4,
      MemberRole.admin: 3,
      MemberRole.moderator: 2,
      MemberRole.member: 1,
    };
    
    return roleLevel[_currentUserRole]! > roleLevel[member.role]!;
  }

  Future<void> _refreshMembers() async {
    setState(() => _isLoading = true);
    try {
      final chatRepository = getIt<ChatRepository>();
      final updatedRoom = await chatRepository.getRoom(widget.room.id);
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          _members = updatedRoom.members;
          _isLoading = false;
        });
        // 刷新后重新检查当前用户角色
        _updateCurrentUserRole();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新失败: ${e.toString()}')),
        );
      }
    }
  }

  /// 更新当前用户角色（成员列表变更后调用）
  void _updateCurrentUserRole() {
    if (_currentUserId == null) return;
    final currentMember = _members.cast<Member?>().firstWhere(
      (m) => m?.userId == _currentUserId,
      orElse: () => null,
    );
    setState(() {
      _currentUserRole = currentMember?.role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群成员 (${_members.length})'),
        actions: [
          if (_room.type != RoomType.direct)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _showAddMemberDialog(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? _buildEmptyView(context)
              : RefreshIndicator(
                  onRefresh: _refreshMembers,
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return _buildMemberItem(context, member);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无成员',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(BuildContext context, Member member) {
    final theme = Theme.of(context);
    final formattedName = _formatDisplayName(member.displayName);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
            ? NetworkImage(member.avatarUrl!)
            : null,
        child: member.avatarUrl == null || member.avatarUrl!.isEmpty
            ? Text(
                formattedName.isNotEmpty
                    ? formattedName[0].toUpperCase()
                    : '?',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(formattedName),
          const SizedBox(width: 8),
          if (member.role == MemberRole.owner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '群主',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            )
          else if (member.role == MemberRole.admin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '管理员',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text('@$formattedName'),
      trailing: _room.type != RoomType.direct
          ? PopupMenuButton<String>(
              onSelected: (value) => _handleMemberAction(context, member, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'message',
                  child: ListTile(
                    leading: Icon(Icons.message),
                    title: Text('发消息'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text('查看资料'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_canRemoveMember(member))
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.person_remove, color: Colors.red),
                      title: Text('移除成员', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            )
          : null,
      onTap: () => _showMemberProfile(context, member),
    );
  }

  void _handleMemberAction(BuildContext context, Member member, String action) {
    final formattedName = _formatDisplayName(member.displayName);
    switch (action) {
      case 'message':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('即将与 $formattedName 聊天')),
        );
        break;
      case 'profile':
        _showMemberProfile(context, member);
        break;
      case 'remove':
        _confirmRemoveMember(context, member);
        break;
    }
  }

  /// 显示移除成员确认对话框
  void _confirmRemoveMember(BuildContext context, Member member) {
    final formattedName = _formatDisplayName(member.displayName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除成员'),
        content: Text('确定要将 $formattedName 移出群组吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _removeMember(member);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  /// 执行移除成员操作
  Future<void> _removeMember(Member member) async {
    final formattedName = _formatDisplayName(member.displayName);
    setState(() => _isLoading = true);
    
    try {
      final chatRepository = getIt<ChatRepository>();
      await chatRepository.removeRoomMember(widget.room.id, member.userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已将 $formattedName 移出群组')),
        );
        await _refreshMembers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('移除失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMemberProfile(BuildContext context, Member member) {
    final formattedName = _formatDisplayName(member.displayName);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                    member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                child: member.avatarUrl == null || member.avatarUrl!.isEmpty
                    ? Text(
                        formattedName.isNotEmpty
                            ? formattedName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 32,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                formattedName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '@$formattedName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context: context,
                    icon: Icons.message,
                    label: '发消息',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('即将与 $formattedName 聊天')),
                      );
                    },
                  ),
                  _buildActionButton(
                    context: context,
                    icon: Icons.call,
                    label: '语音通话',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('语音通话功能开发中')),
                      );
                    },
                  ),
                  _buildActionButton(
                    context: context,
                    icon: Icons.videocam,
                    label: '视频通话',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('视频通话功能开发中')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddMembersPage(room: _room),
      ),
    );

    if (result == true && mounted) {
      _refreshMembers();
    }
  }
}
