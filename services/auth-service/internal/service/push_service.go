package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	"sec-chat/auth-service/internal/repository"
)

var (
	ErrPushDisabled    = errors.New("push notifications disabled for user")
	ErrNoActiveTokens  = errors.New("no active push tokens found")
	ErrInvalidPlatform = errors.New("invalid push platform")
	ErrQuietHours      = errors.New("user is in quiet hours")
)

// FCMConfig Firebase Cloud Messaging 配置
type FCMConfig struct {
	ServerKey string // FCM Server Key (Legacy) 或 Service Account JSON path
	ProjectID string
	UseV1API  bool // 是否使用 FCM v1 API
}

// APNsConfig Apple Push Notification service 配置
type APNsConfig struct {
	KeyID      string // APNs Key ID
	TeamID     string // Apple Developer Team ID
	BundleID   string // App Bundle ID
	KeyPath    string // .p8 私钥文件路径
	Production bool   // 是否生产环境
}

// PushConfig 推送服务配置
type PushConfig struct {
	FCM  *FCMConfig
	APNs *APNsConfig
}

// PushPayload 推送消息载体
type PushPayload struct {
	UserID    string
	Type      repository.PushNotificationType
	Title     string
	Body      string
	Data      map[string]string
	ImageURL  string
	Sound     string
	Badge     int
	RoomID    string // 可选，用于消息推送
	MessageID string // 可选，原始消息ID
}

// PushResult 推送结果
type PushResult struct {
	TokenID      uint
	Platform     repository.PushPlatform
	Success      bool
	MessageID    string
	ErrorMessage string
}

// PushService 推送服务接口
type PushService interface {
	// Token 管理
	RegisterToken(ctx context.Context, userID, deviceID string, platform repository.PushPlatform, token string) error
	UnregisterToken(ctx context.Context, token string) error

	// 推送发送
	SendToUser(ctx context.Context, payload *PushPayload) ([]PushResult, error)
	SendToDevice(ctx context.Context, userID, deviceID string, payload *PushPayload) (*PushResult, error)
	SendToMultipleUsers(ctx context.Context, userIDs []string, payload *PushPayload) (map[string][]PushResult, error)

	// 便捷方法
	SendNewMessageNotification(ctx context.Context, userID, roomID, roomName, senderName, messagePreview string) error
	SendMentionNotification(ctx context.Context, userID, roomID, roomName, senderName string) error
	SendRoomInviteNotification(ctx context.Context, userID, roomID, roomName, inviterName string) error

	// 用户设置
	GetUserSettings(ctx context.Context, userID string) (*repository.UserPushSettings, error)
	UpdateUserSettings(ctx context.Context, settings *repository.UserPushSettings) error

	// 后台任务
	ProcessPendingNotifications(ctx context.Context) error
}

type pushService struct {
	pushRepo   repository.PushRepository
	config     *PushConfig
	httpClient *http.Client
	mu         sync.RWMutex
}

// NewPushService 创建推送服务实例
func NewPushService(pushRepo repository.PushRepository, config *PushConfig) PushService {
	return &pushService{
		pushRepo: pushRepo,
		config:   config,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// ====== Token 管理 ======

func (s *pushService) RegisterToken(ctx context.Context, userID, deviceID string, platform repository.PushPlatform, token string) error {
	pushToken := &repository.PushToken{
		UserID:    userID,
		DeviceID:  deviceID,
		Platform:  platform,
		Token:     token,
		IsActive:  true,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	return s.pushRepo.SaveToken(pushToken)
}

func (s *pushService) UnregisterToken(ctx context.Context, token string) error {
	return s.pushRepo.DeactivateToken(token)
}

// ====== 推送发送 ======

func (s *pushService) SendToUser(ctx context.Context, payload *PushPayload) ([]PushResult, error) {
	// 检查用户推送设置
	settings, err := s.pushRepo.GetUserSettings(payload.UserID)
	if err != nil {
		return nil, err
	}

	if !settings.EnablePush {
		return nil, ErrPushDisabled
	}

	// 检查免打扰时间
	if s.isInQuietHours(settings) {
		return nil, ErrQuietHours
	}

	// 获取用户所有活跃的推送 token
	tokens, err := s.pushRepo.GetActiveTokensByUser(payload.UserID)
	if err != nil {
		return nil, err
	}

	if len(tokens) == 0 {
		return nil, ErrNoActiveTokens
	}

	// 向所有设备发送推送
	var results []PushResult
	for _, token := range tokens {
		result := s.sendToToken(ctx, token, payload, settings)
		results = append(results, result)

		// 记录推送
		s.recordNotification(payload, token, result)
	}

	return results, nil
}

func (s *pushService) SendToDevice(ctx context.Context, userID, deviceID string, payload *PushPayload) (*PushResult, error) {
	token, err := s.pushRepo.GetTokenByDevice(userID, deviceID)
	if err != nil {
		return nil, err
	}

	settings, _ := s.pushRepo.GetUserSettings(userID)
	if settings == nil {
		settings = &repository.UserPushSettings{EnablePush: true, EnableSound: true}
	}

	result := s.sendToToken(ctx, token, payload, settings)
	s.recordNotification(payload, token, result)

	return &result, nil
}

func (s *pushService) SendToMultipleUsers(ctx context.Context, userIDs []string, payload *PushPayload) (map[string][]PushResult, error) {
	results := make(map[string][]PushResult)

	for _, userID := range userIDs {
		payload.UserID = userID
		userResults, err := s.SendToUser(ctx, payload)
		if err != nil {
			// 记录错误但继续处理其他用户
			results[userID] = []PushResult{{Success: false, ErrorMessage: err.Error()}}
			continue
		}
		results[userID] = userResults
	}

	return results, nil
}

// ====== 便捷方法 ======

func (s *pushService) SendNewMessageNotification(ctx context.Context, userID, roomID, roomName, senderName, messagePreview string) error {
	settings, _ := s.pushRepo.GetUserSettings(userID)

	body := messagePreview
	if settings != nil && !settings.EnablePreview {
		body = "您有一条新消息"
	}

	payload := &PushPayload{
		UserID: userID,
		Type:   repository.PushTypeNewMessage,
		Title:  fmt.Sprintf("%s - %s", roomName, senderName),
		Body:   body,
		Data: map[string]string{
			"type":    string(repository.PushTypeNewMessage),
			"room_id": roomID,
		},
		RoomID: roomID,
	}

	_, err := s.SendToUser(ctx, payload)
	return err
}

func (s *pushService) SendMentionNotification(ctx context.Context, userID, roomID, roomName, senderName string) error {
	payload := &PushPayload{
		UserID: userID,
		Type:   repository.PushTypeMention,
		Title:  roomName,
		Body:   fmt.Sprintf("%s 在群聊中@了你", senderName),
		Data: map[string]string{
			"type":    string(repository.PushTypeMention),
			"room_id": roomID,
		},
		RoomID: roomID,
	}

	_, err := s.SendToUser(ctx, payload)
	return err
}

func (s *pushService) SendRoomInviteNotification(ctx context.Context, userID, roomID, roomName, inviterName string) error {
	payload := &PushPayload{
		UserID: userID,
		Type:   repository.PushTypeRoomInvite,
		Title:  "群聊邀请",
		Body:   fmt.Sprintf("%s 邀请你加入 %s", inviterName, roomName),
		Data: map[string]string{
			"type":    string(repository.PushTypeRoomInvite),
			"room_id": roomID,
		},
		RoomID: roomID,
	}

	_, err := s.SendToUser(ctx, payload)
	return err
}

// ====== 用户设置 ======

func (s *pushService) GetUserSettings(ctx context.Context, userID string) (*repository.UserPushSettings, error) {
	return s.pushRepo.GetUserSettings(userID)
}

func (s *pushService) UpdateUserSettings(ctx context.Context, settings *repository.UserPushSettings) error {
	return s.pushRepo.SaveUserSettings(settings)
}

// ====== 后台任务 ======

func (s *pushService) ProcessPendingNotifications(ctx context.Context) error {
	notifications, err := s.pushRepo.GetPendingNotifications(100)
	if err != nil {
		return err
	}

	for _, notification := range notifications {
		// 获取用户的推送 tokens
		tokens, err := s.pushRepo.GetActiveTokensByUser(notification.UserID)
		if err != nil || len(tokens) == 0 {
			s.pushRepo.UpdateNotificationStatus(notification.ID, repository.PushStatusFailed, "", "No active tokens")
			continue
		}

		// 尝试发送
		for _, token := range tokens {
			result := s.sendRawNotification(ctx, token, notification)
			if result.Success {
				s.pushRepo.UpdateNotificationStatus(notification.ID, repository.PushStatusSent, result.MessageID, "")
				break
			} else {
				s.pushRepo.UpdateNotificationStatus(notification.ID, repository.PushStatusFailed, "", result.ErrorMessage)
			}
		}
	}

	return nil
}

// ====== 内部方法 ======

func (s *pushService) sendToToken(ctx context.Context, token *repository.PushToken, payload *PushPayload, settings *repository.UserPushSettings) PushResult {
	result := PushResult{
		TokenID:  token.ID,
		Platform: token.Platform,
	}

	switch token.Platform {
	case repository.PushPlatformFCM:
		msgID, err := s.sendFCM(ctx, token.Token, payload, settings)
		if err != nil {
			result.Success = false
			result.ErrorMessage = err.Error()

			// 如果是 token 无效，停用它
			if isInvalidTokenError(err) {
				s.pushRepo.DeactivateToken(token.Token)
			}
		} else {
			result.Success = true
			result.MessageID = msgID
		}

	case repository.PushPlatformAPNs:
		msgID, err := s.sendAPNs(ctx, token.Token, payload, settings)
		if err != nil {
			result.Success = false
			result.ErrorMessage = err.Error()

			if isInvalidTokenError(err) {
				s.pushRepo.DeactivateToken(token.Token)
			}
		} else {
			result.Success = true
			result.MessageID = msgID
		}

	default:
		result.Success = false
		result.ErrorMessage = "unsupported platform"
	}

	return result
}

func (s *pushService) sendFCM(ctx context.Context, token string, payload *PushPayload, settings *repository.UserPushSettings) (string, error) {
	if s.config == nil || s.config.FCM == nil {
		return "", errors.New("FCM not configured")
	}

	// 构建 FCM 消息
	message := map[string]interface{}{
		"to": token,
		"notification": map[string]interface{}{
			"title": payload.Title,
			"body":  payload.Body,
		},
		"data": payload.Data,
	}

	// 添加声音设置
	if settings != nil && settings.EnableSound {
		message["notification"].(map[string]interface{})["sound"] = "default"
	}

	// 添加图片
	if payload.ImageURL != "" {
		message["notification"].(map[string]interface{})["image"] = payload.ImageURL
	}

	// 发送请求
	body, err := json.Marshal(message)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "https://fcm.googleapis.com/fcm/send", bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "key="+s.config.FCM.ServerKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("FCM error: %s", string(respBody))
	}

	// 解析响应
	var fcmResp struct {
		MessageID string `json:"message_id"`
		Success   int    `json:"success"`
		Failure   int    `json:"failure"`
		Results   []struct {
			MessageID string `json:"message_id"`
			Error     string `json:"error"`
		} `json:"results"`
	}

	if err := json.Unmarshal(respBody, &fcmResp); err != nil {
		return "", err
	}

	if fcmResp.Failure > 0 && len(fcmResp.Results) > 0 {
		return "", errors.New(fcmResp.Results[0].Error)
	}

	messageID := fcmResp.MessageID
	if messageID == "" && len(fcmResp.Results) > 0 {
		messageID = fcmResp.Results[0].MessageID
	}

	return messageID, nil
}

func (s *pushService) sendAPNs(ctx context.Context, token string, payload *PushPayload, settings *repository.UserPushSettings) (string, error) {
	if s.config == nil || s.config.APNs == nil {
		return "", errors.New("APNs not configured")
	}

	// 构建 APNs 消息
	aps := map[string]interface{}{
		"alert": map[string]interface{}{
			"title": payload.Title,
			"body":  payload.Body,
		},
	}

	if settings != nil && settings.EnableSound {
		aps["sound"] = "default"
	}

	if payload.Badge > 0 {
		aps["badge"] = payload.Badge
	}

	message := map[string]interface{}{
		"aps": aps,
	}

	// 添加自定义数据
	for k, v := range payload.Data {
		message[k] = v
	}

	body, err := json.Marshal(message)
	if err != nil {
		return "", err
	}

	// APNs endpoint
	host := "api.sandbox.push.apple.com"
	if s.config.APNs.Production {
		host = "api.push.apple.com"
	}

	url := fmt.Sprintf("https://%s/3/device/%s", host, token)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(body))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apns-topic", s.config.APNs.BundleID)
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")

	// TODO: 添加 JWT 认证头
	// req.Header.Set("Authorization", "bearer "+jwtToken)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	apnsID := resp.Header.Get("apns-id")

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("APNs error: %s", string(respBody))
	}

	return apnsID, nil
}

func (s *pushService) sendRawNotification(ctx context.Context, token *repository.PushToken, notification *repository.PushNotification) PushResult {
	payload := &PushPayload{
		UserID:   notification.UserID,
		Type:     notification.Type,
		Title:    notification.Title,
		Body:     notification.Body,
		ImageURL: notification.ImageURL,
	}

	// 解析 Data JSON
	if notification.Data != "" {
		json.Unmarshal([]byte(notification.Data), &payload.Data)
	}

	settings, _ := s.pushRepo.GetUserSettings(notification.UserID)
	if settings == nil {
		settings = &repository.UserPushSettings{EnablePush: true, EnableSound: true}
	}

	return s.sendToToken(ctx, token, payload, settings)
}

func (s *pushService) recordNotification(payload *PushPayload, token *repository.PushToken, result PushResult) {
	dataJSON, _ := json.Marshal(payload.Data)

	status := repository.PushStatusSent
	if !result.Success {
		status = repository.PushStatusFailed
	}

	notification := &repository.PushNotification{
		UserID:       payload.UserID,
		DeviceID:     token.DeviceID,
		Type:         payload.Type,
		Title:        payload.Title,
		Body:         payload.Body,
		Data:         string(dataJSON),
		ImageURL:     payload.ImageURL,
		Status:       status,
		Platform:     token.Platform,
		MessageID:    result.MessageID,
		ErrorMessage: result.ErrorMessage,
		CreatedAt:    time.Now(),
	}

	if result.Success {
		now := time.Now()
		notification.SentAt = &now
	}

	s.pushRepo.CreateNotification(notification)
}

func (s *pushService) isInQuietHours(settings *repository.UserPushSettings) bool {
	if settings.QuietHoursStart == nil || settings.QuietHoursEnd == nil {
		return false
	}

	now := time.Now()
	hour := now.Hour()
	start := *settings.QuietHoursStart
	end := *settings.QuietHoursEnd

	if start <= end {
		// 例如: 22:00 - 08:00 不跨天
		return hour >= start && hour < end
	} else {
		// 跨天情况，例如: 22:00 - 08:00
		return hour >= start || hour < end
	}
}

func isInvalidTokenError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	invalidErrors := []string{
		"InvalidRegistration",
		"NotRegistered",
		"MismatchSenderId",
		"BadDeviceToken",
		"Unregistered",
		"DeviceTokenNotForTopic",
	}

	for _, e := range invalidErrors {
		if contains(errStr, e) {
			return true
		}
	}
	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && containsHelper(s, substr))
}

func containsHelper(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
