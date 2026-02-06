package repository_test

import (
	"context"
	"testing"

	"sec-chat/auth-service/internal/repository"

	"github.com/glebarez/sqlite"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"gorm.io/gorm"
)

// UserRepositoryTestSuite 用户仓库测试套件
type UserRepositoryTestSuite struct {
	suite.Suite
	db   *gorm.DB
	repo repository.UserRepository
	ctx  context.Context
}

// SetupSuite 测试套件初始化
func (s *UserRepositoryTestSuite) SetupSuite() {
	// 使用内存 SQLite 数据库
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	s.Require().NoError(err)

	// 自动迁移
	err = db.AutoMigrate(&repository.User{}, &repository.Device{}, &repository.RefreshToken{}, &repository.TokenBlacklist{})
	s.Require().NoError(err)

	s.db = db
	s.repo = repository.NewUserRepository(db)
	s.ctx = context.Background()
}

// TearDownSuite 测试套件清理
func (s *UserRepositoryTestSuite) TearDownSuite() {
	sqlDB, _ := s.db.DB()
	if sqlDB != nil {
		sqlDB.Close()
	}
}

// SetupTest 每个测试前清理数据
func (s *UserRepositoryTestSuite) SetupTest() {
	s.db.Exec("DELETE FROM users")
	s.db.Exec("DELETE FROM devices")
	s.db.Exec("DELETE FROM refresh_tokens")
}

// TestCreateUser 测试创建用户
func (s *UserRepositoryTestSuite) TestCreateUser() {
	user := &repository.User{
		UserID:       "user-001",
		Username:     "testuser",
		PasswordHash: "hashedpassword123",
		PhoneNumber:  ptrString("+1234567890"),
		Email:        ptrString("test@example.com"),
		DisplayName:  ptrString("Test User"),
		IsActive:     true,
	}

	err := s.repo.Create(s.ctx, user)
	s.NoError(err)

	// 验证用户已创建
	found, err := s.repo.GetByID(s.ctx, user.UserID)
	s.NoError(err)
	s.NotNil(found)
	s.Equal("testuser", found.Username)
	s.Equal("test@example.com", *found.Email)
}

// TestCreateUserDuplicateUsername 测试重复用户名
func (s *UserRepositoryTestSuite) TestCreateUserDuplicateUsername() {
	user1 := &repository.User{
		UserID:       "user-001",
		Username:     "duplicateuser",
		PasswordHash: "hash1",
		IsActive:     true,
	}
	err := s.repo.Create(s.ctx, user1)
	s.NoError(err)

	user2 := &repository.User{
		UserID:       "user-002",
		Username:     "duplicateuser", // 重复用户名
		PasswordHash: "hash2",
		IsActive:     true,
	}
	err = s.repo.Create(s.ctx, user2)
	s.Error(err) // 应该失败
}

// TestGetByUsername 测试按用户名查询
func (s *UserRepositoryTestSuite) TestGetByUsername() {
	user := &repository.User{
		UserID:       "user-001",
		Username:     "findme",
		PasswordHash: "hash",
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	found, err := s.repo.GetByUsername(s.ctx, "findme")
	s.NoError(err)
	s.NotNil(found)
	s.Equal("user-001", found.UserID)

	// 查询不存在的用户
	notFound, err := s.repo.GetByUsername(s.ctx, "nonexistent")
	s.Error(err)
	s.Nil(notFound)
}

// TestGetByPhoneNumber 测试按手机号查询
func (s *UserRepositoryTestSuite) TestGetByPhoneNumber() {
	phone := "+9876543210"
	user := &repository.User{
		UserID:       "user-001",
		Username:     "phoneuser",
		PasswordHash: "hash",
		PhoneNumber:  &phone,
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	found, err := s.repo.GetByPhoneNumber(s.ctx, phone)
	s.NoError(err)
	s.NotNil(found)
	s.Equal("phoneuser", found.Username)
}

// TestUpdateUser 测试更新用户
func (s *UserRepositoryTestSuite) TestUpdateUser() {
	user := &repository.User{
		UserID:       "user-001",
		Username:     "updateme",
		PasswordHash: "oldhash",
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	// 更新用户
	user.PasswordHash = "newhash"
	newName := "Updated Name"
	user.DisplayName = &newName
	err := s.repo.Update(s.ctx, user)
	s.NoError(err)

	// 验证更新
	found, _ := s.repo.GetByID(s.ctx, "user-001")
	s.Equal("newhash", found.PasswordHash)
	s.Equal("Updated Name", *found.DisplayName)
}

// TestDeleteUser 测试删除用户
func (s *UserRepositoryTestSuite) TestDeleteUser() {
	user := &repository.User{
		UserID:       "user-delete",
		Username:     "deleteme",
		PasswordHash: "hash",
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	err := s.repo.Delete(s.ctx, "user-delete")
	s.NoError(err)

	// 验证已删除（软删除 - IsActive = false）
	found, err := s.repo.GetByID(s.ctx, "user-delete")
	s.Error(err)
	s.Nil(found)
}

// TestListUsers 测试用户列表分页
func (s *UserRepositoryTestSuite) TestListUsers() {
	// 创建多个用户
	for i := 1; i <= 15; i++ {
		user := &repository.User{
			UserID:       "user-list-" + string(rune('a'+i)),
			Username:     "userlist" + string(rune('a'+i)),
			PasswordHash: "hash",
			IsActive:     true,
		}
		s.repo.Create(s.ctx, user)
	}

	// 测试分页
	users, total, err := s.repo.List(s.ctx, 0, 10)
	s.NoError(err)
	s.Equal(int64(15), total)
	s.Len(users, 10)

	// 第二页
	users2, _, err := s.repo.List(s.ctx, 10, 10)
	s.NoError(err)
	s.Len(users2, 5)
}

// TestUpdatePassword 测试更新密码
func (s *UserRepositoryTestSuite) TestUpdatePassword() {
	user := &repository.User{
		UserID:       "pass-user",
		Username:     "passuser",
		PasswordHash: "oldhash",
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	err := s.repo.UpdatePassword(s.ctx, "pass-user", "newhash")
	s.NoError(err)

	found, _ := s.repo.GetByID(s.ctx, "pass-user")
	s.Equal("newhash", found.PasswordHash)
}

// TestUpdateMFA 测试更新MFA
func (s *UserRepositoryTestSuite) TestUpdateMFA() {
	user := &repository.User{
		UserID:       "mfa-user",
		Username:     "mfauser",
		PasswordHash: "hash",
		MFAEnabled:   false,
		IsActive:     true,
	}
	s.repo.Create(s.ctx, user)

	// 启用 MFA
	secret := "JBSWY3DPEHPK3PXP"
	err := s.repo.UpdateMFA(s.ctx, "mfa-user", true, &secret)
	s.NoError(err)

	// 验证 MFA 已启用
	found, _ := s.repo.GetByID(s.ctx, "mfa-user")
	s.True(found.MFAEnabled)
	s.Equal(secret, *found.MFASecret)

	// 禁用 MFA
	err = s.repo.UpdateMFA(s.ctx, "mfa-user", false, nil)
	s.NoError(err)

	found, _ = s.repo.GetByID(s.ctx, "mfa-user")
	s.False(found.MFAEnabled)
}

// 运行测试套件
func TestUserRepositorySuite(t *testing.T) {
	suite.Run(t, new(UserRepositoryTestSuite))
}

// 辅助函数
func ptrString(s string) *string {
	return &s
}

// ============================================================
// 独立测试函数
// ============================================================

func TestUserModel(t *testing.T) {
	user := &repository.User{
		UserID:       "test-id",
		Username:     "testuser",
		PasswordHash: "hash",
	}

	assert.Equal(t, "test-id", user.UserID)
	assert.Equal(t, "testuser", user.Username)
	assert.False(t, user.MFAEnabled)
}

func TestDeviceModel(t *testing.T) {
	device := &repository.Device{
		DeviceID: "device-id",
		UserID:   "user-id",
	}

	assert.Equal(t, "device-id", device.DeviceID)
	assert.Equal(t, "user-id", device.UserID)
}
