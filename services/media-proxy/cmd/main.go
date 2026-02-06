package main

import (
	"log"
	"os"

	"sec-chat/media-proxy/internal/handler"
	"sec-chat/media-proxy/internal/service"
	"sec-chat/media-proxy/internal/storage"

	"github.com/gin-gonic/gin"
)

func main() {
	// 获取配置
	databaseURL := getEnv("DATABASE_URL", "postgres://synapse:synapse_password@localhost:5432/synapse?sslmode=disable")
	minioEndpoint := getEnv("MINIO_ENDPOINT", "localhost:9000")
	minioAccessKey := getEnv("MINIO_ACCESS_KEY", "minioadmin")
	minioSecretKey := getEnv("MINIO_SECRET_KEY", "minioadmin123")
	bucketName := getEnv("MINIO_BUCKET", "secure-chat-media")
	serverPort := getEnv("SERVER_PORT", "8082")
	storageType := getEnv("STORAGE_TYPE", "minio") // minio or local

	// 初始化存储
	var store storage.Storage
	var err error

	if storageType == "local" {
		localPath := getEnv("LOCAL_STORAGE_PATH", "./media")
		store, err = storage.NewLocalStorage(localPath)
	} else {
		useSSL := getEnv("MINIO_USE_SSL", "false") == "true"
		store, err = storage.NewMinioStorage(minioEndpoint, minioAccessKey, minioSecretKey, bucketName, useSSL)
	}

	if err != nil {
		log.Printf("Warning: Failed to initialize storage: %v, using local storage", err)
		store, _ = storage.NewLocalStorage("./media")
	}

	// 初始化服务
	mediaService := service.NewMediaService(databaseURL, store)

	// 初始化处理器
	mediaHandler := handler.NewMediaHandler(mediaService)

	// 设置 Gin 路由
	router := gin.Default()

	// 设置最大上传大小 (100MB)
	router.MaxMultipartMemory = 100 << 20

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "media-proxy"})
	})

	// API v1
	v1 := router.Group("/api/v1")
	mediaHandler.RegisterRoutes(v1)

	// 启动服务器
	log.Printf("Media Proxy Service starting on port %s", serverPort)
	if err := router.Run(":" + serverPort); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
