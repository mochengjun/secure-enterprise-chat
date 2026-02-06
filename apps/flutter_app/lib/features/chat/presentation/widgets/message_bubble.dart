import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showSender;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final VoidCallback? onMediaTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onLongPress,
    this.onRetry,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(theme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: _buildContent(theme),
                  ),
                ),
                const SizedBox(height: 2),
                _buildStatusRow(theme),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (message.senderAvatar != null && message.senderAvatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(message.senderAvatar!),
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: Text(
        message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final textColor = isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent(theme);
      case MessageType.video:
        return _buildVideoContent(theme, textColor);
      case MessageType.audio:
        return _buildAudioContent(theme, textColor);
      case MessageType.file:
        return _buildFileContent(theme, textColor);
      case MessageType.system:
        return _buildSystemContent(theme);
      default:
        return Text(
          message.content,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        );
    }
  }

  Widget _buildImageContent(ThemeData theme) {
    if (message.mediaUrl != null) {
      return GestureDetector(
        onTap: onMediaTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.thumbnailUrl ?? message.mediaUrl!,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 200,
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                color: theme.colorScheme.errorContainer,
                child: Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.onErrorContainer,
                ),
              );
            },
          ),
        ),
      );
    }
    return Text(
      '[图片]',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildVideoContent(ThemeData theme, Color textColor) {
    return GestureDetector(
      onTap: onMediaTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            message.content.isNotEmpty ? message.content : '[视频]',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic, color: textColor, size: 20),
        const SizedBox(width: 8),
        Text(
          message.content.isNotEmpty ? message.content : '[语音]',
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ],
    );
  }

  Widget _buildFileContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file, color: textColor, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message.content.isNotEmpty ? message.content : '[文件]',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemContent(ThemeData theme) {
    return Text(
      message.content,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusRow(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(theme),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.outline,
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: theme.colorScheme.outline,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colorScheme.outline,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colorScheme.primary,
        );
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(
            Icons.error_outline,
            size: 14,
            color: theme.colorScheme.error,
          ),
        );
    }
  }

  String _formatTime() {
    final time = message.createdAt;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
