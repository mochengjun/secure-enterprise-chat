package middleware

import (
	"net/http"
	"strings"

	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

// AuthMiddleware 认证中间件
type AuthMiddleware struct {
	authService service.AuthService
}

// NewAuthMiddleware 创建认证中间件实例
func NewAuthMiddleware(authService service.AuthService) *AuthMiddleware {
	return &AuthMiddleware{authService: authService}
}

// Authenticate 认证中间件
func (m *AuthMiddleware) Authenticate() gin.HandlerFunc {
	return func(c *gin.Context) {
		var token string

		// 首先尝试从 Authorization header 获取
		authHeader := c.GetHeader("Authorization")
		if authHeader != "" {
			// 解析 Bearer Token
			parts := strings.SplitN(authHeader, " ", 2)
			if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
				token = parts[1]
			}
		}

		// 如果 header 中没有，尝试从查询参数获取（用于 WebSocket 连接）
		if token == "" {
			token = c.Query("token")
		}

		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization required"})
			c.Abort()
			return
		}

		// 验证 Token
		claims, err := m.authService.ValidateToken(c.Request.Context(), token)
		if err != nil {
			switch err {
			case service.ErrTokenExpired:
				c.JSON(http.StatusUnauthorized, gin.H{"error": "token expired"})
			case service.ErrTokenBlacklisted:
				c.JSON(http.StatusUnauthorized, gin.H{"error": "token has been revoked"})
			default:
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			}
			c.Abort()
			return
		}

		// 将用户信息存入上下文
		c.Set("user_id", claims.UserID)
		c.Set("username", claims.Username)
		c.Set("device_id", claims.DeviceID)

		c.Next()
	}
}

// OptionalAuth 可选认证中间件（不强制要求认证）
func (m *AuthMiddleware) OptionalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.Next()
			return
		}

		token := parts[1]
		claims, err := m.authService.ValidateToken(c.Request.Context(), token)
		if err == nil {
			c.Set("user_id", claims.UserID)
			c.Set("username", claims.Username)
			c.Set("device_id", claims.DeviceID)
		}

		c.Next()
	}
}
