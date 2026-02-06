import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 媒体类型
enum MediaType {
  image,
  video,
  audio,
  document,
  other,
}

/// 媒体状态
enum MediaStatus {
  uploading,
  processing,
  ready,
  failed,
  deleted,
}

/// 媒体信息模型
class MediaInfo {
  final String id;
  final String uploaderId;
  final String? roomId;
  final String? messageId;
  final String fileName;
  final String originalName;
  final String mimeType;
  final MediaType mediaType;
  final int size;
  final int? width;
  final int? height;
  final int? duration;
  final String? thumbnailUrl;
  final String? downloadUrl;
  final String checksum;
  final MediaStatus status;
  final bool isPublic;
  final DateTime? expiresAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MediaInfo({
    required this.id,
    required this.uploaderId,
    this.roomId,
    this.messageId,
    required this.fileName,
    required this.originalName,
    required this.mimeType,
    required this.mediaType,
    required this.size,
    this.width,
    this.height,
    this.duration,
    this.thumbnailUrl,
    this.downloadUrl,
    required this.checksum,
    required this.status,
    required this.isPublic,
    this.expiresAt,
    this.deletedAt,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaInfo.fromJson(Map<String, dynamic> json) {
    return MediaInfo(
      id: json['id'] ?? '',
      uploaderId: json['uploader_id'] ?? '',
      roomId: json['room_id'],
      messageId: json['message_id'],
      fileName: json['file_name'] ?? '',
      originalName: json['original_name'] ?? '',
      mimeType: json['mime_type'] ?? '',
      mediaType: _parseMediaType(json['media_type']),
      size: json['size'] ?? 0,
      width: json['width'],
      height: json['height'],
      duration: json['duration'],
      thumbnailUrl: json['thumbnail_url'],
      downloadUrl: json['download_url'],
      checksum: json['checksum'] ?? '',
      status: _parseStatus(json['status']),
      isPublic: json['is_public'] ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'])
          : null,
      deletedBy: json['deleted_by'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  static MediaType _parseMediaType(String? type) {
    switch (type) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      case 'audio':
        return MediaType.audio;
      case 'document':
        return MediaType.document;
      default:
        return MediaType.other;
    }
  }

  static MediaStatus _parseStatus(String? status) {
    switch (status) {
      case 'uploading':
        return MediaStatus.uploading;
      case 'processing':
        return MediaStatus.processing;
      case 'ready':
        return MediaStatus.ready;
      case 'failed':
        return MediaStatus.failed;
      case 'deleted':
        return MediaStatus.deleted;
      default:
        return MediaStatus.ready;
    }
  }

  bool get isImage => mediaType == MediaType.image;
  bool get isVideo => mediaType == MediaType.video;
  bool get isAudio => mediaType == MediaType.audio;
  bool get isDocument => mediaType == MediaType.document;
  bool get isDeleted => status == MediaStatus.deleted;
}

/// 删除确认结果
class DeleteConfirmation {
  final String token;
  final DateTime expiresAt;
  final String message;

  DeleteConfirmation({
    required this.token,
    required this.expiresAt,
    required this.message,
  });

  factory DeleteConfirmation.fromJson(Map<String, dynamic> json) {
    return DeleteConfirmation(
      token: json['token'] ?? '',
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      message: json['message'] ?? '',
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 播放位置
class PlaybackPosition {
  final String mediaId;
  final int position;
  final int duration;
  final DateTime updatedAt;

  PlaybackPosition({
    required this.mediaId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  factory PlaybackPosition.fromJson(Map<String, dynamic> json) {
    return PlaybackPosition(
      mediaId: json['media_id'] ?? '',
      position: json['position'] ?? 0,
      duration: json['duration'] ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  double get progress => duration > 0 ? position / duration : 0.0;
}

/// 上传会话
class UploadSession {
  final String id;
  final String userId;
  final String fileName;
  final String mimeType;
  final int totalSize;
  final int chunkSize;
  final int totalChunks;
  final int uploadedChunks;
  final String status;
  final DateTime expiresAt;

  UploadSession({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.mimeType,
    required this.totalSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.uploadedChunks,
    required this.status,
    required this.expiresAt,
  });

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    return UploadSession(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      fileName: json['file_name'] ?? '',
      mimeType: json['mime_type'] ?? '',
      totalSize: json['total_size'] ?? 0,
      chunkSize: json['chunk_size'] ?? 0,
      totalChunks: json['total_chunks'] ?? 0,
      uploadedChunks: json['uploaded_chunks'] ?? 0,
      status: json['status'] ?? '',
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
    );
  }

  double get progress =>
      totalChunks > 0 ? uploadedChunks / totalChunks : 0.0;
}

/// 上传进度回调
typedef UploadProgressCallback = void Function(int sent, int total);

/// 下载进度回调
typedef DownloadProgressCallback = void Function(int received, int total);

/// 媒体服务
class MediaService {
  final Dio _dio;
  final String _baseUrl;
  
  // 缓存目录
  Directory? _cacheDir;
  
  // 下载任务
  final Map<String, CancelToken> _downloadTasks = {};
  
  // 上传任务
  final Map<String, CancelToken> _uploadTasks = {};

  MediaService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// 初始化缓存目录
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/media_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// 上传文件
  Future<MediaInfo> upload(
    File file, {
    String? roomId,
    String? messageId,
    UploadProgressCallback? onProgress,
  }) async {
    final cancelToken = CancelToken();
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _uploadTasks[taskId] = cancelToken;

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
        if (roomId != null) 'room_id': roomId,
        if (messageId != null) 'message_id': messageId,
      });

      final response = await _dio.post(
        '$_baseUrl/media/upload',
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          onProgress?.call(sent, total);
        },
      );

      return MediaInfo.fromJson(response.data);
    } finally {
      _uploadTasks.remove(taskId);
    }
  }

  /// 上传字节数据
  Future<MediaInfo> uploadBytes(
    Uint8List bytes,
    String fileName,
    String mimeType, {
    String? roomId,
    String? messageId,
    UploadProgressCallback? onProgress,
  }) async {
    final cancelToken = CancelToken();
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _uploadTasks[taskId] = cancelToken;

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        if (roomId != null) 'room_id': roomId,
        if (messageId != null) 'message_id': messageId,
      });

      final response = await _dio.post(
        '$_baseUrl/media/upload',
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          onProgress?.call(sent, total);
        },
      );

      return MediaInfo.fromJson(response.data);
    } finally {
      _uploadTasks.remove(taskId);
    }
  }

  /// 初始化分片上传
  Future<UploadSession> initiateChunkedUpload(
    String fileName,
    String mimeType,
    int totalSize,
  ) async {
    final response = await _dio.post(
      '$_baseUrl/media/upload/chunked/init',
      data: {
        'file_name': fileName,
        'mime_type': mimeType,
        'total_size': totalSize,
      },
    );

    return UploadSession.fromJson(response.data);
  }

  /// 上传分片
  Future<void> uploadChunk(
    String sessionId,
    int chunkIndex,
    Uint8List data,
  ) async {
    await _dio.post(
      '$_baseUrl/media/upload/chunked/$sessionId/chunk/$chunkIndex',
      data: Stream.fromIterable([data]),
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': data.length,
        },
      ),
    );
  }

  /// 完成分片上传
  Future<MediaInfo> completeChunkedUpload(String sessionId) async {
    final response = await _dio.post(
      '$_baseUrl/media/upload/chunked/$sessionId/complete',
    );

    return MediaInfo.fromJson(response.data);
  }

  /// 分片上传大文件
  Future<MediaInfo> uploadLargeFile(
    File file, {
    UploadProgressCallback? onProgress,
  }) async {
    final fileSize = await file.length();
    final fileName = path.basename(file.path);
    final mimeType = _getMimeType(fileName);

    // 初始化上传会话
    final session = await initiateChunkedUpload(fileName, mimeType, fileSize);

    // 读取并上传分片
    final randomAccessFile = await file.open();
    try {
      for (int i = 0; i < session.totalChunks; i++) {
        final chunkData = await randomAccessFile.read(session.chunkSize);
        await uploadChunk(session.id, i, Uint8List.fromList(chunkData));

        // 报告进度
        final uploaded = (i + 1) * session.chunkSize;
        onProgress?.call(
          uploaded > fileSize ? fileSize : uploaded,
          fileSize,
        );
      }
    } finally {
      await randomAccessFile.close();
    }

    // 完成上传
    return completeChunkedUpload(session.id);
  }

  /// 获取媒体信息
  Future<MediaInfo?> getMedia(String mediaId) async {
    try {
      final response = await _dio.get('$_baseUrl/media/$mediaId');
      return MediaInfo.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// 下载媒体文件（支持断点续传）
  Future<File> download(
    String mediaId, {
    String? savePath,
    DownloadProgressCallback? onProgress,
    bool useCache = true,
    int? resumeFromByte,
  }) async {
    final targetPath = savePath ?? '${_cacheDir?.path ?? ''}/$mediaId';
    final targetFile = File(targetPath);
    
    // 检查缓存（仅完整下载时使用）
    if (useCache && resumeFromByte == null && _cacheDir != null) {
      final cachedFile = File('${_cacheDir!.path}/$mediaId');
      if (await cachedFile.exists()) {
        return cachedFile;
      }
    }

    // 检查是否可以断点续传
    int startByte = resumeFromByte ?? 0;
    if (resumeFromByte == null && await targetFile.exists()) {
      // 如果文件存在且未指定恢复点，检查是否是部分下载
      final existingSize = await targetFile.length();
      if (existingSize > 0) {
        startByte = existingSize;
      }
    }

    final cancelToken = CancelToken();
    _downloadTasks[mediaId] = cancelToken;

    try {
      final options = Options(
        headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
      );

      // 获取媒体信息以知道总大小
      final mediaInfo = await getMedia(mediaId);
      final totalSize = mediaInfo?.size ?? 0;

      final response = await _dio.get(
        '$_baseUrl/media/$mediaId/download',
        options: Options(
          responseType: ResponseType.stream,
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        ),
        cancelToken: cancelToken,
      );

      // 打开文件以追加模式写入
      final raf = await targetFile.open(
        mode: startByte > 0 ? FileMode.append : FileMode.write,
      );

      try {
        int received = startByte;
        final stream = response.data.stream as Stream<List<int>>;
        
        await for (final chunk in stream) {
          await raf.writeFrom(chunk);
          received += chunk.length;
          onProgress?.call(received, totalSize > 0 ? totalSize : received);
        }
      } finally {
        await raf.close();
      }

      return targetFile;
    } finally {
      _downloadTasks.remove(mediaId);
    }
  }

  /// 流式播放媒体（返回流式URL）
  String getStreamUrl(String mediaId) {
    return '$_baseUrl/media/$mediaId/stream';
  }

  /// 获取缩略图
  Future<Uint8List?> getThumbnail(String mediaId) async {
    // 检查缓存
    if (_cacheDir != null) {
      final cachedFile = File('${_cacheDir!.path}/${mediaId}_thumb');
      if (await cachedFile.exists()) {
        return cachedFile.readAsBytes();
      }
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/media/$mediaId/thumbnail',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data);

      // 缓存缩略图
      if (_cacheDir != null) {
        final cacheFile = File('${_cacheDir!.path}/${mediaId}_thumb');
        await cacheFile.writeAsBytes(bytes);
      }

      return bytes;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// 列出我的媒体
  Future<MediaListResult> listMyMedia({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/media/my',
      queryParameters: {
        'offset': offset,
        'limit': limit,
      },
    );

    return MediaListResult.fromJson(response.data);
  }

  /// 列出聊天室媒体
  Future<MediaListResult> listRoomMedia(
    String roomId, {
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/media/room/$roomId',
      queryParameters: {
        'offset': offset,
        'limit': limit,
      },
    );

    return MediaListResult.fromJson(response.data);
  }

  /// 列出消息媒体
  Future<List<MediaInfo>> listMessageMedia(String messageId) async {
    final response = await _dio.get('$_baseUrl/media/message/$messageId');

    final List<dynamic> mediaList = response.data['media'] ?? [];
    return mediaList.map((m) => MediaInfo.fromJson(m)).toList();
  }

  /// 请求删除确认令牌
  Future<DeleteConfirmation> requestDeleteConfirmation(String mediaId) async {
    final response = await _dio.post('$_baseUrl/media/$mediaId/delete-confirm');
    return DeleteConfirmation.fromJson(response.data);
  }

  /// 确认删除媒体（软删除到回收站）
  Future<void> confirmDelete(
    String mediaId,
    String token, {
    String? reason,
  }) async {
    await _dio.delete(
      '$_baseUrl/media/$mediaId',
      queryParameters: {
        'token': token,
        if (reason != null) 'reason': reason,
      },
    );
    
    // 删除本地缓存
    await _clearLocalCache(mediaId);
  }

  /// 删除媒体（旧API，现在需要先获取令牌）
  @Deprecated('Use requestDeleteConfirmation + confirmDelete instead')
  Future<void> delete(String mediaId) async {
    // 先获取删除令牌
    final confirmation = await requestDeleteConfirmation(mediaId);
    // 然后确认删除
    await confirmDelete(mediaId, confirmation.token);
  }

  /// 列出回收站中的媒体
  Future<MediaListResult> listTrash({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/media/trash',
      queryParameters: {
        'offset': offset,
        'limit': limit,
      },
    );

    return MediaListResult.fromJson(response.data);
  }

  /// 从回收站恢复媒体
  Future<void> restoreMedia(String mediaId) async {
    await _dio.post('$_baseUrl/media/$mediaId/restore');
  }

  /// 永久删除媒体
  Future<void> permanentDelete(String mediaId) async {
    await _dio.delete('$_baseUrl/media/$mediaId/permanent');
    
    // 删除本地缓存
    await _clearLocalCache(mediaId);
  }

  /// 清理本地缓存
  Future<void> _clearLocalCache(String mediaId) async {
    if (_cacheDir != null) {
      final cachedFile = File('${_cacheDir!.path}/$mediaId');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
      final thumbFile = File('${_cacheDir!.path}/${mediaId}_thumb');
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    }
  }

  /// 获取播放位置
  Future<PlaybackPosition?> getPlaybackPosition(String mediaId) async {
    try {
      final response = await _dio.get('$_baseUrl/media/$mediaId/playback-position');
      return PlaybackPosition.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// 更新播放位置
  Future<void> updatePlaybackPosition(
    String mediaId, {
    required int position,
    required int duration,
  }) async {
    await _dio.put(
      '$_baseUrl/media/$mediaId/playback-position',
      data: {
        'position': position,
        'duration': duration,
      },
    );
  }

  /// 授予访问权限
  Future<void> grantAccess(
    String mediaId,
    String userId, {
    bool canView = true,
    bool canDownload = true,
    bool canDelete = false,
  }) async {
    await _dio.post(
      '$_baseUrl/media/$mediaId/access',
      data: {
        'user_id': userId,
        'can_view': canView,
        'can_download': canDownload,
        'can_delete': canDelete,
      },
    );
  }

  /// 撤销访问权限
  Future<void> revokeAccess(String mediaId, String userId) async {
    await _dio.delete(
      '$_baseUrl/media/$mediaId/access',
      data: {'user_id': userId},
    );
  }

  /// 获取媒体统计
  Future<MediaStats> getStats(String mediaId) async {
    final response = await _dio.get('$_baseUrl/media/$mediaId/stats');
    return MediaStats.fromJson(response.data);
  }

  /// 取消下载
  void cancelDownload(String mediaId) {
    _downloadTasks[mediaId]?.cancel();
    _downloadTasks.remove(mediaId);
  }

  /// 取消所有上传
  void cancelAllUploads() {
    for (final token in _uploadTasks.values) {
      token.cancel();
    }
    _uploadTasks.clear();
  }

  /// 清理缓存
  Future<void> clearCache() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    if (_cacheDir == null || !await _cacheDir!.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in _cacheDir!.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// 根据文件名获取MIME类型
  String _getMimeType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.webm':
        return 'video/webm';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
        return 'audio/ogg';
      case '.wav':
        return 'audio/wav';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}

/// 媒体列表结果
class MediaListResult {
  final List<MediaInfo> media;
  final int total;
  final int offset;
  final int limit;

  MediaListResult({
    required this.media,
    required this.total,
    required this.offset,
    required this.limit,
  });

  factory MediaListResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> mediaList = json['media'] ?? [];
    return MediaListResult(
      media: mediaList.map((m) => MediaInfo.fromJson(m)).toList(),
      total: json['total'] ?? 0,
      offset: json['offset'] ?? 0,
      limit: json['limit'] ?? 20,
    );
  }

  bool get hasMore => offset + media.length < total;
}

/// 媒体统计
class MediaStats {
  final String mediaId;
  final int downloadCount;
  final int accessCount;

  MediaStats({
    required this.mediaId,
    required this.downloadCount,
    required this.accessCount,
  });

  factory MediaStats.fromJson(Map<String, dynamic> json) {
    return MediaStats(
      mediaId: json['media_id'] ?? '',
      downloadCount: json['download_count'] ?? 0,
      accessCount: json['access_count'] ?? 0,
    );
  }
}
