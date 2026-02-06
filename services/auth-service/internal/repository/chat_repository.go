package repository

import (
	"time"

	"gorm.io/gorm"
)

// RoomType 房间类型
type RoomType string

const (
	RoomTypeDirect  RoomType = "direct"
	RoomTypeGroup   RoomType = "group"
	RoomTypeChannel RoomType = "channel"
)

// MemberRole 成员角色
type MemberRole string

const (
	MemberRoleOwner     MemberRole = "owner"
	MemberRoleAdmin     MemberRole = "admin"
	MemberRoleModerator MemberRole = "moderator"
	MemberRoleMember    MemberRole = "member"
)

// MessageType 消息类型
type MessageType string

const (
	MessageTypeText   MessageType = "text"
	MessageTypeImage  MessageType = "image"
	MessageTypeVideo  MessageType = "video"
	MessageTypeAudio  MessageType = "audio"
	MessageTypeFile   MessageType = "file"
	MessageTypeSystem MessageType = "system"
)

// MessageStatus 消息状态
type MessageStatus string

const (
	MessageStatusSending   MessageStatus = "sending"
	MessageStatusSent      MessageStatus = "sent"
	MessageStatusDelivered MessageStatus = "delivered"
	MessageStatusRead      MessageStatus = "read"
	MessageStatusFailed    MessageStatus = "failed"
)

// Room 聊天房间
type Room struct {
	ID             string    `gorm:"primaryKey;size:36" json:"id"`
	Name           string    `gorm:"size:255;not null" json:"name"`
	Description    string    `gorm:"size:1000" json:"description,omitempty"`
	AvatarURL      string    `gorm:"size:500" json:"avatar_url,omitempty"`
	Type           RoomType  `gorm:"size:20;not null;default:group" json:"type"`
	CreatorID      string    `gorm:"size:36" json:"creator_id"`
	RetentionHours *int      `json:"retention_hours,omitempty"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

// RoomMember 房间成员
type RoomMember struct {
	ID        string     `gorm:"primaryKey;size:36" json:"id"`
	RoomID    string     `gorm:"size:36;not null;index:idx_room_member" json:"room_id"`
	UserID    string     `gorm:"size:36;not null;index:idx_room_member" json:"user_id"`
	Role      MemberRole `gorm:"size:20;not null;default:member" json:"role"`
	IsMuted   bool       `gorm:"default:false" json:"is_muted"`
	IsPinned  bool       `gorm:"default:false" json:"is_pinned"`
	JoinedAt  time.Time  `json:"joined_at"`
	UpdatedAt time.Time  `json:"updated_at"`

	// 关联
	Room *Room `gorm:"foreignKey:RoomID" json:"room,omitempty"`
	User *User `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

// Message 消息
type Message struct {
	ID           string        `gorm:"primaryKey;size:36" json:"id"`
	RoomID       string        `gorm:"size:36;not null;index:idx_message_room" json:"room_id"`
	SenderID     string        `gorm:"size:36;not null" json:"sender_id"`
	Content      string        `gorm:"type:text" json:"content"`
	Type         MessageType   `gorm:"size:20;not null;default:text" json:"type"`
	Status       MessageStatus `gorm:"size:20;not null;default:sent" json:"status"`
	MediaURL     string        `gorm:"size:500" json:"media_url,omitempty"`
	ThumbnailURL string        `gorm:"size:500" json:"thumbnail_url,omitempty"`
	MediaSize    *int64        `json:"media_size,omitempty"`
	MimeType     string        `gorm:"size:100" json:"mime_type,omitempty"`
	ReplyToID    string        `gorm:"size:36" json:"reply_to_id,omitempty"`
	IsDeleted    bool          `gorm:"default:false" json:"is_deleted"`
	CreatedAt    time.Time     `gorm:"index:idx_message_created" json:"created_at"`
	EditedAt     *time.Time    `json:"edited_at,omitempty"`

	// 关联
	Room   *Room `gorm:"foreignKey:RoomID" json:"room,omitempty"`
	Sender *User `gorm:"foreignKey:SenderID" json:"sender,omitempty"`
}

// ReadReceipt 已读回执
type ReadReceipt struct {
	ID            string    `gorm:"primaryKey;size:36" json:"id"`
	RoomID        string    `gorm:"size:36;not null;index:idx_read_receipt" json:"room_id"`
	UserID        string    `gorm:"size:36;not null;index:idx_read_receipt" json:"user_id"`
	LastMessageID string    `gorm:"size:36" json:"last_message_id"`
	ReadAt        time.Time `json:"read_at"`
}

// ChatRepository 聊天仓库接口
type ChatRepository interface {
	// Room 相关
	CreateRoom(room *Room) error
	GetRoom(roomID string) (*Room, error)
	UpdateRoom(room *Room) error
	DeleteRoom(roomID string) error
	GetUserRooms(userID string) ([]*Room, error)

	// Member 相关
	AddMember(member *RoomMember) error
	GetMember(roomID, userID string) (*RoomMember, error)
	UpdateMember(member *RoomMember) error
	RemoveMember(roomID, userID string) error
	GetRoomMembers(roomID string) ([]*RoomMember, error)
	IsMember(roomID, userID string) (bool, error)

	// Message 相关
	CreateMessage(message *Message) error
	GetMessage(messageID string) (*Message, error)
	GetMessages(roomID string, limit int, beforeID string) ([]*Message, error)
	UpdateMessage(message *Message) error
	DeleteMessage(messageID string) error
	GetUnreadCount(roomID, userID string) (int64, error)

	// ReadReceipt 相关
	UpdateReadReceipt(receipt *ReadReceipt) error
	GetReadReceipt(roomID, userID string) (*ReadReceipt, error)
}

// chatRepository 聊天仓库实现
type chatRepository struct {
	db *gorm.DB
}

// NewChatRepository 创建聊天仓库实例
func NewChatRepository(db *gorm.DB) ChatRepository {
	return &chatRepository{db: db}
}

// === Room 相关 ===

func (r *chatRepository) CreateRoom(room *Room) error {
	return r.db.Create(room).Error
}

func (r *chatRepository) GetRoom(roomID string) (*Room, error) {
	var room Room
	if err := r.db.First(&room, "id = ?", roomID).Error; err != nil {
		return nil, err
	}
	return &room, nil
}

func (r *chatRepository) UpdateRoom(room *Room) error {
	return r.db.Save(room).Error
}

func (r *chatRepository) DeleteRoom(roomID string) error {
	return r.db.Delete(&Room{}, "id = ?", roomID).Error
}

func (r *chatRepository) GetUserRooms(userID string) ([]*Room, error) {
	var rooms []*Room
	err := r.db.
		Joins("JOIN room_members ON room_members.room_id = rooms.id").
		Where("room_members.user_id = ?", userID).
		Order("rooms.updated_at DESC").
		Find(&rooms).Error
	return rooms, err
}

// === Member 相关 ===

func (r *chatRepository) AddMember(member *RoomMember) error {
	return r.db.Create(member).Error
}

func (r *chatRepository) GetMember(roomID, userID string) (*RoomMember, error) {
	var member RoomMember
	if err := r.db.First(&member, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		return nil, err
	}
	return &member, nil
}

func (r *chatRepository) UpdateMember(member *RoomMember) error {
	return r.db.Save(member).Error
}

func (r *chatRepository) RemoveMember(roomID, userID string) error {
	return r.db.Delete(&RoomMember{}, "room_id = ? AND user_id = ?", roomID, userID).Error
}

func (r *chatRepository) GetRoomMembers(roomID string) ([]*RoomMember, error) {
	var members []*RoomMember
	err := r.db.Preload("User").Where("room_id = ?", roomID).Find(&members).Error
	return members, err
}

func (r *chatRepository) IsMember(roomID, userID string) (bool, error) {
	var count int64
	err := r.db.Model(&RoomMember{}).Where("room_id = ? AND user_id = ?", roomID, userID).Count(&count).Error
	return count > 0, err
}

// === Message 相关 ===

func (r *chatRepository) CreateMessage(message *Message) error {
	return r.db.Create(message).Error
}

func (r *chatRepository) GetMessage(messageID string) (*Message, error) {
	var message Message
	if err := r.db.Preload("Sender").First(&message, "id = ?", messageID).Error; err != nil {
		return nil, err
	}
	return &message, nil
}

func (r *chatRepository) GetMessages(roomID string, limit int, beforeID string) ([]*Message, error) {
	var messages []*Message
	query := r.db.Preload("Sender").Where("room_id = ? AND is_deleted = ?", roomID, false)

	if beforeID != "" {
		var beforeMsg Message
		if err := r.db.Select("created_at").First(&beforeMsg, "id = ?", beforeID).Error; err == nil {
			query = query.Where("created_at < ?", beforeMsg.CreatedAt)
		}
	}

	err := query.Order("created_at DESC").Limit(limit).Find(&messages).Error
	return messages, err
}

func (r *chatRepository) UpdateMessage(message *Message) error {
	return r.db.Save(message).Error
}

func (r *chatRepository) DeleteMessage(messageID string) error {
	return r.db.Model(&Message{}).Where("id = ?", messageID).Update("is_deleted", true).Error
}

func (r *chatRepository) GetUnreadCount(roomID, userID string) (int64, error) {
	var receipt ReadReceipt
	var count int64

	if err := r.db.First(&receipt, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		// 没有已读记录，返回所有消息数
		r.db.Model(&Message{}).Where("room_id = ? AND is_deleted = ?", roomID, false).Count(&count)
		return count, nil
	}

	// 统计已读之后的消息数
	r.db.Model(&Message{}).
		Where("room_id = ? AND is_deleted = ? AND created_at > ?", roomID, false, receipt.ReadAt).
		Count(&count)
	return count, nil
}

// === ReadReceipt 相关 ===

func (r *chatRepository) UpdateReadReceipt(receipt *ReadReceipt) error {
	return r.db.Save(receipt).Error
}

func (r *chatRepository) GetReadReceipt(roomID, userID string) (*ReadReceipt, error) {
	var receipt ReadReceipt
	if err := r.db.First(&receipt, "room_id = ? AND user_id = ?", roomID, userID).Error; err != nil {
		return nil, err
	}
	return &receipt, nil
}
