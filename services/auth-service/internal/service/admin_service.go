package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"sec-chat/auth-service/internal/repository"

	"golang.org/x/crypto/bcrypt"
)

var (
	ErrNotAdmin          = errors.New("user is not an admin")
	ErrInsufficientPerms = errors.New("insufficient permissions")
	ErrCannotDeleteSelf  = errors.New("cannot delete yourself")
	ErrLastSuperAdmin    = errors.New("cannot remove the last super admin")
	ErrSettingNotFound   = errors.New("setting not found")
)

// UserListResponse 用户列表响应
type UserListResponse struct {
	Users      []*repository.User `json:"users"`
	Total      int64              `json:"total"`
	Page       int                `json:"page"`
	PageSize   int                `json:"page_size"`
	TotalPages int                `json:"total_pages"`
}

// RoomListResponse 房间列表响应
type RoomListResponse struct {
	Rooms      []*repository.Room `json:"rooms"`
	Total      int64              `json:"total"`
	Page       int                `json:"page"`
	PageSize   int                `json:"page_size"`
	TotalPages int                `json:"total_pages"`
}

// AuditLogListResponse 审计日志列表响应
type AuditLogListResponse struct {
	Logs       []*repository.AuditLog `json:"logs"`
	Total      int64                  `json:"total"`
	Page       int                    `json:"page"`
	PageSize   int                    `json:"page_size"`
	TotalPages int                    `json:"total_pages"`
}

// AdminUserInfo 管理员用户信息（关联用户详情）
type AdminUserInfo struct {
	UserID      string               `json:"user_id"`
	Username    string               `json:"username"`
	DisplayName *string              `json:"display_name"`
	Email       *string              `json:"email"`
	Role        repository.AdminRole `json:"role"`
	CreatedAt   time.Time            `json:"created_at"`
	CreatedBy   string               `json:"created_by"`
}

// CreateAdminRequest 创建管理员请求
type CreateAdminRequest struct {
	UserID string               `json:"user_id" binding:"required"`
	Role   repository.AdminRole `json:"role" binding:"required"`
}

// UpdateAdminRoleRequest 更新管理员角色请求
type UpdateAdminRoleRequest struct {
	Role repository.AdminRole `json:"role" binding:"required"`
}

// UpdateUserStatusRequest 更新用户状态请求
type UpdateUserStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// ResetPasswordRequest 重置密码请求
type ResetPasswordRequest struct {
	NewPassword string `json:"new_password" binding:"required,min=8"`
}

// UpdateSettingRequest 更新设置请求
type UpdateSettingRequest struct {
	Value       string `json:"value" binding:"required"`
	Description string `json:"description"`
}

// AdminService 管理服务接口
type AdminService interface {
	// 权限检查
	CheckAdminAccess(ctx context.Context, userID string, requiredRoles ...repository.AdminRole) error
	IsAdmin(ctx context.Context, userID string) (bool, repository.AdminRole, error)

	// 用户管理
	GetUsers(ctx context.Context, adminUserID string, page, pageSize int, search string, activeOnly bool) (*UserListResponse, error)
	GetUser(ctx context.Context, adminUserID, targetUserID string) (*repository.User, error)
	UpdateUserStatus(ctx context.Context, adminUserID, targetUserID string, isActive bool, ipAddress, userAgent string) error
	ResetUserPassword(ctx context.Context, adminUserID, targetUserID, newPassword string, ipAddress, userAgent string) error
	DeleteUser(ctx context.Context, adminUserID, targetUserID string, ipAddress, userAgent string) error

	// 管理员管理
	GetAdminUsers(ctx context.Context, adminUserID string) ([]*AdminUserInfo, error)
	CreateAdminUser(ctx context.Context, adminUserID string, req *CreateAdminRequest, ipAddress, userAgent string) error
	UpdateAdminRole(ctx context.Context, adminUserID, targetUserID string, role repository.AdminRole, ipAddress, userAgent string) error
	DeleteAdminUser(ctx context.Context, adminUserID, targetUserID string, ipAddress, userAgent string) error

	// 房间管理
	GetRooms(ctx context.Context, adminUserID string, page, pageSize int, search, roomType string) (*RoomListResponse, error)
	GetRoom(ctx context.Context, adminUserID, roomID string) (*repository.Room, error)
	GetRoomMembers(ctx context.Context, adminUserID, roomID string) ([]*repository.RoomMember, error)
	DeleteRoom(ctx context.Context, adminUserID, roomID string, ipAddress, userAgent string) error

	// 审计日志
	GetAuditLogs(ctx context.Context, adminUserID string, page, pageSize int, action, actorID string, startTime, endTime *time.Time) (*AuditLogListResponse, error)

	// 系统设置
	GetSettings(ctx context.Context, adminUserID string) ([]*repository.SystemSetting, error)
	GetSetting(ctx context.Context, adminUserID, key string) (*repository.SystemSetting, error)
	UpdateSetting(ctx context.Context, adminUserID, key string, req *UpdateSettingRequest, ipAddress, userAgent string) error

	// 统计
	GetStats(ctx context.Context, adminUserID string) (*repository.SystemStats, error)
	GetUserStats(ctx context.Context, adminUserID string) (*repository.UserStats, error)
	GetRoomStats(ctx context.Context, adminUserID string) (*repository.RoomStats, error)
	GetMessageStats(ctx context.Context, adminUserID string) (*repository.MessageStats, error)
}

type adminService struct {
	adminRepo repository.AdminRepository
	userRepo  repository.UserRepository
}

// NewAdminService 创建管理服务实例
func NewAdminService(
	adminRepo repository.AdminRepository,
	userRepo repository.UserRepository,
) AdminService {
	return &adminService{
		adminRepo: adminRepo,
		userRepo:  userRepo,
	}
}

// roleHierarchy 角色权限等级（数值越大权限越高）
var roleHierarchy = map[repository.AdminRole]int{
	repository.AdminRoleViewer:     1,
	repository.AdminRoleOperator:   2,
	repository.AdminRoleAdmin:      3,
	repository.AdminRoleSuperAdmin: 4,
}

// CheckAdminAccess 检查管理员访问权限
func (s *adminService) CheckAdminAccess(ctx context.Context, userID string, requiredRoles ...repository.AdminRole) error {
	isAdmin, role, err := s.adminRepo.IsAdmin(userID)
	if err != nil {
		return fmt.Errorf("failed to check admin status: %w", err)
	}
	if !isAdmin {
		return ErrNotAdmin
	}

	// 如果没有指定所需角色，只需是管理员即可
	if len(requiredRoles) == 0 {
		return nil
	}

	// 检查角色权限
	userLevel := roleHierarchy[role]
	for _, required := range requiredRoles {
		if userLevel >= roleHierarchy[required] {
			return nil
		}
	}

	return ErrInsufficientPerms
}

// IsAdmin 检查用户是否是管理员
func (s *adminService) IsAdmin(ctx context.Context, userID string) (bool, repository.AdminRole, error) {
	return s.adminRepo.IsAdmin(userID)
}

// ====== 用户管理 ======

func (s *adminService) GetUsers(ctx context.Context, adminUserID string, page, pageSize int, search string, activeOnly bool) (*UserListResponse, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	// 参数校验
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	users, total, err := s.adminRepo.GetUsers(page, pageSize, search, activeOnly)
	if err != nil {
		return nil, fmt.Errorf("failed to get users: %w", err)
	}

	totalPages := int(total) / pageSize
	if int(total)%pageSize > 0 {
		totalPages++
	}

	return &UserListResponse{
		Users:      users,
		Total:      total,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}, nil
}

func (s *adminService) GetUser(ctx context.Context, adminUserID, targetUserID string) (*repository.User, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	user, err := s.adminRepo.GetUserByID(targetUserID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	return user, nil
}

func (s *adminService) UpdateUserStatus(ctx context.Context, adminUserID, targetUserID string, isActive bool, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleOperator); err != nil {
		return err
	}

	// 获取目标用户信息（用于审计日志）
	targetUser, err := s.adminRepo.GetUserByID(targetUserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if err := s.adminRepo.UpdateUserStatus(targetUserID, isActive); err != nil {
		return fmt.Errorf("failed to update user status: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	action := "disabled"
	if isActive {
		action = "enabled"
	}

	s.createAuditLog(repository.AuditActionUserUpdate, adminUserID, actorName, "user", targetUserID, targetUser.Username, fmt.Sprintf("User %s", action), ipAddress, userAgent)

	return nil
}

func (s *adminService) ResetUserPassword(ctx context.Context, adminUserID, targetUserID, newPassword string, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleAdmin); err != nil {
		return err
	}

	// 获取目标用户信息
	targetUser, err := s.adminRepo.GetUserByID(targetUserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	// 哈希新密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	if err := s.adminRepo.ResetUserPassword(targetUserID, string(hashedPassword)); err != nil {
		return fmt.Errorf("failed to reset password: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	s.createAuditLog(repository.AuditActionUserUpdate, adminUserID, actorName, "user", targetUserID, targetUser.Username, "Password reset by admin", ipAddress, userAgent)

	return nil
}

func (s *adminService) DeleteUser(ctx context.Context, adminUserID, targetUserID string, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 不能删除自己
	if adminUserID == targetUserID {
		return ErrCannotDeleteSelf
	}

	// 获取目标用户信息
	targetUser, err := s.adminRepo.GetUserByID(targetUserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if err := s.adminRepo.DeleteUser(targetUserID); err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	s.createAuditLog(repository.AuditActionUserDelete, adminUserID, actorName, "user", targetUserID, targetUser.Username, "User deleted", ipAddress, userAgent)

	return nil
}

// ====== 管理员管理 ======

func (s *adminService) GetAdminUsers(ctx context.Context, adminUserID string) ([]*AdminUserInfo, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleAdmin); err != nil {
		return nil, err
	}

	admins, err := s.adminRepo.GetAdminUsers()
	if err != nil {
		return nil, fmt.Errorf("failed to get admin users: %w", err)
	}

	// 关联用户信息
	result := make([]*AdminUserInfo, 0, len(admins))
	for _, admin := range admins {
		user, err := s.adminRepo.GetUserByID(admin.UserID)
		if err != nil {
			continue // 跳过找不到用户的记录
		}

		result = append(result, &AdminUserInfo{
			UserID:      admin.UserID,
			Username:    user.Username,
			DisplayName: user.DisplayName,
			Email:       user.Email,
			Role:        admin.Role,
			CreatedAt:   admin.CreatedAt,
			CreatedBy:   admin.CreatedBy,
		})
	}

	return result, nil
}

func (s *adminService) CreateAdminUser(ctx context.Context, adminUserID string, req *CreateAdminRequest, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 验证目标用户存在
	targetUser, err := s.adminRepo.GetUserByID(req.UserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	// 检查是否已是管理员
	isAdmin, _, _ := s.adminRepo.IsAdmin(req.UserID)
	if isAdmin {
		return errors.New("user is already an admin")
	}

	admin := &repository.AdminUser{
		UserID:    req.UserID,
		Role:      req.Role,
		CreatedAt: time.Now(),
		CreatedBy: adminUserID,
	}

	if err := s.adminRepo.CreateAdminUser(admin); err != nil {
		return fmt.Errorf("failed to create admin user: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	s.createAuditLog(repository.AuditActionAdminAction, adminUserID, actorName, "admin", req.UserID, targetUser.Username, fmt.Sprintf("Granted %s role", req.Role), ipAddress, userAgent)

	return nil
}

func (s *adminService) UpdateAdminRole(ctx context.Context, adminUserID, targetUserID string, role repository.AdminRole, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 不能修改自己的角色
	if adminUserID == targetUserID {
		return errors.New("cannot modify your own role")
	}

	// 验证目标用户是管理员
	targetAdmin, err := s.adminRepo.GetAdminUser(targetUserID)
	if err != nil {
		return fmt.Errorf("admin user not found: %w", err)
	}

	// 如果是超级管理员，检查是否是最后一个
	if targetAdmin.Role == repository.AdminRoleSuperAdmin && role != repository.AdminRoleSuperAdmin {
		admins, _ := s.adminRepo.GetAdminUsers()
		superAdminCount := 0
		for _, a := range admins {
			if a.Role == repository.AdminRoleSuperAdmin {
				superAdminCount++
			}
		}
		if superAdminCount <= 1 {
			return ErrLastSuperAdmin
		}
	}

	oldRole := targetAdmin.Role

	if err := s.adminRepo.UpdateAdminRole(targetUserID, role); err != nil {
		return fmt.Errorf("failed to update admin role: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	targetUser, _ := s.adminRepo.GetUserByID(targetUserID)
	targetName := targetUserID
	if targetUser != nil {
		targetName = targetUser.Username
	}

	s.createAuditLog(repository.AuditActionAdminAction, adminUserID, actorName, "admin", targetUserID, targetName, fmt.Sprintf("Role changed from %s to %s", oldRole, role), ipAddress, userAgent)

	return nil
}

func (s *adminService) DeleteAdminUser(ctx context.Context, adminUserID, targetUserID string, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 不能删除自己
	if adminUserID == targetUserID {
		return ErrCannotDeleteSelf
	}

	// 验证目标用户是管理员
	targetAdmin, err := s.adminRepo.GetAdminUser(targetUserID)
	if err != nil {
		return fmt.Errorf("admin user not found: %w", err)
	}

	// 如果是超级管理员，检查是否是最后一个
	if targetAdmin.Role == repository.AdminRoleSuperAdmin {
		admins, _ := s.adminRepo.GetAdminUsers()
		superAdminCount := 0
		for _, a := range admins {
			if a.Role == repository.AdminRoleSuperAdmin {
				superAdminCount++
			}
		}
		if superAdminCount <= 1 {
			return ErrLastSuperAdmin
		}
	}

	if err := s.adminRepo.DeleteAdminUser(targetUserID); err != nil {
		return fmt.Errorf("failed to delete admin user: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	targetUser, _ := s.adminRepo.GetUserByID(targetUserID)
	targetName := targetUserID
	if targetUser != nil {
		targetName = targetUser.Username
	}

	s.createAuditLog(repository.AuditActionAdminAction, adminUserID, actorName, "admin", targetUserID, targetName, fmt.Sprintf("Removed %s role", targetAdmin.Role), ipAddress, userAgent)

	return nil
}

// ====== 房间管理 ======

func (s *adminService) GetRooms(ctx context.Context, adminUserID string, page, pageSize int, search, roomType string) (*RoomListResponse, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	// 参数校验
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	rooms, total, err := s.adminRepo.GetRooms(page, pageSize, search, roomType)
	if err != nil {
		return nil, fmt.Errorf("failed to get rooms: %w", err)
	}

	totalPages := int(total) / pageSize
	if int(total)%pageSize > 0 {
		totalPages++
	}

	return &RoomListResponse{
		Rooms:      rooms,
		Total:      total,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}, nil
}

func (s *adminService) GetRoom(ctx context.Context, adminUserID, roomID string) (*repository.Room, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	room, err := s.adminRepo.GetRoomByID(roomID)
	if err != nil {
		return nil, fmt.Errorf("room not found: %w", err)
	}

	return room, nil
}

func (s *adminService) GetRoomMembers(ctx context.Context, adminUserID, roomID string) ([]*repository.RoomMember, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	members, err := s.adminRepo.GetRoomMembersAdmin(roomID)
	if err != nil {
		return nil, fmt.Errorf("failed to get room members: %w", err)
	}

	return members, nil
}

func (s *adminService) DeleteRoom(ctx context.Context, adminUserID, roomID string, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 获取房间信息
	room, err := s.adminRepo.GetRoomByID(roomID)
	if err != nil {
		return fmt.Errorf("room not found: %w", err)
	}

	if err := s.adminRepo.DeleteRoom(roomID); err != nil {
		return fmt.Errorf("failed to delete room: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	roomName := roomID
	if room.Name != "" {
		roomName = room.Name
	}

	s.createAuditLog(repository.AuditActionRoomDelete, adminUserID, actorName, "room", roomID, roomName, fmt.Sprintf("Room deleted (type: %s)", room.Type), ipAddress, userAgent)

	return nil
}

// ====== 审计日志 ======

func (s *adminService) GetAuditLogs(ctx context.Context, adminUserID string, page, pageSize int, action, actorID string, startTime, endTime *time.Time) (*AuditLogListResponse, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleAdmin); err != nil {
		return nil, err
	}

	// 参数校验
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	logs, total, err := s.adminRepo.GetAuditLogs(page, pageSize, action, actorID, startTime, endTime)
	if err != nil {
		return nil, fmt.Errorf("failed to get audit logs: %w", err)
	}

	totalPages := int(total) / pageSize
	if int(total)%pageSize > 0 {
		totalPages++
	}

	return &AuditLogListResponse{
		Logs:       logs,
		Total:      total,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}, nil
}

// ====== 系统设置 ======

func (s *adminService) GetSettings(ctx context.Context, adminUserID string) ([]*repository.SystemSetting, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleAdmin); err != nil {
		return nil, err
	}

	settings, err := s.adminRepo.GetSettings()
	if err != nil {
		return nil, fmt.Errorf("failed to get settings: %w", err)
	}

	return settings, nil
}

func (s *adminService) GetSetting(ctx context.Context, adminUserID, key string) (*repository.SystemSetting, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleAdmin); err != nil {
		return nil, err
	}

	setting, err := s.adminRepo.GetSetting(key)
	if err != nil {
		return nil, ErrSettingNotFound
	}

	return setting, nil
}

func (s *adminService) UpdateSetting(ctx context.Context, adminUserID, key string, req *UpdateSettingRequest, ipAddress, userAgent string) error {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleSuperAdmin); err != nil {
		return err
	}

	// 获取现有设置
	setting, err := s.adminRepo.GetSetting(key)
	if err != nil {
		// 如果不存在则创建
		setting = &repository.SystemSetting{
			Key: key,
		}
	}

	oldValue := setting.Value
	setting.Value = req.Value
	if req.Description != "" {
		setting.Description = req.Description
	}
	setting.UpdatedAt = time.Now()
	setting.UpdatedBy = adminUserID

	if err := s.adminRepo.UpdateSetting(setting); err != nil {
		return fmt.Errorf("failed to update setting: %w", err)
	}

	// 记录审计日志
	adminUser, _ := s.adminRepo.GetUserByID(adminUserID)
	actorName := adminUserID
	if adminUser != nil {
		actorName = adminUser.Username
	}

	details := fmt.Sprintf("Setting '%s' changed from '%s' to '%s'", key, oldValue, req.Value)
	s.createAuditLog(repository.AuditActionSettingUpdate, adminUserID, actorName, "setting", key, key, details, ipAddress, userAgent)

	return nil
}

// ====== 统计 ======

func (s *adminService) GetStats(ctx context.Context, adminUserID string) (*repository.SystemStats, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	userStats, err := s.adminRepo.GetUserStats()
	if err != nil {
		return nil, fmt.Errorf("failed to get user stats: %w", err)
	}

	roomStats, err := s.adminRepo.GetRoomStats()
	if err != nil {
		return nil, fmt.Errorf("failed to get room stats: %w", err)
	}

	messageStats, err := s.adminRepo.GetMessageStats()
	if err != nil {
		return nil, fmt.Errorf("failed to get message stats: %w", err)
	}

	return &repository.SystemStats{
		Users:    *userStats,
		Rooms:    *roomStats,
		Messages: *messageStats,
	}, nil
}

func (s *adminService) GetUserStats(ctx context.Context, adminUserID string) (*repository.UserStats, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	return s.adminRepo.GetUserStats()
}

func (s *adminService) GetRoomStats(ctx context.Context, adminUserID string) (*repository.RoomStats, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	return s.adminRepo.GetRoomStats()
}

func (s *adminService) GetMessageStats(ctx context.Context, adminUserID string) (*repository.MessageStats, error) {
	if err := s.CheckAdminAccess(ctx, adminUserID, repository.AdminRoleViewer); err != nil {
		return nil, err
	}

	return s.adminRepo.GetMessageStats()
}

// ====== 辅助方法 ======

func (s *adminService) createAuditLog(action repository.AuditAction, actorID, actorName, targetType, targetID, targetName, details, ipAddress, userAgent string) {
	log := &repository.AuditLog{
		Action:     action,
		ActorID:    actorID,
		ActorName:  actorName,
		TargetType: targetType,
		TargetID:   targetID,
		TargetName: targetName,
		Details:    details,
		IPAddress:  ipAddress,
		UserAgent:  userAgent,
		CreatedAt:  time.Now(),
	}

	// 忽略错误，审计日志失败不应影响主操作
	_ = s.adminRepo.CreateAuditLog(log)
}
