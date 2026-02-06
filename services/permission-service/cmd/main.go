package main

import (
	"log"
	"os"

	"sec-chat/permission-service/internal/handler"
	"sec-chat/permission-service/internal/service"

	"github.com/gin-gonic/gin"
)

func main() {
	// 获取配置
	databaseURL := getEnv("DATABASE_URL", "postgres://synapse:synapse_password@localhost:5432/synapse?sslmode=disable")
	serverPort := getEnv("SERVER_PORT", "8085")

	// 初始化服务
	permissionService := service.NewPermissionService(databaseURL)

	// 初始化处理器
	permissionHandler := handler.NewPermissionHandler(permissionService)

	// 设置 Gin 路由
	router := gin.Default()

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "permission-service"})
	})

	// API v1
	v1 := router.Group("/api/v1")
	permissionHandler.RegisterRoutes(v1)

	// 启动服务器
	log.Printf("Permission Service starting on port %s", serverPort)
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
