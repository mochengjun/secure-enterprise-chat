package main

import (
	"log"
	"os"

	"sec-chat/auth-service/internal/handler"
	"sec-chat/auth-service/internal/middleware"
	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func main() {
	// 获取配置
	dbType := getEnv("DB_TYPE", "sqlite") // sqlite 或 postgres
	databaseURL := getEnv("DATABASE_URL", "postgres://synapse:synapse_password@localhost:5432/synapse?sslmode=disable")
	sqlitePath := getEnv("SQLITE_PATH", "./auth.db")
	jwtSecret := getEnv("JWT_SECRET", "your-super-secret-jwt-key")
	serverPort := getEnv("SERVER_PORT", "8081")

	// 初始化数据库
	var db *gorm.DB
	var err error

	if dbType == "sqlite" {
		log.Println("Using SQLite database:", sqlitePath)
		db, err = gorm.Open(sqlite.Open(sqlitePath), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info),
		})
	} else {
		log.Println("Using PostgreSQL database")
		db, err = gorm.Open(postgres.Open(databaseURL), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Info),
		})
	}

	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// 自动迁移数据库表
	if err := autoMigrate(db); err != nil {
		log.Fatalf("Failed to migrate database: %v", err)
	}

	// 初始化仓库层（使用内存缓存替代 Redis）
	userRepo := repository.NewUserRepository(db)
	deviceRepo := repository.NewDeviceRepository(db)
	tokenRepo := repository.NewTokenRepositoryWithoutRedis(db)
	chatRepo := repository.NewChatRepository(db)
	adminRepo := repository.NewAdminRepository(db)
	pushRepo := repository.NewPushRepository(db)
	mediaRepo := repository.NewMediaRepository(db)
	callRepo := repository.NewCallRepository(db)
	e2eeRepo := repository.NewE2EERepository(db)

	// 媒体服务配置
	mediaConfig := service.DefaultMediaConfig()
	mediaConfig.StoragePath = getEnv("MEDIA_STORAGE_PATH", "./uploads/media")
	mediaConfig.ThumbnailPath = getEnv("MEDIA_THUMBNAIL_PATH", "./uploads/thumbnails")
	mediaConfig.TempPath = getEnv("MEDIA_TEMP_PATH", "./uploads/temp")
	mediaConfig.BaseURL = "/api/v1/media"

	// 推送服务配置（从环境变量读取）
	var pushConfig *service.PushConfig
	fcmKey := getEnv("FCM_SERVER_KEY", "")
	if fcmKey != "" {
		pushConfig = &service.PushConfig{
			FCM: &service.FCMConfig{
				ServerKey: fcmKey,
				ProjectID: getEnv("FCM_PROJECT_ID", ""),
			},
		}
	}

	// 初始化服务层
	authService := service.NewAuthService(userRepo, deviceRepo, tokenRepo, jwtSecret)
	mfaService := service.NewMFAService(userRepo)
	chatService := service.NewChatService(chatRepo, userRepo)
	adminService := service.NewAdminService(adminRepo, userRepo)
	pushService := service.NewPushService(pushRepo, pushConfig)
	mediaService := service.NewMediaService(mediaRepo, mediaConfig)
	callService := service.NewCallService(callRepo, nil)
	e2eeService := service.NewE2EEService(e2eeRepo)

	// 初始化 WebSocket Hub
	wsHub := handler.NewWSHub(chatService)
	go wsHub.Run()

	// 初始化信令 Hub (WebRTC)
	signalingHub := handler.NewSignalingHub(callService)
	go signalingHub.Run()

	// 初始化处理器
	authHandler := handler.NewAuthHandler(authService, mfaService)
	chatHandler := handler.NewChatHandler(chatService, wsHub)
	adminHandler := handler.NewAdminHandler(adminService)
	pushHandler := handler.NewPushHandler(pushService)
	mediaHandler := handler.NewMediaHandler(mediaService)
	callHandler := handler.NewCallHandler(callService, signalingHub)
	e2eeHandler := handler.NewE2EEHandler(e2eeService)

	// 初始化中间件
	authMiddleware := middleware.NewAuthMiddleware(authService)

	// 设置 Gin 路由
	router := gin.Default()

	// CORS 配置
	router.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// 健康检查
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "auth-service", "db_type": dbType})
	})

	// Admin Web 静态文件服务
	adminWebPath := getEnv("ADMIN_WEB_PATH", "../../admin-web")
	router.Static("/admin", adminWebPath)

	// API v1
	v1 := router.Group("/api/v1")
	{
		// 公开接口
		auth := v1.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/refresh", authHandler.RefreshToken)
			auth.POST("/verify-mfa", authHandler.VerifyMFA)
			auth.POST("/send-sms-code", authHandler.SendSMSCode)
		}

		// 需要认证的接口
		protected := v1.Group("/")
		protected.Use(authMiddleware.Authenticate())
		{
			protected.POST("/auth/logout", authHandler.Logout)
			protected.GET("/auth/me", authHandler.GetCurrentUser)
			protected.PUT("/auth/password", authHandler.ChangePassword)

			// MFA 管理
			mfa := protected.Group("/mfa")
			{
				mfa.POST("/enable", authHandler.EnableMFA)
				mfa.POST("/disable", authHandler.DisableMFA)
				mfa.GET("/setup", authHandler.GetMFASetup)
			}

			// 设备管理
			devices := protected.Group("/devices")
			{
				devices.GET("", authHandler.ListDevices)
				devices.DELETE("/:deviceId", authHandler.RevokeDevice)
			}

			// ====== Chat API ======
			chat := protected.Group("/chat")
			{
				// 用户搜索
				chat.GET("/users/search", chatHandler.SearchUsers)

				// 房间管理
				rooms := chat.Group("/rooms")
				{
					rooms.GET("", chatHandler.ListRooms)
					rooms.POST("", chatHandler.CreateRoom)
					rooms.GET("/:roomId", chatHandler.GetRoom)
					rooms.PUT("/:roomId", chatHandler.UpdateRoom)
					rooms.POST("/:roomId/leave", chatHandler.LeaveRoom)
					rooms.PUT("/:roomId/mute", chatHandler.MuteRoom)
					rooms.PUT("/:roomId/pin", chatHandler.PinRoom)

					// 成员管理
					rooms.GET("/:roomId/members", chatHandler.ListMembers)
					rooms.POST("/:roomId/members", chatHandler.AddMembers)
					rooms.DELETE("/:roomId/members/:userId", chatHandler.RemoveMember)
					rooms.PUT("/:roomId/members/:userId/role", chatHandler.UpdateMemberRole)

					// 消息管理
					rooms.GET("/:roomId/messages", chatHandler.ListMessages)
					rooms.POST("/:roomId/messages", chatHandler.SendMessage)
					rooms.DELETE("/:roomId/messages/:messageId", chatHandler.DeleteMessage)
					rooms.POST("/:roomId/read", chatHandler.MarkAsRead)
				}
			}

			// WebSocket 连接
			protected.GET("/ws", wsHub.HandleWebSocket)

			// WebRTC 信令 WebSocket
			protected.GET("/signaling", signalingHub.HandleSignaling)

			// ====== Call API (WebRTC) ======
			calls := protected.Group("/calls")
			{
				calls.POST("", callHandler.InitiateCall)
				calls.GET("/active", callHandler.GetActiveCall)
				calls.GET("/history", callHandler.ListCallHistory)
				calls.GET("/ice-servers", callHandler.GetICEServers)
				calls.GET("/:callId", callHandler.GetCall)
				calls.POST("/:callId/accept", callHandler.AcceptCall)
				calls.POST("/:callId/reject", callHandler.RejectCall)
				calls.POST("/:callId/end", callHandler.EndCall)
				calls.POST("/:callId/join", callHandler.JoinCall)
				calls.POST("/:callId/leave", callHandler.LeaveCall)
				calls.POST("/:callId/mute", callHandler.ToggleMute)
				calls.POST("/:callId/video", callHandler.ToggleVideo)
			}

			// ====== Push Notification API ======
			push := protected.Group("/push")
			{
				push.POST("/token", pushHandler.RegisterToken)
				push.DELETE("/token", pushHandler.UnregisterToken)
				push.GET("/settings", pushHandler.GetSettings)
				push.PUT("/settings", pushHandler.UpdateSettings)
				push.POST("/test", pushHandler.SendTestNotification)
			}

			// ====== Media API ======
			media := protected.Group("/media")
			{
				// 上传
				media.POST("/upload", mediaHandler.Upload)
				media.POST("/upload/chunked/init", mediaHandler.InitiateChunkedUpload)
				media.POST("/upload/chunked/:session_id/chunk/:chunk_index", mediaHandler.UploadChunk)
				media.POST("/upload/chunked/:session_id/complete", mediaHandler.CompleteChunkedUpload)

				// 列表
				media.GET("/my", mediaHandler.ListMyMedia)
				media.GET("/room/:room_id", mediaHandler.ListRoomMedia)
				media.GET("/message/:message_id", mediaHandler.ListMessageMedia)
				media.GET("/trash", mediaHandler.ListTrash)

				// 单个媒体操作
				media.GET("/:id", mediaHandler.GetMedia)
				media.GET("/:id/download", mediaHandler.Download)
				media.GET("/:id/stream", mediaHandler.Stream)
				media.GET("/:id/thumbnail", mediaHandler.GetThumbnail)
				media.GET("/:id/stats", mediaHandler.GetStats)
				media.POST("/:id/delete-confirm", mediaHandler.RequestDeleteConfirm)
				media.DELETE("/:id", mediaHandler.Delete)
				media.POST("/:id/restore", mediaHandler.Restore)
				media.DELETE("/:id/permanent", mediaHandler.PermanentDelete)

				// 播放位置
				media.GET("/:id/playback-position", mediaHandler.GetPlaybackPosition)
				media.PUT("/:id/playback-position", mediaHandler.UpdatePlaybackPosition)

				// 权限管理
				media.POST("/:id/access", mediaHandler.GrantAccess)
				media.DELETE("/:id/access", mediaHandler.RevokeAccess)
			}

			// ====== E2EE (End-to-End Encryption) API ======
			e2ee := protected.Group("/e2ee")
			{
				// 密钥管理
				e2ee.POST("/keys", e2eeHandler.RegisterKeys)
				e2ee.GET("/keys/:userId", e2eeHandler.GetKeyBundle)
				e2ee.GET("/keys/:userId/:deviceId", e2eeHandler.GetDeviceKeyBundle)
				e2ee.DELETE("/keys/:deviceId", e2eeHandler.RevokeDeviceKeys)

				// 一次性密钥
				e2ee.POST("/keys/one-time", e2eeHandler.UploadOneTimeKeys)
				e2ee.GET("/keys/one-time/count", e2eeHandler.GetOneTimeKeysCount)

				// 会话管理
				e2ee.POST("/sessions", e2eeHandler.InitiateSession)
				e2ee.GET("/sessions", e2eeHandler.ListSessions)
				e2ee.GET("/sessions/pending", e2eeHandler.GetPendingExchanges)
				e2ee.POST("/sessions/accept", e2eeHandler.AcceptSession)
				e2ee.DELETE("/sessions/:sessionId", e2eeHandler.TerminateSession)
			}

			// ====== Admin API ======
			admin := protected.Group("/admin")
			{
				// 管理员状态检查
				admin.GET("/status", adminHandler.CheckAdminStatus)

				// 用户管理
				users := admin.Group("/users")
				{
					users.GET("", adminHandler.GetUsers)
					users.GET("/:userId", adminHandler.GetUser)
					users.PUT("/:userId/status", adminHandler.UpdateUserStatus)
					users.POST("/:userId/reset-password", adminHandler.ResetUserPassword)
					users.DELETE("/:userId", adminHandler.DeleteUser)
				}

				// 管理员管理
				admins := admin.Group("/admins")
				{
					admins.GET("", adminHandler.GetAdminUsers)
					admins.POST("", adminHandler.CreateAdminUser)
					admins.PUT("/:userId", adminHandler.UpdateAdminRole)
					admins.DELETE("/:userId", adminHandler.DeleteAdminUser)
				}

				// 房间管理
				rooms := admin.Group("/rooms")
				{
					rooms.GET("", adminHandler.GetRooms)
					rooms.GET("/:roomId", adminHandler.GetRoom)
					rooms.GET("/:roomId/members", adminHandler.GetRoomMembers)
					rooms.DELETE("/:roomId", adminHandler.DeleteRoom)
				}

				// 审计日志
				admin.GET("/audit-logs", adminHandler.GetAuditLogs)

				// 系统设置
				settings := admin.Group("/settings")
				{
					settings.GET("", adminHandler.GetSettings)
					settings.GET("/:key", adminHandler.GetSetting)
					settings.PUT("/:key", adminHandler.UpdateSetting)
				}

				// 统计数据
				stats := admin.Group("/stats")
				{
					stats.GET("", adminHandler.GetStats)
					stats.GET("/users", adminHandler.GetUserStats)
					stats.GET("/rooms", adminHandler.GetRoomStats)
					stats.GET("/messages", adminHandler.GetMessageStats)
				}
			}
		}
	}

	// 启动服务器
	log.Printf("Auth Service starting on port %s (DB: %s)", serverPort, dbType)
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

// autoMigrate 自动迁移数据库表
func autoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&repository.User{},
		&repository.Device{},
		&repository.RefreshToken{},
		&repository.TokenBlacklist{},
		&repository.Room{},
		&repository.RoomMember{},
		&repository.Message{},
		&repository.ReadReceipt{},
		&repository.AuditLog{},
		&repository.SystemSetting{},
		&repository.AdminUser{},
		&repository.PushToken{},
		&repository.PushNotification{},
		&repository.UserPushSettings{},
		&repository.Media{},
		&repository.MediaAccess{},
		&repository.MediaDownloadLog{},
		&repository.MediaDeletionLog{},
		&repository.MediaPlaybackPosition{},
		&repository.UploadSession{},
		&repository.Call{},
		&repository.CallParticipant{},
		&repository.DeviceKey{},
		&repository.SessionKey{},
		&repository.EncryptedMessage{},
		&repository.KeyExchangeMessage{},
	)
}
