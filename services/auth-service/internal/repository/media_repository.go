package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// MediaType 媒体类型
type MediaType string

const (
	MediaTypeImage    MediaType = "image"
	MediaTypeVideo    MediaType = "video"
	MediaTypeAudio    MediaType = "audio"
	MediaTypeDocument MediaType = "document"
	MediaTypeOther    MediaType = "other"
)

// MediaStatus 媒体状态
type MediaStatus string

const (
	MediaStatusUploading  MediaStatus = "uploading"
	MediaStatusProcessing MediaStatus = "processing"
	MediaStatusReady      MediaStatus = "ready"
	MediaStatusFailed     MediaStatus = "failed"
	MediaStatusDeleted    MediaStatus = "deleted"
)

// Media 媒体文件记录
type Media struct {
	ID            string      `gorm:"primaryKey;size:64" json:"id"`
	UploaderID    string      `gorm:"size:255;index" json:"uploader_id"`
	RoomID        string      `gorm:"size:64;index" json:"room_id,omitempty"`    // 可选，关联到聊天室
	MessageID     string      `gorm:"size:64;index" json:"message_id,omitempty"` // 可选，关联到消息
	FileName      string      `gorm:"size:512" json:"file_name"`
	OriginalName  string      `gorm:"size:512" json:"original_name"`
	MimeType      string      `gorm:"size:128" json:"mime_type"`
	MediaType     MediaType   `gorm:"size:32;index" json:"media_type"`
	Size          int64       `json:"size"`                             // 字节数
	Width         int         `json:"width,omitempty"`                  // 图片/视频宽度
	Height        int         `json:"height,omitempty"`                 // 图片/视频高度
	Duration      int         `json:"duration,omitempty"`               // 音视频时长（秒）
	StoragePath   string      `gorm:"size:1024" json:"-"`               // 存储路径，不暴露给客户端
	ThumbnailPath string      `gorm:"size:1024" json:"-"`               // 缩略图路径
	ThumbnailURL  string      `gorm:"-" json:"thumbnail_url,omitempty"` // 缩略图URL
	DownloadURL   string      `gorm:"-" json:"download_url,omitempty"`  // 下载URL
	Checksum      string      `gorm:"size:128" json:"checksum"`         // SHA256校验和
	Status        MediaStatus `gorm:"size:32;index" json:"status"`
	IsPublic      bool        `gorm:"default:false" json:"is_public"`       // 是否公开访问
	ExpiresAt     *time.Time  `json:"expires_at,omitempty"`                 // 过期时间，nil表示永久
	DeletedAt     *time.Time  `gorm:"index" json:"deleted_at,omitempty"`    // 软删除时间
	DeletedBy     string      `gorm:"size:255" json:"deleted_by,omitempty"` // 删除者ID
	CreatedAt     time.Time   `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt     time.Time   `gorm:"autoUpdateTime" json:"updated_at"`
}

// MediaAccess 媒体访问权限记录
type MediaAccess struct {
	ID          uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	MediaID     string     `gorm:"size:64;index" json:"media_id"`
	UserID      string     `gorm:"size:255;index" json:"user_id"`
	CanView     bool       `gorm:"default:true" json:"can_view"`
	CanDownload bool       `gorm:"default:true" json:"can_download"`
	CanDelete   bool       `gorm:"default:false" json:"can_delete"`
	GrantedBy   string     `gorm:"size:255" json:"granted_by"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"created_at"`
}

// MediaDownloadLog 媒体下载日志
type MediaDownloadLog struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MediaID      string    `gorm:"size:64;index" json:"media_id"`
	UserID       string    `gorm:"size:255;index" json:"user_id"`
	IPAddress    string    `gorm:"size:45" json:"ip_address"`
	UserAgent    string    `gorm:"size:512" json:"user_agent"`
	DownloadedAt time.Time `gorm:"autoCreateTime" json:"downloaded_at"`
}

// MediaDeletionLog 媒体删除审计日志
type MediaDeletionLog struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MediaID      string    `gorm:"size:64;index" json:"media_id"`
	FileName     string    `gorm:"size:512" json:"file_name"`
	OriginalSize int64     `json:"original_size"`
	DeletedBy    string    `gorm:"size:255;index" json:"deleted_by"`
	Reason       string    `gorm:"size:512" json:"reason"`
	IPAddress    string    `gorm:"size:45" json:"ip_address"`
	UserAgent    string    `gorm:"size:512" json:"user_agent"`
	DeletedAt    time.Time `gorm:"autoCreateTime;index" json:"deleted_at"`
}

// MediaPlaybackPosition 媒体播放位置记录
type MediaPlaybackPosition struct {
	UserID    string    `gorm:"primaryKey;size:255" json:"user_id"`
	MediaID   string    `gorm:"primaryKey;size:64" json:"media_id"`
	Position  int       `json:"position"` // 播放位置（秒）
	Duration  int       `json:"duration"` // 总时长（秒）
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

// UploadSession 上传会话（支持分片上传）
type UploadSession struct {
	ID             string    `gorm:"primaryKey;size:64" json:"id"`
	UserID         string    `gorm:"size:255;index" json:"user_id"`
	FileName       string    `gorm:"size:512" json:"file_name"`
	MimeType       string    `gorm:"size:128" json:"mime_type"`
	TotalSize      int64     `json:"total_size"`
	ChunkSize      int64     `json:"chunk_size"`
	TotalChunks    int       `json:"total_chunks"`
	UploadedChunks int       `json:"uploaded_chunks"`
	TempPath       string    `gorm:"size:1024" json:"-"`
	Status         string    `gorm:"size:32" json:"status"` // pending, uploading, completed, failed
	ExpiresAt      time.Time `json:"expires_at"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

// MediaRepository 媒体仓库接口
type MediaRepository interface {
	// 媒体文件操作
	CreateMedia(ctx context.Context, media *Media) error
	GetMediaByID(ctx context.Context, id string) (*Media, error)
	UpdateMedia(ctx context.Context, media *Media) error
	DeleteMedia(ctx context.Context, id string) error
	ListMediaByUploader(ctx context.Context, uploaderID string, offset, limit int) ([]*Media, int64, error)
	ListMediaByRoom(ctx context.Context, roomID string, offset, limit int) ([]*Media, int64, error)
	ListMediaByMessage(ctx context.Context, messageID string) ([]*Media, error)
	ListExpiredMedia(ctx context.Context) ([]*Media, error)

	// 软删除与回收站
	SoftDeleteMedia(ctx context.Context, id, deletedBy string) error
	GetDeletedMediaByID(ctx context.Context, id string) (*Media, error)
	ListDeletedMedia(ctx context.Context, uploaderID string, offset, limit int) ([]*Media, int64, error)
	RestoreMedia(ctx context.Context, id string) error
	PermanentDeleteMedia(ctx context.Context, id string) error

	// 删除审计日志
	CreateDeletionLog(ctx context.Context, log *MediaDeletionLog) error
	ListDeletionLogs(ctx context.Context, mediaID string, offset, limit int) ([]*MediaDeletionLog, int64, error)

	// 媒体访问权限
	GrantAccess(ctx context.Context, access *MediaAccess) error
	RevokeAccess(ctx context.Context, mediaID, userID string) error
	GetAccess(ctx context.Context, mediaID, userID string) (*MediaAccess, error)
	CheckAccess(ctx context.Context, mediaID, userID string, needDownload bool) (bool, error)
	ListAccessByMedia(ctx context.Context, mediaID string) ([]*MediaAccess, error)

	// 下载日志
	LogDownload(ctx context.Context, log *MediaDownloadLog) error
	GetDownloadStats(ctx context.Context, mediaID string) (int64, error)
	ListDownloadsByUser(ctx context.Context, userID string, offset, limit int) ([]*MediaDownloadLog, int64, error)

	// 上传会话（分片上传）
	CreateUploadSession(ctx context.Context, session *UploadSession) error
	GetUploadSession(ctx context.Context, id string) (*UploadSession, error)
	UpdateUploadSession(ctx context.Context, session *UploadSession) error
	DeleteUploadSession(ctx context.Context, id string) error
	ListExpiredSessions(ctx context.Context) ([]*UploadSession, error)

	// 播放位置
	GetPlaybackPosition(ctx context.Context, mediaID, userID string) (*MediaPlaybackPosition, error)
	UpdatePlaybackPosition(ctx context.Context, position *MediaPlaybackPosition) error
	DeletePlaybackPosition(ctx context.Context, mediaID, userID string) error
}

// mediaRepository 媒体仓库实现
type mediaRepository struct {
	db *gorm.DB
}

// NewMediaRepository 创建媒体仓库实例
func NewMediaRepository(db *gorm.DB) MediaRepository {
	return &mediaRepository{db: db}
}

// CreateMedia 创建媒体记录
func (r *mediaRepository) CreateMedia(ctx context.Context, media *Media) error {
	return r.db.WithContext(ctx).Create(media).Error
}

// GetMediaByID 根据ID获取媒体
func (r *mediaRepository) GetMediaByID(ctx context.Context, id string) (*Media, error) {
	var media Media
	err := r.db.WithContext(ctx).Where("id = ? AND status != ?", id, MediaStatusDeleted).First(&media).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &media, nil
}

// UpdateMedia 更新媒体记录
func (r *mediaRepository) UpdateMedia(ctx context.Context, media *Media) error {
	return r.db.WithContext(ctx).Save(media).Error
}

// DeleteMedia 删除媒体（软删除）
func (r *mediaRepository) DeleteMedia(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Model(&Media{}).Where("id = ?", id).
		Update("status", MediaStatusDeleted).Error
}

// ListMediaByUploader 列出用户上传的媒体
func (r *mediaRepository) ListMediaByUploader(ctx context.Context, uploaderID string, offset, limit int) ([]*Media, int64, error) {
	var media []*Media
	var total int64

	query := r.db.WithContext(ctx).Model(&Media{}).
		Where("uploader_id = ? AND status = ?", uploaderID, MediaStatusReady)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("created_at DESC").Offset(offset).Limit(limit).Find(&media).Error; err != nil {
		return nil, 0, err
	}

	return media, total, nil
}

// ListMediaByRoom 列出聊天室的媒体
func (r *mediaRepository) ListMediaByRoom(ctx context.Context, roomID string, offset, limit int) ([]*Media, int64, error) {
	var media []*Media
	var total int64

	query := r.db.WithContext(ctx).Model(&Media{}).
		Where("room_id = ? AND status = ?", roomID, MediaStatusReady)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("created_at DESC").Offset(offset).Limit(limit).Find(&media).Error; err != nil {
		return nil, 0, err
	}

	return media, total, nil
}

// ListMediaByMessage 列出消息的媒体
func (r *mediaRepository) ListMediaByMessage(ctx context.Context, messageID string) ([]*Media, error) {
	var media []*Media
	err := r.db.WithContext(ctx).Where("message_id = ? AND status = ?", messageID, MediaStatusReady).
		Order("created_at ASC").Find(&media).Error
	return media, err
}

// ListExpiredMedia 列出已过期的媒体
func (r *mediaRepository) ListExpiredMedia(ctx context.Context) ([]*Media, error) {
	var media []*Media
	err := r.db.WithContext(ctx).
		Where("expires_at IS NOT NULL AND expires_at < ? AND status = ?", time.Now(), MediaStatusReady).
		Find(&media).Error
	return media, err
}

// GrantAccess 授予媒体访问权限
func (r *mediaRepository) GrantAccess(ctx context.Context, access *MediaAccess) error {
	// 先检查是否已存在
	var existing MediaAccess
	err := r.db.WithContext(ctx).
		Where("media_id = ? AND user_id = ?", access.MediaID, access.UserID).
		First(&existing).Error

	if err == nil {
		// 更新现有权限
		access.ID = existing.ID
		return r.db.WithContext(ctx).Save(access).Error
	}

	if errors.Is(err, gorm.ErrRecordNotFound) {
		return r.db.WithContext(ctx).Create(access).Error
	}

	return err
}

// RevokeAccess 撤销媒体访问权限
func (r *mediaRepository) RevokeAccess(ctx context.Context, mediaID, userID string) error {
	return r.db.WithContext(ctx).
		Where("media_id = ? AND user_id = ?", mediaID, userID).
		Delete(&MediaAccess{}).Error
}

// GetAccess 获取特定用户的媒体访问权限
func (r *mediaRepository) GetAccess(ctx context.Context, mediaID, userID string) (*MediaAccess, error) {
	var access MediaAccess
	err := r.db.WithContext(ctx).
		Where("media_id = ? AND user_id = ?", mediaID, userID).
		First(&access).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &access, nil
}

// CheckAccess 检查用户是否有访问权限
func (r *mediaRepository) CheckAccess(ctx context.Context, mediaID, userID string, needDownload bool) (bool, error) {
	// 先获取媒体信息
	media, err := r.GetMediaByID(ctx, mediaID)
	if err != nil {
		return false, err
	}
	if media == nil {
		return false, nil
	}

	// 上传者始终有权限
	if media.UploaderID == userID {
		return true, nil
	}

	// 公开媒体可以查看
	if media.IsPublic && !needDownload {
		return true, nil
	}

	// 检查显式授权
	access, err := r.GetAccess(ctx, mediaID, userID)
	if err != nil {
		return false, err
	}

	if access == nil {
		return false, nil
	}

	// 检查是否过期
	if access.ExpiresAt != nil && access.ExpiresAt.Before(time.Now()) {
		return false, nil
	}

	if needDownload {
		return access.CanDownload, nil
	}
	return access.CanView, nil
}

// ListAccessByMedia 列出媒体的所有访问权限
func (r *mediaRepository) ListAccessByMedia(ctx context.Context, mediaID string) ([]*MediaAccess, error) {
	var accesses []*MediaAccess
	err := r.db.WithContext(ctx).Where("media_id = ?", mediaID).Find(&accesses).Error
	return accesses, err
}

// LogDownload 记录下载
func (r *mediaRepository) LogDownload(ctx context.Context, log *MediaDownloadLog) error {
	return r.db.WithContext(ctx).Create(log).Error
}

// GetDownloadStats 获取下载统计
func (r *mediaRepository) GetDownloadStats(ctx context.Context, mediaID string) (int64, error) {
	var count int64
	err := r.db.WithContext(ctx).Model(&MediaDownloadLog{}).
		Where("media_id = ?", mediaID).
		Count(&count).Error
	return count, err
}

// ListDownloadsByUser 列出用户的下载记录
func (r *mediaRepository) ListDownloadsByUser(ctx context.Context, userID string, offset, limit int) ([]*MediaDownloadLog, int64, error) {
	var logs []*MediaDownloadLog
	var total int64

	query := r.db.WithContext(ctx).Model(&MediaDownloadLog{}).Where("user_id = ?", userID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("downloaded_at DESC").Offset(offset).Limit(limit).Find(&logs).Error; err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}

// CreateUploadSession 创建上传会话
func (r *mediaRepository) CreateUploadSession(ctx context.Context, session *UploadSession) error {
	return r.db.WithContext(ctx).Create(session).Error
}

// GetUploadSession 获取上传会话
func (r *mediaRepository) GetUploadSession(ctx context.Context, id string) (*UploadSession, error) {
	var session UploadSession
	err := r.db.WithContext(ctx).Where("id = ?", id).First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &session, nil
}

// UpdateUploadSession 更新上传会话
func (r *mediaRepository) UpdateUploadSession(ctx context.Context, session *UploadSession) error {
	return r.db.WithContext(ctx).Save(session).Error
}

// DeleteUploadSession 删除上传会话
func (r *mediaRepository) DeleteUploadSession(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Where("id = ?", id).Delete(&UploadSession{}).Error
}

// ListExpiredSessions 列出过期的上传会话
func (r *mediaRepository) ListExpiredSessions(ctx context.Context) ([]*UploadSession, error) {
	var sessions []*UploadSession
	err := r.db.WithContext(ctx).
		Where("expires_at < ? AND status != ?", time.Now(), "completed").
		Find(&sessions).Error
	return sessions, err
}

// SoftDeleteMedia 软删除媒体
func (r *mediaRepository) SoftDeleteMedia(ctx context.Context, id, deletedBy string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&Media{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":     MediaStatusDeleted,
			"deleted_at": now,
			"deleted_by": deletedBy,
		}).Error
}

// GetDeletedMediaByID 获取已删除的媒体
func (r *mediaRepository) GetDeletedMediaByID(ctx context.Context, id string) (*Media, error) {
	var media Media
	err := r.db.WithContext(ctx).Where("id = ? AND status = ?", id, MediaStatusDeleted).First(&media).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &media, nil
}

// ListDeletedMedia 列出用户回收站中的媒体
func (r *mediaRepository) ListDeletedMedia(ctx context.Context, uploaderID string, offset, limit int) ([]*Media, int64, error) {
	var media []*Media
	var total int64

	query := r.db.WithContext(ctx).Model(&Media{}).
		Where("uploader_id = ? AND status = ?", uploaderID, MediaStatusDeleted)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("deleted_at DESC").Offset(offset).Limit(limit).Find(&media).Error; err != nil {
		return nil, 0, err
	}

	return media, total, nil
}

// RestoreMedia 恢复已删除的媒体
func (r *mediaRepository) RestoreMedia(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Model(&Media{}).Where("id = ? AND status = ?", id, MediaStatusDeleted).
		Updates(map[string]interface{}{
			"status":     MediaStatusReady,
			"deleted_at": nil,
			"deleted_by": "",
		}).Error
}

// PermanentDeleteMedia 永久删除媒体
func (r *mediaRepository) PermanentDeleteMedia(ctx context.Context, id string) error {
	return r.db.WithContext(ctx).Where("id = ?", id).Delete(&Media{}).Error
}

// CreateDeletionLog 创建删除审计日志
func (r *mediaRepository) CreateDeletionLog(ctx context.Context, log *MediaDeletionLog) error {
	return r.db.WithContext(ctx).Create(log).Error
}

// ListDeletionLogs 列出删除日志
func (r *mediaRepository) ListDeletionLogs(ctx context.Context, mediaID string, offset, limit int) ([]*MediaDeletionLog, int64, error) {
	var logs []*MediaDeletionLog
	var total int64

	query := r.db.WithContext(ctx).Model(&MediaDeletionLog{}).Where("media_id = ?", mediaID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("deleted_at DESC").Offset(offset).Limit(limit).Find(&logs).Error; err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}

// GetPlaybackPosition 获取播放位置
func (r *mediaRepository) GetPlaybackPosition(ctx context.Context, mediaID, userID string) (*MediaPlaybackPosition, error) {
	var position MediaPlaybackPosition
	err := r.db.WithContext(ctx).
		Where("media_id = ? AND user_id = ?", mediaID, userID).
		First(&position).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &position, nil
}

// UpdatePlaybackPosition 更新播放位置
func (r *mediaRepository) UpdatePlaybackPosition(ctx context.Context, position *MediaPlaybackPosition) error {
	// 使用Upsert：如果存在则更新，否则创建
	return r.db.WithContext(ctx).Save(position).Error
}

// DeletePlaybackPosition 删除播放位置
func (r *mediaRepository) DeletePlaybackPosition(ctx context.Context, mediaID, userID string) error {
	return r.db.WithContext(ctx).
		Where("media_id = ? AND user_id = ?", mediaID, userID).
		Delete(&MediaPlaybackPosition{}).Error
}
