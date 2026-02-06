package handler

import (
	"context"
	"log"
	"time"

	"sec-chat/cleanup-service/internal/service"
)

type CleanupHandler struct {
	service *service.CleanupService
}

func NewCleanupHandler(svc *service.CleanupService) *CleanupHandler {
	return &CleanupHandler{
		service: svc,
	}
}

// PerformCleanup 执行清理任务
func (h *CleanupHandler) PerformCleanup() error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	log.Println("Starting cleanup job...")

	result, err := h.service.PerformFullCleanup(ctx)
	if err != nil {
		log.Printf("Cleanup failed: %v", err)
		return err
	}

	// 记录结果
	log.Printf("Cleanup job completed:")
	log.Printf("  - Messages deleted: %d", result.MessagesDeleted)
	log.Printf("  - Media files deleted: %d", result.MediaFilesDeleted)
	log.Printf("  - Audit logs deleted: %d", result.AuditLogsDeleted)
	log.Printf("  - Tokens deleted: %d", result.TokensDeleted)
	log.Printf("  - Duration: %v", result.Duration)

	if len(result.Errors) > 0 {
		log.Printf("  - Errors encountered: %d", len(result.Errors))
		for i, err := range result.Errors {
			log.Printf("    [%d] %v", i+1, err)
		}
	}

	return nil
}

// GetStats 获取统计信息
func (h *CleanupHandler) GetStats() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	stats, err := h.service.GetStats(ctx)
	if err != nil {
		return err
	}

	log.Printf("Current stats:")
	log.Printf("  - Total messages: %d", stats.TotalMessages)
	log.Printf("  - Total media files: %d", stats.TotalMediaFiles)
	log.Printf("  - Total audit logs: %d", stats.TotalAuditLogs)

	return nil
}
