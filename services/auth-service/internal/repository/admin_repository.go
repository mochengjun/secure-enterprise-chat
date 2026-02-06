package repository

import (
	"time"

	"gorm.io/gorm"
)

// AuditAction 审计操作类型
type AuditAction string

const (
	AuditActionUserCreate    AuditAction = "user_create"
	AuditActionUserUpdate    AuditAction = "user_update"
	AuditActionUserDelete    AuditAction = "user_delete"
	AuditActionUserLogin     AuditAction = "user_login"
	AuditActionUserLogout    AuditAction = "user_logout"
	AuditActionRoomCreate    AuditAction = "room_create"
	AuditActionRoomUpdate    AuditAction = "room_update"
	AuditActionRoomDelete    AuditAction = "room_delete"
	AuditActionMemberAdd     AuditAction = "member_add"
	AuditActionMemberRemove  AuditAction = "member_remove"
	AuditActionMemberRole    AuditAction = "member_role"
	AuditActionMessageDelete AuditAction = "message_delete"
	AuditActionSettingUpdate AuditAction = "setting_update"
	AuditActionAdminAction   AuditAction = "admin_action"
)

// AuditLog 审计日志
type AuditLog struct {
	ID         uint        `gorm:"primaryKey" json:"id"`
	Action     AuditAction `gorm:"size:50;not null;index" json:"action"`
	ActorID    string      `gorm:"size:36;index" json:"actor_id"`
	ActorName  string      `gorm:"size:100" json:"actor_name"`
	TargetType string      `gorm:"size:50" json:"target_type,omitempty"`
	TargetID   string      `gorm:"size:36" json:"target_id,omitempty"`
	TargetName string      `gorm:"size:255" json:"target_name,omitempty"`
	Details    string      `gorm:"type:text" json:"details,omitempty"`
	IPAddress  string      `gorm:"size:45" json:"ip_address,omitempty"`
	UserAgent  string      `gorm:"size:500" json:"user_agent,omitempty"`
	CreatedAt  time.Time   `gorm:"index" json:"created_at"`
}

// SystemSetting 系统设置
type SystemSetting struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	Key         string    `gorm:"size:100;uniqueIndex;not null" json:"key"`
	Value       string    `gorm:"type:text" json:"value"`
	Description string    `gorm:"size:500" json:"description,omitempty"`
	UpdatedAt   time.Time `json:"updated_at"`
	UpdatedBy   string    `gorm:"size:36" json:"updated_by,omitempty"`
}

// AdminRole 管理员角色
type AdminRole string

const (
	AdminRoleSuperAdmin AdminRole = "super_admin"
	AdminRoleAdmin      AdminRole = "admin"
	AdminRoleOperator   AdminRole = "operator"
	AdminRoleViewer     AdminRole = "viewer"
)

// AdminUser 管理员用户（扩展 User）
type AdminUser struct {
	UserID    string    `gorm:"primaryKey;size:36" json:"user_id"`
	Role      AdminRole `gorm:"size:20;not null;default:viewer" json:"role"`
	CreatedAt time.Time `json:"created_at"`
	CreatedBy string    `gorm:"size:36" json:"created_by,omitempty"`
}

// UserStats 用户统计
type UserStats struct {
	TotalUsers       int64 `json:"total_users"`
	ActiveUsers      int64 `json:"active_users"`
	InactiveUsers    int64 `json:"inactive_users"`
	NewUsersToday    int64 `json:"new_users_today"`
	NewUsersThisWeek int64 `json:"new_users_this_week"`
}

// RoomStats 房间统计
type RoomStats struct {
	TotalRooms       int64 `json:"total_rooms"`
	DirectRooms      int64 `json:"direct_rooms"`
	GroupRooms       int64 `json:"group_rooms"`
	ChannelRooms     int64 `json:"channel_rooms"`
	NewRoomsToday    int64 `json:"new_rooms_today"`
	NewRoomsThisWeek int64 `json:"new_rooms_this_week"`
}

// MessageStats 消息统计
type MessageStats struct {
	TotalMessages    int64 `json:"total_messages"`
	MessagesToday    int64 `json:"messages_today"`
	MessagesThisWeek int64 `json:"messages_this_week"`
	TextMessages     int64 `json:"text_messages"`
	MediaMessages    int64 `json:"media_messages"`
	DeletedMessages  int64 `json:"deleted_messages"`
}

// SystemStats 系统统计
type SystemStats struct {
	Users    UserStats    `json:"users"`
	Rooms    RoomStats    `json:"rooms"`
	Messages MessageStats `json:"messages"`
}

// AdminRepository 管理员仓库接口
type AdminRepository interface {
	// 用户管理
	GetUsers(page, pageSize int, search string, activeOnly bool) ([]*User, int64, error)
	GetUserByID(userID string) (*User, error)
	UpdateUserStatus(userID string, isActive bool) error
	ResetUserPassword(userID string, passwordHash string) error
	DeleteUser(userID string) error

	// 管理员管理
	GetAdminUsers() ([]*AdminUser, error)
	GetAdminUser(userID string) (*AdminUser, error)
	CreateAdminUser(admin *AdminUser) error
	UpdateAdminRole(userID string, role AdminRole) error
	DeleteAdminUser(userID string) error
	IsAdmin(userID string) (bool, AdminRole, error)

	// 房间管理
	GetRooms(page, pageSize int, search string, roomType string) ([]*Room, int64, error)
	GetRoomByID(roomID string) (*Room, error)
	DeleteRoom(roomID string) error
	GetRoomMembersAdmin(roomID string) ([]*RoomMember, error)

	// 审计日志
	CreateAuditLog(log *AuditLog) error
	GetAuditLogs(page, pageSize int, action string, actorID string, startTime, endTime *time.Time) ([]*AuditLog, int64, error)

	// 系统设置
	GetSettings() ([]*SystemSetting, error)
	GetSetting(key string) (*SystemSetting, error)
	UpdateSetting(setting *SystemSetting) error

	// 统计
	GetUserStats() (*UserStats, error)
	GetRoomStats() (*RoomStats, error)
	GetMessageStats() (*MessageStats, error)
}

// adminRepository 管理员仓库实现
type adminRepository struct {
	db *gorm.DB
}

// NewAdminRepository 创建管理员仓库实例
func NewAdminRepository(db *gorm.DB) AdminRepository {
	return &adminRepository{db: db}
}

// ====== 用户管理 ======

func (r *adminRepository) GetUsers(page, pageSize int, search string, activeOnly bool) ([]*User, int64, error) {
	var users []*User
	var total int64

	query := r.db.Model(&User{})

	if search != "" {
		query = query.Where("username LIKE ? OR display_name LIKE ? OR email LIKE ?",
			"%"+search+"%", "%"+search+"%", "%"+search+"%")
	}

	if activeOnly {
		query = query.Where("is_active = ?", true)
	}

	query.Count(&total)

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&users).Error

	return users, total, err
}

func (r *adminRepository) GetUserByID(userID string) (*User, error) {
	var user User
	err := r.db.First(&user, "user_id = ?", userID).Error
	return &user, err
}

func (r *adminRepository) UpdateUserStatus(userID string, isActive bool) error {
	return r.db.Model(&User{}).Where("user_id = ?", userID).Update("is_active", isActive).Error
}

func (r *adminRepository) ResetUserPassword(userID string, passwordHash string) error {
	return r.db.Model(&User{}).Where("user_id = ?", userID).Update("password_hash", passwordHash).Error
}

func (r *adminRepository) DeleteUser(userID string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 删除用户的所有房间成员记录
		if err := tx.Delete(&RoomMember{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户的设备记录
		if err := tx.Delete(&Device{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户的 Token
		if err := tx.Delete(&RefreshToken{}, "user_id = ?", userID).Error; err != nil {
			return err
		}
		// 删除用户
		return tx.Delete(&User{}, "user_id = ?", userID).Error
	})
}

// ====== 管理员管理 ======

func (r *adminRepository) GetAdminUsers() ([]*AdminUser, error) {
	var admins []*AdminUser
	err := r.db.Find(&admins).Error
	return admins, err
}

func (r *adminRepository) GetAdminUser(userID string) (*AdminUser, error) {
	var admin AdminUser
	err := r.db.First(&admin, "user_id = ?", userID).Error
	return &admin, err
}

func (r *adminRepository) CreateAdminUser(admin *AdminUser) error {
	return r.db.Create(admin).Error
}

func (r *adminRepository) UpdateAdminRole(userID string, role AdminRole) error {
	return r.db.Model(&AdminUser{}).Where("user_id = ?", userID).Update("role", role).Error
}

func (r *adminRepository) DeleteAdminUser(userID string) error {
	return r.db.Delete(&AdminUser{}, "user_id = ?", userID).Error
}

func (r *adminRepository) IsAdmin(userID string) (bool, AdminRole, error) {
	var admin AdminUser
	err := r.db.First(&admin, "user_id = ?", userID).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return false, "", nil
		}
		return false, "", err
	}
	return true, admin.Role, nil
}

// ====== 房间管理 ======

func (r *adminRepository) GetRooms(page, pageSize int, search string, roomType string) ([]*Room, int64, error) {
	var rooms []*Room
	var total int64

	query := r.db.Model(&Room{})

	if search != "" {
		query = query.Where("name LIKE ? OR description LIKE ?", "%"+search+"%", "%"+search+"%")
	}

	if roomType != "" {
		query = query.Where("type = ?", roomType)
	}

	query.Count(&total)

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&rooms).Error

	return rooms, total, err
}

func (r *adminRepository) GetRoomByID(roomID string) (*Room, error) {
	var room Room
	err := r.db.First(&room, "id = ?", roomID).Error
	return &room, err
}

func (r *adminRepository) DeleteRoom(roomID string) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// 删除消息
		if err := tx.Delete(&Message{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除已读回执
		if err := tx.Delete(&ReadReceipt{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除成员
		if err := tx.Delete(&RoomMember{}, "room_id = ?", roomID).Error; err != nil {
			return err
		}
		// 删除房间
		return tx.Delete(&Room{}, "id = ?", roomID).Error
	})
}

func (r *adminRepository) GetRoomMembersAdmin(roomID string) ([]*RoomMember, error) {
	var members []*RoomMember
	err := r.db.Preload("User").Where("room_id = ?", roomID).Find(&members).Error
	return members, err
}

// ====== 审计日志 ======

func (r *adminRepository) CreateAuditLog(log *AuditLog) error {
	return r.db.Create(log).Error
}

func (r *adminRepository) GetAuditLogs(page, pageSize int, action string, actorID string, startTime, endTime *time.Time) ([]*AuditLog, int64, error) {
	var logs []*AuditLog
	var total int64

	query := r.db.Model(&AuditLog{})

	if action != "" {
		query = query.Where("action = ?", action)
	}
	if actorID != "" {
		query = query.Where("actor_id = ?", actorID)
	}
	if startTime != nil {
		query = query.Where("created_at >= ?", startTime)
	}
	if endTime != nil {
		query = query.Where("created_at <= ?", endTime)
	}

	query.Count(&total)

	offset := (page - 1) * pageSize
	err := query.Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&logs).Error

	return logs, total, err
}

// ====== 系统设置 ======

func (r *adminRepository) GetSettings() ([]*SystemSetting, error) {
	var settings []*SystemSetting
	err := r.db.Find(&settings).Error
	return settings, err
}

func (r *adminRepository) GetSetting(key string) (*SystemSetting, error) {
	var setting SystemSetting
	err := r.db.First(&setting, "`key` = ?", key).Error
	return &setting, err
}

func (r *adminRepository) UpdateSetting(setting *SystemSetting) error {
	return r.db.Save(setting).Error
}

// ====== 统计 ======

func (r *adminRepository) GetUserStats() (*UserStats, error) {
	var stats UserStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	r.db.Model(&User{}).Count(&stats.TotalUsers)
	r.db.Model(&User{}).Where("is_active = ?", true).Count(&stats.ActiveUsers)
	r.db.Model(&User{}).Where("is_active = ?", false).Count(&stats.InactiveUsers)
	r.db.Model(&User{}).Where("created_at >= ?", today).Count(&stats.NewUsersToday)
	r.db.Model(&User{}).Where("created_at >= ?", weekAgo).Count(&stats.NewUsersThisWeek)

	return &stats, nil
}

func (r *adminRepository) GetRoomStats() (*RoomStats, error) {
	var stats RoomStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	r.db.Model(&Room{}).Count(&stats.TotalRooms)
	r.db.Model(&Room{}).Where("type = ?", RoomTypeDirect).Count(&stats.DirectRooms)
	r.db.Model(&Room{}).Where("type = ?", RoomTypeGroup).Count(&stats.GroupRooms)
	r.db.Model(&Room{}).Where("type = ?", RoomTypeChannel).Count(&stats.ChannelRooms)
	r.db.Model(&Room{}).Where("created_at >= ?", today).Count(&stats.NewRoomsToday)
	r.db.Model(&Room{}).Where("created_at >= ?", weekAgo).Count(&stats.NewRoomsThisWeek)

	return &stats, nil
}

func (r *adminRepository) GetMessageStats() (*MessageStats, error) {
	var stats MessageStats
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekAgo := today.AddDate(0, 0, -7)

	r.db.Model(&Message{}).Count(&stats.TotalMessages)
	r.db.Model(&Message{}).Where("created_at >= ?", today).Count(&stats.MessagesToday)
	r.db.Model(&Message{}).Where("created_at >= ?", weekAgo).Count(&stats.MessagesThisWeek)
	r.db.Model(&Message{}).Where("type = ?", MessageTypeText).Count(&stats.TextMessages)
	r.db.Model(&Message{}).Where("type IN ?", []MessageType{MessageTypeImage, MessageTypeVideo, MessageTypeAudio, MessageTypeFile}).Count(&stats.MediaMessages)
	r.db.Model(&Message{}).Where("is_deleted = ?", true).Count(&stats.DeletedMessages)

	return &stats, nil
}
