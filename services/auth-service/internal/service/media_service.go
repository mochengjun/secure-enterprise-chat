package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/nfnt/resize"

	"sec-chat/auth-service/internal/repository"
)

// MediaConfig 媒体服务配置
type MediaConfig struct {
	StoragePath     string                            // 存储根路径
	ThumbnailPath   string                            // 缩略图路径
	TempPath        string                            // 临时文件路径
	MaxFileSize     int64                             // 最大文件大小（字节）
	MaxImageSize    int64                             // 最大图片大小
	MaxVideoSize    int64                             // 最大视频大小
	ThumbnailWidth  uint                              // 缩略图宽度
	ThumbnailHeight uint                              // 缩略图高度
	AllowedTypes    map[repository.MediaType][]string // 允许的MIME类型
	BaseURL         string                            // 基础URL

	// 下载限速配置
	RateLimitEnabled     bool  // 是否启用限速
	DefaultBandwidth     int64 // 默认带宽 (bytes/sec)
	DownloadMaxPerMinute int   // 每分钟最大下载次数
	DeleteMaxPerHour     int   // 每小时最大删除次数

	// 回收站配置
	TrashRetentionDays int           // 回收站保留天数
	DeleteTokenTTL     time.Duration // 删除令牌有效期
}

// DefaultMediaConfig 默认配置
func DefaultMediaConfig() *MediaConfig {
	return &MediaConfig{
		StoragePath:     "./uploads/media",
		ThumbnailPath:   "./uploads/thumbnails",
		TempPath:        "./uploads/temp",
		MaxFileSize:     100 * 1024 * 1024, // 100MB
		MaxImageSize:    20 * 1024 * 1024,  // 20MB
		MaxVideoSize:    100 * 1024 * 1024, // 100MB
		ThumbnailWidth:  200,
		ThumbnailHeight: 200,
		AllowedTypes: map[repository.MediaType][]string{
			repository.MediaTypeImage:    {"image/jpeg", "image/png", "image/gif", "image/webp"},
			repository.MediaTypeVideo:    {"video/mp4", "video/webm", "video/quicktime"},
			repository.MediaTypeAudio:    {"audio/mpeg", "audio/ogg", "audio/wav", "audio/webm"},
			repository.MediaTypeDocument: {"application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text/plain"},
		},
		BaseURL:              "/api/v1/media",
		RateLimitEnabled:     true,
		DefaultBandwidth:     1024 * 1024,     // 1MB/s
		DownloadMaxPerMinute: 30,              // 每分钟30次
		DeleteMaxPerHour:     10,              // 每小时10次
		TrashRetentionDays:   30,              // 30天
		DeleteTokenTTL:       5 * time.Minute, // 5分钟
	}
}

// RangeDownloadResult 断点续传下载结果
type RangeDownloadResult struct {
	Reader        io.ReadCloser
	Media         *repository.Media
	Start         int64
	End           int64
	TotalSize     int64
	ContentLength int64
}

// PlaybackPosition 播放位置
type PlaybackPosition struct {
	MediaID   string    `json:"media_id"`
	Position  int       `json:"position"`
	Duration  int       `json:"duration"`
	UpdatedAt time.Time `json:"updated_at"`
}

// MediaService 媒体服务接口
type MediaService interface {
	// 上传
	Upload(ctx context.Context, userID string, file *multipart.FileHeader, roomID, messageID string) (*repository.Media, error)
	InitiateChunkedUpload(ctx context.Context, userID, fileName, mimeType string, totalSize int64) (*repository.UploadSession, error)
	UploadChunk(ctx context.Context, sessionID string, chunkIndex int, data io.Reader) error
	CompleteChunkedUpload(ctx context.Context, sessionID string) (*repository.Media, error)

	// 获取与下载
	GetMedia(ctx context.Context, id string) (*repository.Media, error)
	GetMediaWithURLs(ctx context.Context, id, userID string) (*repository.Media, error)
	Download(ctx context.Context, mediaID, userID, ip, userAgent string) (io.ReadCloser, *repository.Media, error)
	DownloadRange(ctx context.Context, mediaID, userID string, start, end int64, ip, userAgent string) (*RangeDownloadResult, error)
	GetThumbnail(ctx context.Context, mediaID, userID string) (io.ReadCloser, error)

	// 列表
	ListByUploader(ctx context.Context, userID string, offset, limit int) ([]*repository.Media, int64, error)
	ListByRoom(ctx context.Context, roomID, userID string, offset, limit int) ([]*repository.Media, int64, error)
	ListByMessage(ctx context.Context, messageID string) ([]*repository.Media, error)

	// 权限管理
	GrantAccess(ctx context.Context, mediaID, targetUserID, grantedBy string, canView, canDownload, canDelete bool) error
	RevokeAccess(ctx context.Context, mediaID, targetUserID, revokerID string) error
	CheckAccess(ctx context.Context, mediaID, userID string, needDownload bool) (bool, error)

	// 删除管理（增强）
	Delete(ctx context.Context, mediaID, userID string) error
	GenerateDeleteToken(ctx context.Context, mediaID, userID string) (string, time.Time, error)
	DeleteWithToken(ctx context.Context, mediaID, userID, token, reason, ip, userAgent string) error
	ListTrash(ctx context.Context, userID string, offset, limit int) ([]*repository.Media, int64, error)
	RestoreMedia(ctx context.Context, mediaID, userID string) error
	PermanentDelete(ctx context.Context, mediaID, userID string) error

	// 清理
	CleanupExpired(ctx context.Context) (int, error)
	CleanupExpiredSessions(ctx context.Context) (int, error)

	// 统计
	GetStats(ctx context.Context, mediaID string) (*MediaStats, error)

	// 播放位置
	GetPlaybackPosition(ctx context.Context, mediaID, userID string) (*PlaybackPosition, error)
	UpdatePlaybackPosition(ctx context.Context, mediaID, userID string, position, duration int) error
}

// MediaStats 媒体统计
type MediaStats struct {
	MediaID       string `json:"media_id"`
	DownloadCount int64  `json:"download_count"`
	AccessCount   int    `json:"access_count"`
}

// deleteTokenStore 删除令牌存储（简单内存实现，生产环境应使用Redis）
type deleteTokenStore struct {
	tokens map[string]*deleteTokenInfo
	mu     sync.RWMutex
}

type deleteTokenInfo struct {
	MediaID   string
	UserID    string
	ExpiresAt time.Time
}

var globalDeleteTokenStore = &deleteTokenStore{
	tokens: make(map[string]*deleteTokenInfo),
}

// mediaService 媒体服务实现
type mediaService struct {
	repo   repository.MediaRepository
	config *MediaConfig
}

// NewMediaService 创建媒体服务实例
func NewMediaService(repo repository.MediaRepository, config *MediaConfig) MediaService {
	if config == nil {
		config = DefaultMediaConfig()
	}

	// 确保目录存在
	os.MkdirAll(config.StoragePath, 0755)
	os.MkdirAll(config.ThumbnailPath, 0755)
	os.MkdirAll(config.TempPath, 0755)

	return &mediaService{
		repo:   repo,
		config: config,
	}
}

// Upload 上传文件
func (s *mediaService) Upload(ctx context.Context, userID string, file *multipart.FileHeader, roomID, messageID string) (*repository.Media, error) {
	// 检查文件大小
	if file.Size > s.config.MaxFileSize {
		return nil, fmt.Errorf("file size exceeds maximum allowed (%d bytes)", s.config.MaxFileSize)
	}

	// 获取MIME类型
	mimeType := file.Header.Get("Content-Type")
	mediaType := s.detectMediaType(mimeType)

	// 验证MIME类型
	if !s.isAllowedType(mediaType, mimeType) {
		return nil, fmt.Errorf("file type not allowed: %s", mimeType)
	}

	// 打开文件
	src, err := file.Open()
	if err != nil {
		return nil, fmt.Errorf("failed to open uploaded file: %w", err)
	}
	defer src.Close()

	// 生成文件ID和路径
	mediaID := uuid.New().String()
	ext := filepath.Ext(file.Filename)
	fileName := mediaID + ext
	storagePath := filepath.Join(s.config.StoragePath, time.Now().Format("2006/01/02"), fileName)

	// 确保目录存在
	if err := os.MkdirAll(filepath.Dir(storagePath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create storage directory: %w", err)
	}

	// 创建目标文件
	dst, err := os.Create(storagePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create destination file: %w", err)
	}
	defer dst.Close()

	// 计算校验和并复制文件
	hasher := sha256.New()
	writer := io.MultiWriter(dst, hasher)

	written, err := io.Copy(writer, src)
	if err != nil {
		os.Remove(storagePath)
		return nil, fmt.Errorf("failed to save file: %w", err)
	}

	checksum := hex.EncodeToString(hasher.Sum(nil))

	// 创建媒体记录
	media := &repository.Media{
		ID:           mediaID,
		UploaderID:   userID,
		RoomID:       roomID,
		MessageID:    messageID,
		FileName:     fileName,
		OriginalName: file.Filename,
		MimeType:     mimeType,
		MediaType:    mediaType,
		Size:         written,
		StoragePath:  storagePath,
		Checksum:     checksum,
		Status:       repository.MediaStatusProcessing,
		IsPublic:     false,
	}

	// 处理图片（获取尺寸、生成缩略图）
	if mediaType == repository.MediaTypeImage {
		if err := s.processImage(media); err != nil {
			// 处理失败不影响上传，只记录日志
			fmt.Printf("Warning: failed to process image: %v\n", err)
		}
	}

	media.Status = repository.MediaStatusReady

	if err := s.repo.CreateMedia(ctx, media); err != nil {
		os.Remove(storagePath)
		if media.ThumbnailPath != "" {
			os.Remove(media.ThumbnailPath)
		}
		return nil, fmt.Errorf("failed to save media record: %w", err)
	}

	// 填充URL
	s.fillURLs(media)

	return media, nil
}

// InitiateChunkedUpload 初始化分片上传
func (s *mediaService) InitiateChunkedUpload(ctx context.Context, userID, fileName, mimeType string, totalSize int64) (*repository.UploadSession, error) {
	if totalSize > s.config.MaxFileSize {
		return nil, fmt.Errorf("file size exceeds maximum allowed (%d bytes)", s.config.MaxFileSize)
	}

	mediaType := s.detectMediaType(mimeType)
	if !s.isAllowedType(mediaType, mimeType) {
		return nil, fmt.Errorf("file type not allowed: %s", mimeType)
	}

	sessionID := uuid.New().String()
	chunkSize := int64(5 * 1024 * 1024) // 5MB chunks
	totalChunks := int((totalSize + chunkSize - 1) / chunkSize)

	tempPath := filepath.Join(s.config.TempPath, sessionID)
	if err := os.MkdirAll(tempPath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create temp directory: %w", err)
	}

	session := &repository.UploadSession{
		ID:             sessionID,
		UserID:         userID,
		FileName:       fileName,
		MimeType:       mimeType,
		TotalSize:      totalSize,
		ChunkSize:      chunkSize,
		TotalChunks:    totalChunks,
		UploadedChunks: 0,
		TempPath:       tempPath,
		Status:         "pending",
		ExpiresAt:      time.Now().Add(24 * time.Hour),
	}

	if err := s.repo.CreateUploadSession(ctx, session); err != nil {
		os.RemoveAll(tempPath)
		return nil, fmt.Errorf("failed to create upload session: %w", err)
	}

	return session, nil
}

// UploadChunk 上传分片
func (s *mediaService) UploadChunk(ctx context.Context, sessionID string, chunkIndex int, data io.Reader) error {
	session, err := s.repo.GetUploadSession(ctx, sessionID)
	if err != nil {
		return fmt.Errorf("failed to get upload session: %w", err)
	}
	if session == nil {
		return fmt.Errorf("upload session not found")
	}

	if session.Status == "completed" {
		return fmt.Errorf("upload session already completed")
	}

	if time.Now().After(session.ExpiresAt) {
		return fmt.Errorf("upload session expired")
	}

	if chunkIndex < 0 || chunkIndex >= session.TotalChunks {
		return fmt.Errorf("invalid chunk index: %d", chunkIndex)
	}

	chunkPath := filepath.Join(session.TempPath, fmt.Sprintf("chunk_%d", chunkIndex))
	chunkFile, err := os.Create(chunkPath)
	if err != nil {
		return fmt.Errorf("failed to create chunk file: %w", err)
	}
	defer chunkFile.Close()

	if _, err := io.Copy(chunkFile, data); err != nil {
		os.Remove(chunkPath)
		return fmt.Errorf("failed to save chunk: %w", err)
	}

	session.UploadedChunks++
	session.Status = "uploading"

	if err := s.repo.UpdateUploadSession(ctx, session); err != nil {
		return fmt.Errorf("failed to update upload session: %w", err)
	}

	return nil
}

// CompleteChunkedUpload 完成分片上传
func (s *mediaService) CompleteChunkedUpload(ctx context.Context, sessionID string) (*repository.Media, error) {
	session, err := s.repo.GetUploadSession(ctx, sessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get upload session: %w", err)
	}
	if session == nil {
		return nil, fmt.Errorf("upload session not found")
	}

	if session.UploadedChunks != session.TotalChunks {
		return nil, fmt.Errorf("not all chunks uploaded: %d/%d", session.UploadedChunks, session.TotalChunks)
	}

	// 合并分片
	mediaID := uuid.New().String()
	ext := filepath.Ext(session.FileName)
	fileName := mediaID + ext
	storagePath := filepath.Join(s.config.StoragePath, time.Now().Format("2006/01/02"), fileName)

	if err := os.MkdirAll(filepath.Dir(storagePath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create storage directory: %w", err)
	}

	dst, err := os.Create(storagePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create destination file: %w", err)
	}
	defer dst.Close()

	hasher := sha256.New()
	writer := io.MultiWriter(dst, hasher)

	for i := 0; i < session.TotalChunks; i++ {
		chunkPath := filepath.Join(session.TempPath, fmt.Sprintf("chunk_%d", i))
		chunkFile, err := os.Open(chunkPath)
		if err != nil {
			os.Remove(storagePath)
			return nil, fmt.Errorf("failed to open chunk %d: %w", i, err)
		}

		if _, err := io.Copy(writer, chunkFile); err != nil {
			chunkFile.Close()
			os.Remove(storagePath)
			return nil, fmt.Errorf("failed to copy chunk %d: %w", i, err)
		}
		chunkFile.Close()
	}

	checksum := hex.EncodeToString(hasher.Sum(nil))

	// 获取文件大小
	fileInfo, _ := dst.Stat()

	mediaType := s.detectMediaType(session.MimeType)
	media := &repository.Media{
		ID:           mediaID,
		UploaderID:   session.UserID,
		FileName:     fileName,
		OriginalName: session.FileName,
		MimeType:     session.MimeType,
		MediaType:    mediaType,
		Size:         fileInfo.Size(),
		StoragePath:  storagePath,
		Checksum:     checksum,
		Status:       repository.MediaStatusProcessing,
		IsPublic:     false,
	}

	// 处理图片
	if mediaType == repository.MediaTypeImage {
		if err := s.processImage(media); err != nil {
			fmt.Printf("Warning: failed to process image: %v\n", err)
		}
	}

	media.Status = repository.MediaStatusReady

	if err := s.repo.CreateMedia(ctx, media); err != nil {
		os.Remove(storagePath)
		return nil, fmt.Errorf("failed to save media record: %w", err)
	}

	// 清理临时文件
	os.RemoveAll(session.TempPath)

	session.Status = "completed"
	s.repo.UpdateUploadSession(ctx, session)

	s.fillURLs(media)

	return media, nil
}

// GetMedia 获取媒体信息
func (s *mediaService) GetMedia(ctx context.Context, id string) (*repository.Media, error) {
	return s.repo.GetMediaByID(ctx, id)
}

// GetMediaWithURLs 获取媒体信息（带URL）
func (s *mediaService) GetMediaWithURLs(ctx context.Context, id, userID string) (*repository.Media, error) {
	media, err := s.repo.GetMediaByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if media == nil {
		return nil, nil
	}

	// 检查权限
	hasAccess, err := s.repo.CheckAccess(ctx, id, userID, false)
	if err != nil {
		return nil, err
	}
	if !hasAccess {
		return nil, fmt.Errorf("access denied")
	}

	s.fillURLs(media)
	return media, nil
}

// Download 下载媒体
func (s *mediaService) Download(ctx context.Context, mediaID, userID, ip, userAgent string) (io.ReadCloser, *repository.Media, error) {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return nil, nil, fmt.Errorf("media not found")
	}

	// 检查下载权限
	hasAccess, err := s.repo.CheckAccess(ctx, mediaID, userID, true)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to check access: %w", err)
	}
	if !hasAccess {
		return nil, nil, fmt.Errorf("download access denied")
	}

	// 打开文件
	file, err := os.Open(media.StoragePath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open file: %w", err)
	}

	// 记录下载
	s.repo.LogDownload(ctx, &repository.MediaDownloadLog{
		MediaID:   mediaID,
		UserID:    userID,
		IPAddress: ip,
		UserAgent: userAgent,
	})

	return file, media, nil
}

// GetThumbnail 获取缩略图
func (s *mediaService) GetThumbnail(ctx context.Context, mediaID, userID string) (io.ReadCloser, error) {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return nil, fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return nil, fmt.Errorf("media not found")
	}

	// 检查查看权限
	hasAccess, err := s.repo.CheckAccess(ctx, mediaID, userID, false)
	if err != nil {
		return nil, fmt.Errorf("failed to check access: %w", err)
	}
	if !hasAccess {
		return nil, fmt.Errorf("access denied")
	}

	if media.ThumbnailPath == "" {
		return nil, fmt.Errorf("no thumbnail available")
	}

	file, err := os.Open(media.ThumbnailPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open thumbnail: %w", err)
	}

	return file, nil
}

// ListByUploader 列出用户上传的媒体
func (s *mediaService) ListByUploader(ctx context.Context, userID string, offset, limit int) ([]*repository.Media, int64, error) {
	media, total, err := s.repo.ListMediaByUploader(ctx, userID, offset, limit)
	if err != nil {
		return nil, 0, err
	}

	for _, m := range media {
		s.fillURLs(m)
	}

	return media, total, nil
}

// ListByRoom 列出聊天室的媒体
func (s *mediaService) ListByRoom(ctx context.Context, roomID, userID string, offset, limit int) ([]*repository.Media, int64, error) {
	// TODO: 检查用户是否是聊天室成员

	media, total, err := s.repo.ListMediaByRoom(ctx, roomID, offset, limit)
	if err != nil {
		return nil, 0, err
	}

	for _, m := range media {
		s.fillURLs(m)
	}

	return media, total, nil
}

// ListByMessage 列出消息的媒体
func (s *mediaService) ListByMessage(ctx context.Context, messageID string) ([]*repository.Media, error) {
	media, err := s.repo.ListMediaByMessage(ctx, messageID)
	if err != nil {
		return nil, err
	}

	for _, m := range media {
		s.fillURLs(m)
	}

	return media, nil
}

// GrantAccess 授予访问权限
func (s *mediaService) GrantAccess(ctx context.Context, mediaID, targetUserID, grantedBy string, canView, canDownload, canDelete bool) error {
	// 检查授权者是否有权限（必须是上传者或有删除权限）
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return fmt.Errorf("media not found")
	}

	if media.UploaderID != grantedBy {
		access, err := s.repo.GetAccess(ctx, mediaID, grantedBy)
		if err != nil {
			return fmt.Errorf("failed to check granter access: %w", err)
		}
		if access == nil || !access.CanDelete {
			return fmt.Errorf("no permission to grant access")
		}
	}

	return s.repo.GrantAccess(ctx, &repository.MediaAccess{
		MediaID:     mediaID,
		UserID:      targetUserID,
		CanView:     canView,
		CanDownload: canDownload,
		CanDelete:   canDelete,
		GrantedBy:   grantedBy,
	})
}

// RevokeAccess 撤销访问权限
func (s *mediaService) RevokeAccess(ctx context.Context, mediaID, targetUserID, revokerID string) error {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return fmt.Errorf("media not found")
	}

	if media.UploaderID != revokerID {
		access, err := s.repo.GetAccess(ctx, mediaID, revokerID)
		if err != nil {
			return fmt.Errorf("failed to check revoker access: %w", err)
		}
		if access == nil || !access.CanDelete {
			return fmt.Errorf("no permission to revoke access")
		}
	}

	return s.repo.RevokeAccess(ctx, mediaID, targetUserID)
}

// CheckAccess 检查访问权限
func (s *mediaService) CheckAccess(ctx context.Context, mediaID, userID string, needDownload bool) (bool, error) {
	return s.repo.CheckAccess(ctx, mediaID, userID, needDownload)
}

// Delete 删除媒体
func (s *mediaService) Delete(ctx context.Context, mediaID, userID string) error {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return fmt.Errorf("media not found")
	}

	// 检查删除权限
	if media.UploaderID != userID {
		access, err := s.repo.GetAccess(ctx, mediaID, userID)
		if err != nil {
			return fmt.Errorf("failed to check access: %w", err)
		}
		if access == nil || !access.CanDelete {
			return fmt.Errorf("no permission to delete")
		}
	}

	// 删除文件
	if media.StoragePath != "" {
		os.Remove(media.StoragePath)
	}
	if media.ThumbnailPath != "" {
		os.Remove(media.ThumbnailPath)
	}

	return s.repo.DeleteMedia(ctx, mediaID)
}

// CleanupExpired 清理过期媒体
func (s *mediaService) CleanupExpired(ctx context.Context) (int, error) {
	expired, err := s.repo.ListExpiredMedia(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to list expired media: %w", err)
	}

	count := 0
	for _, media := range expired {
		if media.StoragePath != "" {
			os.Remove(media.StoragePath)
		}
		if media.ThumbnailPath != "" {
			os.Remove(media.ThumbnailPath)
		}

		if err := s.repo.DeleteMedia(ctx, media.ID); err == nil {
			count++
		}
	}

	return count, nil
}

// CleanupExpiredSessions 清理过期上传会话
func (s *mediaService) CleanupExpiredSessions(ctx context.Context) (int, error) {
	sessions, err := s.repo.ListExpiredSessions(ctx)
	if err != nil {
		return 0, fmt.Errorf("failed to list expired sessions: %w", err)
	}

	count := 0
	for _, session := range sessions {
		os.RemoveAll(session.TempPath)
		if err := s.repo.DeleteUploadSession(ctx, session.ID); err == nil {
			count++
		}
	}

	return count, nil
}

// GetStats 获取媒体统计
func (s *mediaService) GetStats(ctx context.Context, mediaID string) (*MediaStats, error) {
	downloadCount, err := s.repo.GetDownloadStats(ctx, mediaID)
	if err != nil {
		return nil, fmt.Errorf("failed to get download stats: %w", err)
	}

	accesses, err := s.repo.ListAccessByMedia(ctx, mediaID)
	if err != nil {
		return nil, fmt.Errorf("failed to list accesses: %w", err)
	}

	return &MediaStats{
		MediaID:       mediaID,
		DownloadCount: downloadCount,
		AccessCount:   len(accesses),
	}, nil
}

// detectMediaType 检测媒体类型
func (s *mediaService) detectMediaType(mimeType string) repository.MediaType {
	mimeType = strings.ToLower(mimeType)

	if strings.HasPrefix(mimeType, "image/") {
		return repository.MediaTypeImage
	}
	if strings.HasPrefix(mimeType, "video/") {
		return repository.MediaTypeVideo
	}
	if strings.HasPrefix(mimeType, "audio/") {
		return repository.MediaTypeAudio
	}
	if strings.HasPrefix(mimeType, "application/pdf") ||
		strings.Contains(mimeType, "document") ||
		strings.HasPrefix(mimeType, "text/") {
		return repository.MediaTypeDocument
	}

	return repository.MediaTypeOther
}

// isAllowedType 检查是否是允许的类型
func (s *mediaService) isAllowedType(mediaType repository.MediaType, mimeType string) bool {
	allowedTypes, ok := s.config.AllowedTypes[mediaType]
	if !ok {
		return mediaType == repository.MediaTypeOther
	}

	mimeType = strings.ToLower(mimeType)
	for _, allowed := range allowedTypes {
		if mimeType == allowed {
			return true
		}
	}

	return false
}

// processImage 处理图片（获取尺寸、生成缩略图）
func (s *mediaService) processImage(media *repository.Media) error {
	file, err := os.Open(media.StoragePath)
	if err != nil {
		return fmt.Errorf("failed to open image: %w", err)
	}
	defer file.Close()

	// 解码图片
	img, _, err := image.Decode(file)
	if err != nil {
		return fmt.Errorf("failed to decode image: %w", err)
	}

	// 获取尺寸
	bounds := img.Bounds()
	media.Width = bounds.Dx()
	media.Height = bounds.Dy()

	// 生成缩略图
	thumbnail := resize.Thumbnail(s.config.ThumbnailWidth, s.config.ThumbnailHeight, img, resize.Lanczos3)

	thumbnailPath := filepath.Join(s.config.ThumbnailPath, time.Now().Format("2006/01/02"), media.FileName)
	if err := os.MkdirAll(filepath.Dir(thumbnailPath), 0755); err != nil {
		return fmt.Errorf("failed to create thumbnail directory: %w", err)
	}

	thumbnailFile, err := os.Create(thumbnailPath)
	if err != nil {
		return fmt.Errorf("failed to create thumbnail file: %w", err)
	}
	defer thumbnailFile.Close()

	if err := jpeg.Encode(thumbnailFile, thumbnail, &jpeg.Options{Quality: 85}); err != nil {
		os.Remove(thumbnailPath)
		return fmt.Errorf("failed to encode thumbnail: %w", err)
	}

	media.ThumbnailPath = thumbnailPath

	return nil
}

// fillURLs 填充媒体URL
func (s *mediaService) fillURLs(media *repository.Media) {
	media.DownloadURL = fmt.Sprintf("%s/%s/download", s.config.BaseURL, media.ID)
	if media.ThumbnailPath != "" {
		media.ThumbnailURL = fmt.Sprintf("%s/%s/thumbnail", s.config.BaseURL, media.ID)
	}
}

// validateStoragePath 验证存储路径（防止路径遍历攻击）
func (s *mediaService) validateStoragePath(path string) error {
	cleanPath := filepath.Clean(path)
	absPath, err := filepath.Abs(cleanPath)
	if err != nil {
		return fmt.Errorf("invalid path: %w", err)
	}

	absStoragePath, err := filepath.Abs(s.config.StoragePath)
	if err != nil {
		return fmt.Errorf("invalid storage path: %w", err)
	}

	if !strings.HasPrefix(absPath, absStoragePath) {
		return fmt.Errorf("path traversal detected")
	}

	return nil
}

// DownloadRange 断点续传下载
func (s *mediaService) DownloadRange(ctx context.Context, mediaID, userID string, start, end int64, ip, userAgent string) (*RangeDownloadResult, error) {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return nil, fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return nil, fmt.Errorf("media not found")
	}

	// 检查下载权限
	hasAccess, err := s.repo.CheckAccess(ctx, mediaID, userID, true)
	if err != nil {
		return nil, fmt.Errorf("failed to check access: %w", err)
	}
	if !hasAccess {
		return nil, fmt.Errorf("download access denied")
	}

	// 验证存储路径
	if err := s.validateStoragePath(media.StoragePath); err != nil {
		return nil, fmt.Errorf("invalid storage path: %w", err)
	}

	// 打开文件
	file, err := os.Open(media.StoragePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}

	// 获取文件大小
	fileInfo, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, fmt.Errorf("failed to get file info: %w", err)
	}
	totalSize := fileInfo.Size()

	// 处理Range
	if start < 0 {
		start = 0
	}
	if end < 0 || end >= totalSize {
		end = totalSize - 1
	}
	if start > end || start >= totalSize {
		file.Close()
		return nil, fmt.Errorf("invalid range")
	}

	// Seek到起始位置
	if _, err := file.Seek(start, io.SeekStart); err != nil {
		file.Close()
		return nil, fmt.Errorf("failed to seek: %w", err)
	}

	contentLength := end - start + 1

	// 记录下载
	s.repo.LogDownload(ctx, &repository.MediaDownloadLog{
		MediaID:   mediaID,
		UserID:    userID,
		IPAddress: ip,
		UserAgent: userAgent,
	})

	// 返回带限制的Reader
	limitedReader := io.LimitReader(file, contentLength)

	return &RangeDownloadResult{
		Reader:        &limitedReadCloser{Reader: limitedReader, Closer: file},
		Media:         media,
		Start:         start,
		End:           end,
		TotalSize:     totalSize,
		ContentLength: contentLength,
	}, nil
}

// limitedReadCloser 组合io.Reader和io.Closer
type limitedReadCloser struct {
	io.Reader
	io.Closer
}

// GenerateDeleteToken 生成删除令牌
func (s *mediaService) GenerateDeleteToken(ctx context.Context, mediaID, userID string) (string, time.Time, error) {
	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return "", time.Time{}, fmt.Errorf("media not found")
	}

	// 检查删除权限
	if media.UploaderID != userID {
		access, err := s.repo.GetAccess(ctx, mediaID, userID)
		if err != nil {
			return "", time.Time{}, fmt.Errorf("failed to check access: %w", err)
		}
		if access == nil || !access.CanDelete {
			return "", time.Time{}, fmt.Errorf("no permission to delete")
		}
	}

	// 生成令牌
	token := uuid.New().String()
	expiresAt := time.Now().Add(s.config.DeleteTokenTTL)

	// 存储令牌
	globalDeleteTokenStore.mu.Lock()
	globalDeleteTokenStore.tokens[token] = &deleteTokenInfo{
		MediaID:   mediaID,
		UserID:    userID,
		ExpiresAt: expiresAt,
	}
	globalDeleteTokenStore.mu.Unlock()

	return token, expiresAt, nil
}

// DeleteWithToken 使用令牌执行删除（软删除）
func (s *mediaService) DeleteWithToken(ctx context.Context, mediaID, userID, token, reason, ip, userAgent string) error {
	// 验证令牌
	globalDeleteTokenStore.mu.Lock()
	tokenInfo, exists := globalDeleteTokenStore.tokens[token]
	if exists {
		delete(globalDeleteTokenStore.tokens, token) // 使用后立即删除
	}
	globalDeleteTokenStore.mu.Unlock()

	if !exists {
		return fmt.Errorf("invalid or expired delete token")
	}
	if tokenInfo.MediaID != mediaID || tokenInfo.UserID != userID {
		return fmt.Errorf("invalid or expired delete token")
	}
	if time.Now().After(tokenInfo.ExpiresAt) {
		return fmt.Errorf("invalid or expired delete token")
	}

	media, err := s.repo.GetMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return fmt.Errorf("media not found")
	}

	// 记录删除日志
	s.repo.CreateDeletionLog(ctx, &repository.MediaDeletionLog{
		MediaID:      mediaID,
		FileName:     media.OriginalName,
		OriginalSize: media.Size,
		DeletedBy:    userID,
		Reason:       reason,
		IPAddress:    ip,
		UserAgent:    userAgent,
	})

	// 执行软删除
	return s.repo.SoftDeleteMedia(ctx, mediaID, userID)
}

// ListTrash 列出回收站中的媒体
func (s *mediaService) ListTrash(ctx context.Context, userID string, offset, limit int) ([]*repository.Media, int64, error) {
	media, total, err := s.repo.ListDeletedMedia(ctx, userID, offset, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to list trash: %w", err)
	}

	for _, m := range media {
		s.fillURLs(m)
	}

	return media, total, nil
}

// RestoreMedia 从回收站恢复媒体
func (s *mediaService) RestoreMedia(ctx context.Context, mediaID, userID string) error {
	media, err := s.repo.GetDeletedMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		return fmt.Errorf("media not found in trash")
	}

	// 检查权限
	if media.UploaderID != userID {
		return fmt.Errorf("no permission to restore")
	}

	return s.repo.RestoreMedia(ctx, mediaID)
}

// PermanentDelete 永久删除媒体
func (s *mediaService) PermanentDelete(ctx context.Context, mediaID, userID string) error {
	media, err := s.repo.GetDeletedMediaByID(ctx, mediaID)
	if err != nil {
		return fmt.Errorf("failed to get media: %w", err)
	}
	if media == nil {
		// 也尝试获取正常媒体
		media, err = s.repo.GetMediaByID(ctx, mediaID)
		if err != nil {
			return fmt.Errorf("failed to get media: %w", err)
		}
		if media == nil {
			return fmt.Errorf("media not found")
		}
	}

	// 检查权限
	if media.UploaderID != userID {
		return fmt.Errorf("no permission to delete permanently")
	}

	// 删除物理文件
	if media.StoragePath != "" {
		os.Remove(media.StoragePath)
	}
	if media.ThumbnailPath != "" {
		os.Remove(media.ThumbnailPath)
	}

	// 永久删除数据库记录
	return s.repo.PermanentDeleteMedia(ctx, mediaID)
}

// GetPlaybackPosition 获取播放位置
func (s *mediaService) GetPlaybackPosition(ctx context.Context, mediaID, userID string) (*PlaybackPosition, error) {
	position, err := s.repo.GetPlaybackPosition(ctx, mediaID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get playback position: %w", err)
	}
	if position == nil {
		return nil, fmt.Errorf("position not found")
	}

	return &PlaybackPosition{
		MediaID:   position.MediaID,
		Position:  position.Position,
		Duration:  position.Duration,
		UpdatedAt: position.UpdatedAt,
	}, nil
}

// UpdatePlaybackPosition 更新播放位置
func (s *mediaService) UpdatePlaybackPosition(ctx context.Context, mediaID, userID string, position, duration int) error {
	return s.repo.UpdatePlaybackPosition(ctx, &repository.MediaPlaybackPosition{
		UserID:   userID,
		MediaID:  mediaID,
		Position: position,
		Duration: duration,
	})
}
