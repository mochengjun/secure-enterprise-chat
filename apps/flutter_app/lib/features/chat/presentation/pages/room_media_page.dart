import 'package:flutter/material.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/di/injection.dart';

class RoomMediaPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomMediaPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<RoomMediaPage> createState() => _RoomMediaPageState();
}

class _RoomMediaPageState extends State<RoomMediaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<MediaInfo> _images = [];
  final List<MediaInfo> _videos = [];
  final List<MediaInfo> _files = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mediaService = getIt<MediaService>();
      final result = await mediaService.listRoomMedia(widget.roomId, limit: 100);

      _images.clear();
      _videos.clear();
      _files.clear();

      for (final media in result.media) {
        switch (media.mediaType) {
          case MediaType.image:
            _images.add(media);
            break;
          case MediaType.video:
            _videos.add(media);
            break;
          default:
            _files.add(media);
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.roomName} - 媒体文件'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '图片 (${_images.length})'),
            Tab(text: '视频 (${_videos.length})'),
            Tab(text: '文件 (${_files.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildImageGrid(),
                    _buildVideoList(),
                    _buildFileList(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
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
          Text('加载失败: $_error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMedia,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return _buildEmptyView('暂无图片', Icons.photo_library_outlined);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final media = _images[index];
        return GestureDetector(
          onTap: () => _openMediaViewer(context, media),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: media.thumbnailUrl != null
                ? Image.network(
                    media.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  )
                : media.downloadUrl != null
                    ? Image.network(
                        media.downloadUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                      )
                    : const Icon(Icons.image),
          ),
        );
      },
    );
  }

  Widget _buildVideoList() {
    if (_videos.isEmpty) {
      return _buildEmptyView('暂无视频', Icons.videocam_outlined);
    }

    return ListView.builder(
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final media = _videos[index];
        return ListTile(
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: media.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          media.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.videocam),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Icon(Icons.videocam),
          ),
          title: Text(
            media.originalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_formatFileSize(media.size)),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadMedia(media),
          ),
          onTap: () => _openMediaViewer(context, media),
        );
      },
    );
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return _buildEmptyView('暂无文件', Icons.folder_outlined);
    }

    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final media = _files[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFileIcon(media.mimeType),
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(
            media.originalName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_formatFileSize(media.size)),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadMedia(media),
          ),
          onTap: () => _downloadMedia(media),
        );
      },
    );
  }

  Widget _buildEmptyView(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.folder_zip;
    }
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  void _openMediaViewer(BuildContext context, MediaInfo media) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('媒体查看器开发中')),
    );
  }

  void _downloadMedia(MediaInfo media) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在下载: ${media.originalName}')),
    );
    // TODO: 实现下载逻辑
  }
}
