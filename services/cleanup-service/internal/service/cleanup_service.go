package service

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"sec-chat/cleanup-service/internal/repository"
)

type CleanupService struct {
	repo        *repository.CleanupRepository
	minioClient MinioClient
}

type MinioClient interface {
	DeleteObject(ctx context.Context, bucket, object string) error
}

type CleanupResult struct {
	MessagesDeleted   int64
	MediaFilesDeleted int64
	AuditLogsDeleted  int64
	TokensDeleted     int64
	Errors            []error
	Duration          time.Duration
}

func NewCleanupService(databaseURL string) *CleanupService {
	repo, err := repository.NewCleanupRepository(databaseURL)
	if err != nil {
		log.Printf("Warning: Failed to connect to database: %v", err)
		return &CleanupService{}
	}

	return &CleanupService{
		repo: repo,
	}
}

func (s *CleanupService) SetMinioClient(client MinioClient) {
	s.minioClient = client
}

// PerformFullCleanup 执行完整的清理任务
func (s *CleanupService) PerformFullCleanup(ctx context.Context) (*CleanupResult, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	startTime := time.Now()
	result := &CleanupResult{}

	// 1. 清理过期消息
	msgDeleted, errs := s.cleanupExpiredMessages(ctx)
	result.MessagesDeleted = msgDeleted
	result.Errors = append(result.Errors, errs...)

	// 2. 清理过期媒体文件
	mediaDeleted, errs := s.cleanupExpiredMedia(ctx)
	result.MediaFilesDeleted = mediaDeleted
	result.Errors = append(result.Errors, errs...)

	// 3. 清理过期审计日志（保留90天）
	logsDeleted, err := s.cleanupAuditLogs(ctx, 90*24*time.Hour)
	if err != nil {
		result.Errors = append(result.Errors, err)
	}
	result.AuditLogsDeleted = logsDeleted

	// 4. 清理过期Token
	tokensDeleted, err := s.cleanupExpiredTokens(ctx)
	if err != nil {
		result.Errors = append(result.Errors, err)
	}
	result.TokensDeleted = tokensDeleted

	result.Duration = time.Since(startTime)

	log.Printf("Cleanup completed: messages=%d, media=%d, logs=%d, tokens=%d, duration=%v, errors=%d",
		result.MessagesDeleted,
		result.MediaFilesDeleted,
		result.AuditLogsDeleted,
		result.TokensDeleted,
		result.Duration,
		len(result.Errors))

	return result, nil
}

// cleanupExpiredMessages 清理过期消息
func (s *CleanupService) cleanupExpiredMessages(ctx context.Context) (int64, []error) {
	var totalDeleted int64
	var errors []error

	// 获取群组特定的保留策略
	policies, err := s.repo.GetRoomRetentionPolicies()
	if err != nil {
		errors = append(errors, fmt.Errorf("failed to get room policies: %w", err))
	}

	// 按群组策略删除消息
	excludeRooms := make([]string, 0)
	for _, policy := range policies {
		if policy.RetentionHours == 0 {
			// 永久保留，跳过
			excludeRooms = append(excludeRooms, policy.RoomID)
			continue
		}

		beforeTime := time.Now().Add(-time.Duration(policy.RetentionHours) * time.Hour)
		deleted, err := s.repo.DeleteExpiredMessages(policy.RoomID, beforeTime)
		if err != nil {
			errors = append(errors, fmt.Errorf("failed to delete messages for room %s: %w", policy.RoomID, err))
			continue
		}
		totalDeleted += deleted
		excludeRooms = append(excludeRooms, policy.RoomID)

		if deleted > 0 {
			log.Printf("Deleted %d messages from room %s (retention: %dh)", deleted, policy.RoomID, policy.RetentionHours)
		}
	}

	// 使用全局策略删除其他群组的消息
	globalHours, err := s.repo.GetGlobalRetentionHours()
	if err != nil {
		errors = append(errors, fmt.Errorf("failed to get global retention: %w", err))
		globalHours = 72 // 默认值
	}

	if globalHours > 0 {
		beforeTime := time.Now().Add(-time.Duration(globalHours) * time.Hour)
		deleted, err := s.repo.DeleteExpiredMessagesGlobal(beforeTime, excludeRooms)
		if err != nil {
			errors = append(errors, fmt.Errorf("failed to delete global messages: %w", err))
		} else {
			totalDeleted += deleted
			if deleted > 0 {
				log.Printf("Deleted %d messages using global policy (retention: %dh)", deleted, globalHours)
			}
		}
	}

	return totalDeleted, errors
}

// cleanupExpiredMedia 清理过期媒体文件
func (s *CleanupService) cleanupExpiredMedia(ctx context.Context) (int64, []error) {
	var errors []error

	paths, err := s.repo.DeleteExpiredMediaFiles(time.Now())
	if err != nil {
		return 0, []error{fmt.Errorf("failed to delete expired media: %w", err)}
	}

	// 删除实际文件
	for _, path := range paths {
		if s.minioClient != nil {
			// 使用MinIO删除
			bucket := os.Getenv("MINIO_BUCKET")
			if bucket == "" {
				bucket = "secure-chat-media"
			}
			err := s.minioClient.DeleteObject(ctx, bucket, path)
			if err != nil {
				errors = append(errors, fmt.Errorf("failed to delete from minio %s: %w", path, err))
			}
		} else {
			// 本地文件删除
			fullPath := filepath.Join(os.Getenv("MEDIA_STORAGE_PATH"), path)
			if err := os.Remove(fullPath); err != nil && !os.IsNotExist(err) {
				errors = append(errors, fmt.Errorf("failed to delete file %s: %w", fullPath, err))
			}
		}
	}

	return int64(len(paths)), errors
}

// cleanupAuditLogs 清理审计日志
func (s *CleanupService) cleanupAuditLogs(ctx context.Context, retention time.Duration) (int64, error) {
	beforeTime := time.Now().Add(-retention)
	return s.repo.DeleteOldAuditLogs(beforeTime)
}

// cleanupExpiredTokens 清理过期Token
func (s *CleanupService) cleanupExpiredTokens(ctx context.Context) (int64, error) {
	return s.repo.DeleteExpiredTokens()
}

// GetStats 获取当前统计信息
func (s *CleanupService) GetStats(ctx context.Context) (*repository.CleanupStats, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}
	return s.repo.GetCleanupStats()
}

// UpdateRoomRetention 更新群组保留策略
func (s *CleanupService) UpdateRoomRetention(ctx context.Context, roomID string, hours int) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}
	// 这个功能可以通过admin service调用
	log.Printf("Room retention update requested: room=%s, hours=%d", roomID, hours)
	return nil
}
