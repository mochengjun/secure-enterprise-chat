package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// KeyType 密钥类型
type KeyType string

const (
	KeyTypeIdentity KeyType = "identity" // 身份密钥（长期）
	KeyTypeSigned   KeyType = "signed"   // 签名预密钥（中期）
	KeyTypeOneTime  KeyType = "one_time" // 一次性预密钥
	KeyTypeSession  KeyType = "session"  // 会话密钥
)

// DeviceKey 设备密钥（X3DH密钥包）
type DeviceKey struct {
	ID        uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID    string     `gorm:"size:255;index" json:"user_id"`
	DeviceID  string     `gorm:"size:64;index" json:"device_id"`
	KeyType   KeyType    `gorm:"size:32;index" json:"key_type"`
	KeyID     string     `gorm:"size:64;uniqueIndex" json:"key_id"`   // 密钥标识符
	PublicKey string     `gorm:"size:512" json:"public_key"`          // Base64编码的公钥
	Signature string     `gorm:"size:512" json:"signature,omitempty"` // 签名（用于签名预密钥）
	IsUsed    bool       `gorm:"default:false" json:"is_used"`        // 一次性密钥是否已使用
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
	CreatedAt time.Time  `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time  `gorm:"autoUpdateTime" json:"updated_at"`
}

// SessionKey 会话密钥（Double Ratchet状态）
type SessionKey struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	SessionID         string    `gorm:"size:64;uniqueIndex" json:"session_id"`
	UserID            string    `gorm:"size:255;index" json:"user_id"`      // 本地用户
	PeerUserID        string    `gorm:"size:255;index" json:"peer_user_id"` // 对方用户
	PeerDeviceID      string    `gorm:"size:64" json:"peer_device_id"`      // 对方设备
	RootKey           string    `gorm:"size:512" json:"-"`                  // 根密钥（加密存储）
	ChainKeySend      string    `gorm:"size:512" json:"-"`                  // 发送链密钥
	ChainKeyReceive   string    `gorm:"size:512" json:"-"`                  // 接收链密钥
	SendMessageNumber int       `gorm:"default:0" json:"send_message_number"`
	RecvMessageNumber int       `gorm:"default:0" json:"recv_message_number"`
	DHRatchetKey      string    `gorm:"size:512" json:"-"`           // DH棘轮密钥
	PeerDHKey         string    `gorm:"size:512" json:"peer_dh_key"` // 对方当前DH公钥
	Status            string    `gorm:"size:32" json:"status"`       // active, expired
	CreatedAt         time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt         time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

// EncryptedMessage 加密消息记录
type EncryptedMessage struct {
	ID                  uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	MessageID           string    `gorm:"size:64;uniqueIndex" json:"message_id"`
	SessionID           string    `gorm:"size:64;index" json:"session_id"`
	SenderID            string    `gorm:"size:255;index" json:"sender_id"`
	RecipientID         string    `gorm:"size:255;index" json:"recipient_id"`
	CipherText          string    `gorm:"type:text" json:"cipher_text"` // Base64编码的密文
	MessageNumber       int       `json:"message_number"`
	PreviousChainLength int       `json:"previous_chain_length"`
	DHPublicKey         string    `gorm:"size:512" json:"dh_public_key"` // 发送者当前DH公钥
	IV                  string    `gorm:"size:64" json:"iv"`             // 初始化向量
	AuthTag             string    `gorm:"size:64" json:"auth_tag"`       // 认证标签
	CreatedAt           time.Time `gorm:"autoCreateTime" json:"created_at"`
}

// KeyExchangeMessage 密钥交换消息（X3DH初始消息）
type KeyExchangeMessage struct {
	ID                 uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	FromUserID         string    `gorm:"size:255;index" json:"from_user_id"`
	FromDeviceID       string    `gorm:"size:64" json:"from_device_id"`
	ToUserID           string    `gorm:"size:255;index" json:"to_user_id"`
	ToDeviceID         string    `gorm:"size:64" json:"to_device_id"`
	EphemeralPublicKey string    `gorm:"size:512" json:"ephemeral_public_key"`          // 临时公钥
	IdentityPublicKey  string    `gorm:"size:512" json:"identity_public_key"`           // 发送者身份公钥
	UsedOneTimeKeyID   string    `gorm:"size:64" json:"used_one_time_key_id,omitempty"` // 使用的一次性密钥ID
	UsedSignedKeyID    string    `gorm:"size:64" json:"used_signed_key_id"`             // 使用的签名预密钥ID
	InitialCipherText  string    `gorm:"type:text" json:"initial_cipher_text"`          // 初始加密消息
	Status             string    `gorm:"size:32" json:"status"`                         // pending, accepted, rejected
	CreatedAt          time.Time `gorm:"autoCreateTime" json:"created_at"`
}

// E2EERepository 端到端加密仓库接口
type E2EERepository interface {
	// 设备密钥管理
	SaveDeviceKey(ctx context.Context, key *DeviceKey) error
	GetDeviceKey(ctx context.Context, keyID string) (*DeviceKey, error)
	GetIdentityKey(ctx context.Context, userID, deviceID string) (*DeviceKey, error)
	GetSignedPreKey(ctx context.Context, userID, deviceID string) (*DeviceKey, error)
	GetOneTimePreKeys(ctx context.Context, userID, deviceID string, count int) ([]*DeviceKey, error)
	MarkOneTimeKeyUsed(ctx context.Context, keyID string) error
	DeleteExpiredKeys(ctx context.Context) (int, error)
	GetKeyBundle(ctx context.Context, userID string) (*KeyBundle, error)
	GetDeviceKeys(ctx context.Context, userID, deviceID string) ([]*DeviceKey, error)
	DeleteDeviceKeys(ctx context.Context, userID, deviceID string) error

	// 会话密钥管理
	SaveSessionKey(ctx context.Context, session *SessionKey) error
	GetSessionKey(ctx context.Context, sessionID string) (*SessionKey, error)
	GetSessionByPeer(ctx context.Context, userID, peerUserID, peerDeviceID string) (*SessionKey, error)
	UpdateSessionKey(ctx context.Context, session *SessionKey) error
	ListActiveSessions(ctx context.Context, userID string) ([]*SessionKey, error)
	ExpireSession(ctx context.Context, sessionID string) error

	// 加密消息
	SaveEncryptedMessage(ctx context.Context, msg *EncryptedMessage) error
	GetEncryptedMessage(ctx context.Context, messageID string) (*EncryptedMessage, error)

	// 密钥交换
	SaveKeyExchange(ctx context.Context, exchange *KeyExchangeMessage) error
	GetPendingKeyExchanges(ctx context.Context, userID, deviceID string) ([]*KeyExchangeMessage, error)
	UpdateKeyExchangeStatus(ctx context.Context, id uint, status string) error
}

// KeyBundle 密钥包（用于X3DH）
type KeyBundle struct {
	UserID         string       `json:"user_id"`
	DeviceID       string       `json:"device_id"`
	IdentityKey    *DeviceKey   `json:"identity_key"`
	SignedPreKey   *DeviceKey   `json:"signed_pre_key"`
	OneTimePreKeys []*DeviceKey `json:"one_time_pre_keys,omitempty"`
}

// e2eeRepository 端到端加密仓库实现
type e2eeRepository struct {
	db *gorm.DB
}

// NewE2EERepository 创建E2EE仓库实例
func NewE2EERepository(db *gorm.DB) E2EERepository {
	return &e2eeRepository{db: db}
}

// SaveDeviceKey 保存设备密钥
func (r *e2eeRepository) SaveDeviceKey(ctx context.Context, key *DeviceKey) error {
	return r.db.WithContext(ctx).Save(key).Error
}

// GetDeviceKey 获取设备密钥
func (r *e2eeRepository) GetDeviceKey(ctx context.Context, keyID string) (*DeviceKey, error) {
	var key DeviceKey
	err := r.db.WithContext(ctx).Where("key_id = ?", keyID).First(&key).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &key, nil
}

// GetIdentityKey 获取身份密钥
func (r *e2eeRepository) GetIdentityKey(ctx context.Context, userID, deviceID string) (*DeviceKey, error) {
	var key DeviceKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND device_id = ? AND key_type = ?", userID, deviceID, KeyTypeIdentity).
		First(&key).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &key, nil
}

// GetSignedPreKey 获取签名预密钥
func (r *e2eeRepository) GetSignedPreKey(ctx context.Context, userID, deviceID string) (*DeviceKey, error) {
	var key DeviceKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND device_id = ? AND key_type = ? AND (expires_at IS NULL OR expires_at > ?)",
			userID, deviceID, KeyTypeSigned, time.Now()).
		Order("created_at DESC").
		First(&key).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &key, nil
}

// GetOneTimePreKeys 获取一次性预密钥
func (r *e2eeRepository) GetOneTimePreKeys(ctx context.Context, userID, deviceID string, count int) ([]*DeviceKey, error) {
	var keys []*DeviceKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND device_id = ? AND key_type = ? AND is_used = ?",
			userID, deviceID, KeyTypeOneTime, false).
		Limit(count).
		Find(&keys).Error
	return keys, err
}

// MarkOneTimeKeyUsed 标记一次性密钥已使用
func (r *e2eeRepository) MarkOneTimeKeyUsed(ctx context.Context, keyID string) error {
	return r.db.WithContext(ctx).Model(&DeviceKey{}).
		Where("key_id = ?", keyID).
		Update("is_used", true).Error
}

// DeleteExpiredKeys 删除过期密钥
func (r *e2eeRepository) DeleteExpiredKeys(ctx context.Context) (int, error) {
	result := r.db.WithContext(ctx).
		Where("expires_at IS NOT NULL AND expires_at < ?", time.Now()).
		Delete(&DeviceKey{})
	return int(result.RowsAffected), result.Error
}

// GetKeyBundle 获取密钥包
func (r *e2eeRepository) GetKeyBundle(ctx context.Context, userID string) (*KeyBundle, error) {
	// 获取用户的任一设备
	var identityKey DeviceKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND key_type = ?", userID, KeyTypeIdentity).
		First(&identityKey).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}

	deviceID := identityKey.DeviceID

	signedKey, _ := r.GetSignedPreKey(ctx, userID, deviceID)
	oneTimeKeys, _ := r.GetOneTimePreKeys(ctx, userID, deviceID, 10)

	return &KeyBundle{
		UserID:         userID,
		DeviceID:       deviceID,
		IdentityKey:    &identityKey,
		SignedPreKey:   signedKey,
		OneTimePreKeys: oneTimeKeys,
	}, nil
}

// GetDeviceKeys 获取设备所有密钥
func (r *e2eeRepository) GetDeviceKeys(ctx context.Context, userID, deviceID string) ([]*DeviceKey, error) {
	var keys []*DeviceKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND device_id = ?", userID, deviceID).
		Find(&keys).Error
	return keys, err
}

// DeleteDeviceKeys 删除设备密钥
func (r *e2eeRepository) DeleteDeviceKeys(ctx context.Context, userID, deviceID string) error {
	return r.db.WithContext(ctx).
		Where("user_id = ? AND device_id = ?", userID, deviceID).
		Delete(&DeviceKey{}).Error
}

// SaveSessionKey 保存会话密钥
func (r *e2eeRepository) SaveSessionKey(ctx context.Context, session *SessionKey) error {
	return r.db.WithContext(ctx).Create(session).Error
}

// GetSessionKey 获取会话密钥
func (r *e2eeRepository) GetSessionKey(ctx context.Context, sessionID string) (*SessionKey, error) {
	var session SessionKey
	err := r.db.WithContext(ctx).Where("session_id = ?", sessionID).First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &session, nil
}

// GetSessionByPeer 根据对端获取会话
func (r *e2eeRepository) GetSessionByPeer(ctx context.Context, userID, peerUserID, peerDeviceID string) (*SessionKey, error) {
	var session SessionKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND peer_user_id = ? AND peer_device_id = ? AND status = ?",
			userID, peerUserID, peerDeviceID, "active").
		First(&session).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &session, nil
}

// UpdateSessionKey 更新会话密钥
func (r *e2eeRepository) UpdateSessionKey(ctx context.Context, session *SessionKey) error {
	return r.db.WithContext(ctx).Save(session).Error
}

// ListActiveSessions 列出活跃会话
func (r *e2eeRepository) ListActiveSessions(ctx context.Context, userID string) ([]*SessionKey, error) {
	var sessions []*SessionKey
	err := r.db.WithContext(ctx).
		Where("user_id = ? AND status = ?", userID, "active").
		Find(&sessions).Error
	return sessions, err
}

// ExpireSession 过期会话
func (r *e2eeRepository) ExpireSession(ctx context.Context, sessionID string) error {
	return r.db.WithContext(ctx).Model(&SessionKey{}).
		Where("session_id = ?", sessionID).
		Update("status", "expired").Error
}

// SaveEncryptedMessage 保存加密消息
func (r *e2eeRepository) SaveEncryptedMessage(ctx context.Context, msg *EncryptedMessage) error {
	return r.db.WithContext(ctx).Create(msg).Error
}

// GetEncryptedMessage 获取加密消息
func (r *e2eeRepository) GetEncryptedMessage(ctx context.Context, messageID string) (*EncryptedMessage, error) {
	var msg EncryptedMessage
	err := r.db.WithContext(ctx).Where("message_id = ?", messageID).First(&msg).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &msg, nil
}

// SaveKeyExchange 保存密钥交换消息
func (r *e2eeRepository) SaveKeyExchange(ctx context.Context, exchange *KeyExchangeMessage) error {
	return r.db.WithContext(ctx).Create(exchange).Error
}

// GetPendingKeyExchanges 获取待处理的密钥交换
func (r *e2eeRepository) GetPendingKeyExchanges(ctx context.Context, userID, deviceID string) ([]*KeyExchangeMessage, error) {
	var exchanges []*KeyExchangeMessage
	err := r.db.WithContext(ctx).
		Where("to_user_id = ? AND to_device_id = ? AND status = ?", userID, deviceID, "pending").
		Find(&exchanges).Error
	return exchanges, err
}

// UpdateKeyExchangeStatus 更新密钥交换状态
func (r *e2eeRepository) UpdateKeyExchangeStatus(ctx context.Context, id uint, status string) error {
	return r.db.WithContext(ctx).Model(&KeyExchangeMessage{}).
		Where("id = ?", id).
		Update("status", status).Error
}
