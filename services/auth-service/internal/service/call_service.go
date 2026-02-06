package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"sec-chat/auth-service/internal/repository"
)

// WebRTCConfig WebRTC配置
type WebRTCConfig struct {
	ICEServers []repository.ICEServer
}

// DefaultWebRTCConfig 默认WebRTC配置
func DefaultWebRTCConfig() *WebRTCConfig {
	return &WebRTCConfig{
		ICEServers: []repository.ICEServer{
			{
				URLs: []string{
					"stun:stun.l.google.com:19302",
					"stun:stun1.l.google.com:19302",
				},
			},
		},
	}
}

// CallService 通话服务接口
type CallService interface {
	// 通话管理
	InitiateCall(ctx context.Context, initiatorID string, targetUserIDs []string, callType repository.CallType, roomID string) (*repository.Call, error)
	AcceptCall(ctx context.Context, callID, userID string) error
	RejectCall(ctx context.Context, callID, userID string) error
	EndCall(ctx context.Context, callID, userID, reason string) error
	GetCall(ctx context.Context, callID string) (*repository.Call, error)
	GetActiveCall(ctx context.Context, userID string) (*repository.Call, error)
	ListCallHistory(ctx context.Context, userID string, offset, limit int) ([]*repository.Call, int64, error)

	// 参与者管理
	JoinCall(ctx context.Context, callID, userID string) error
	LeaveCall(ctx context.Context, callID, userID string) error
	ToggleMute(ctx context.Context, callID, userID string, muted bool) error
	ToggleVideo(ctx context.Context, callID, userID string, videoOn bool) error

	// 配置
	GetICEServers(ctx context.Context) []repository.ICEServer
}

// callService 通话服务实现
type callService struct {
	repo   repository.CallRepository
	config *WebRTCConfig
}

// NewCallService 创建通话服务实例
func NewCallService(repo repository.CallRepository, config *WebRTCConfig) CallService {
	if config == nil {
		config = DefaultWebRTCConfig()
	}
	return &callService{
		repo:   repo,
		config: config,
	}
}

// InitiateCall 发起通话
func (s *callService) InitiateCall(ctx context.Context, initiatorID string, targetUserIDs []string, callType repository.CallType, roomID string) (*repository.Call, error) {
	// 检查是否已有进行中的通话
	activeCall, err := s.repo.GetActiveCallByUser(ctx, initiatorID)
	if err != nil {
		return nil, fmt.Errorf("failed to check active call: %w", err)
	}
	if activeCall != nil {
		return nil, fmt.Errorf("user already in a call")
	}

	// 创建通话记录
	call := &repository.Call{
		ID:          uuid.New().String(),
		RoomID:      roomID,
		InitiatorID: initiatorID,
		CallType:    callType,
		Status:      repository.CallStatusInitiated,
	}

	if err := s.repo.CreateCall(ctx, call); err != nil {
		return nil, fmt.Errorf("failed to create call: %w", err)
	}

	// 添加发起者为参与者
	initiatorParticipant := &repository.CallParticipant{
		CallID:    call.ID,
		UserID:    initiatorID,
		Status:    repository.ParticipantStatusConnected,
		IsVideoOn: callType == repository.CallTypeVideo,
	}
	now := time.Now()
	initiatorParticipant.JoinedAt = &now

	if err := s.repo.AddParticipant(ctx, initiatorParticipant); err != nil {
		return nil, fmt.Errorf("failed to add initiator: %w", err)
	}

	// 添加被邀请者
	for _, targetID := range targetUserIDs {
		if targetID == initiatorID {
			continue
		}

		participant := &repository.CallParticipant{
			CallID:    call.ID,
			UserID:    targetID,
			Status:    repository.ParticipantStatusInvited,
			IsVideoOn: callType == repository.CallTypeVideo,
		}

		if err := s.repo.AddParticipant(ctx, participant); err != nil {
			return nil, fmt.Errorf("failed to add participant %s: %w", targetID, err)
		}
	}

	// 更新状态为响铃
	call.Status = repository.CallStatusRinging
	if err := s.repo.UpdateCall(ctx, call); err != nil {
		return nil, fmt.Errorf("failed to update call status: %w", err)
	}

	// 重新获取包含参与者的通话
	return s.repo.GetCallByID(ctx, call.ID)
}

// AcceptCall 接受通话
func (s *callService) AcceptCall(ctx context.Context, callID, userID string) error {
	call, err := s.repo.GetCallByID(ctx, callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	if call.Status != repository.CallStatusRinging && call.Status != repository.CallStatusConnecting {
		return fmt.Errorf("call is not in ringing or connecting state")
	}

	participant, err := s.repo.GetParticipant(ctx, callID, userID)
	if err != nil {
		return fmt.Errorf("failed to get participant: %w", err)
	}
	if participant == nil {
		return fmt.Errorf("user is not a participant of this call")
	}

	// 更新参与者状态
	now := time.Now()
	participant.Status = repository.ParticipantStatusConnected
	participant.JoinedAt = &now

	if err := s.repo.UpdateParticipant(ctx, participant); err != nil {
		return fmt.Errorf("failed to update participant: %w", err)
	}

	// 如果这是第一个接受的人，更新通话状态
	if call.Status == repository.CallStatusRinging {
		call.Status = repository.CallStatusConnecting
		call.StartedAt = &now
		if err := s.repo.UpdateCall(ctx, call); err != nil {
			return fmt.Errorf("failed to update call: %w", err)
		}
	}

	// 检查是否所有邀请的人都已连接
	participants, _ := s.repo.ListParticipants(ctx, callID)
	allConnected := true
	for _, p := range participants {
		if p.Status == repository.ParticipantStatusInvited || p.Status == repository.ParticipantStatusRinging {
			allConnected = false
			break
		}
	}

	if allConnected && call.Status == repository.CallStatusConnecting {
		call.Status = repository.CallStatusConnected
		if err := s.repo.UpdateCall(ctx, call); err != nil {
			return fmt.Errorf("failed to update call to connected: %w", err)
		}
	}

	return nil
}

// RejectCall 拒绝通话
func (s *callService) RejectCall(ctx context.Context, callID, userID string) error {
	call, err := s.repo.GetCallByID(ctx, callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	participant, err := s.repo.GetParticipant(ctx, callID, userID)
	if err != nil {
		return fmt.Errorf("failed to get participant: %w", err)
	}
	if participant == nil {
		return fmt.Errorf("user is not a participant of this call")
	}

	// 更新参与者状态
	now := time.Now()
	participant.Status = repository.ParticipantStatusRejected
	participant.LeftAt = &now

	if err := s.repo.UpdateParticipant(ctx, participant); err != nil {
		return fmt.Errorf("failed to update participant: %w", err)
	}

	// 检查是否所有人都拒绝了
	participants, _ := s.repo.ListParticipants(ctx, callID)
	allRejectedOrLeft := true
	connectedCount := 0
	for _, p := range participants {
		if p.UserID == call.InitiatorID {
			if p.Status == repository.ParticipantStatusConnected {
				connectedCount++
			}
			continue
		}
		if p.Status != repository.ParticipantStatusRejected && p.Status != repository.ParticipantStatusLeft {
			allRejectedOrLeft = false
		}
		if p.Status == repository.ParticipantStatusConnected {
			connectedCount++
		}
	}

	// 如果所有被邀请者都拒绝了，结束通话
	if allRejectedOrLeft && connectedCount <= 1 {
		call.Status = repository.CallStatusRejected
		call.EndedAt = &now
		call.EndReason = "all_rejected"
		if err := s.repo.UpdateCall(ctx, call); err != nil {
			return fmt.Errorf("failed to end call: %w", err)
		}
	}

	return nil
}

// EndCall 结束通话
func (s *callService) EndCall(ctx context.Context, callID, userID, reason string) error {
	call, err := s.repo.GetCallByID(ctx, callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	if call.Status == repository.CallStatusEnded {
		return nil // 已经结束
	}

	now := time.Now()

	// 更新所有参与者状态
	participants, _ := s.repo.ListParticipants(ctx, callID)
	for _, p := range participants {
		if p.Status == repository.ParticipantStatusConnected {
			p.Status = repository.ParticipantStatusLeft
			p.LeftAt = &now
			s.repo.UpdateParticipant(ctx, p)
		}
	}

	// 计算通话时长
	var duration int
	if call.StartedAt != nil {
		duration = int(now.Sub(*call.StartedAt).Seconds())
	}

	// 更新通话状态
	call.Status = repository.CallStatusEnded
	call.EndedAt = &now
	call.Duration = duration
	if reason != "" {
		call.EndReason = reason
	} else {
		call.EndReason = "ended_by_user"
	}

	return s.repo.UpdateCall(ctx, call)
}

// GetCall 获取通话
func (s *callService) GetCall(ctx context.Context, callID string) (*repository.Call, error) {
	return s.repo.GetCallByID(ctx, callID)
}

// GetActiveCall 获取用户活跃通话
func (s *callService) GetActiveCall(ctx context.Context, userID string) (*repository.Call, error) {
	return s.repo.GetActiveCallByUser(ctx, userID)
}

// ListCallHistory 获取通话历史
func (s *callService) ListCallHistory(ctx context.Context, userID string, offset, limit int) ([]*repository.Call, int64, error) {
	return s.repo.ListCallsByUser(ctx, userID, offset, limit)
}

// JoinCall 加入通话
func (s *callService) JoinCall(ctx context.Context, callID, userID string) error {
	call, err := s.repo.GetCallByID(ctx, callID)
	if err != nil {
		return fmt.Errorf("failed to get call: %w", err)
	}
	if call == nil {
		return fmt.Errorf("call not found")
	}

	if call.Status == repository.CallStatusEnded {
		return fmt.Errorf("call has ended")
	}

	// 检查是否已是参与者
	participant, _ := s.repo.GetParticipant(ctx, callID, userID)
	if participant != nil {
		// 重新加入
		now := time.Now()
		participant.Status = repository.ParticipantStatusConnected
		participant.JoinedAt = &now
		participant.LeftAt = nil
		return s.repo.UpdateParticipant(ctx, participant)
	}

	// 添加新参与者
	now := time.Now()
	newParticipant := &repository.CallParticipant{
		CallID:    callID,
		UserID:    userID,
		Status:    repository.ParticipantStatusConnected,
		JoinedAt:  &now,
		IsVideoOn: call.CallType == repository.CallTypeVideo,
	}

	return s.repo.AddParticipant(ctx, newParticipant)
}

// LeaveCall 离开通话
func (s *callService) LeaveCall(ctx context.Context, callID, userID string) error {
	participant, err := s.repo.GetParticipant(ctx, callID, userID)
	if err != nil {
		return fmt.Errorf("failed to get participant: %w", err)
	}
	if participant == nil {
		return fmt.Errorf("user is not a participant")
	}

	now := time.Now()
	participant.Status = repository.ParticipantStatusLeft
	participant.LeftAt = &now

	if err := s.repo.UpdateParticipant(ctx, participant); err != nil {
		return fmt.Errorf("failed to update participant: %w", err)
	}

	// 检查是否还有连接的参与者
	participants, _ := s.repo.ListParticipants(ctx, callID)
	connectedCount := 0
	for _, p := range participants {
		if p.Status == repository.ParticipantStatusConnected {
			connectedCount++
		}
	}

	// 如果只剩一个或没有人，自动结束通话
	if connectedCount <= 1 {
		return s.EndCall(ctx, callID, userID, "last_participant_left")
	}

	return nil
}

// ToggleMute 切换静音
func (s *callService) ToggleMute(ctx context.Context, callID, userID string, muted bool) error {
	participant, err := s.repo.GetParticipant(ctx, callID, userID)
	if err != nil {
		return fmt.Errorf("failed to get participant: %w", err)
	}
	if participant == nil {
		return fmt.Errorf("user is not a participant")
	}

	participant.IsMuted = muted
	return s.repo.UpdateParticipant(ctx, participant)
}

// ToggleVideo 切换视频
func (s *callService) ToggleVideo(ctx context.Context, callID, userID string, videoOn bool) error {
	participant, err := s.repo.GetParticipant(ctx, callID, userID)
	if err != nil {
		return fmt.Errorf("failed to get participant: %w", err)
	}
	if participant == nil {
		return fmt.Errorf("user is not a participant")
	}

	participant.IsVideoOn = videoOn
	return s.repo.UpdateParticipant(ctx, participant)
}

// GetICEServers 获取ICE服务器配置
func (s *callService) GetICEServers(ctx context.Context) []repository.ICEServer {
	return s.config.ICEServers
}
