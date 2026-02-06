package service

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/google/uuid"

	"sec-chat/auth-service/internal/repository"
)

// E2EEService 端到端加密服务接口
type E2EEService interface {
	// 密钥管理
	RegisterDeviceKeys(ctx context.Context, userID, deviceID string, keys *DeviceKeyBundle) error
	GetKeyBundle(ctx context.Context, targetUserID string) (*repository.KeyBundle, error)
	GetDeviceKeyBundle(ctx context.Context, userID, deviceID string) (*repository.KeyBundle, error)
	UploadOneTimePreKeys(ctx context.Context, userID, deviceID string, keys []*PreKeyUpload) error
	GetOneTimePreKeysCount(ctx context.Context, userID, deviceID string) (int, error)

	// 会话管理
	InitiateSession(ctx context.Context, userID, deviceID string, exchange *KeyExchangeRequest) (*KeyExchangeResponse, error)
	AcceptSession(ctx context.Context, userID, deviceID string, exchangeID uint) (*SessionInfo, error)
	GetSession(ctx context.Context, userID, peerUserID, peerDeviceID string) (*SessionInfo, error)
	ListSessions(ctx context.Context, userID string) ([]*SessionInfo, error)
	TerminateSession(ctx context.Context, userID, sessionID string) error

	// 消息加密支持
	StoreEncryptedMessage(ctx context.Context, msg *EncryptedMessageRequest) error
	GetEncryptedMessage(ctx context.Context, messageID string) (*repository.EncryptedMessage, error)

	// 密钥交换
	GetPendingKeyExchanges(ctx context.Context, userID, deviceID string) ([]*repository.KeyExchangeMessage, error)

	// 设备管理
	RevokeDeviceKeys(ctx context.Context, userID, deviceID string) error
}

// DeviceKeyBundle 设备密钥包（上传用）
type DeviceKeyBundle struct {
	IdentityKey    *PreKeyUpload       `json:"identity_key"`
	SignedPreKey   *SignedPreKeyUpload `json:"signed_pre_key"`
	OneTimePreKeys []*PreKeyUpload     `json:"one_time_pre_keys,omitempty"`
}

// PreKeyUpload 预密钥上传
type PreKeyUpload struct {
	KeyID     string `json:"key_id"`
	PublicKey string `json:"public_key"` // Base64编码
}

// SignedPreKeyUpload 签名预密钥上传
type SignedPreKeyUpload struct {
	KeyID     string `json:"key_id"`
	PublicKey string `json:"public_key"` // Base64编码
	Signature string `json:"signature"`  // Base64编码
}

// KeyExchangeRequest 密钥交换请求（X3DH）
type KeyExchangeRequest struct {
	TargetUserID       string `json:"target_user_id"`
	TargetDeviceID     string `json:"target_device_id,omitempty"`     // 可选，不指定则选择任意设备
	EphemeralPublicKey string `json:"ephemeral_public_key"`           // 临时公钥
	IdentityPublicKey  string `json:"identity_public_key"`            // 发送者身份公钥
	UsedSignedKeyID    string `json:"used_signed_key_id"`             // 使用的对方签名预密钥ID
	UsedOneTimeKeyID   string `json:"used_one_time_key_id,omitempty"` // 使用的对方一次性密钥ID
	InitialCipherText  string `json:"initial_cipher_text"`            // 初始加密消息
}

// KeyExchangeResponse 密钥交换响应
type KeyExchangeResponse struct {
	ExchangeID        uint   `json:"exchange_id"`
	SessionID         string `json:"session_id"`
	TargetDeviceID    string `json:"target_device_id"`
	TargetIdentityKey string `json:"target_identity_key"`
	UsedSignedKeyID   string `json:"used_signed_key_id"`
	UsedOneTimeKeyID  string `json:"used_one_time_key_id,omitempty"`
}

// SessionInfo 会话信息
type SessionInfo struct {
	SessionID      string    `json:"session_id"`
	PeerUserID     string    `json:"peer_user_id"`
	PeerDeviceID   string    `json:"peer_device_id"`
	Status         string    `json:"status"`
	CreatedAt      time.Time `json:"created_at"`
	LastActivityAt time.Time `json:"last_activity_at"`
}

// EncryptedMessageRequest 加密消息请求
type EncryptedMessageRequest struct {
	MessageID           string `json:"message_id"`
	SessionID           string `json:"session_id"`
	RecipientID         string `json:"recipient_id"`
	CipherText          string `json:"cipher_text"`
	MessageNumber       int    `json:"message_number"`
	PreviousChainLength int    `json:"previous_chain_length"`
	DHPublicKey         string `json:"dh_public_key"`
	IV                  string `json:"iv"`
	AuthTag             string `json:"auth_tag"`
}

// e2eeService E2EE服务实现
type e2eeService struct {
	repo repository.E2EERepository
}

// NewE2EEService 创建E2EE服务实例
func NewE2EEService(repo repository.E2EERepository) E2EEService {
	return &e2eeService{repo: repo}
}

// RegisterDeviceKeys 注册设备密钥
func (s *e2eeService) RegisterDeviceKeys(ctx context.Context, userID, deviceID string, keys *DeviceKeyBundle) error {
	// 删除旧密钥
	s.repo.DeleteDeviceKeys(ctx, userID, deviceID)

	// 保存身份密钥
	if keys.IdentityKey != nil {
		identityKey := &repository.DeviceKey{
			UserID:    userID,
			DeviceID:  deviceID,
			KeyType:   repository.KeyTypeIdentity,
			KeyID:     keys.IdentityKey.KeyID,
			PublicKey: keys.IdentityKey.PublicKey,
		}
		if err := s.repo.SaveDeviceKey(ctx, identityKey); err != nil {
			return fmt.Errorf("failed to save identity key: %w", err)
		}
	}

	// 保存签名预密钥
	if keys.SignedPreKey != nil {
		// 签名预密钥有效期30天
		expiresAt := time.Now().Add(30 * 24 * time.Hour)
		signedKey := &repository.DeviceKey{
			UserID:    userID,
			DeviceID:  deviceID,
			KeyType:   repository.KeyTypeSigned,
			KeyID:     keys.SignedPreKey.KeyID,
			PublicKey: keys.SignedPreKey.PublicKey,
			Signature: keys.SignedPreKey.Signature,
			ExpiresAt: &expiresAt,
		}
		if err := s.repo.SaveDeviceKey(ctx, signedKey); err != nil {
			return fmt.Errorf("failed to save signed pre-key: %w", err)
		}
	}

	// 保存一次性预密钥
	for _, otk := range keys.OneTimePreKeys {
		oneTimeKey := &repository.DeviceKey{
			UserID:    userID,
			DeviceID:  deviceID,
			KeyType:   repository.KeyTypeOneTime,
			KeyID:     otk.KeyID,
			PublicKey: otk.PublicKey,
			IsUsed:    false,
		}
		if err := s.repo.SaveDeviceKey(ctx, oneTimeKey); err != nil {
			return fmt.Errorf("failed to save one-time key: %w", err)
		}
	}

	return nil
}

// GetKeyBundle 获取用户密钥包
func (s *e2eeService) GetKeyBundle(ctx context.Context, targetUserID string) (*repository.KeyBundle, error) {
	return s.repo.GetKeyBundle(ctx, targetUserID)
}

// GetDeviceKeyBundle 获取特定设备密钥包
func (s *e2eeService) GetDeviceKeyBundle(ctx context.Context, userID, deviceID string) (*repository.KeyBundle, error) {
	identityKey, err := s.repo.GetIdentityKey(ctx, userID, deviceID)
	if err != nil {
		return nil, fmt.Errorf("failed to get identity key: %w", err)
	}
	if identityKey == nil {
		return nil, nil
	}

	signedKey, _ := s.repo.GetSignedPreKey(ctx, userID, deviceID)
	oneTimeKeys, _ := s.repo.GetOneTimePreKeys(ctx, userID, deviceID, 10)

	return &repository.KeyBundle{
		UserID:         userID,
		DeviceID:       deviceID,
		IdentityKey:    identityKey,
		SignedPreKey:   signedKey,
		OneTimePreKeys: oneTimeKeys,
	}, nil
}

// UploadOneTimePreKeys 上传一次性预密钥
func (s *e2eeService) UploadOneTimePreKeys(ctx context.Context, userID, deviceID string, keys []*PreKeyUpload) error {
	for _, key := range keys {
		oneTimeKey := &repository.DeviceKey{
			UserID:    userID,
			DeviceID:  deviceID,
			KeyType:   repository.KeyTypeOneTime,
			KeyID:     key.KeyID,
			PublicKey: key.PublicKey,
			IsUsed:    false,
		}
		if err := s.repo.SaveDeviceKey(ctx, oneTimeKey); err != nil {
			return fmt.Errorf("failed to save one-time key %s: %w", key.KeyID, err)
		}
	}
	return nil
}

// GetOneTimePreKeysCount 获取一次性预密钥数量
func (s *e2eeService) GetOneTimePreKeysCount(ctx context.Context, userID, deviceID string) (int, error) {
	keys, err := s.repo.GetOneTimePreKeys(ctx, userID, deviceID, 1000)
	if err != nil {
		return 0, err
	}
	return len(keys), nil
}

// InitiateSession 发起会话（X3DH）
func (s *e2eeService) InitiateSession(ctx context.Context, userID, deviceID string, req *KeyExchangeRequest) (*KeyExchangeResponse, error) {
	// 获取目标用户的密钥包
	var targetBundle *repository.KeyBundle
	var err error

	if req.TargetDeviceID != "" {
		targetBundle, err = s.GetDeviceKeyBundle(ctx, req.TargetUserID, req.TargetDeviceID)
	} else {
		targetBundle, err = s.GetKeyBundle(ctx, req.TargetUserID)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to get target key bundle: %w", err)
	}
	if targetBundle == nil || targetBundle.IdentityKey == nil {
		return nil, fmt.Errorf("target user has no encryption keys")
	}

	// 验证使用的签名预密钥ID
	if targetBundle.SignedPreKey == nil || targetBundle.SignedPreKey.KeyID != req.UsedSignedKeyID {
		return nil, fmt.Errorf("invalid signed pre-key ID")
	}

	// 如果使用了一次性密钥，标记为已使用
	if req.UsedOneTimeKeyID != "" {
		found := false
		for _, otk := range targetBundle.OneTimePreKeys {
			if otk.KeyID == req.UsedOneTimeKeyID {
				found = true
				s.repo.MarkOneTimeKeyUsed(ctx, req.UsedOneTimeKeyID)
				break
			}
		}
		if !found {
			return nil, fmt.Errorf("invalid one-time pre-key ID")
		}
	}

	// 创建密钥交换记录
	exchange := &repository.KeyExchangeMessage{
		FromUserID:         userID,
		FromDeviceID:       deviceID,
		ToUserID:           req.TargetUserID,
		ToDeviceID:         targetBundle.DeviceID,
		EphemeralPublicKey: req.EphemeralPublicKey,
		IdentityPublicKey:  req.IdentityPublicKey,
		UsedSignedKeyID:    req.UsedSignedKeyID,
		UsedOneTimeKeyID:   req.UsedOneTimeKeyID,
		InitialCipherText:  req.InitialCipherText,
		Status:             "pending",
	}

	if err := s.repo.SaveKeyExchange(ctx, exchange); err != nil {
		return nil, fmt.Errorf("failed to save key exchange: %w", err)
	}

	// 生成会话ID
	sessionID := generateSessionID()

	return &KeyExchangeResponse{
		ExchangeID:        exchange.ID,
		SessionID:         sessionID,
		TargetDeviceID:    targetBundle.DeviceID,
		TargetIdentityKey: targetBundle.IdentityKey.PublicKey,
		UsedSignedKeyID:   req.UsedSignedKeyID,
		UsedOneTimeKeyID:  req.UsedOneTimeKeyID,
	}, nil
}

// AcceptSession 接受会话
func (s *e2eeService) AcceptSession(ctx context.Context, userID, deviceID string, exchangeID uint) (*SessionInfo, error) {
	// 更新密钥交换状态
	if err := s.repo.UpdateKeyExchangeStatus(ctx, exchangeID, "accepted"); err != nil {
		return nil, fmt.Errorf("failed to update key exchange: %w", err)
	}

	// 会话密钥的实际创建在客户端完成
	// 这里只返回会话信息占位

	return &SessionInfo{
		SessionID:      generateSessionID(),
		Status:         "active",
		CreatedAt:      time.Now(),
		LastActivityAt: time.Now(),
	}, nil
}

// GetSession 获取会话
func (s *e2eeService) GetSession(ctx context.Context, userID, peerUserID, peerDeviceID string) (*SessionInfo, error) {
	session, err := s.repo.GetSessionByPeer(ctx, userID, peerUserID, peerDeviceID)
	if err != nil {
		return nil, err
	}
	if session == nil {
		return nil, nil
	}

	return &SessionInfo{
		SessionID:      session.SessionID,
		PeerUserID:     session.PeerUserID,
		PeerDeviceID:   session.PeerDeviceID,
		Status:         session.Status,
		CreatedAt:      session.CreatedAt,
		LastActivityAt: session.UpdatedAt,
	}, nil
}

// ListSessions 列出会话
func (s *e2eeService) ListSessions(ctx context.Context, userID string) ([]*SessionInfo, error) {
	sessions, err := s.repo.ListActiveSessions(ctx, userID)
	if err != nil {
		return nil, err
	}

	result := make([]*SessionInfo, len(sessions))
	for i, session := range sessions {
		result[i] = &SessionInfo{
			SessionID:      session.SessionID,
			PeerUserID:     session.PeerUserID,
			PeerDeviceID:   session.PeerDeviceID,
			Status:         session.Status,
			CreatedAt:      session.CreatedAt,
			LastActivityAt: session.UpdatedAt,
		}
	}

	return result, nil
}

// TerminateSession 终止会话
func (s *e2eeService) TerminateSession(ctx context.Context, userID, sessionID string) error {
	return s.repo.ExpireSession(ctx, sessionID)
}

// StoreEncryptedMessage 存储加密消息
func (s *e2eeService) StoreEncryptedMessage(ctx context.Context, req *EncryptedMessageRequest) error {
	msg := &repository.EncryptedMessage{
		MessageID:           req.MessageID,
		SessionID:           req.SessionID,
		SenderID:            "", // 由调用方设置
		RecipientID:         req.RecipientID,
		CipherText:          req.CipherText,
		MessageNumber:       req.MessageNumber,
		PreviousChainLength: req.PreviousChainLength,
		DHPublicKey:         req.DHPublicKey,
		IV:                  req.IV,
		AuthTag:             req.AuthTag,
	}

	return s.repo.SaveEncryptedMessage(ctx, msg)
}

// GetEncryptedMessage 获取加密消息
func (s *e2eeService) GetEncryptedMessage(ctx context.Context, messageID string) (*repository.EncryptedMessage, error) {
	return s.repo.GetEncryptedMessage(ctx, messageID)
}

// GetPendingKeyExchanges 获取待处理的密钥交换
func (s *e2eeService) GetPendingKeyExchanges(ctx context.Context, userID, deviceID string) ([]*repository.KeyExchangeMessage, error) {
	return s.repo.GetPendingKeyExchanges(ctx, userID, deviceID)
}

// RevokeDeviceKeys 撤销设备密钥
func (s *e2eeService) RevokeDeviceKeys(ctx context.Context, userID, deviceID string) error {
	return s.repo.DeleteDeviceKeys(ctx, userID, deviceID)
}

// generateSessionID 生成会话ID
func generateSessionID() string {
	return uuid.New().String()
}

// generateRandomBytes 生成随机字节
func generateRandomBytes(n int) ([]byte, error) {
	b := make([]byte, n)
	_, err := rand.Read(b)
	return b, err
}

// generateRandomBase64 生成随机Base64字符串
func generateRandomBase64(n int) (string, error) {
	b, err := generateRandomBytes(n)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(b), nil
}
