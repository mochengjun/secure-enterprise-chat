import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/message.dart';

class MediaViewerPage extends StatefulWidget {
  final Message message;

  const MediaViewerPage({super.key, required this.message});

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  final TransformationController _transformationController = TransformationController();
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // 全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 媒体内容
          GestureDetector(
            onTap: _toggleControls,
            child: Center(
              child: _buildMediaContent(),
            ),
          ),

          // 顶部控制栏
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDateTime(widget.message.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.white),
                        onPressed: () => _shareMedia(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () => _downloadMedia(context),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) => _handleMenuAction(context, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'forward',
                            child: ListTile(
                              leading: Icon(Icons.forward),
                              title: Text('转发'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'save',
                            child: ListTile(
                              leading: Icon(Icons.save_alt),
                              title: Text('保存到相册'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 底部信息栏
          if (_showControls && widget.message.content.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.message.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (widget.message.type) {
      case MessageType.image:
        return _buildImageViewer();
      case MessageType.video:
        return _buildVideoPlayer();
      default:
        return _buildUnsupportedContent();
    }
  }

  Widget _buildImageViewer() {
    final imageUrl = widget.message.mediaUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(Icons.broken_image, '图片无法加载');
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(Icons.broken_image, '图片加载失败');
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // 视频播放器占位
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.white,
        ),
        const SizedBox(height: 16),
        const Text(
          '视频播放功能开发中',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _downloadMedia(context),
          icon: const Icon(Icons.download),
          label: const Text('下载视频'),
        ),
      ],
    );
  }

  Widget _buildUnsupportedContent() {
    return _buildPlaceholder(Icons.help_outline, '不支持的媒体类型');
  }

  Widget _buildPlaceholder(IconData icon, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareMedia(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中')),
    );
  }

  void _downloadMedia(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在下载...')),
    );
    // TODO: 实现下载逻辑
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'forward':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('转发功能开发中')),
        );
        break;
      case 'save':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在保存到相册...')),
        );
        // TODO: 实现保存到相册逻辑
        break;
    }
  }
}
