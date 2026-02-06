package service

import (
	"context"
	"errors"
	"time"

	"sec-chat/auth-service/internal/repository"

	"github.com/google/uuid"
)

var (
	ErrRoomNotFound     = errors.New("room not found")
	ErrNotRoomMember    = errors.New("not a member of this room")
	ErrNoPermission     = errors.New("no permission for this action")
	ErrMessageNotFound  = errors.New("message not found")
	ErrCannotLeaveOwner = errors.New("owner cannot leave room")
	ErrAlreadyMember    = errors.New("already a member")
)

// RoomResponse 房间响应
type RoomResponse struct {
	ID             string              `json:"id"`
	Name           string              `json:"name"`
	Description    string              `json:"description,omitempty"`
	AvatarURL      string              `json:"avatar_url,omitempty"`
	Type           repository.RoomType `json:"type"`
	CreatorID      string              `json:"creator_id"`
	RetentionHours *int                `json:"retention_hours,omitempty"`
	UnreadCount    int64               `json:"unread_count"`
	LastMessage    *MessageResponse    `json:"last_message,omitempty"`
	Members        []*MemberResponse   `json:"members,omitempty"`
	IsMuted        bool                `json:"is_muted"`
	IsPinned       bool                `json:"is_pinned"`
	CreatedAt      time.Time           `json:"created_at"`
	UpdatedAt      time.Time           `json:"updated_at"`
}

// MemberResponse 成员响应
type MemberResponse struct {
	UserID      string                `json:"user_id"`
	DisplayName string                `json:"display_name"`
	AvatarURL   string                `json:"avatar_url,omitempty"`
	Role        repository.MemberRole `json:"role"`
	JoinedAt    time.Time             `json:"joined_at"`
	IsOnline    bool                  `json:"is_online"`
}

// MessageResponse 消息响应
type MessageResponse struct {
	ID           string                   `json:"id"`
	RoomID       string                   `json:"room_id"`
	SenderID     string                   `json:"sender_id"`
	SenderName   string                   `json:"sender_name"`
	SenderAvatar string                   `json:"sender_avatar,omitempty"`
	Content      string                   `json:"content"`
	Type         repository.MessageType   `json:"type"`
	Status       repository.MessageStatus `json:"status"`
	MediaURL     string                   `json:"media_url,omitempty"`
	ThumbnailURL string                   `json:"thumbnail_url,omitempty"`
	MediaSize    *int64                   `json:"media_size,omitempty"`
	MimeType     string                   `json:"mime_type,omitempty"`
	ReplyToID    string                   `json:"reply_to_id,omitempty"`
	IsDeleted    bool                     `json:"is_deleted"`
	CreatedAt    time.Time                `json:"created_at"`
	EditedAt     *time.Time               `json:"edited_at,omitempty"`
}

// CreateRoomRequest 创建房间请求
type CreateRoomRequest struct {
	Name           string              `json:"name" binding:"required"`
	Description    string              `json:"description"`
	Type           repository.RoomType `json:"type"`
	MemberIDs      []string            `json:"member_ids"`
	RetentionHours *int                `json:"retention_hours"`
}

// SendMessageRequest 发送消息请求
type SendMessageRequest struct {
	Content   string                 `json:"content" binding:"required"`
	Type      repository.MessageType `json:"type"`
	ReplyToID string                 `json:"reply_to_id"`
}

// UserSearchResult 用户搜索结果
type UserSearchResult struct {
	UserID      string `json:"user_id"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	Email       string `json:"email,omitempty"`
	IsActive    bool   `json:"is_active"`
}

// ChatService 聊天服务接口
type ChatService interface {
	// Room
	CreateRoom(ctx context.Context, userID string, req *CreateRoomRequest) (*RoomResponse, error)
	GetRoom(ctx context.Context, userID, roomID string) (*RoomResponse, error)
	GetUserRooms(ctx context.Context, userID string) ([]*RoomResponse, error)
	UpdateRoom(ctx context.Context, userID, roomID string, name, description string, retentionHours *int) (*RoomResponse, error)
	LeaveRoom(ctx context.Context, userID, roomID string) error
	MuteRoom(ctx context.Context, userID, roomID string, muted bool) error
	PinRoom(ctx context.Context, userID, roomID string, pinned bool) error

	// Member
	AddMembers(ctx context.Context, userID, roomID string, memberIDs []string) error
	RemoveMember(ctx context.Context, userID, roomID, targetUserID string) error
	UpdateMemberRole(ctx context.Context, userID, roomID, targetUserID string, role repository.MemberRole) error
	GetRoomMembers(ctx context.Context, userID, roomID string) ([]*MemberResponse, error)

	// User
	SearchUsers(ctx context.Context, query string, limit int) ([]*UserSearchResult, error)

	// Message
	SendMessage(ctx context.Context, userID, roomID string, req *SendMessageRequest) (*MessageResponse, error)
	GetMessages(ctx context.Context, userID, roomID string, limit int, beforeID string) ([]*MessageResponse, error)
	DeleteMessage(ctx context.Context, userID, roomID, messageID string) error
	MarkAsRead(ctx context.Context, userID, roomID string) error
}

// chatService 聊天服务实现
type chatService struct {
	chatRepo repository.ChatRepository
	userRepo repository.UserRepository
}

// NewChatService 创建聊天服务实例
func NewChatService(chatRepo repository.ChatRepository, userRepo repository.UserRepository) ChatService {
	return &chatService{
		chatRepo: chatRepo,
		userRepo: userRepo,
	}
}

// === Room 相关 ===

func (s *chatService) CreateRoom(ctx context.Context, userID string, req *CreateRoomRequest) (*RoomResponse, error) {
	roomID := uuid.New().String()
	now := time.Now()

	roomType := req.Type
	if roomType == "" {
		roomType = repository.RoomTypeGroup
	}

	room := &repository.Room{
		ID:             roomID,
		Name:           req.Name,
		Description:    req.Description,
		Type:           roomType,
		CreatorID:      userID,
		RetentionHours: req.RetentionHours,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	if err := s.chatRepo.CreateRoom(room); err != nil {
		return nil, err
	}

	// 添加创建者为 Owner
	ownerMember := &repository.RoomMember{
		ID:        uuid.New().String(),
		RoomID:    roomID,
		UserID:    userID,
		Role:      repository.MemberRoleOwner,
		JoinedAt:  now,
		UpdatedAt: now,
	}
	if err := s.chatRepo.AddMember(ownerMember); err != nil {
		return nil, err
	}

	// 添加其他成员
	for _, memberID := range req.MemberIDs {
		if memberID == userID {
			continue
		}
		member := &repository.RoomMember{
			ID:        uuid.New().String(),
			RoomID:    roomID,
			UserID:    memberID,
			Role:      repository.MemberRoleMember,
			JoinedAt:  now,
			UpdatedAt: now,
		}
		s.chatRepo.AddMember(member)
	}

	return s.buildRoomResponse(room, userID)
}

func (s *chatService) GetRoom(ctx context.Context, userID, roomID string) (*RoomResponse, error) {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil {
		return nil, err
	}
	if !isMember {
		return nil, ErrNotRoomMember
	}

	room, err := s.chatRepo.GetRoom(roomID)
	if err != nil {
		return nil, ErrRoomNotFound
	}

	return s.buildRoomResponse(room, userID)
}

func (s *chatService) GetUserRooms(ctx context.Context, userID string) ([]*RoomResponse, error) {
	rooms, err := s.chatRepo.GetUserRooms(userID)
	if err != nil {
		return nil, err
	}

	responses := make([]*RoomResponse, 0, len(rooms))
	for _, room := range rooms {
		resp, err := s.buildRoomResponse(room, userID)
		if err == nil {
			responses = append(responses, resp)
		}
	}
	return responses, nil
}

func (s *chatService) UpdateRoom(ctx context.Context, userID, roomID string, name, description string, retentionHours *int) (*RoomResponse, error) {
	if err := s.checkPermission(roomID, userID, repository.MemberRoleAdmin); err != nil {
		return nil, err
	}

	room, err := s.chatRepo.GetRoom(roomID)
	if err != nil {
		return nil, ErrRoomNotFound
	}

	if name != "" {
		room.Name = name
	}
	if description != "" {
		room.Description = description
	}
	if retentionHours != nil {
		room.RetentionHours = retentionHours
	}
	room.UpdatedAt = time.Now()

	if err := s.chatRepo.UpdateRoom(room); err != nil {
		return nil, err
	}

	return s.buildRoomResponse(room, userID)
}

func (s *chatService) LeaveRoom(ctx context.Context, userID, roomID string) error {
	member, err := s.chatRepo.GetMember(roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	if member.Role == repository.MemberRoleOwner {
		return ErrCannotLeaveOwner
	}

	return s.chatRepo.RemoveMember(roomID, userID)
}

func (s *chatService) MuteRoom(ctx context.Context, userID, roomID string, muted bool) error {
	member, err := s.chatRepo.GetMember(roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	member.IsMuted = muted
	member.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(member)
}

func (s *chatService) PinRoom(ctx context.Context, userID, roomID string, pinned bool) error {
	member, err := s.chatRepo.GetMember(roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	member.IsPinned = pinned
	member.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(member)
}

// === Member 相关 ===

func (s *chatService) AddMembers(ctx context.Context, userID, roomID string, memberIDs []string) error {
	if err := s.checkPermission(roomID, userID, repository.MemberRoleAdmin); err != nil {
		return err
	}

	now := time.Now()
	for _, memberID := range memberIDs {
		exists, _ := s.chatRepo.IsMember(roomID, memberID)
		if exists {
			continue
		}

		member := &repository.RoomMember{
			ID:        uuid.New().String(),
			RoomID:    roomID,
			UserID:    memberID,
			Role:      repository.MemberRoleMember,
			JoinedAt:  now,
			UpdatedAt: now,
		}
		s.chatRepo.AddMember(member)
	}
	return nil
}

func (s *chatService) RemoveMember(ctx context.Context, userID, roomID, targetUserID string) error {
	if err := s.checkPermission(roomID, userID, repository.MemberRoleModerator); err != nil {
		return err
	}

	targetMember, err := s.chatRepo.GetMember(roomID, targetUserID)
	if err != nil {
		return ErrNotRoomMember
	}

	// 不能移除 Owner
	if targetMember.Role == repository.MemberRoleOwner {
		return ErrNoPermission
	}

	// 检查是否有权限移除目标成员
	actorMember, _ := s.chatRepo.GetMember(roomID, userID)
	if !canManageRole(actorMember.Role, targetMember.Role) {
		return ErrNoPermission
	}

	return s.chatRepo.RemoveMember(roomID, targetUserID)
}

func (s *chatService) UpdateMemberRole(ctx context.Context, userID, roomID, targetUserID string, role repository.MemberRole) error {
	if err := s.checkPermission(roomID, userID, repository.MemberRoleAdmin); err != nil {
		return err
	}

	actorMember, _ := s.chatRepo.GetMember(roomID, userID)
	targetMember, err := s.chatRepo.GetMember(roomID, targetUserID)
	if err != nil {
		return ErrNotRoomMember
	}

	// 不能修改 Owner 角色
	if targetMember.Role == repository.MemberRoleOwner || role == repository.MemberRoleOwner {
		return ErrNoPermission
	}

	// 检查是否有权限设置目标角色
	if !canSetRole(actorMember.Role, role) {
		return ErrNoPermission
	}

	targetMember.Role = role
	targetMember.UpdatedAt = time.Now()
	return s.chatRepo.UpdateMember(targetMember)
}

func (s *chatService) GetRoomMembers(ctx context.Context, userID, roomID string) ([]*MemberResponse, error) {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	members, err := s.chatRepo.GetRoomMembers(roomID)
	if err != nil {
		return nil, err
	}

	responses := make([]*MemberResponse, 0, len(members))
	for _, m := range members {
		displayName := ""
		avatarURL := ""
		if m.User != nil {
			if m.User.DisplayName != nil {
				displayName = *m.User.DisplayName
			} else {
				displayName = m.User.Username
			}
			if m.User.AvatarURL != nil {
				avatarURL = *m.User.AvatarURL
			}
		}

		responses = append(responses, &MemberResponse{
			UserID:      m.UserID,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Role:        m.Role,
			JoinedAt:    m.JoinedAt,
			IsOnline:    false, // TODO: 实现在线状态
		})
	}
	return responses, nil
}

// === Message 相关 ===

func (s *chatService) SendMessage(ctx context.Context, userID, roomID string, req *SendMessageRequest) (*MessageResponse, error) {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	msgType := req.Type
	if msgType == "" {
		msgType = repository.MessageTypeText
	}

	now := time.Now()
	message := &repository.Message{
		ID:        uuid.New().String(),
		RoomID:    roomID,
		SenderID:  userID,
		Content:   req.Content,
		Type:      msgType,
		Status:    repository.MessageStatusSent,
		ReplyToID: req.ReplyToID,
		CreatedAt: now,
	}

	if err := s.chatRepo.CreateMessage(message); err != nil {
		return nil, err
	}

	// 获取发送者信息
	user, _ := s.userRepo.GetByID(ctx, userID)
	senderName := ""
	senderAvatar := ""
	if user != nil {
		if user.DisplayName != nil {
			senderName = *user.DisplayName
		} else {
			senderName = user.Username
		}
		if user.AvatarURL != nil {
			senderAvatar = *user.AvatarURL
		}
	}

	return &MessageResponse{
		ID:           message.ID,
		RoomID:       message.RoomID,
		SenderID:     message.SenderID,
		SenderName:   senderName,
		SenderAvatar: senderAvatar,
		Content:      message.Content,
		Type:         message.Type,
		Status:       message.Status,
		ReplyToID:    message.ReplyToID,
		IsDeleted:    message.IsDeleted,
		CreatedAt:    message.CreatedAt,
	}, nil
}

func (s *chatService) GetMessages(ctx context.Context, userID, roomID string, limit int, beforeID string) ([]*MessageResponse, error) {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil || !isMember {
		return nil, ErrNotRoomMember
	}

	if limit <= 0 || limit > 100 {
		limit = 50
	}

	messages, err := s.chatRepo.GetMessages(roomID, limit, beforeID)
	if err != nil {
		return nil, err
	}

	responses := make([]*MessageResponse, 0, len(messages))
	for _, msg := range messages {
		senderName := ""
		senderAvatar := ""
		if msg.Sender != nil {
			if msg.Sender.DisplayName != nil {
				senderName = *msg.Sender.DisplayName
			} else {
				senderName = msg.Sender.Username
			}
			if msg.Sender.AvatarURL != nil {
				senderAvatar = *msg.Sender.AvatarURL
			}
		}

		responses = append(responses, &MessageResponse{
			ID:           msg.ID,
			RoomID:       msg.RoomID,
			SenderID:     msg.SenderID,
			SenderName:   senderName,
			SenderAvatar: senderAvatar,
			Content:      msg.Content,
			Type:         msg.Type,
			Status:       msg.Status,
			MediaURL:     msg.MediaURL,
			ThumbnailURL: msg.ThumbnailURL,
			MediaSize:    msg.MediaSize,
			MimeType:     msg.MimeType,
			ReplyToID:    msg.ReplyToID,
			IsDeleted:    msg.IsDeleted,
			CreatedAt:    msg.CreatedAt,
			EditedAt:     msg.EditedAt,
		})
	}
	return responses, nil
}

func (s *chatService) DeleteMessage(ctx context.Context, userID, roomID, messageID string) error {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil || !isMember {
		return ErrNotRoomMember
	}

	message, err := s.chatRepo.GetMessage(messageID)
	if err != nil {
		return ErrMessageNotFound
	}

	// 只有发送者或管理员可以删除
	if message.SenderID != userID {
		if err := s.checkPermission(roomID, userID, repository.MemberRoleModerator); err != nil {
			return ErrNoPermission
		}
	}

	return s.chatRepo.DeleteMessage(messageID)
}

func (s *chatService) MarkAsRead(ctx context.Context, userID, roomID string) error {
	isMember, err := s.chatRepo.IsMember(roomID, userID)
	if err != nil || !isMember {
		return ErrNotRoomMember
	}

	receipt := &repository.ReadReceipt{
		ID:     uuid.New().String(),
		RoomID: roomID,
		UserID: userID,
		ReadAt: time.Now(),
	}

	return s.chatRepo.UpdateReadReceipt(receipt)
}

// === Helper 函数 ===

func (s *chatService) checkPermission(roomID, userID string, minRole repository.MemberRole) error {
	member, err := s.chatRepo.GetMember(roomID, userID)
	if err != nil {
		return ErrNotRoomMember
	}

	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}

	if roleLevel[member.Role] < roleLevel[minRole] {
		return ErrNoPermission
	}
	return nil
}

func canManageRole(actorRole, targetRole repository.MemberRole) bool {
	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}
	return roleLevel[actorRole] > roleLevel[targetRole]
}

func canSetRole(actorRole, targetRole repository.MemberRole) bool {
	roleLevel := map[repository.MemberRole]int{
		repository.MemberRoleOwner:     4,
		repository.MemberRoleAdmin:     3,
		repository.MemberRoleModerator: 2,
		repository.MemberRoleMember:    1,
	}
	return roleLevel[actorRole] > roleLevel[targetRole]
}

func (s *chatService) buildRoomResponse(room *repository.Room, userID string) (*RoomResponse, error) {
	// 获取未读数
	unreadCount, _ := s.chatRepo.GetUnreadCount(room.ID, userID)

	// 获取成员信息
	member, _ := s.chatRepo.GetMember(room.ID, userID)
	isMuted := false
	isPinned := false
	if member != nil {
		isMuted = member.IsMuted
		isPinned = member.IsPinned
	}

	// 获取最后一条消息
	messages, _ := s.chatRepo.GetMessages(room.ID, 1, "")
	var lastMessage *MessageResponse
	if len(messages) > 0 {
		msg := messages[0]
		senderName := ""
		if msg.Sender != nil {
			if msg.Sender.DisplayName != nil {
				senderName = *msg.Sender.DisplayName
			} else {
				senderName = msg.Sender.Username
			}
		}
		lastMessage = &MessageResponse{
			ID:         msg.ID,
			RoomID:     msg.RoomID,
			SenderID:   msg.SenderID,
			SenderName: senderName,
			Content:    msg.Content,
			Type:       msg.Type,
			CreatedAt:  msg.CreatedAt,
		}
	}

	// 获取房间所有成员
	members, _ := s.chatRepo.GetRoomMembers(room.ID)
	memberResponses := make([]*MemberResponse, 0, len(members))
	for _, m := range members {
		displayName := m.UserID // 默认使用UserID
		avatarURL := ""
		if m.User != nil {
			displayName = m.User.Username
			if m.User.DisplayName != nil {
				displayName = *m.User.DisplayName
			}
			if m.User.AvatarURL != nil {
				avatarURL = *m.User.AvatarURL
			}
		}
		memberResponses = append(memberResponses, &MemberResponse{
			UserID:      m.UserID,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Role:        m.Role,
			JoinedAt:    m.JoinedAt,
			IsOnline:    false,
		})
	}

	return &RoomResponse{
		ID:             room.ID,
		Name:           room.Name,
		Description:    room.Description,
		AvatarURL:      room.AvatarURL,
		Type:           room.Type,
		CreatorID:      room.CreatorID,
		RetentionHours: room.RetentionHours,
		UnreadCount:    unreadCount,
		LastMessage:    lastMessage,
		Members:        memberResponses,
		IsMuted:        isMuted,
		IsPinned:       isPinned,
		CreatedAt:      room.CreatedAt,
		UpdatedAt:      room.UpdatedAt,
	}, nil
}

// === User 搜索 ===

func (s *chatService) SearchUsers(ctx context.Context, query string, limit int) ([]*UserSearchResult, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	users, err := s.userRepo.SearchUsers(ctx, query, limit)
	if err != nil {
		return nil, err
	}

	results := make([]*UserSearchResult, 0, len(users))
	for _, user := range users {
		displayName := user.Username
		if user.DisplayName != nil {
			displayName = *user.DisplayName
		}
		avatarURL := ""
		if user.AvatarURL != nil {
			avatarURL = *user.AvatarURL
		}
		email := ""
		if user.Email != nil {
			email = *user.Email
		}

		results = append(results, &UserSearchResult{
			UserID:      user.UserID,
			Username:    user.Username,
			DisplayName: displayName,
			AvatarURL:   avatarURL,
			Email:       email,
			IsActive:    user.IsActive,
		})
	}
	return results, nil
}
