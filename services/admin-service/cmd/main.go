package main

import (
	"log"
	"os"

	"sec-chat/admin-service/internal/handler"
	"sec-chat/admin-service/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	// 获取配置
	databaseURL := getEnv("DATABASE_URL", "postgres://synapse:synapse_password@localhost:5432/synapse?sslmode=disable")
	serverPort := getEnv("SERVER_PORT", "8084")

	// 初始化数据库
	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// 初始化服务
	adminService := service.NewAdminService(db)

	// 初始化处理器
	adminHandler := handler.NewAdminHandler(adminService)

	// 设置 Gin 路由
	router := gin.Default()

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "admin-service"})
	})

	// API v1
	v1 := router.Group("/api/v1")
	{
		// 用户管理
		users := v1.Group("/users")
		{
			users.GET("", adminHandler.ListUsers)
			users.GET("/:userId", adminHandler.GetUser)
			users.PUT("/:userId", adminHandler.UpdateUser)
			users.DELETE("/:userId", adminHandler.DeleteUser)
		}

		// 群组管理
		groups := v1.Group("/groups")
		{
			groups.GET("", adminHandler.ListGroups)
			groups.GET("/:groupId", adminHandler.GetGroup)
			groups.POST("", adminHandler.CreateGroup)
			groups.PUT("/:groupId", adminHandler.UpdateGroup)
			groups.DELETE("/:groupId", adminHandler.DeleteGroup)
		}

		// 系统配置管理
		config := v1.Group("/config")
		{
			config.GET("", adminHandler.GetSystemConfig)
			config.PUT("", adminHandler.UpdateSystemConfig)
		}

		// 日志管理
		logs := v1.Group("/logs")
		{
			logs.GET("/audit", adminHandler.GetAuditLogs)
			logs.GET("/system", adminHandler.GetSystemLogs)
		}
	}

	// 启动服务器
	log.Printf("Admin Service starting on port %s", serverPort)
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
