package handler

import (
	"net/http"

	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

// PushHandler 推送处理器
type PushHandler struct {
	pushService service.PushService
}

// NewPushHandler 创建推送处理器实例
func NewPushHandler(pushService service.PushService) *PushHandler {
	return &PushHandler{
		pushService: pushService,
	}
}

// RegisterTokenRequest 注册推送 Token 请求
type RegisterTokenRequest struct {
	DeviceID string `json:"device_id" binding:"required"`
	Platform string `json:"platform" binding:"required,oneof=fcm apns web"`
	Token    string `json:"token" binding:"required"`
}

// RegisterToken 注册推送 Token
func (h *PushHandler) RegisterToken(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req RegisterTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	platform := repository.PushPlatform(req.Platform)
	if err := h.pushService.RegisterToken(c.Request.Context(), userID.(string), req.DeviceID, platform, req.Token); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to register token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "token registered successfully"})
}

// UnregisterTokenRequest 注销推送 Token 请求
type UnregisterTokenRequest struct {
	Token string `json:"token" binding:"required"`
}

// UnregisterToken 注销推送 Token
func (h *PushHandler) UnregisterToken(c *gin.Context) {
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req UnregisterTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.pushService.UnregisterToken(c.Request.Context(), req.Token); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to unregister token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "token unregistered successfully"})
}

// GetSettings 获取推送设置
func (h *PushHandler) GetSettings(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	settings, err := h.pushService.GetUserSettings(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get settings"})
		return
	}

	c.JSON(http.StatusOK, settings)
}

// UpdateSettingsRequest 更新推送设置请求
type UpdateSettingsRequest struct {
	EnablePush      *bool  `json:"enable_push"`
	EnableSound     *bool  `json:"enable_sound"`
	EnableVibration *bool  `json:"enable_vibration"`
	EnablePreview   *bool  `json:"enable_preview"`
	QuietHoursStart *int   `json:"quiet_hours_start"`
	QuietHoursEnd   *int   `json:"quiet_hours_end"`
	MutedRooms      string `json:"muted_rooms"`
}

// UpdateSettings 更新推送设置
func (h *PushHandler) UpdateSettings(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req UpdateSettingsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 获取现有设置
	settings, err := h.pushService.GetUserSettings(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get settings"})
		return
	}

	// 更新字段
	if req.EnablePush != nil {
		settings.EnablePush = *req.EnablePush
	}
	if req.EnableSound != nil {
		settings.EnableSound = *req.EnableSound
	}
	if req.EnableVibration != nil {
		settings.EnableVibration = *req.EnableVibration
	}
	if req.EnablePreview != nil {
		settings.EnablePreview = *req.EnablePreview
	}
	if req.QuietHoursStart != nil {
		settings.QuietHoursStart = req.QuietHoursStart
	}
	if req.QuietHoursEnd != nil {
		settings.QuietHoursEnd = req.QuietHoursEnd
	}
	if req.MutedRooms != "" {
		settings.MutedRooms = req.MutedRooms
	}

	if err := h.pushService.UpdateUserSettings(c.Request.Context(), settings); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update settings"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "settings updated successfully"})
}

// SendTestNotification 发送测试推送（仅用于调试）
func (h *PushHandler) SendTestNotification(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	payload := &service.PushPayload{
		UserID: userID.(string),
		Type:   repository.PushTypeSystemAlert,
		Title:  "测试推送",
		Body:   "这是一条测试推送消息",
		Data: map[string]string{
			"type": "test",
		},
	}

	results, err := h.pushService.SendToUser(c.Request.Context(), payload)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "test notification sent",
		"results": results,
	})
}
