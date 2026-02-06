import 'package:flutter/material.dart';
import '../../domain/entities/room.dart';

class ChatSettingsPage extends StatefulWidget {
  final Room room;

  const ChatSettingsPage({super.key, required this.room});

  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  late bool _muteNotifications;
  late bool _pinToTop;
  late bool _showMemberActivity;

  @override
  void initState() {
    super.initState();
    _muteNotifications = false;
    _pinToTop = false;
    _showMemberActivity = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = widget.room;

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天设置'),
      ),
      body: ListView(
        children: [
          // 聊天室信息头部
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: room.avatarUrl != null && room.avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            room.avatarUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 32,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          room.name.isNotEmpty ? room.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 32,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  room.name,
                  style: theme.textTheme.headlineSmall,
                ),
                if (room.type != RoomType.direct)
                  Text(
                    '${room.members.length} 名成员',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),

          // 通知设置
          _buildSectionHeader(context, '通知设置'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off_outlined),
            title: const Text('消息免打扰'),
            subtitle: const Text('关闭此聊天的通知提醒'),
            value: _muteNotifications,
            onChanged: (value) {
              setState(() => _muteNotifications = value);
              _showSaveHint(context);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.push_pin_outlined),
            title: const Text('置顶聊天'),
            subtitle: const Text('将此聊天固定在列表顶部'),
            value: _pinToTop,
            onChanged: (value) {
              setState(() => _pinToTop = value);
              _showSaveHint(context);
            },
          ),
          const Divider(),

          // 隐私设置
          _buildSectionHeader(context, '隐私设置'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('显示成员活动'),
            subtitle: const Text('显示成员的在线状态和正在输入'),
            value: _showMemberActivity,
            onChanged: (value) {
              setState(() => _showMemberActivity = value);
              _showSaveHint(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('消息自动删除'),
            subtitle: const Text('关闭'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAutoDeleteDialog(context),
          ),
          const Divider(),

          // 聊天记录
          _buildSectionHeader(context, '聊天记录'),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('搜索聊天记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('搜索功能开发中')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导出聊天记录'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('导出功能开发中')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text('清空聊天记录', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmClearHistory(context),
          ),
          const Divider(),

          // 群组操作（非私聊）
          if (room.type != RoomType.direct) ...[
            _buildSectionHeader(context, '群组操作'),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: theme.colorScheme.error),
              title: Text('退出群组', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => _confirmLeaveGroup(context),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showSaveHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showAutoDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('消息自动删除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('关闭'),
              value: 0,
              groupValue: 0,
              onChanged: (value) => Navigator.pop(dialogContext),
            ),
            RadioListTile<int>(
              title: const Text('24小时'),
              value: 24,
              groupValue: 0,
              onChanged: (value) => Navigator.pop(dialogContext),
            ),
            RadioListTile<int>(
              title: const Text('7天'),
              value: 168,
              groupValue: 0,
              onChanged: (value) => Navigator.pop(dialogContext),
            ),
            RadioListTile<int>(
              title: const Text('30天'),
              value: 720,
              groupValue: 0,
              onChanged: (value) => Navigator.pop(dialogContext),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空所有聊天记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('聊天记录已清空')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出群组'),
        content: const Text('确定要退出此群组吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context); // 返回聊天列表
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出群组')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
