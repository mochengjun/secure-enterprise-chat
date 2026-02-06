package service_test

import (
	"context"
	"testing"

	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"

	"github.com/glebarez/sqlite"
	"github.com/stretchr/testify/suite"
	"gorm.io/gorm"
)

// AuthServiceTestSuite 认证服务测试套件
type AuthServiceTestSuite struct {
	suite.Suite
	db         *gorm.DB
	userRepo   repository.UserRepository
	deviceRepo repository.DeviceRepository
	tokenRepo  repository.TokenRepository
	svc        service.AuthService
	ctx        context.Context
}

func (s *AuthServiceTestSuite) SetupSuite() {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	s.Require().NoError(err)

	err = db.AutoMigrate(
		&repository.User{},
		&repository.Device{},
		&repository.RefreshToken{},
		&repository.TokenBlacklist{},
	)
	s.Require().NoError(err)

	s.db = db
	s.userRepo = repository.NewUserRepository(db)
	s.deviceRepo = repository.NewDeviceRepository(db)
	s.tokenRepo = repository.NewTokenRepositoryWithoutRedis(db)
	s.svc = service.NewAuthService(s.userRepo, s.deviceRepo, s.tokenRepo, "test-jwt-secret-key-32chars!!")
	s.ctx = context.Background()
}

func (s *AuthServiceTestSuite) TearDownSuite() {
	sqlDB, _ := s.db.DB()
	if sqlDB != nil {
		sqlDB.Close()
	}
}

func (s *AuthServiceTestSuite) SetupTest() {
	s.db.Exec("DELETE FROM token_blacklist")
	s.db.Exec("DELETE FROM refresh_tokens")
	s.db.Exec("DELETE FROM devices")
	s.db.Exec("DELETE FROM users")
}

// ============================================================
// Registration Tests
// ============================================================

func (s *AuthServiceTestSuite) TestRegister() {
	email := "newuser@example.com"
	displayName := "New User"
	req := &service.RegisterRequest{
		Username:    "newuser",
		Password:    "SecurePass123!",
		Email:       &email,
		DisplayName: &displayName,
	}

	user, err := s.svc.Register(s.ctx, req)
	s.NoError(err)
	s.NotNil(user)
	s.Equal("newuser", user.Username)
	s.NotEmpty(user.UserID)
}

func (s *AuthServiceTestSuite) TestRegisterDuplicateUsername() {
	req := &service.RegisterRequest{
		Username: "duplicate",
		Password: "SecurePass123!",
	}

	_, err := s.svc.Register(s.ctx, req)
	s.NoError(err)

	// 尝试注册相同用户名
	_, err = s.svc.Register(s.ctx, req)
	s.Error(err)
}

// ============================================================
// Login Tests
// ============================================================

func (s *AuthServiceTestSuite) TestLogin() {
	// 先注册用户
	s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "loginuser",
		Password: "SecurePass123!",
	})

	// 登录
	req := &service.LoginRequest{
		Username:   "loginuser",
		Password:   "SecurePass123!",
		DeviceID:   "test-device-001",
		DeviceName: "Test Device",
		DeviceType: "test",
	}

	resp, err := s.svc.Login(s.ctx, req)
	s.NoError(err)
	s.NotNil(resp)
	s.NotEmpty(resp.AccessToken)
	s.NotEmpty(resp.RefreshToken)
}

func (s *AuthServiceTestSuite) TestLoginInvalidPassword() {
	s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "wrongpassuser",
		Password: "CorrectPass123!",
	})

	req := &service.LoginRequest{
		Username: "wrongpassuser",
		Password: "WrongPass123!",
	}

	_, err := s.svc.Login(s.ctx, req)
	s.Error(err)
}

func (s *AuthServiceTestSuite) TestLoginNonexistentUser() {
	req := &service.LoginRequest{
		Username: "nonexistent",
		Password: "SomePass123!",
	}

	_, err := s.svc.Login(s.ctx, req)
	s.Error(err)
}

// ============================================================
// Token Tests
// ============================================================

func (s *AuthServiceTestSuite) TestValidateToken() {
	// 注册并登录
	s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "tokenuser",
		Password: "SecurePass123!",
	})

	loginResp, _ := s.svc.Login(s.ctx, &service.LoginRequest{
		Username: "tokenuser",
		Password: "SecurePass123!",
	})

	// 验证 token
	claims, err := s.svc.ValidateToken(s.ctx, loginResp.AccessToken)
	s.NoError(err)
	s.NotNil(claims)
}

func (s *AuthServiceTestSuite) TestValidateInvalidToken() {
	_, err := s.svc.ValidateToken(s.ctx, "invalid.token.here")
	s.Error(err)
}

func (s *AuthServiceTestSuite) TestRefreshToken() {
	// 注册并登录
	s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "refreshuser",
		Password: "SecurePass123!",
	})

	loginResp, _ := s.svc.Login(s.ctx, &service.LoginRequest{
		Username:   "refreshuser",
		Password:   "SecurePass123!",
		DeviceID:   "refresh-device",
		DeviceName: "Refresh Device",
	})

	// 刷新 token
	newTokens, err := s.svc.RefreshToken(s.ctx, loginResp.RefreshToken)
	s.NoError(err)
	s.NotNil(newTokens)
	s.NotEmpty(newTokens.AccessToken)
}

func (s *AuthServiceTestSuite) TestLogout() {
	// 注册并登录
	s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "logoutuser",
		Password: "SecurePass123!",
	})

	loginResp, _ := s.svc.Login(s.ctx, &service.LoginRequest{
		Username: "logoutuser",
		Password: "SecurePass123!",
	})

	// 登出
	err := s.svc.Logout(s.ctx, loginResp.AccessToken, loginResp.RefreshToken)
	s.NoError(err)

	// 验证 token 已失效
	_, err = s.svc.ValidateToken(s.ctx, loginResp.AccessToken)
	s.Error(err)
}

// ============================================================
// Password Tests
// ============================================================

func (s *AuthServiceTestSuite) TestChangePassword() {
	user, _ := s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "changepassuser",
		Password: "OldPass123!",
	})

	err := s.svc.ChangePassword(s.ctx, user.UserID, "OldPass123!", "NewPass456!")
	s.NoError(err)

	// 使用新密码登录
	_, err = s.svc.Login(s.ctx, &service.LoginRequest{
		Username: "changepassuser",
		Password: "NewPass456!",
	})
	s.NoError(err)

	// 旧密码应该失效
	_, err = s.svc.Login(s.ctx, &service.LoginRequest{
		Username: "changepassuser",
		Password: "OldPass123!",
	})
	s.Error(err)
}

func (s *AuthServiceTestSuite) TestChangePasswordWrongOldPassword() {
	user, _ := s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "wrongoldpass",
		Password: "CorrectOld123!",
	})

	err := s.svc.ChangePassword(s.ctx, user.UserID, "WrongOld123!", "NewPass456!")
	s.Error(err)
}

// ============================================================
// Device Tests
// ============================================================

func (s *AuthServiceTestSuite) TestGetDevices() {
	user, _ := s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "devicelistuser",
		Password: "SecurePass123!",
	})

	// 从多个设备登录
	for i := 1; i <= 3; i++ {
		s.svc.Login(s.ctx, &service.LoginRequest{
			Username:   "devicelistuser",
			Password:   "SecurePass123!",
			DeviceID:   "device-" + string(rune('0'+i)),
			DeviceName: "Device " + string(rune('0'+i)),
		})
	}

	devices, err := s.svc.GetDevices(s.ctx, user.UserID)
	s.NoError(err)
	s.GreaterOrEqual(len(devices), 1)
}

func (s *AuthServiceTestSuite) TestRevokeDevice() {
	user, _ := s.svc.Register(s.ctx, &service.RegisterRequest{
		Username: "revokedeviceuser",
		Password: "SecurePass123!",
	})

	s.svc.Login(s.ctx, &service.LoginRequest{
		Username:   "revokedeviceuser",
		Password:   "SecurePass123!",
		DeviceID:   "revoke-device",
		DeviceName: "Revoke Device",
	})

	err := s.svc.RevokeDevice(s.ctx, user.UserID, "revoke-device")
	s.NoError(err)
}

// 运行测试套件
func TestAuthServiceSuite(t *testing.T) {
	suite.Run(t, new(AuthServiceTestSuite))
}
