package handler

import (
	"net/http"

	"sec-chat/permission-service/internal/service"

	"github.com/gin-gonic/gin"
)

type PermissionHandler struct {
	service *service.PermissionService
}

func NewPermissionHandler(svc *service.PermissionService) *PermissionHandler {
	return &PermissionHandler{
		service: svc,
	}
}

// CheckPermissionRequest 权限检查请求
type CheckPermissionRequest struct {
	UserID     string `json:"user_id" binding:"required"`
	RoomID     string `json:"room_id" binding:"required"`
	Permission string `json:"permission" binding:"required"`
}

// CheckPermissionResponse 权限检查响应
type CheckPermissionResponse struct {
	Allowed bool   `json:"allowed"`
	Role    string `json:"role,omitempty"`
}

// SetRoleRequest 设置角色请求
type SetRoleRequest struct {
	TargetUserID string `json:"target_user_id" binding:"required"`
	RoomID       string `json:"room_id" binding:"required"`
	Role         string `json:"role" binding:"required"`
}

// AddMemberRequest 添加成员请求
type AddMemberRequest struct {
	UserID string `json:"user_id" binding:"required"`
	RoomID string `json:"room_id" binding:"required"`
}

// CheckPermission 检查权限
// POST /api/v1/permissions/check
func (h *PermissionHandler) CheckPermission(c *gin.Context) {
	var req CheckPermissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	permission := service.RoomPermission(req.Permission)
	allowed, err := h.service.CheckRoomPermission(c.Request.Context(), req.UserID, req.RoomID, permission)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	role, _ := h.service.GetUserRoomRole(c.Request.Context(), req.UserID, req.RoomID)

	c.JSON(http.StatusOK, CheckPermissionResponse{
		Allowed: allowed,
		Role:    string(role),
	})
}

// GetUserPermissions 获取用户在群组中的所有权限
// GET /api/v1/permissions/:room_id
func (h *PermissionHandler) GetUserPermissions(c *gin.Context) {
	roomID := c.Param("room_id")
	userID := c.GetString("user_id") // 从认证中间件获取

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	perms, err := h.service.GetUserPermissions(c.Request.Context(), userID, roomID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	role, _ := h.service.GetUserRoomRole(c.Request.Context(), userID, roomID)

	permStrings := make([]string, len(perms))
	for i, p := range perms {
		permStrings[i] = string(p)
	}

	c.JSON(http.StatusOK, gin.H{
		"role":        string(role),
		"permissions": permStrings,
	})
}

// SetMemberRole 设置成员角色
// PUT /api/v1/permissions/role
func (h *PermissionHandler) SetMemberRole(c *gin.Context) {
	operatorID := c.GetString("user_id")
	if operatorID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req SetRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	role := service.RoomRole(req.Role)
	err := h.service.SetUserRoomRole(c.Request.Context(), operatorID, req.TargetUserID, req.RoomID, role)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "role updated successfully"})
}

// GetRoomMembers 获取群组成员列表
// GET /api/v1/rooms/:room_id/members
func (h *PermissionHandler) GetRoomMembers(c *gin.Context) {
	roomID := c.Param("room_id")
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	members, err := h.service.GetRoomMembers(c.Request.Context(), userID, roomID)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"members": members})
}

// AddMember 添加群组成员
// POST /api/v1/rooms/:room_id/members
func (h *PermissionHandler) AddMember(c *gin.Context) {
	roomID := c.Param("room_id")
	operatorID := c.GetString("user_id")

	if operatorID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req AddMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.AddRoomMember(c.Request.Context(), operatorID, req.UserID, roomID)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "member added successfully"})
}

// RemoveMember 移除群组成员
// DELETE /api/v1/rooms/:room_id/members/:user_id
func (h *PermissionHandler) RemoveMember(c *gin.Context) {
	roomID := c.Param("room_id")
	targetUserID := c.Param("user_id")
	operatorID := c.GetString("user_id")

	if operatorID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	err := h.service.RemoveRoomMember(c.Request.Context(), operatorID, targetUserID, roomID)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "member removed successfully"})
}

// RegisterRoutes 注册路由
func (h *PermissionHandler) RegisterRoutes(r *gin.RouterGroup) {
	r.POST("/permissions/check", h.CheckPermission)
	r.GET("/permissions/:room_id", h.GetUserPermissions)
	r.PUT("/permissions/role", h.SetMemberRole)
	r.GET("/rooms/:room_id/members", h.GetRoomMembers)
	r.POST("/rooms/:room_id/members", h.AddMember)
	r.DELETE("/rooms/:room_id/members/:user_id", h.RemoveMember)
}
