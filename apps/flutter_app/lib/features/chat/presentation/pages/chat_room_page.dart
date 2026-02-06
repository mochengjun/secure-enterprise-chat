import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/room.dart';
import '../bloc/chat_room_bloc.dart';
import '../bloc/chat_room_event.dart';
import '../bloc/chat_room_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import 'chat_settings_page.dart';
import 'media_viewer_page.dart';
import 'room_media_page.dart';
import 'room_members_page.dart';

class ChatRoomPage extends StatelessWidget {
  final String roomId;

  const ChatRoomPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ChatRoomBloc>()..add(LoadMessages(roomId)),
      child: _ChatRoomView(roomId: roomId),
    );
  }
}

class _ChatRoomView extends StatefulWidget {
  final String roomId;

  const _ChatRoomView({required this.roomId});

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final _scrollController = ScrollController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    // In real app, get from auth state
    setState(() => _currentUserId = 'current_user_id');
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100) {
      context.read<ChatRoomBloc>().add(const LoadMoreMessages());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatRoomBloc, ChatRoomState>(
      listener: (context, state) {
        if (state is ChatRoomLoaded && state.sendingError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.sendingError!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: _buildAppBar(context, state),
          body: Column(
            children: [
              Expanded(child: _buildMessageList(context, state)),
              _buildInputArea(context, state),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatRoomState state) {
    String title = '聊天';
    String? subtitle;

    if (state is ChatRoomLoaded && state.room != null) {
      title = state.room!.name;
      final memberCount = state.room!.members.length;
      if (memberCount > 0) {
        subtitle = '$memberCount 名成员';
      }
    }

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call),
          onPressed: () => _startVoiceCall(context),
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () => _startVideoCall(context),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showRoomSettings(context),
        ),
      ],
    );
  }

  Widget _buildMessageList(BuildContext context, ChatRoomState state) {
    if (state is ChatRoomLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ChatRoomError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(state.message),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<ChatRoomBloc>().add(LoadMessages(widget.roomId));
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state is ChatRoomLoaded) {
      if (state.messages.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无消息',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '发送一条消息开始聊天吧',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.isLoadingMore && index == state.messages.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final reversedIndex = state.messages.length - 1 - index;
          final message = state.messages[reversedIndex];
          final isMe = message.senderId == _currentUserId;
          
          bool showSender = false;
          if (!isMe && state.room?.type != RoomType.direct) {
            if (reversedIndex == 0) {
              showSender = true;
            } else {
              final prevMessage = state.messages[reversedIndex - 1];
              showSender = prevMessage.senderId != message.senderId;
            }
          }

          return MessageBubble(
            message: message,
            isMe: isMe,
            showSender: showSender,
            onLongPress: () => _showMessageOptions(context, message),
            onMediaTap: (message.type == MessageType.image || message.type == MessageType.video)
                ? () => _openMediaViewer(context, message)
                : null,
            onRetry: message.status == MessageStatus.failed
                ? () => context.read<ChatRoomBloc>().add(
                    RetryMessage(messageId: message.id, content: message.content))
                : null,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInputArea(BuildContext context, ChatRoomState state) {
    final isSending = state is ChatRoomLoaded && state.isSending;
    
    return MessageInputField(
      onSendText: (text) {
        context.read<ChatRoomBloc>().add(SendTextMessage(text));
      },
      onAttachmentPressed: () => _showAttachmentOptions(context),
      onVoicePressed: () => _startVoiceRecording(context),
      isSending: isSending,
    );
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(sheetContext);
                // Copy to clipboard
              },
            ),
            if (message.senderId == _currentUserId)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteMessage(context, message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('回复'),
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('转发'),
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMessage(BuildContext context, Message message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatRoomBloc>().add(DeleteMessage(message.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentOption(
                context: sheetContext,
                icon: Icons.photo,
                label: '相册',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(context, ImageSource.gallery);
                },
              ),
              _buildAttachmentOption(
                context: sheetContext,
                icon: Icons.camera_alt,
                label: '拍照',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickImage(context, ImageSource.camera);
                },
              ),
              _buildAttachmentOption(
                context: sheetContext,
                icon: Icons.insert_drive_file,
                label: '文件',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickFile(context);
                },
              ),
              _buildAttachmentOption(
                context: sheetContext,
                icon: Icons.location_on,
                label: '位置',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('位置分享功能开发中')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        await _uploadAndSendMedia(context, File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        if (file.path != null) {
          await _uploadAndSendMedia(context, File(file.path!));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadAndSendMedia(BuildContext context, File file) async {
    // 根据文件扩展名确定消息类型
    final extension = file.path.split('.').last.toLowerCase();
    final MessageType messageType;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      messageType = MessageType.image;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      messageType = MessageType.video;
    } else {
      messageType = MessageType.file;
    }

    // 使用SendMediaMessage事件，让Bloc处理上传和发送
    if (mounted) {
      context.read<ChatRoomBloc>().add(SendMediaMessage(
        filePath: file.path,
        type: messageType,
      ));
    }
  }

  Widget _buildAttachmentOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  void _startVoiceRecording(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('语音录制功能开发中')),
    );
  }

  void _startVoiceCall(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('语音通话功能开发中')),
    );
  }

  void _startVideoCall(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('视频通话功能开发中')),
    );
  }

  void _showRoomSettings(BuildContext context) {
    final state = context.read<ChatRoomBloc>().state;
    final room = state is ChatRoomLoaded ? state.room : null;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('群成员'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (room != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomMembersPage(room: room),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('加载聊天室信息失败')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索消息'),
              onTap: () {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('搜索功能开发中')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('媒体文件'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (room != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomMediaPage(
                        roomId: room.id,
                        roomName: room.name,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('加载聊天室信息失败')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('聊天设置'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (room != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatSettingsPage(room: room),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('加载聊天室信息失败')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openMediaViewer(BuildContext context, Message message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerPage(message: message),
      ),
    );
  }
}
