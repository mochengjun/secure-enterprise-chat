package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"mime"
	"path/filepath"
	"time"

	"sec-chat/media-proxy/internal/repository"
	"sec-chat/media-proxy/internal/storage"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

type MediaService struct {
	repo    *repository.MediaRepository
	storage storage.Storage
}

type UploadRequest struct {
	FileName      string
	ContentType   string
	Size          int64
	Reader        io.Reader
	UploadedBy    string
	RoomID        string
	Password      string
	DownloadLimit int
	ExpiresIn     time.Duration
}

type UploadResult struct {
	ID        string    `json:"id"`
	FileName  string    `json:"file_name"`
	MimeType  string    `json:"mime_type"`
	Size      int64     `json:"size"`
	URL       string    `json:"url"`
	CreatedAt time.Time `json:"created_at"`
}

type DownloadRequest struct {
	MediaID   string
	UserID    string
	Password  string
	IPAddress string
	UserAgent string
}

func NewMediaService(databaseURL string, store storage.Storage) *MediaService {
	repo, err := repository.NewMediaRepository(databaseURL)
	if err != nil {
		log.Printf("Warning: Failed to connect to database: %v", err)
		return &MediaService{storage: store}
	}

	return &MediaService{
		repo:    repo,
		storage: store,
	}
}

// Upload 上传文件
func (s *MediaService) Upload(ctx context.Context, req *UploadRequest) (*UploadResult, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	// 生成文件ID和存储路径
	fileID := uuid.New().String()
	ext := filepath.Ext(req.FileName)
	storagePath := fmt.Sprintf("%s/%s/%s%s",
		time.Now().Format("2006/01/02"),
		req.UploadedBy,
		fileID,
		ext,
	)

	// 确定MIME类型
	contentType := req.ContentType
	if contentType == "" {
		contentType = mime.TypeByExtension(ext)
		if contentType == "" {
			contentType = "application/octet-stream"
		}
	}

	// 上传到存储
	if err := s.storage.Upload(ctx, storagePath, req.Reader, req.Size, contentType); err != nil {
		return nil, fmt.Errorf("failed to upload file: %w", err)
	}

	// 处理密码
	var passwordHash string
	if req.Password != "" {
		hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
		if err != nil {
			return nil, fmt.Errorf("failed to hash password: %w", err)
		}
		passwordHash = string(hash)
	}

	// 计算过期时间
	var expiresAt *time.Time
	if req.ExpiresIn > 0 {
		t := time.Now().Add(req.ExpiresIn)
		expiresAt = &t
	}

	// 保存到数据库
	file := &repository.MediaFile{
		ID:            fileID,
		FileName:      req.FileName,
		MimeType:      contentType,
		Size:          req.Size,
		StoragePath:   storagePath,
		UploadedBy:    req.UploadedBy,
		RoomID:        req.RoomID,
		PasswordHash:  passwordHash,
		DownloadLimit: req.DownloadLimit,
		ExpiresAt:     expiresAt,
	}

	if err := s.repo.CreateMediaFile(file); err != nil {
		// 清理已上传的文件
		s.storage.Delete(ctx, storagePath)
		return nil, fmt.Errorf("failed to save file record: %w", err)
	}

	url, _ := s.storage.GetURL(ctx, storagePath)

	return &UploadResult{
		ID:        fileID,
		FileName:  req.FileName,
		MimeType:  contentType,
		Size:      req.Size,
		URL:       url,
		CreatedAt: time.Now(),
	}, nil
}

// Download 下载文件
func (s *MediaService) Download(ctx context.Context, req *DownloadRequest) (io.ReadCloser, *repository.MediaFile, error) {
	if s.repo == nil {
		return nil, nil, fmt.Errorf("database connection not available")
	}

	// 获取文件信息
	file, err := s.repo.GetMediaFile(req.MediaID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get file: %w", err)
	}
	if file == nil {
		return nil, nil, fmt.Errorf("file not found")
	}

	// 检查过期
	if file.ExpiresAt != nil && file.ExpiresAt.Before(time.Now()) {
		return nil, nil, fmt.Errorf("file has expired")
	}

	// 检查下载次数限制
	if file.DownloadLimit > 0 && file.DownloadCount >= file.DownloadLimit {
		return nil, nil, fmt.Errorf("download limit exceeded")
	}

	// 验证密码
	if file.PasswordHash != "" {
		if req.Password == "" {
			return nil, nil, fmt.Errorf("password required")
		}
		if err := bcrypt.CompareHashAndPassword([]byte(file.PasswordHash), []byte(req.Password)); err != nil {
			return nil, nil, fmt.Errorf("invalid password")
		}
	}

	// 获取权限设置
	perm, err := s.repo.GetMediaPermission(req.MediaID)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get permissions: %w", err)
	}

	// 检查下载权限
	if !perm.AllowDownload {
		return nil, nil, fmt.Errorf("download not allowed")
	}

	// 从存储获取文件
	reader, err := s.storage.Download(ctx, file.StoragePath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to download file: %w", err)
	}

	// 增加下载次数
	s.repo.IncrementDownloadCount(req.MediaID)

	// 记录访问日志
	logEntry := &repository.MediaAccessLog{
		ID:        uuid.New().String(),
		MediaID:   req.MediaID,
		UserID:    req.UserID,
		Action:    "download",
		IPAddress: req.IPAddress,
		UserAgent: req.UserAgent,
	}
	s.repo.CreateAccessLog(logEntry)

	return reader, file, nil
}

// GetFileInfo 获取文件信息
func (s *MediaService) GetFileInfo(ctx context.Context, mediaID, userID string) (*repository.MediaFile, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	file, err := s.repo.GetMediaFile(mediaID)
	if err != nil {
		return nil, err
	}
	if file == nil {
		return nil, fmt.Errorf("file not found")
	}

	// 隐藏敏感信息
	file.PasswordHash = ""
	file.StoragePath = ""

	return file, nil
}

// DeleteFile 删除文件
func (s *MediaService) DeleteFile(ctx context.Context, mediaID, userID string) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}

	file, err := s.repo.GetMediaFile(mediaID)
	if err != nil {
		return err
	}
	if file == nil {
		return fmt.Errorf("file not found")
	}

	// 检查权限（只有上传者可以删除）
	if file.UploadedBy != userID {
		return fmt.Errorf("permission denied")
	}

	// 删除存储中的文件
	if err := s.storage.Delete(ctx, file.StoragePath); err != nil {
		log.Printf("Warning: failed to delete file from storage: %v", err)
	}

	// 删除数据库记录
	return s.repo.DeleteMediaFile(mediaID)
}

// GetAccessLogs 获取访问日志
func (s *MediaService) GetAccessLogs(ctx context.Context, mediaID, userID string) ([]repository.MediaAccessLog, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	file, err := s.repo.GetMediaFile(mediaID)
	if err != nil {
		return nil, err
	}
	if file == nil {
		return nil, fmt.Errorf("file not found")
	}

	// 检查权限（只有上传者可以查看日志）
	if file.UploadedBy != userID {
		return nil, fmt.Errorf("permission denied")
	}

	return s.repo.GetAccessLogs(mediaID, 100)
}

// GenerateFileHash 生成文件哈希
func GenerateFileHash(reader io.Reader) (string, error) {
	h := sha256.New()
	if _, err := io.Copy(h, reader); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// SetFilePermission 设置文件权限
func (s *MediaService) SetFilePermission(ctx context.Context, mediaID, userID string, allowDownload, requireAuth bool) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}

	file, err := s.repo.GetMediaFile(mediaID)
	if err != nil {
		return err
	}
	if file == nil {
		return fmt.Errorf("file not found")
	}

	// 检查权限
	if file.UploadedBy != userID {
		return fmt.Errorf("permission denied")
	}

	perm := &repository.MediaPermission{
		MediaID:       mediaID,
		AllowDownload: allowDownload,
		RequireAuth:   requireAuth,
	}

	return s.repo.UpdateMediaPermission(mediaID, perm)
}
