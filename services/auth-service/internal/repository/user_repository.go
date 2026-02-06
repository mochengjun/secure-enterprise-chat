package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	UserID       string    `gorm:"column:user_id;primaryKey" json:"user_id"`
	Username     string    `gorm:"column:username;uniqueIndex;not null" json:"username"`
	PasswordHash string    `gorm:"column:password_hash;not null" json:"-"`
	PhoneNumber  *string   `gorm:"column:phone_number;uniqueIndex" json:"phone_number,omitempty"`
	Email        *string   `gorm:"column:email" json:"email,omitempty"`
	DisplayName  *string   `gorm:"column:display_name" json:"display_name,omitempty"`
	AvatarURL    *string   `gorm:"column:avatar_url" json:"avatar_url,omitempty"`
	MFAEnabled   bool      `gorm:"column:mfa_enabled;default:false" json:"mfa_enabled"`
	MFASecret    *string   `gorm:"column:mfa_secret" json:"-"`
	IsActive     bool      `gorm:"column:is_active;default:true" json:"is_active"`
	CreatedAt    time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	UpdatedAt    time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updated_at"`
}

func (User) TableName() string {
	return "users"
}

// UserRepository 用户仓库接口
type UserRepository interface {
	Create(ctx context.Context, user *User) error
	GetByID(ctx context.Context, userID string) (*User, error)
	GetByUsername(ctx context.Context, username string) (*User, error)
	GetByPhoneNumber(ctx context.Context, phone string) (*User, error)
	Update(ctx context.Context, user *User) error
	UpdatePassword(ctx context.Context, userID, passwordHash string) error
	UpdateMFA(ctx context.Context, userID string, enabled bool, secret *string) error
	Delete(ctx context.Context, userID string) error
	List(ctx context.Context, offset, limit int) ([]User, int64, error)
	SearchUsers(ctx context.Context, query string, limit int) ([]User, error)
}

type userRepository struct {
	db *gorm.DB
}

// NewUserRepository 创建用户仓库实例
func NewUserRepository(db *gorm.DB) UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) Create(ctx context.Context, user *User) error {
	return r.db.WithContext(ctx).Create(user).Error
}

func (r *userRepository) GetByID(ctx context.Context, userID string) (*User, error) {
	var user User
	if err := r.db.WithContext(ctx).Where("user_id = ? AND is_active = ?", userID, true).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) GetByUsername(ctx context.Context, username string) (*User, error) {
	var user User
	if err := r.db.WithContext(ctx).Where("username = ? AND is_active = ?", username, true).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) GetByPhoneNumber(ctx context.Context, phone string) (*User, error) {
	var user User
	if err := r.db.WithContext(ctx).Where("phone_number = ? AND is_active = ?", phone, true).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) Update(ctx context.Context, user *User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

func (r *userRepository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	return r.db.WithContext(ctx).Model(&User{}).Where("user_id = ?", userID).Update("password_hash", passwordHash).Error
}

func (r *userRepository) UpdateMFA(ctx context.Context, userID string, enabled bool, secret *string) error {
	updates := map[string]interface{}{
		"mfa_enabled": enabled,
		"mfa_secret":  secret,
	}
	return r.db.WithContext(ctx).Model(&User{}).Where("user_id = ?", userID).Updates(updates).Error
}

func (r *userRepository) Delete(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Model(&User{}).Where("user_id = ?", userID).Update("is_active", false).Error
}

func (r *userRepository) List(ctx context.Context, offset, limit int) ([]User, int64, error) {
	var users []User
	var total int64

	if err := r.db.WithContext(ctx).Model(&User{}).Where("is_active = ?", true).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := r.db.WithContext(ctx).Where("is_active = ?", true).Offset(offset).Limit(limit).Find(&users).Error; err != nil {
		return nil, 0, err
	}

	return users, total, nil
}

func (r *userRepository) SearchUsers(ctx context.Context, query string, limit int) ([]User, error) {
	var users []User
	searchPattern := "%" + query + "%"

	err := r.db.WithContext(ctx).
		Where("is_active = ?", true).
		Where("username LIKE ? OR display_name LIKE ? OR email LIKE ?", searchPattern, searchPattern, searchPattern).
		Limit(limit).
		Find(&users).Error

	if err != nil {
		return nil, err
	}
	return users, nil
}
