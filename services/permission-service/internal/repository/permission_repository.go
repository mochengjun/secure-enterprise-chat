package repository

import (
	"database/sql"
	"time"

	_ "github.com/lib/pq"
)

type PermissionRepository struct {
	db *sql.DB
}

func NewPermissionRepository(databaseURL string) (*PermissionRepository, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &PermissionRepository{db: db}, nil
}

func (r *PermissionRepository) Close() error {
	return r.db.Close()
}

// Role 角色定义
type Role struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Permissions []string  `json:"permissions"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// UserRole 用户角色关联
type UserRole struct {
	UserID    string    `json:"user_id"`
	RoleID    string    `json:"role_id"`
	RoomID    string    `json:"room_id,omitempty"` // 可选，用于群组级别角色
	CreatedAt time.Time `json:"created_at"`
}

// Permission 权限定义
type Permission struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Resource    string `json:"resource"`
	Action      string `json:"action"`
}

// RoomMember 群组成员
type RoomMember struct {
	UserID    string    `json:"user_id"`
	RoomID    string    `json:"room_id"`
	Role      string    `json:"role"` // owner, admin, moderator, member
	JoinedAt  time.Time `json:"joined_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// GetUserRoles 获取用户的所有角色
func (r *PermissionRepository) GetUserRoles(userID string) ([]Role, error) {
	query := `
		SELECT r.id, r.name, r.description, r.created_at, r.updated_at
		FROM roles r
		INNER JOIN user_roles ur ON r.id = ur.role_id
		WHERE ur.user_id = $1
	`

	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []Role
	for rows.Next() {
		var role Role
		err := rows.Scan(&role.ID, &role.Name, &role.Description, &role.CreatedAt, &role.UpdatedAt)
		if err != nil {
			return nil, err
		}

		// 获取角色的权限
		perms, err := r.GetRolePermissions(role.ID)
		if err != nil {
			return nil, err
		}
		role.Permissions = perms

		roles = append(roles, role)
	}

	return roles, rows.Err()
}

// GetRolePermissions 获取角色的权限列表
func (r *PermissionRepository) GetRolePermissions(roleID string) ([]string, error) {
	query := `
		SELECT p.name
		FROM permissions p
		INNER JOIN role_permissions rp ON p.id = rp.permission_id
		WHERE rp.role_id = $1
	`

	rows, err := r.db.Query(query, roleID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var permissions []string
	for rows.Next() {
		var perm string
		if err := rows.Scan(&perm); err != nil {
			return nil, err
		}
		permissions = append(permissions, perm)
	}

	return permissions, rows.Err()
}

// GetRoomMember 获取群组成员信息
func (r *PermissionRepository) GetRoomMember(userID, roomID string) (*RoomMember, error) {
	query := `
		SELECT user_id, room_id, role, joined_at, updated_at
		FROM room_members
		WHERE user_id = $1 AND room_id = $2
	`

	member := &RoomMember{}
	err := r.db.QueryRow(query, userID, roomID).Scan(
		&member.UserID,
		&member.RoomID,
		&member.Role,
		&member.JoinedAt,
		&member.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return member, nil
}

// UpdateRoomMemberRole 更新群组成员角色
func (r *PermissionRepository) UpdateRoomMemberRole(userID, roomID, role string) error {
	query := `
		UPDATE room_members
		SET role = $1, updated_at = NOW()
		WHERE user_id = $2 AND room_id = $3
	`

	_, err := r.db.Exec(query, role, userID, roomID)
	return err
}

// GetRoomMembers 获取群组所有成员
func (r *PermissionRepository) GetRoomMembers(roomID string) ([]RoomMember, error) {
	query := `
		SELECT user_id, room_id, role, joined_at, updated_at
		FROM room_members
		WHERE room_id = $1
		ORDER BY role, joined_at
	`

	rows, err := r.db.Query(query, roomID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []RoomMember
	for rows.Next() {
		var member RoomMember
		err := rows.Scan(&member.UserID, &member.RoomID, &member.Role, &member.JoinedAt, &member.UpdatedAt)
		if err != nil {
			return nil, err
		}
		members = append(members, member)
	}

	return members, rows.Err()
}

// AddRoomMember 添加群组成员
func (r *PermissionRepository) AddRoomMember(userID, roomID, role string) error {
	query := `
		INSERT INTO room_members (user_id, room_id, role, joined_at, updated_at)
		VALUES ($1, $2, $3, NOW(), NOW())
		ON CONFLICT (user_id, room_id) DO UPDATE
		SET role = EXCLUDED.role, updated_at = NOW()
	`

	_, err := r.db.Exec(query, userID, roomID, role)
	return err
}

// RemoveRoomMember 移除群组成员
func (r *PermissionRepository) RemoveRoomMember(userID, roomID string) error {
	query := `DELETE FROM room_members WHERE user_id = $1 AND room_id = $2`
	_, err := r.db.Exec(query, userID, roomID)
	return err
}

// HasPermission 检查用户是否有特定权限
func (r *PermissionRepository) HasPermission(userID, permission string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1
			FROM user_roles ur
			INNER JOIN role_permissions rp ON ur.role_id = rp.role_id
			INNER JOIN permissions p ON rp.permission_id = p.id
			WHERE ur.user_id = $1 AND p.name = $2
		)
	`

	var exists bool
	err := r.db.QueryRow(query, userID, permission).Scan(&exists)
	return exists, err
}

// CreateRole 创建角色
func (r *PermissionRepository) CreateRole(name, description string) (*Role, error) {
	query := `
		INSERT INTO roles (name, description, created_at, updated_at)
		VALUES ($1, $2, NOW(), NOW())
		RETURNING id, name, description, created_at, updated_at
	`

	role := &Role{}
	err := r.db.QueryRow(query, name, description).Scan(
		&role.ID, &role.Name, &role.Description, &role.CreatedAt, &role.UpdatedAt,
	)
	return role, err
}

// AssignRoleToUser 给用户分配角色
func (r *PermissionRepository) AssignRoleToUser(userID, roleID string) error {
	query := `
		INSERT INTO user_roles (user_id, role_id, created_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id, role_id) DO NOTHING
	`

	_, err := r.db.Exec(query, userID, roleID)
	return err
}

// RemoveRoleFromUser 移除用户角色
func (r *PermissionRepository) RemoveRoleFromUser(userID, roleID string) error {
	query := `DELETE FROM user_roles WHERE user_id = $1 AND role_id = $2`
	_, err := r.db.Exec(query, userID, roleID)
	return err
}
