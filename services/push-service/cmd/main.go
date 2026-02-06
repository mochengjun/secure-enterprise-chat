package main

import (
	"log"
	"os"

	"sec-chat/push-service/internal/handler"
	"sec-chat/push-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

func main() {
	// 获取配置
	redisURL := getEnv("REDIS_URL", "redis://:redis_password@localhost:6379/1")
	apnsKeyPath := getEnv("APNS_KEY_PATH", "")
	apnsKeyID := getEnv("APNS_KEY_ID", "")
	apnsTeamID := getEnv("APNS_TEAM_ID", "")
	fcmCredentialsPath := getEnv("FCM_CREDENTIALS_PATH", "")
	serverPort := getEnv("SERVER_PORT", "8083")

	// 初始化 Redis
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}
	redisClient := redis.NewClient(opt)

	// 初始化服务
	pushService := service.NewPushService(apnsKeyPath, apnsKeyID, apnsTeamID, fcmCredentialsPath)

	// 初始化处理器
	pushHandler := handler.NewPushHandler(pushService, redisClient)

	// 设置 Gin 路由
	router := gin.Default()

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "push-service"})
	})

	// API v1
	v1 := router.Group("/api/v1")
	{
		// 发送推送通知
		v1.POST("/push/send", pushHandler.SendPushNotification)
		
		// 注册设备 Token
		v1.POST("/push/register", pushHandler.RegisterDeviceToken)
		
		// 注销设备 Token
		v1.POST("/push/unregister", pushHandler.UnregisterDeviceToken)
	}

	// 启动服务器
	log.Printf("Push Service starting on port %s", serverPort)
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
