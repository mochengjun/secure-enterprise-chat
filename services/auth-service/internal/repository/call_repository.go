package repository

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// CallType 通话类型
type CallType string

const (
	CallTypeVoice CallType = "voice"
	CallTypeVideo CallType = "video"
)

// CallStatus 通话状态
type CallStatus string

const (
	CallStatusInitiated  CallStatus = "initiated"  // 发起中
	CallStatusRinging    CallStatus = "ringing"    // 响铃中
	CallStatusConnecting CallStatus = "connecting" // 连接中
	CallStatusConnected  CallStatus = "connected"  // 已连接
	CallStatusEnded      CallStatus = "ended"      // 已结束
	CallStatusMissed     CallStatus = "missed"     // 未接
	CallStatusRejected   CallStatus = "rejected"   // 已拒绝
	CallStatusFailed     CallStatus = "failed"     // 失败
)

// ParticipantStatus 参与者状态
type ParticipantStatus string

const (
	ParticipantStatusInvited   ParticipantStatus = "invited"
	ParticipantStatusRinging   ParticipantStatus = "ringing"
	ParticipantStatusConnected ParticipantStatus = "connected"
	ParticipantStatusLeft      ParticipantStatus = "left"
	ParticipantStatusRejected  ParticipantStatus = "rejected"
)

// Call 通话记录
type Call struct {
	ID          string     `gorm:"primaryKey;size:64" json:"id"`
	RoomID      string     `gorm:"size:64;index" json:"room_id,omitempty"` // 可选，关联聊天室
	InitiatorID string     `gorm:"size:255;index" json:"initiator_id"`
	CallType    CallType   `gorm:"size:16" json:"call_type"`
	Status      CallStatus `gorm:"size:32;index" json:"status"`
	StartedAt   *time.Time `json:"started_at,omitempty"`
	EndedAt     *time.Time `json:"ended_at,omitempty"`
	Duration    int        `json:"duration,omitempty"` // 秒
	EndReason   string     `gorm:"size:128" json:"end_reason,omitempty"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time  `gorm:"autoUpdateTime" json:"updated_at"`

	Participants []CallParticipant `gorm:"foreignKey:CallID" json:"participants,omitempty"`
}

// CallParticipant 通话参与者
type CallParticipant struct {
	ID        uint              `gorm:"primaryKey;autoIncrement" json:"id"`
	CallID    string            `gorm:"size:64;index" json:"call_id"`
	UserID    string            `gorm:"size:255;index" json:"user_id"`
	Status    ParticipantStatus `gorm:"size:32" json:"status"`
	JoinedAt  *time.Time        `json:"joined_at,omitempty"`
	LeftAt    *time.Time        `json:"left_at,omitempty"`
	IsMuted   bool              `gorm:"default:false" json:"is_muted"`
	IsVideoOn bool              `gorm:"default:true" json:"is_video_on"`
	CreatedAt time.Time         `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time         `gorm:"autoUpdateTime" json:"updated_at"`
}

// ICEServer ICE服务器配置
type ICEServer struct {
	URLs       []string `json:"urls"`
	Username   string   `json:"username,omitempty"`
	Credential string   `json:"credential,omitempty"`
}

// SignalingMessage 信令消息
type SignalingMessage struct {
	Type      string      `json:"type"` // offer, answer, ice-candidate, call-invite, call-accept, call-reject, call-end
	CallID    string      `json:"call_id"`
	FromUser  string      `json:"from_user"`
	ToUser    string      `json:"to_user,omitempty"`
	Payload   interface{} `json:"payload,omitempty"`
	Timestamp time.Time   `json:"timestamp"`
}

// SDPPayload SDP负载
type SDPPayload struct {
	Type string `json:"type"` // offer or answer
	SDP  string `json:"sdp"`
}

// ICECandidatePayload ICE候选负载
type ICECandidatePayload struct {
	Candidate     string `json:"candidate"`
	SDPMid        string `json:"sdpMid"`
	SDPMLineIndex int    `json:"sdpMLineIndex"`
}

// CallInvitePayload 通话邀请负载
type CallInvitePayload struct {
	CallType CallType `json:"call_type"`
	RoomID   string   `json:"room_id,omitempty"`
	RoomName string   `json:"room_name,omitempty"`
}

// CallRepository 通话仓库接口
type CallRepository interface {
	// 通话管理
	CreateCall(ctx context.Context, call *Call) error
	GetCallByID(ctx context.Context, id string) (*Call, error)
	UpdateCall(ctx context.Context, call *Call) error
	GetActiveCallByUser(ctx context.Context, userID string) (*Call, error)
	GetActiveCallByRoom(ctx context.Context, roomID string) (*Call, error)
	ListCallsByUser(ctx context.Context, userID string, offset, limit int) ([]*Call, int64, error)
	ListCallsByRoom(ctx context.Context, roomID string, offset, limit int) ([]*Call, int64, error)

	// 参与者管理
	AddParticipant(ctx context.Context, participant *CallParticipant) error
	UpdateParticipant(ctx context.Context, participant *CallParticipant) error
	GetParticipant(ctx context.Context, callID, userID string) (*CallParticipant, error)
	ListParticipants(ctx context.Context, callID string) ([]*CallParticipant, error)
	RemoveParticipant(ctx context.Context, callID, userID string) error
}

// callRepository 通话仓库实现
type callRepository struct {
	db *gorm.DB
}

// NewCallRepository 创建通话仓库实例
func NewCallRepository(db *gorm.DB) CallRepository {
	return &callRepository{db: db}
}

// CreateCall 创建通话
func (r *callRepository) CreateCall(ctx context.Context, call *Call) error {
	return r.db.WithContext(ctx).Create(call).Error
}

// GetCallByID 根据ID获取通话
func (r *callRepository) GetCallByID(ctx context.Context, id string) (*Call, error) {
	var call Call
	err := r.db.WithContext(ctx).Preload("Participants").Where("id = ?", id).First(&call).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &call, nil
}

// UpdateCall 更新通话
func (r *callRepository) UpdateCall(ctx context.Context, call *Call) error {
	return r.db.WithContext(ctx).Save(call).Error
}

// GetActiveCallByUser 获取用户当前活跃通话
func (r *callRepository) GetActiveCallByUser(ctx context.Context, userID string) (*Call, error) {
	var call Call
	err := r.db.WithContext(ctx).
		Preload("Participants").
		Joins("JOIN call_participants ON call_participants.call_id = calls.id").
		Where("call_participants.user_id = ? AND calls.status IN ?", userID,
			[]CallStatus{CallStatusInitiated, CallStatusRinging, CallStatusConnecting, CallStatusConnected}).
		First(&call).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &call, nil
}

// GetActiveCallByRoom 获取房间当前活跃通话
func (r *callRepository) GetActiveCallByRoom(ctx context.Context, roomID string) (*Call, error) {
	var call Call
	err := r.db.WithContext(ctx).
		Preload("Participants").
		Where("room_id = ? AND status IN ?", roomID,
			[]CallStatus{CallStatusInitiated, CallStatusRinging, CallStatusConnecting, CallStatusConnected}).
		First(&call).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &call, nil
}

// ListCallsByUser 列出用户通话历史
func (r *callRepository) ListCallsByUser(ctx context.Context, userID string, offset, limit int) ([]*Call, int64, error) {
	var calls []*Call
	var total int64

	subQuery := r.db.Model(&CallParticipant{}).Select("call_id").Where("user_id = ?", userID)

	query := r.db.WithContext(ctx).Model(&Call{}).
		Where("id IN (?)", subQuery)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Preload("Participants").
		Order("created_at DESC").
		Offset(offset).Limit(limit).
		Find(&calls).Error; err != nil {
		return nil, 0, err
	}

	return calls, total, nil
}

// ListCallsByRoom 列出房间通话历史
func (r *callRepository) ListCallsByRoom(ctx context.Context, roomID string, offset, limit int) ([]*Call, int64, error) {
	var calls []*Call
	var total int64

	query := r.db.WithContext(ctx).Model(&Call{}).Where("room_id = ?", roomID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Preload("Participants").
		Order("created_at DESC").
		Offset(offset).Limit(limit).
		Find(&calls).Error; err != nil {
		return nil, 0, err
	}

	return calls, total, nil
}

// AddParticipant 添加参与者
func (r *callRepository) AddParticipant(ctx context.Context, participant *CallParticipant) error {
	return r.db.WithContext(ctx).Create(participant).Error
}

// UpdateParticipant 更新参与者
func (r *callRepository) UpdateParticipant(ctx context.Context, participant *CallParticipant) error {
	return r.db.WithContext(ctx).Save(participant).Error
}

// GetParticipant 获取参与者
func (r *callRepository) GetParticipant(ctx context.Context, callID, userID string) (*CallParticipant, error) {
	var participant CallParticipant
	err := r.db.WithContext(ctx).
		Where("call_id = ? AND user_id = ?", callID, userID).
		First(&participant).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &participant, nil
}

// ListParticipants 列出通话参与者
func (r *callRepository) ListParticipants(ctx context.Context, callID string) ([]*CallParticipant, error) {
	var participants []*CallParticipant
	err := r.db.WithContext(ctx).Where("call_id = ?", callID).Find(&participants).Error
	return participants, err
}

// RemoveParticipant 移除参与者
func (r *callRepository) RemoveParticipant(ctx context.Context, callID, userID string) error {
	return r.db.WithContext(ctx).
		Where("call_id = ? AND user_id = ?", callID, userID).
		Delete(&CallParticipant{}).Error
}
