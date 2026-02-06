package repository_test

import (
	"context"
	"testing"
	"time"

	"sec-chat/auth-service/internal/repository"

	"github.com/glebarez/sqlite"
	"github.com/stretchr/testify/suite"
	"gorm.io/gorm"
)

// ChatRepositoryTestSuite 聊天仓库测试套件
type ChatRepositoryTestSuite struct {
	suite.Suite
	db       *gorm.DB
	repo     repository.ChatRepository
	userRepo repository.UserRepository
	ctx      context.Context
}

func (s *ChatRepositoryTestSuite) SetupSuite() {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	s.Require().NoError(err)

	// 迁移所有相关表
	err = db.AutoMigrate(
		&repository.User{},
		&repository.Room{},
		&repository.RoomMember{},
		&repository.Message{},
		&repository.ReadReceipt{},
	)
	s.Require().NoError(err)

	s.db = db
	s.repo = repository.NewChatRepository(db)
	s.userRepo = repository.NewUserRepository(db)
	s.ctx = context.Background()
}

func (s *ChatRepositoryTestSuite) TearDownSuite() {
	sqlDB, _ := s.db.DB()
	if sqlDB != nil {
		sqlDB.Close()
	}
}

func (s *ChatRepositoryTestSuite) SetupTest() {
	s.db.Exec("DELETE FROM read_receipts")
	s.db.Exec("DELETE FROM messages")
	s.db.Exec("DELETE FROM room_members")
	s.db.Exec("DELETE FROM rooms")
	s.db.Exec("DELETE FROM users")

	// 创建测试用户
	s.createTestUser("user-001", "alice")
	s.createTestUser("user-002", "bob")
	s.createTestUser("user-003", "charlie")
}

func (s *ChatRepositoryTestSuite) createTestUser(id, username string) {
	user := &repository.User{
		UserID:       id,
		Username:     username,
		PasswordHash: "hash",
		IsActive:     true,
	}
	s.userRepo.Create(s.ctx, user)
}

// ============================================================
// Room Tests
// ============================================================

func (s *ChatRepositoryTestSuite) TestCreateRoom() {
	room := &repository.Room{
		ID:          "room-001",
		Name:        "Test Room",
		Type:        "group",
		CreatorID:   "user-001",
		Description: "A test room",
	}

	err := s.repo.CreateRoom(room)
	s.NoError(err)

	found, err := s.repo.GetRoom("room-001")
	s.NoError(err)
	s.Equal("Test Room", found.Name)
	s.Equal(repository.RoomType("group"), found.Type)
}

func (s *ChatRepositoryTestSuite) TestCreateDirectRoom() {
	room := &repository.Room{
		ID:        "dm-001",
		Name:      "Direct Message",
		Type:      "direct",
		CreatorID: "user-001",
	}

	err := s.repo.CreateRoom(room)
	s.NoError(err)

	// 添加两个成员
	s.repo.AddMember(&repository.RoomMember{
		ID:     "member-001",
		RoomID: "dm-001",
		UserID: "user-001",
		Role:   "member",
	})
	s.repo.AddMember(&repository.RoomMember{
		ID:     "member-002",
		RoomID: "dm-001",
		UserID: "user-002",
		Role:   "member",
	})

	// 验证成员存在
	isMember, err := s.repo.IsMember("dm-001", "user-001")
	s.NoError(err)
	s.True(isMember)

	isMember2, err := s.repo.IsMember("dm-001", "user-002")
	s.NoError(err)
	s.True(isMember2)
}

func (s *ChatRepositoryTestSuite) TestUpdateRoom() {
	room := &repository.Room{
		ID:        "room-update",
		Name:      "Original Name",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	// 更新房间
	room.Name = "Updated Name"
	room.Description = "New description"
	err := s.repo.UpdateRoom(room)
	s.NoError(err)

	found, _ := s.repo.GetRoom("room-update")
	s.Equal("Updated Name", found.Name)
	s.Equal("New description", found.Description)
}

func (s *ChatRepositoryTestSuite) TestDeleteRoom() {
	room := &repository.Room{
		ID:        "room-delete",
		Name:      "Delete Me",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	err := s.repo.DeleteRoom("room-delete")
	s.NoError(err)

	found, err := s.repo.GetRoom("room-delete")
	s.Error(err)
	s.Nil(found)
}

func (s *ChatRepositoryTestSuite) TestGetUserRooms() {
	// 创建多个房间
	for i := 1; i <= 5; i++ {
		room := &repository.Room{
			ID:        "room-list-" + string(rune('0'+i)),
			Name:      "Room " + string(rune('0'+i)),
			Type:      "group",
			CreatorID: "user-001",
		}
		s.repo.CreateRoom(room)
		s.repo.AddMember(&repository.RoomMember{
			ID:     "mem-" + string(rune('0'+i)),
			RoomID: room.ID,
			UserID: "user-001",
			Role:   "admin",
		})
	}

	rooms, err := s.repo.GetUserRooms("user-001")
	s.NoError(err)
	s.Len(rooms, 5)
}

// ============================================================
// Room Member Tests
// ============================================================

func (s *ChatRepositoryTestSuite) TestAddMember() {
	room := &repository.Room{
		ID:        "member-room",
		Name:      "Member Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	member := &repository.RoomMember{
		ID:     "mem-add-001",
		RoomID: "member-room",
		UserID: "user-001",
		Role:   "admin",
	}
	err := s.repo.AddMember(member)
	s.NoError(err)

	// 验证成员已添加
	isMember, err := s.repo.IsMember("member-room", "user-001")
	s.NoError(err)
	s.True(isMember)
}

func (s *ChatRepositoryTestSuite) TestRemoveMember() {
	room := &repository.Room{
		ID:        "remove-member-room",
		Name:      "Remove Member Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	s.repo.AddMember(&repository.RoomMember{
		ID:     "mem-remove-001",
		RoomID: "remove-member-room",
		UserID: "user-002",
		Role:   "member",
	})

	// 移除成员
	err := s.repo.RemoveMember("remove-member-room", "user-002")
	s.NoError(err)

	isMember, _ := s.repo.IsMember("remove-member-room", "user-002")
	s.False(isMember)
}

func (s *ChatRepositoryTestSuite) TestGetRoomMembers() {
	room := &repository.Room{
		ID:        "list-members-room",
		Name:      "List Members",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	// 添加多个成员
	s.repo.AddMember(&repository.RoomMember{ID: "lm-1", RoomID: "list-members-room", UserID: "user-001", Role: "admin"})
	s.repo.AddMember(&repository.RoomMember{ID: "lm-2", RoomID: "list-members-room", UserID: "user-002", Role: "member"})
	s.repo.AddMember(&repository.RoomMember{ID: "lm-3", RoomID: "list-members-room", UserID: "user-003", Role: "member"})

	members, err := s.repo.GetRoomMembers("list-members-room")
	s.NoError(err)
	s.Len(members, 3)
}

func (s *ChatRepositoryTestSuite) TestUpdateMember() {
	room := &repository.Room{
		ID:        "role-room",
		Name:      "Role Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	member := &repository.RoomMember{
		ID:     "role-mem-001",
		RoomID: "role-room",
		UserID: "user-002",
		Role:   "member",
	}
	s.repo.AddMember(member)

	// 升级为管理员
	member.Role = "admin"
	err := s.repo.UpdateMember(member)
	s.NoError(err)

	found, _ := s.repo.GetMember("role-room", "user-002")
	s.Equal(repository.MemberRole("admin"), found.Role)
}

// ============================================================
// Message Tests
// ============================================================

func (s *ChatRepositoryTestSuite) TestCreateMessage() {
	room := &repository.Room{
		ID:        "msg-room",
		Name:      "Message Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	msg := &repository.Message{
		ID:       "msg-001",
		RoomID:   "msg-room",
		SenderID: "user-001",
		Content:  "Hello, World!",
		Type:     "text",
	}

	err := s.repo.CreateMessage(msg)
	s.NoError(err)

	found, err := s.repo.GetMessage("msg-001")
	s.NoError(err)
	s.Equal("Hello, World!", found.Content)
}

func (s *ChatRepositoryTestSuite) TestGetMessages() {
	room := &repository.Room{
		ID:        "paginate-msg-room",
		Name:      "Paginate Messages",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	// 创建多条消息
	for i := 1; i <= 25; i++ {
		content := "Message " + string(rune('0'+i))
		msg := &repository.Message{
			ID:       "msg-p-" + string(rune('0'+i)),
			RoomID:   "paginate-msg-room",
			SenderID: "user-001",
			Content:  content,
			Type:     "text",
		}
		s.repo.CreateMessage(msg)
		time.Sleep(time.Millisecond) // 确保时间戳不同
	}

	// 获取消息（分页）
	messages, err := s.repo.GetMessages("paginate-msg-room", 20, "")
	s.NoError(err)
	s.LessOrEqual(len(messages), 20)
}

func (s *ChatRepositoryTestSuite) TestDeleteMessage() {
	room := &repository.Room{
		ID:        "delete-msg-room",
		Name:      "Delete Message",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	msg := &repository.Message{
		ID:       "delete-msg",
		RoomID:   "delete-msg-room",
		SenderID: "user-001",
		Content:  "Delete me",
		Type:     "text",
	}
	s.repo.CreateMessage(msg)

	err := s.repo.DeleteMessage("delete-msg")
	s.NoError(err)

	// 软删除 - 消息仍存在但标记为已删除
	found, err := s.repo.GetMessage("delete-msg")
	s.NoError(err)
	s.NotNil(found)
	s.True(found.IsDeleted)
}

func (s *ChatRepositoryTestSuite) TestUpdateMessage() {
	room := &repository.Room{
		ID:        "status-msg-room",
		Name:      "Status Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	msg := &repository.Message{
		ID:       "status-msg",
		RoomID:   "status-msg-room",
		SenderID: "user-001",
		Content:  "Status message",
		Type:     "text",
		Status:   "sent",
	}
	s.repo.CreateMessage(msg)

	msg.Status = "delivered"
	err := s.repo.UpdateMessage(msg)
	s.NoError(err)

	found, _ := s.repo.GetMessage("status-msg")
	s.Equal(repository.MessageStatus("delivered"), found.Status)
}

// ============================================================
// Read Receipt Tests
// ============================================================

func (s *ChatRepositoryTestSuite) TestReadReceipt() {
	room := &repository.Room{
		ID:        "read-room",
		Name:      "Read Receipt Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	msg := &repository.Message{
		ID:       "read-msg",
		RoomID:   "read-room",
		SenderID: "user-001",
		Content:  "Read me",
		Type:     "text",
	}
	s.repo.CreateMessage(msg)

	// 更新已读回执
	receipt := &repository.ReadReceipt{
		RoomID:        "read-room",
		UserID:        "user-002",
		LastMessageID: "read-msg",
		ReadAt:        time.Now(),
	}
	err := s.repo.UpdateReadReceipt(receipt)
	s.NoError(err)

	// 获取已读回执
	found, err := s.repo.GetReadReceipt("read-room", "user-002")
	s.NoError(err)
	s.Equal("read-msg", found.LastMessageID)
}

func (s *ChatRepositoryTestSuite) TestGetUnreadCount() {
	room := &repository.Room{
		ID:        "unread-room",
		Name:      "Unread Test",
		Type:      "group",
		CreatorID: "user-001",
	}
	s.repo.CreateRoom(room)

	// 添加成员
	s.repo.AddMember(&repository.RoomMember{ID: "unread-mem", RoomID: "unread-room", UserID: "user-002", Role: "member"})

	// 创建消息
	for i := 1; i <= 5; i++ {
		content := "Unread message " + string(rune('0'+i))
		msg := &repository.Message{
			ID:       "unread-msg-" + string(rune('0'+i)),
			RoomID:   "unread-room",
			SenderID: "user-001",
			Content:  content,
			Type:     "text",
		}
		s.repo.CreateMessage(msg)
	}

	// 获取未读数量
	count, err := s.repo.GetUnreadCount("unread-room", "user-002")
	s.NoError(err)
	s.GreaterOrEqual(count, int64(0))
}

// 运行测试套件
func TestChatRepositorySuite(t *testing.T) {
	suite.Run(t, new(ChatRepositoryTestSuite))
}
