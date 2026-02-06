package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"sec-chat/auth-service/internal/service"
)

// E2EEHandler 端到端加密处理器
type E2EEHandler struct {
	service service.E2EEService
}

// NewE2EEHandler 创建E2EE处理器实例
func NewE2EEHandler(service service.E2EEService) *E2EEHandler {
	return &E2EEHandler{service: service}
}

// RegisterKeysRequest 注册密钥请求
type RegisterKeysRequest struct {
	DeviceID       string                      `json:"device_id" binding:"required"`
	IdentityKey    *service.PreKeyUpload       `json:"identity_key" binding:"required"`
	SignedPreKey   *service.SignedPreKeyUpload `json:"signed_pre_key" binding:"required"`
	OneTimePreKeys []*service.PreKeyUpload     `json:"one_time_pre_keys,omitempty"`
}

// RegisterKeys 注册设备密钥
// POST /api/v1/e2ee/keys
func (h *E2EEHandler) RegisterKeys(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req RegisterKeysRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	keyBundle := &service.DeviceKeyBundle{
		IdentityKey:    req.IdentityKey,
		SignedPreKey:   req.SignedPreKey,
		OneTimePreKeys: req.OneTimePreKeys,
	}

	if err := h.service.RegisterDeviceKeys(c.Request.Context(), userID.(string), req.DeviceID, keyBundle); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "keys registered successfully"})
}

// GetKeyBundle 获取用户密钥包
// GET /api/v1/e2ee/keys/:userId
func (h *E2EEHandler) GetKeyBundle(c *gin.Context) {
	targetUserID := c.Param("userId")

	bundle, err := h.service.GetKeyBundle(c.Request.Context(), targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if bundle == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no keys found for user"})
		return
	}

	// 不返回敏感信息，只返回公钥
	response := gin.H{
		"user_id":   bundle.UserID,
		"device_id": bundle.DeviceID,
	}

	if bundle.IdentityKey != nil {
		response["identity_key"] = gin.H{
			"key_id":     bundle.IdentityKey.KeyID,
			"public_key": bundle.IdentityKey.PublicKey,
		}
	}

	if bundle.SignedPreKey != nil {
		response["signed_pre_key"] = gin.H{
			"key_id":     bundle.SignedPreKey.KeyID,
			"public_key": bundle.SignedPreKey.PublicKey,
			"signature":  bundle.SignedPreKey.Signature,
		}
	}

	if len(bundle.OneTimePreKeys) > 0 {
		// 只返回一个一次性密钥
		otk := bundle.OneTimePreKeys[0]
		response["one_time_pre_key"] = gin.H{
			"key_id":     otk.KeyID,
			"public_key": otk.PublicKey,
		}
	}

	c.JSON(http.StatusOK, response)
}

// GetDeviceKeyBundle 获取特定设备密钥包
// GET /api/v1/e2ee/keys/:userId/:deviceId
func (h *E2EEHandler) GetDeviceKeyBundle(c *gin.Context) {
	targetUserID := c.Param("userId")
	targetDeviceID := c.Param("deviceId")

	bundle, err := h.service.GetDeviceKeyBundle(c.Request.Context(), targetUserID, targetDeviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if bundle == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "no keys found for device"})
		return
	}

	response := gin.H{
		"user_id":   bundle.UserID,
		"device_id": bundle.DeviceID,
	}

	if bundle.IdentityKey != nil {
		response["identity_key"] = gin.H{
			"key_id":     bundle.IdentityKey.KeyID,
			"public_key": bundle.IdentityKey.PublicKey,
		}
	}

	if bundle.SignedPreKey != nil {
		response["signed_pre_key"] = gin.H{
			"key_id":     bundle.SignedPreKey.KeyID,
			"public_key": bundle.SignedPreKey.PublicKey,
			"signature":  bundle.SignedPreKey.Signature,
		}
	}

	if len(bundle.OneTimePreKeys) > 0 {
		otk := bundle.OneTimePreKeys[0]
		response["one_time_pre_key"] = gin.H{
			"key_id":     otk.KeyID,
			"public_key": otk.PublicKey,
		}
	}

	c.JSON(http.StatusOK, response)
}

// UploadOneTimeKeysRequest 上传一次性密钥请求
type UploadOneTimeKeysRequest struct {
	DeviceID string                  `json:"device_id" binding:"required"`
	Keys     []*service.PreKeyUpload `json:"keys" binding:"required,min=1"`
}

// UploadOneTimeKeys 上传一次性预密钥
// POST /api/v1/e2ee/keys/one-time
func (h *E2EEHandler) UploadOneTimeKeys(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req UploadOneTimeKeysRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.UploadOneTimePreKeys(c.Request.Context(), userID.(string), req.DeviceID, req.Keys); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "one-time keys uploaded", "count": len(req.Keys)})
}

// GetOneTimeKeysCount 获取一次性密钥数量
// GET /api/v1/e2ee/keys/one-time/count
func (h *E2EEHandler) GetOneTimeKeysCount(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID := c.Query("device_id")
	if deviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id required"})
		return
	}

	count, err := h.service.GetOneTimePreKeysCount(c.Request.Context(), userID.(string), deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": count})
}

// InitiateSession 发起加密会话
// POST /api/v1/e2ee/sessions
func (h *E2EEHandler) InitiateSession(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID, _ := c.Get("device_id")

	var req service.KeyExchangeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	response, err := h.service.InitiateSession(c.Request.Context(), userID.(string), deviceID.(string), &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// GetPendingExchanges 获取待处理的密钥交换
// GET /api/v1/e2ee/sessions/pending
func (h *E2EEHandler) GetPendingExchanges(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID, _ := c.Get("device_id")

	exchanges, err := h.service.GetPendingKeyExchanges(c.Request.Context(), userID.(string), deviceID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"exchanges": exchanges})
}

// AcceptSessionRequest 接受会话请求
type AcceptSessionRequest struct {
	ExchangeID uint `json:"exchange_id" binding:"required"`
}

// AcceptSession 接受加密会话
// POST /api/v1/e2ee/sessions/accept
func (h *E2EEHandler) AcceptSession(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID, _ := c.Get("device_id")

	var req AcceptSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.service.AcceptSession(c.Request.Context(), userID.(string), deviceID.(string), req.ExchangeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, session)
}

// ListSessions 列出活跃会话
// GET /api/v1/e2ee/sessions
func (h *E2EEHandler) ListSessions(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	sessions, err := h.service.ListSessions(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"sessions": sessions})
}

// TerminateSession 终止会话
// DELETE /api/v1/e2ee/sessions/:sessionId
func (h *E2EEHandler) TerminateSession(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	sessionID := c.Param("sessionId")

	if err := h.service.TerminateSession(c.Request.Context(), userID.(string), sessionID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "session terminated"})
}

// RevokeDeviceKeys 撤销设备密钥
// DELETE /api/v1/e2ee/keys/:deviceId
func (h *E2EEHandler) RevokeDeviceKeys(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID := c.Param("deviceId")

	if err := h.service.RevokeDeviceKeys(c.Request.Context(), userID.(string), deviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "device keys revoked"})
}
