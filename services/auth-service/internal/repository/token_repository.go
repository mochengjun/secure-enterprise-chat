package repository

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

// RefreshToken 刷新令牌模型
type RefreshToken struct {
	ID        uint       `gorm:"primaryKey" json:"id"`
	TokenHash string     `gorm:"column:token_hash;uniqueIndex;not null" json:"-"`
	UserID    string     `gorm:"column:user_id;index" json:"user_id"`
	DeviceID  string     `gorm:"column:device_id" json:"device_id"`
	ExpiresAt time.Time  `gorm:"column:expires_at;not null" json:"expires_at"`
	CreatedAt time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
	RevokedAt *time.Time `gorm:"column:revoked_at" json:"revoked_at,omitempty"`
}

func (RefreshToken) TableName() string {
	return "refresh_tokens"
}

// TokenBlacklist Token 黑名单
type TokenBlacklist struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	TokenHash string    `gorm:"column:token_hash;uniqueIndex;not null" json:"-"`
	ExpiresAt time.Time `gorm:"column:expires_at;not null" json:"expires_at"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

func (TokenBlacklist) TableName() string {
	return "token_blacklist"
}

// TokenRepository Token 仓库接口
type TokenRepository interface {
	// Refresh Token 操作
	SaveRefreshToken(ctx context.Context, token *RefreshToken) error
	GetRefreshToken(ctx context.Context, tokenHash string) (*RefreshToken, error)
	RevokeRefreshToken(ctx context.Context, tokenHash string) error
	RevokeAllUserTokens(ctx context.Context, userID string) error
	RevokeDeviceTokens(ctx context.Context, deviceID string) error
	CleanExpiredTokens(ctx context.Context) error

	// Token 黑名单操作
	AddToBlacklist(ctx context.Context, tokenHash string, expiresAt time.Time) error
	IsBlacklisted(ctx context.Context, tokenHash string) (bool, error)
	CleanExpiredBlacklist(ctx context.Context) error

	// 辅助方法
	HashToken(token string) string
}

type tokenRepository struct {
	db    *gorm.DB
	redis *redis.Client
}

// NewTokenRepository 创建 Token 仓库实例
func NewTokenRepository(db *gorm.DB, redis *redis.Client) TokenRepository {
	return &tokenRepository{db: db, redis: redis}
}

// NewTokenRepositoryWithoutRedis 创建不依赖 Redis 的 Token 仓库实例
func NewTokenRepositoryWithoutRedis(db *gorm.DB) TokenRepository {
	return &tokenRepository{db: db, redis: nil}
}

func (r *tokenRepository) HashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

func (r *tokenRepository) SaveRefreshToken(ctx context.Context, token *RefreshToken) error {
	return r.db.WithContext(ctx).Create(token).Error
}

func (r *tokenRepository) GetRefreshToken(ctx context.Context, tokenHash string) (*RefreshToken, error) {
	var token RefreshToken
	if err := r.db.WithContext(ctx).Where("token_hash = ? AND revoked_at IS NULL AND expires_at > ?", tokenHash, time.Now()).First(&token).Error; err != nil {
		return nil, err
	}
	return &token, nil
}

func (r *tokenRepository) RevokeRefreshToken(ctx context.Context, tokenHash string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&RefreshToken{}).Where("token_hash = ?", tokenHash).Update("revoked_at", now).Error
}

func (r *tokenRepository) RevokeAllUserTokens(ctx context.Context, userID string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&RefreshToken{}).Where("user_id = ? AND revoked_at IS NULL", userID).Update("revoked_at", now).Error
}

func (r *tokenRepository) RevokeDeviceTokens(ctx context.Context, deviceID string) error {
	now := time.Now()
	return r.db.WithContext(ctx).Model(&RefreshToken{}).Where("device_id = ? AND revoked_at IS NULL", deviceID).Update("revoked_at", now).Error
}

func (r *tokenRepository) CleanExpiredTokens(ctx context.Context) error {
	return r.db.WithContext(ctx).Where("expires_at < ?", time.Now()).Delete(&RefreshToken{}).Error
}

func (r *tokenRepository) AddToBlacklist(ctx context.Context, tokenHash string, expiresAt time.Time) error {
	// 存入数据库
	blacklist := &TokenBlacklist{
		TokenHash: tokenHash,
		ExpiresAt: expiresAt,
	}
	if err := r.db.WithContext(ctx).Create(blacklist).Error; err != nil {
		return err
	}

	// 如果 Redis 可用，也存入 Redis
	if r.redis != nil {
		key := fmt.Sprintf("blacklist:%s", tokenHash)
		ttl := time.Until(expiresAt)
		if ttl > 0 {
			return r.redis.Set(ctx, key, "1", ttl).Err()
		}
	}
	return nil
}

func (r *tokenRepository) IsBlacklisted(ctx context.Context, tokenHash string) (bool, error) {
	// 如果 Redis 可用，先检查 Redis
	if r.redis != nil {
		key := fmt.Sprintf("blacklist:%s", tokenHash)
		exists, err := r.redis.Exists(ctx, key).Result()
		if err == nil && exists > 0 {
			return true, nil
		}
	}

	// 检查数据库
	var count int64
	if err := r.db.WithContext(ctx).Model(&TokenBlacklist{}).Where("token_hash = ? AND expires_at > ?", tokenHash, time.Now()).Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func (r *tokenRepository) CleanExpiredBlacklist(ctx context.Context) error {
	return r.db.WithContext(ctx).Where("expires_at < ?", time.Now()).Delete(&TokenBlacklist{}).Error
}
