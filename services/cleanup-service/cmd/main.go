package main

import (
	"log"
	"os"

	"sec-chat/cleanup-service/internal/handler"
	"sec-chat/cleanup-service/internal/service"

	"github.com/robfig/cron/v3"
)

func main() {
	// 获取配置
	databaseURL := getEnv("DATABASE_URL", "postgres://synapse:synapse_password@localhost:5432/synapse?sslmode=disable")
	interval := getEnv("CLEANUP_INTERVAL", "1h")

	// 初始化服务
	cleanupService := service.NewCleanupService(databaseURL)

	// 初始化处理器
	cleanupHandler := handler.NewCleanupHandler(cleanupService)

	// 设置定时任务
	c := cron.New()
	
	// 每小时清理过期消息
	schedule, err := c.AddFunc("@every "+interval, func() {
		log.Println("Starting scheduled cleanup...")
		err := cleanupHandler.PerformCleanup()
		if err != nil {
			log.Printf("Cleanup error: %v", err)
		} else {
			log.Println("Cleanup completed successfully")
		}
	})
	if err != nil {
		log.Fatalf("Failed to schedule cleanup job: %v", err)
	}

	log.Printf("Cleanup Service scheduled with interval: %s (schedule ID: %d)", interval, schedule)

	// 立即执行一次清理
	log.Println("Performing initial cleanup...")
	err = cleanupHandler.PerformCleanup()
	if err != nil {
		log.Printf("Initial cleanup error: %v", err)
	} else {
		log.Println("Initial cleanup completed successfully")
	}

	// 启动定时任务
	c.Start()

	// 保持服务运行
	select {}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
