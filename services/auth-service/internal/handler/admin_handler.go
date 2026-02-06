package handler

import (
	"net/http"
	"strconv"
	"time"

	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

// AdminHandler 管理后台处理器
type AdminHandler struct {
	adminService service.AdminService
}

// NewAdminHandler 创建管理后台处理器实例
func NewAdminHandler(adminService service.AdminService) *AdminHandler {
	return &AdminHandler{
		adminService: adminService,
	}
}

// getClientInfo 获取客户端信息
func (h *AdminHandler) getClientInfo(c *gin.Context) (string, string) {
	ipAddress := c.ClientIP()
	userAgent := c.GetHeader("User-Agent")
	return ipAddress, userAgent
}

// ====== 用户管理 ======

// GetUsers 获取用户列表
func (h *AdminHandler) GetUsers(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	search := c.Query("search")
	activeOnly := c.Query("active_only") == "true"

	result, err := h.adminService.GetUsers(c.Request.Context(), adminUserID.(string), page, pageSize, search, activeOnly)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetUser 获取单个用户详情
func (h *AdminHandler) GetUser(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	user, err := h.adminService.GetUser(c.Request.Context(), adminUserID.(string), targetUserID)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, user)
}

// UpdateUserStatus 更新用户状态（启用/禁用）
func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	var req service.UpdateUserStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.UpdateUserStatus(c.Request.Context(), adminUserID.(string), targetUserID, req.IsActive, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	status := "disabled"
	if req.IsActive {
		status = "enabled"
	}
	c.JSON(http.StatusOK, gin.H{"message": "user " + status + " successfully"})
}

// ResetUserPassword 重置用户密码
func (h *AdminHandler) ResetUserPassword(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	var req service.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.ResetUserPassword(c.Request.Context(), adminUserID.(string), targetUserID, req.NewPassword, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "password reset successfully"})
}

// DeleteUser 删除用户
func (h *AdminHandler) DeleteUser(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.DeleteUser(c.Request.Context(), adminUserID.(string), targetUserID, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "user deleted successfully"})
}

// ====== 管理员管理 ======

// GetAdminUsers 获取管理员列表
func (h *AdminHandler) GetAdminUsers(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	admins, err := h.adminService.GetAdminUsers(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"admins": admins})
}

// CreateAdminUser 创建管理员
func (h *AdminHandler) CreateAdminUser(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req service.CreateAdminRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.CreateAdminUser(c.Request.Context(), adminUserID.(string), &req, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "admin user created successfully"})
}

// UpdateAdminRole 更新管理员角色
func (h *AdminHandler) UpdateAdminRole(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	var req service.UpdateAdminRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.UpdateAdminRole(c.Request.Context(), adminUserID.(string), targetUserID, req.Role, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "admin role updated successfully"})
}

// DeleteAdminUser 删除管理员
func (h *AdminHandler) DeleteAdminUser(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	targetUserID := c.Param("userId")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.DeleteAdminUser(c.Request.Context(), adminUserID.(string), targetUserID, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "admin user removed successfully"})
}

// ====== 房间管理 ======

// GetRooms 获取房间列表
func (h *AdminHandler) GetRooms(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	search := c.Query("search")
	roomType := c.Query("type")

	result, err := h.adminService.GetRooms(c.Request.Context(), adminUserID.(string), page, pageSize, search, roomType)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, result)
}

// GetRoom 获取房间详情
func (h *AdminHandler) GetRoom(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	roomID := c.Param("roomId")
	if roomID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "room_id is required"})
		return
	}

	room, err := h.adminService.GetRoom(c.Request.Context(), adminUserID.(string), roomID)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, room)
}

// GetRoomMembers 获取房间成员
func (h *AdminHandler) GetRoomMembers(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	roomID := c.Param("roomId")
	if roomID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "room_id is required"})
		return
	}

	members, err := h.adminService.GetRoomMembers(c.Request.Context(), adminUserID.(string), roomID)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"members": members})
}

// DeleteRoom 删除房间
func (h *AdminHandler) DeleteRoom(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	roomID := c.Param("roomId")
	if roomID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "room_id is required"})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.DeleteRoom(c.Request.Context(), adminUserID.(string), roomID, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "room deleted successfully"})
}

// ====== 审计日志 ======

// GetAuditLogs 获取审计日志
func (h *AdminHandler) GetAuditLogs(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	action := c.Query("action")
	actorID := c.Query("actor_id")

	var startTime, endTime *time.Time
	if start := c.Query("start_time"); start != "" {
		if t, err := time.Parse(time.RFC3339, start); err == nil {
			startTime = &t
		}
	}
	if end := c.Query("end_time"); end != "" {
		if t, err := time.Parse(time.RFC3339, end); err == nil {
			endTime = &t
		}
	}

	result, err := h.adminService.GetAuditLogs(c.Request.Context(), adminUserID.(string), page, pageSize, action, actorID, startTime, endTime)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, result)
}

// ====== 系统设置 ======

// GetSettings 获取所有系统设置
func (h *AdminHandler) GetSettings(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	settings, err := h.adminService.GetSettings(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"settings": settings})
}

// GetSetting 获取单个系统设置
func (h *AdminHandler) GetSetting(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	key := c.Param("key")
	if key == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "key is required"})
		return
	}

	setting, err := h.adminService.GetSetting(c.Request.Context(), adminUserID.(string), key)
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, setting)
}

// UpdateSetting 更新系统设置
func (h *AdminHandler) UpdateSetting(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	key := c.Param("key")
	if key == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "key is required"})
		return
	}

	var req service.UpdateSettingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ipAddress, userAgent := h.getClientInfo(c)
	if err := h.adminService.UpdateSetting(c.Request.Context(), adminUserID.(string), key, &req, ipAddress, userAgent); err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "setting updated successfully"})
}

// ====== 统计 ======

// GetStats 获取系统统计概览
func (h *AdminHandler) GetStats(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	stats, err := h.adminService.GetStats(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetUserStats 获取用户统计
func (h *AdminHandler) GetUserStats(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	stats, err := h.adminService.GetUserStats(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetRoomStats 获取房间统计
func (h *AdminHandler) GetRoomStats(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	stats, err := h.adminService.GetRoomStats(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, stats)
}

// GetMessageStats 获取消息统计
func (h *AdminHandler) GetMessageStats(c *gin.Context) {
	adminUserID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	stats, err := h.adminService.GetMessageStats(c.Request.Context(), adminUserID.(string))
	if err != nil {
		h.handleError(c, err)
		return
	}

	c.JSON(http.StatusOK, stats)
}

// CheckAdminStatus 检查当前用户是否是管理员
func (h *AdminHandler) CheckAdminStatus(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	isAdmin, role, err := h.adminService.IsAdmin(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to check admin status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"is_admin": isAdmin,
		"role":     role,
	})
}

// handleError 统一错误处理
func (h *AdminHandler) handleError(c *gin.Context, err error) {
	switch err {
	case service.ErrNotAdmin:
		c.JSON(http.StatusForbidden, gin.H{"error": "admin access required"})
	case service.ErrInsufficientPerms:
		c.JSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
	case service.ErrCannotDeleteSelf:
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot delete yourself"})
	case service.ErrLastSuperAdmin:
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot remove the last super admin"})
	case service.ErrSettingNotFound:
		c.JSON(http.StatusNotFound, gin.H{"error": "setting not found"})
	default:
		if err.Error() == "user not found: record not found" ||
			err.Error() == "room not found: record not found" ||
			err.Error() == "admin user not found: record not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "resource not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
	}
}
