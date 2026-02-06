package handler

import (
	"net/http"
	"strconv"

	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

// ChatHandler 聊天处理器
type ChatHandler struct {
	chatService service.ChatService
	wsHub       *WSHub
}

// NewChatHandler 创建聊天处理器实例
func NewChatHandler(chatService service.ChatService, wsHub *WSHub) *ChatHandler {
	return &ChatHandler{
		chatService: chatService,
		wsHub:       wsHub,
	}
}

// ====== Room Handlers ======

// ListRooms 获取用户房间列表
func (h *ChatHandler) ListRooms(c *gin.Context) {
	userID := c.GetString("user_id")

	rooms, err := h.chatService.GetUserRooms(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"rooms": rooms})
}

// CreateRoom 创建房间
func (h *ChatHandler) CreateRoom(c *gin.Context) {
	userID := c.GetString("user_id")

	var req service.CreateRoomRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	room, err := h.chatService.CreateRoom(c.Request.Context(), userID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, room)
}

// GetRoom 获取房间详情
func (h *ChatHandler) GetRoom(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	room, err := h.chatService.GetRoom(c.Request.Context(), userID, roomID)
	if err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrRoomNotFound {
			status = http.StatusNotFound
		} else if err == service.ErrNotRoomMember {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, room)
}

// UpdateRoom 更新房间
func (h *ChatHandler) UpdateRoom(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	var req struct {
		Name           string `json:"name"`
		Description    string `json:"description"`
		RetentionHours *int   `json:"retention_hours"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	room, err := h.chatService.UpdateRoom(c.Request.Context(), userID, roomID, req.Name, req.Description, req.RetentionHours)
	if err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNoPermission {
			status = http.StatusForbidden
		} else if err == service.ErrRoomNotFound {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, room)
}

// LeaveRoom 离开房间
func (h *ChatHandler) LeaveRoom(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	if err := h.chatService.LeaveRoom(c.Request.Context(), userID, roomID); err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrCannotLeaveOwner {
			status = http.StatusBadRequest
		} else if err == service.ErrNotRoomMember {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "left room successfully"})
}

// MuteRoom 静音房间
func (h *ChatHandler) MuteRoom(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	var req struct {
		Muted bool `json:"muted"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.chatService.MuteRoom(c.Request.Context(), userID, roomID, req.Muted); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"muted": req.Muted})
}

// PinRoom 置顶房间
func (h *ChatHandler) PinRoom(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	var req struct {
		Pinned bool `json:"pinned"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.chatService.PinRoom(c.Request.Context(), userID, roomID, req.Pinned); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"pinned": req.Pinned})
}

// ====== Member Handlers ======

// ListMembers 获取房间成员
func (h *ChatHandler) ListMembers(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	members, err := h.chatService.GetRoomMembers(c.Request.Context(), userID, roomID)
	if err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNotRoomMember {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"members": members})
}

// AddMembers 添加成员
func (h *ChatHandler) AddMembers(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	var req struct {
		UserIDs []string `json:"user_ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	if err := h.chatService.AddMembers(c.Request.Context(), userID, roomID, req.UserIDs); err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNoPermission {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "members added successfully"})
}

// RemoveMember 移除成员
func (h *ChatHandler) RemoveMember(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")
	targetUserID := c.Param("userId")

	if err := h.chatService.RemoveMember(c.Request.Context(), userID, roomID, targetUserID); err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNoPermission {
			status = http.StatusForbidden
		} else if err == service.ErrNotRoomMember {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	// 通过 WebSocket 广播成员移除事件
	if h.wsHub != nil {
		// 通知房间内所有成员
		h.wsHub.BroadcastToRoom(roomID, WSMessage{
			Type: "member_removed",
			Payload: gin.H{
				"room_id": roomID,
				"user_id": targetUserID,
			},
		})

		// 通知被移除的用户
		h.wsHub.BroadcastToUser(targetUserID, WSMessage{
			Type: "kicked_from_room",
			Payload: gin.H{
				"room_id": roomID,
			},
		})
	}

	c.JSON(http.StatusOK, gin.H{"message": "member removed successfully"})
}

// UpdateMemberRole 更新成员角色
func (h *ChatHandler) UpdateMemberRole(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")
	targetUserID := c.Param("userId")

	var req struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	role := repository.MemberRole(req.Role)
	if err := h.chatService.UpdateMemberRole(c.Request.Context(), userID, roomID, targetUserID, role); err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNoPermission {
			status = http.StatusForbidden
		} else if err == service.ErrNotRoomMember {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"role": req.Role})
}

// ====== Message Handlers ======

// ListMessages 获取消息列表
func (h *ChatHandler) ListMessages(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	limit := 50
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	beforeID := c.Query("before_id")

	messages, err := h.chatService.GetMessages(c.Request.Context(), userID, roomID, limit, beforeID)
	if err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNotRoomMember {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"messages": messages})
}

// SendMessage 发送消息
func (h *ChatHandler) SendMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	var req service.SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	message, err := h.chatService.SendMessage(c.Request.Context(), userID, roomID, &req)
	if err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNotRoomMember {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	// 通过 WebSocket 广播消息给房间内所有成员
	if h.wsHub != nil {
		h.wsHub.BroadcastToRoom(roomID, WSMessage{
			Type:    "new_message",
			Payload: message,
		})
	}

	c.JSON(http.StatusCreated, message)
}

// DeleteMessage 删除消息
func (h *ChatHandler) DeleteMessage(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")
	messageID := c.Param("messageId")

	if err := h.chatService.DeleteMessage(c.Request.Context(), userID, roomID, messageID); err != nil {
		status := http.StatusInternalServerError
		if err == service.ErrNoPermission {
			status = http.StatusForbidden
		} else if err == service.ErrMessageNotFound {
			status = http.StatusNotFound
		}
		c.JSON(status, gin.H{"error": err.Error()})
		return
	}

	// 通过 WebSocket 广播删除事件
	if h.wsHub != nil {
		h.wsHub.BroadcastToRoom(roomID, WSMessage{
			Type: "message_deleted",
			Payload: gin.H{
				"room_id":    roomID,
				"message_id": messageID,
			},
		})
	}

	c.JSON(http.StatusOK, gin.H{"message": "message deleted successfully"})
}

// MarkAsRead 标记已读
func (h *ChatHandler) MarkAsRead(c *gin.Context) {
	userID := c.GetString("user_id")
	roomID := c.Param("roomId")

	if err := h.chatService.MarkAsRead(c.Request.Context(), userID, roomID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "marked as read"})
}

// ====== User Search ======

// SearchUsers 搜索用户
func (h *ChatHandler) SearchUsers(c *gin.Context) {
	query := c.Query("search")
	if query == "" {
		c.JSON(http.StatusOK, gin.H{"users": []interface{}{}})
		return
	}

	limit := 20
	if l := c.Query("limit"); l != "" {
		if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 50 {
			limit = parsed
		}
	}

	users, err := h.chatService.SearchUsers(c.Request.Context(), query, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}
