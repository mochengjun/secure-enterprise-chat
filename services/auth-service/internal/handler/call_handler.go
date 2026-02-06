package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"
)

// CallHandler 通话处理器
type CallHandler struct {
	callService  service.CallService
	signalingHub *SignalingHub
}

// NewCallHandler 创建通话处理器实例
func NewCallHandler(callService service.CallService, signalingHub *SignalingHub) *CallHandler {
	return &CallHandler{
		callService:  callService,
		signalingHub: signalingHub,
	}
}

// InitiateCallRequest 发起通话请求
type InitiateCallRequest struct {
	TargetUserIDs []string            `json:"target_user_ids" binding:"required,min=1"`
	CallType      repository.CallType `json:"call_type" binding:"required,oneof=voice video"`
	RoomID        string              `json:"room_id,omitempty"`
}

// InitiateCall 发起通话
// POST /api/v1/calls
func (h *CallHandler) InitiateCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req InitiateCallRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	call, err := h.callService.InitiateCall(
		c.Request.Context(),
		userID.(string),
		req.TargetUserIDs,
		req.CallType,
		req.RoomID,
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通过信令通知被邀请者
	for _, targetID := range req.TargetUserIDs {
		h.signalingHub.SendToUser(targetID, &repository.SignalingMessage{
			Type:     "call-invite",
			CallID:   call.ID,
			FromUser: userID.(string),
			Payload: repository.CallInvitePayload{
				CallType: req.CallType,
				RoomID:   req.RoomID,
			},
		})
	}

	c.JSON(http.StatusOK, call)
}

// GetCall 获取通话信息
// GET /api/v1/calls/:callId
func (h *CallHandler) GetCall(c *gin.Context) {
	callID := c.Param("callId")

	call, err := h.callService.GetCall(c.Request.Context(), callID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if call == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "call not found"})
		return
	}

	c.JSON(http.StatusOK, call)
}

// GetActiveCall 获取当前活跃通话
// GET /api/v1/calls/active
func (h *CallHandler) GetActiveCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	call, err := h.callService.GetActiveCall(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if call == nil {
		c.JSON(http.StatusOK, gin.H{"call": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{"call": call})
}

// AcceptCall 接受通话
// POST /api/v1/calls/:callId/accept
func (h *CallHandler) AcceptCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	if err := h.callService.AcceptCall(c.Request.Context(), callID, userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "call-accept",
		CallID:   callID,
		FromUser: userID.(string),
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "call accepted"})
}

// RejectCall 拒绝通话
// POST /api/v1/calls/:callId/reject
func (h *CallHandler) RejectCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	if err := h.callService.RejectCall(c.Request.Context(), callID, userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "call-reject",
		CallID:   callID,
		FromUser: userID.(string),
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "call rejected"})
}

// EndCall 结束通话
// POST /api/v1/calls/:callId/end
func (h *CallHandler) EndCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	var req struct {
		Reason string `json:"reason,omitempty"`
	}
	c.ShouldBindJSON(&req)

	if err := h.callService.EndCall(c.Request.Context(), callID, userID.(string), req.Reason); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知所有参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "call-end",
		CallID:   callID,
		FromUser: userID.(string),
	}, "")

	c.JSON(http.StatusOK, gin.H{"message": "call ended"})
}

// JoinCall 加入通话
// POST /api/v1/calls/:callId/join
func (h *CallHandler) JoinCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	if err := h.callService.JoinCall(c.Request.Context(), callID, userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "participant-joined",
		CallID:   callID,
		FromUser: userID.(string),
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "joined call"})
}

// LeaveCall 离开通话
// POST /api/v1/calls/:callId/leave
func (h *CallHandler) LeaveCall(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	if err := h.callService.LeaveCall(c.Request.Context(), callID, userID.(string)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "participant-left",
		CallID:   callID,
		FromUser: userID.(string),
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "left call"})
}

// ToggleMuteRequest 静音切换请求
type ToggleMuteRequest struct {
	Muted bool `json:"muted"`
}

// ToggleMute 切换静音
// POST /api/v1/calls/:callId/mute
func (h *CallHandler) ToggleMute(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	var req ToggleMuteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.callService.ToggleMute(c.Request.Context(), callID, userID.(string), req.Muted); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "mute-toggle",
		CallID:   callID,
		FromUser: userID.(string),
		Payload:  map[string]bool{"muted": req.Muted},
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "mute toggled", "muted": req.Muted})
}

// ToggleVideoRequest 视频切换请求
type ToggleVideoRequest struct {
	VideoOn bool `json:"video_on"`
}

// ToggleVideo 切换视频
// POST /api/v1/calls/:callId/video
func (h *CallHandler) ToggleVideo(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	callID := c.Param("callId")

	var req ToggleVideoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.callService.ToggleVideo(c.Request.Context(), callID, userID.(string), req.VideoOn); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 通知其他参与者
	h.signalingHub.SendToParticipants(callID, &repository.SignalingMessage{
		Type:     "video-toggle",
		CallID:   callID,
		FromUser: userID.(string),
		Payload:  map[string]bool{"video_on": req.VideoOn},
	}, userID.(string))

	c.JSON(http.StatusOK, gin.H{"message": "video toggled", "video_on": req.VideoOn})
}

// ListCallHistory 获取通话历史
// GET /api/v1/calls/history
func (h *CallHandler) ListCallHistory(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if limit > 100 {
		limit = 100
	}

	calls, total, err := h.callService.ListCallHistory(c.Request.Context(), userID.(string), offset, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"calls":  calls,
		"total":  total,
		"offset": offset,
		"limit":  limit,
	})
}

// GetICEServers 获取ICE服务器配置
// GET /api/v1/calls/ice-servers
func (h *CallHandler) GetICEServers(c *gin.Context) {
	servers := h.callService.GetICEServers(c.Request.Context())
	c.JSON(http.StatusOK, gin.H{"ice_servers": servers})
}
