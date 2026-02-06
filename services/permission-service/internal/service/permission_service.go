package service

import (
	"context"
	"fmt"
	"log"

	"sec-chat/permission-service/internal/repository"
)

// RoomRole 群组角色定义
type RoomRole string

const (
	RoleOwner     RoomRole = "owner"
	RoleAdmin     RoomRole = "admin"
	RoleModerator RoomRole = "moderator"
	RoleMember    RoomRole = "member"
)

// RoomPermission 群组权限定义
type RoomPermission string

const (
	PermManageRoom       RoomPermission = "manage_room"
	PermManageMembers    RoomPermission = "manage_members"
	PermKickMembers      RoomPermission = "kick_members"
	PermBanMembers       RoomPermission = "ban_members"
	PermMuteMembers      RoomPermission = "mute_members"
	PermPinMessages      RoomPermission = "pin_messages"
	PermDeleteMessages   RoomPermission = "delete_messages"
	PermSendMessages     RoomPermission = "send_messages"
	PermSendMedia        RoomPermission = "send_media"
	PermInviteMembers    RoomPermission = "invite_members"
	PermChangeRetention  RoomPermission = "change_retention"
	PermViewAuditLog     RoomPermission = "view_audit_log"
)

// RolePermissions 角色权限映射
var RolePermissions = map[RoomRole][]RoomPermission{
	RoleOwner: {
		PermManageRoom,
		PermManageMembers,
		PermKickMembers,
		PermBanMembers,
		PermMuteMembers,
		PermPinMessages,
		PermDeleteMessages,
		PermSendMessages,
		PermSendMedia,
		PermInviteMembers,
		PermChangeRetention,
		PermViewAuditLog,
	},
	RoleAdmin: {
		PermManageMembers,
		PermKickMembers,
		PermBanMembers,
		PermMuteMembers,
		PermPinMessages,
		PermDeleteMessages,
		PermSendMessages,
		PermSendMedia,
		PermInviteMembers,
		PermViewAuditLog,
	},
	RoleModerator: {
		PermKickMembers,
		PermMuteMembers,
		PermPinMessages,
		PermDeleteMessages,
		PermSendMessages,
		PermSendMedia,
		PermInviteMembers,
	},
	RoleMember: {
		PermSendMessages,
		PermSendMedia,
	},
}

type PermissionService struct {
	repo *repository.PermissionRepository
}

func NewPermissionService(databaseURL string) *PermissionService {
	repo, err := repository.NewPermissionRepository(databaseURL)
	if err != nil {
		log.Printf("Warning: Failed to connect to database: %v", err)
		return &PermissionService{}
	}

	return &PermissionService{
		repo: repo,
	}
}

// CheckRoomPermission 检查用户在群组中是否有特定权限
func (s *PermissionService) CheckRoomPermission(ctx context.Context, userID, roomID string, permission RoomPermission) (bool, error) {
	if s.repo == nil {
		return false, fmt.Errorf("database connection not available")
	}

	// 获取用户在群组中的角色
	member, err := s.repo.GetRoomMember(userID, roomID)
	if err != nil {
		return false, err
	}

	if member == nil {
		return false, nil // 用户不是群组成员
	}

	// 检查角色是否有该权限
	role := RoomRole(member.Role)
	perms, ok := RolePermissions[role]
	if !ok {
		return false, nil
	}

	for _, p := range perms {
		if p == permission {
			return true, nil
		}
	}

	return false, nil
}

// GetUserRoomRole 获取用户在群组中的角色
func (s *PermissionService) GetUserRoomRole(ctx context.Context, userID, roomID string) (RoomRole, error) {
	if s.repo == nil {
		return "", fmt.Errorf("database connection not available")
	}

	member, err := s.repo.GetRoomMember(userID, roomID)
	if err != nil {
		return "", err
	}

	if member == nil {
		return "", nil
	}

	return RoomRole(member.Role), nil
}

// SetUserRoomRole 设置用户在群组中的角色
func (s *PermissionService) SetUserRoomRole(ctx context.Context, operatorID, targetUserID, roomID string, newRole RoomRole) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}

	// 检查操作者权限
	operatorRole, err := s.GetUserRoomRole(ctx, operatorID, roomID)
	if err != nil {
		return err
	}

	// 权限检查：只有owner可以设置admin，admin可以设置moderator
	if !s.canSetRole(operatorRole, newRole) {
		return fmt.Errorf("insufficient permissions to set role %s", newRole)
	}

	// 不能修改owner的角色
	targetRole, err := s.GetUserRoomRole(ctx, targetUserID, roomID)
	if err != nil {
		return err
	}
	if targetRole == RoleOwner {
		return fmt.Errorf("cannot modify owner's role")
	}

	return s.repo.UpdateRoomMemberRole(targetUserID, roomID, string(newRole))
}

// canSetRole 检查是否可以设置角色
func (s *PermissionService) canSetRole(operatorRole, targetRole RoomRole) bool {
	roleHierarchy := map[RoomRole]int{
		RoleOwner:     4,
		RoleAdmin:     3,
		RoleModerator: 2,
		RoleMember:    1,
	}

	operatorLevel := roleHierarchy[operatorRole]
	targetLevel := roleHierarchy[targetRole]

	// 操作者必须比目标角色高
	return operatorLevel > targetLevel
}

// AddRoomMember 添加群组成员
func (s *PermissionService) AddRoomMember(ctx context.Context, operatorID, userID, roomID string) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}

	// 检查操作者是否有邀请权限
	hasPermission, err := s.CheckRoomPermission(ctx, operatorID, roomID, PermInviteMembers)
	if err != nil {
		return err
	}
	if !hasPermission {
		return fmt.Errorf("no permission to invite members")
	}

	return s.repo.AddRoomMember(userID, roomID, string(RoleMember))
}

// RemoveRoomMember 移除群组成员
func (s *PermissionService) RemoveRoomMember(ctx context.Context, operatorID, userID, roomID string) error {
	if s.repo == nil {
		return fmt.Errorf("database connection not available")
	}

	// 检查操作者是否有踢人权限
	hasPermission, err := s.CheckRoomPermission(ctx, operatorID, roomID, PermKickMembers)
	if err != nil {
		return err
	}
	if !hasPermission {
		return fmt.Errorf("no permission to kick members")
	}

	// 不能踢owner
	targetRole, err := s.GetUserRoomRole(ctx, userID, roomID)
	if err != nil {
		return err
	}
	if targetRole == RoleOwner {
		return fmt.Errorf("cannot kick room owner")
	}

	// 不能踢比自己权限高的人
	operatorRole, err := s.GetUserRoomRole(ctx, operatorID, roomID)
	if err != nil {
		return err
	}
	if !s.canSetRole(operatorRole, targetRole) {
		return fmt.Errorf("cannot kick member with equal or higher role")
	}

	return s.repo.RemoveRoomMember(userID, roomID)
}

// GetRoomMembers 获取群组成员列表
func (s *PermissionService) GetRoomMembers(ctx context.Context, userID, roomID string) ([]repository.RoomMember, error) {
	if s.repo == nil {
		return nil, fmt.Errorf("database connection not available")
	}

	// 检查用户是否是群组成员
	member, err := s.repo.GetRoomMember(userID, roomID)
	if err != nil {
		return nil, err
	}
	if member == nil {
		return nil, fmt.Errorf("user is not a room member")
	}

	return s.repo.GetRoomMembers(roomID)
}

// GetUserPermissions 获取用户在群组中的所有权限
func (s *PermissionService) GetUserPermissions(ctx context.Context, userID, roomID string) ([]RoomPermission, error) {
	role, err := s.GetUserRoomRole(ctx, userID, roomID)
	if err != nil {
		return nil, err
	}

	if role == "" {
		return []RoomPermission{}, nil
	}

	perms, ok := RolePermissions[role]
	if !ok {
		return []RoomPermission{}, nil
	}

	return perms, nil
}

// HasGlobalPermission 检查用户是否有全局权限（管理员权限）
func (s *PermissionService) HasGlobalPermission(ctx context.Context, userID, permission string) (bool, error) {
	if s.repo == nil {
		return false, fmt.Errorf("database connection not available")
	}

	return s.repo.HasPermission(userID, permission)
}
