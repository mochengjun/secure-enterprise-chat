import 'package:flutter/material.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';

class RoomListItem extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const RoomListItem({
    super.key,
    required this.room,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: _buildAvatar(theme),
      title: Row(
        children: [
          if (room.isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.push_pin,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          Expanded(
            child: Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: room.unreadCount > 0 
                    ? FontWeight.bold 
                    : FontWeight.normal,
              ),
            ),
          ),
          if (room.isMuted)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.notifications_off,
                size: 16,
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
      subtitle: room.lastMessage != null
          ? Text(
              _formatLastMessage(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: room.unreadCount > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          if (room.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: room.isMuted
                    ? theme.colorScheme.outline
                    : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (room.avatarUrl != null && room.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(room.avatarUrl!),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        _getInitials(),
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials() {
    final words = room.name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return room.name.isNotEmpty 
        ? room.name[0].toUpperCase() 
        : '?';
  }

  String _formatLastMessage() {
    final message = room.lastMessage;
    if (message == null) return '';
    
    String prefix = '';
    if (room.type == RoomType.group && message.senderName.isNotEmpty) {
      prefix = '${message.senderName}: ';
    }
    
    switch (message.type) {
      case MessageType.image:
        return '$prefix[图片]';
      case MessageType.video:
        return '$prefix[视频]';
      case MessageType.audio:
        return '$prefix[语音]';
      case MessageType.file:
        return '$prefix[文件]';
      case MessageType.system:
        return message.content;
      default:
        return '$prefix${message.content}';
    }
  }

  String _formatTime() {
    final time = room.lastMessage?.createdAt ?? room.updatedAt ?? room.createdAt;
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
