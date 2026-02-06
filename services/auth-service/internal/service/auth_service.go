package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"sec-chat/auth-service/internal/repository"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUserNotFound       = errors.New("user not found")
	ErrUserExists         = errors.New("user already exists")
	ErrMFARequired        = errors.New("mfa verification required")
	ErrInvalidMFACode     = errors.New("invalid mfa code")
	ErrTokenExpired       = errors.New("token expired")
	ErrTokenInvalid       = errors.New("token invalid")
	ErrTokenBlacklisted   = errors.New("token blacklisted")
)

// Claims JWT 声明
type Claims struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	DeviceID string `json:"device_id"`
	jwt.RegisteredClaims
}

// LoginRequest 登录请求
type LoginRequest struct {
	Username   string `json:"username" binding:"required"`
	Password   string `json:"password" binding:"required"`
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
	DeviceType string `json:"device_type"`
}

// RegisterRequest 注册请求
type RegisterRequest struct {
	Username    string  `json:"username" binding:"required,min=3,max=50"`
	Password    string  `json:"password" binding:"required,min=8"`
	PhoneNumber *string `json:"phone_number"`
	Email       *string `json:"email"`
	DisplayName *string `json:"display_name"`
}

// TokenResponse Token 响应
type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
	TokenType    string `json:"token_type"`
	MFARequired  bool   `json:"mfa_required,omitempty"`
}

// AuthService 认证服务接口
type AuthService interface {
	Register(ctx context.Context, req *RegisterRequest) (*repository.User, error)
	Login(ctx context.Context, req *LoginRequest) (*TokenResponse, error)
	RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error)
	Logout(ctx context.Context, accessToken, refreshToken string) error
	ValidateToken(ctx context.Context, token string) (*Claims, error)
	GetUserByID(ctx context.Context, userID string) (*repository.User, error)
	ChangePassword(ctx context.Context, userID, oldPassword, newPassword string) error
	GetDevices(ctx context.Context, userID string) ([]repository.Device, error)
	RevokeDevice(ctx context.Context, userID, deviceID string) error
}

type authService struct {
	userRepo   repository.UserRepository
	deviceRepo repository.DeviceRepository
	tokenRepo  repository.TokenRepository
	jwtSecret  []byte
}

// NewAuthService 创建认证服务实例
func NewAuthService(
	userRepo repository.UserRepository,
	deviceRepo repository.DeviceRepository,
	tokenRepo repository.TokenRepository,
	jwtSecret string,
) AuthService {
	return &authService{
		userRepo:   userRepo,
		deviceRepo: deviceRepo,
		tokenRepo:  tokenRepo,
		jwtSecret:  []byte(jwtSecret),
	}
}

func (s *authService) Register(ctx context.Context, req *RegisterRequest) (*repository.User, error) {
	// 检查用户是否已存在
	existingUser, _ := s.userRepo.GetByUsername(ctx, req.Username)
	if existingUser != nil {
		return nil, ErrUserExists
	}

	// 哈希密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	// 生成用户 ID（Matrix 格式）
	userID := fmt.Sprintf("@%s:sec-chat.local", req.Username)

	user := &repository.User{
		UserID:       userID,
		Username:     req.Username,
		PasswordHash: string(hashedPassword),
		PhoneNumber:  req.PhoneNumber,
		Email:        req.Email,
		DisplayName:  req.DisplayName,
		IsActive:     true,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return user, nil
}

func (s *authService) Login(ctx context.Context, req *LoginRequest) (*TokenResponse, error) {
	// 获取用户
	user, err := s.userRepo.GetByUsername(ctx, req.Username)
	if err != nil {
		return nil, ErrInvalidCredentials
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	// 检查是否需要 MFA
	if user.MFAEnabled {
		return &TokenResponse{
			MFARequired: true,
		}, nil
	}

	// 创建或更新设备
	deviceID := req.DeviceID
	if deviceID == "" {
		deviceID = uuid.New().String()
	}

	device := &repository.Device{
		DeviceID:   deviceID,
		UserID:     user.UserID,
		DeviceName: &req.DeviceName,
		DeviceType: &req.DeviceType,
	}

	// 尝试获取现有设备
	existingDevice, _ := s.deviceRepo.GetByID(ctx, deviceID)
	if existingDevice == nil {
		if err := s.deviceRepo.Create(ctx, device); err != nil {
			return nil, fmt.Errorf("failed to create device: %w", err)
		}
	}

	// 生成 Token
	return s.generateTokens(ctx, user, deviceID)
}

func (s *authService) RefreshToken(ctx context.Context, refreshToken string) (*TokenResponse, error) {
	// 验证 Refresh Token
	tokenHash := s.tokenRepo.HashToken(refreshToken)
	storedToken, err := s.tokenRepo.GetRefreshToken(ctx, tokenHash)
	if err != nil {
		return nil, ErrTokenInvalid
	}

	// 获取用户
	user, err := s.userRepo.GetByID(ctx, storedToken.UserID)
	if err != nil {
		return nil, ErrUserNotFound
	}

	// 撤销旧的 Refresh Token
	if err := s.tokenRepo.RevokeRefreshToken(ctx, tokenHash); err != nil {
		return nil, fmt.Errorf("failed to revoke old token: %w", err)
	}

	// 生成新的 Token
	return s.generateTokens(ctx, user, storedToken.DeviceID)
}

func (s *authService) Logout(ctx context.Context, accessToken, refreshToken string) error {
	// 解析 Access Token 获取过期时间
	claims, err := s.parseToken(accessToken)
	if err == nil {
		// 将 Access Token 加入黑名单
		tokenHash := s.tokenRepo.HashToken(accessToken)
		if err := s.tokenRepo.AddToBlacklist(ctx, tokenHash, claims.ExpiresAt.Time); err != nil {
			return fmt.Errorf("failed to blacklist access token: %w", err)
		}
	}

	// 撤销 Refresh Token
	if refreshToken != "" {
		tokenHash := s.tokenRepo.HashToken(refreshToken)
		if err := s.tokenRepo.RevokeRefreshToken(ctx, tokenHash); err != nil {
			return fmt.Errorf("failed to revoke refresh token: %w", err)
		}
	}

	return nil
}

func (s *authService) ValidateToken(ctx context.Context, token string) (*Claims, error) {
	// 检查是否在黑名单中
	tokenHash := s.tokenRepo.HashToken(token)
	blacklisted, err := s.tokenRepo.IsBlacklisted(ctx, tokenHash)
	if err != nil {
		return nil, fmt.Errorf("failed to check blacklist: %w", err)
	}
	if blacklisted {
		return nil, ErrTokenBlacklisted
	}

	// 解析和验证 Token
	claims, err := s.parseToken(token)
	if err != nil {
		return nil, err
	}

	return claims, nil
}

func (s *authService) GetUserByID(ctx context.Context, userID string) (*repository.User, error) {
	return s.userRepo.GetByID(ctx, userID)
}

func (s *authService) ChangePassword(ctx context.Context, userID, oldPassword, newPassword string) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return ErrUserNotFound
	}

	// 验证旧密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(oldPassword)); err != nil {
		return ErrInvalidCredentials
	}

	// 哈希新密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("failed to hash password: %w", err)
	}

	// 更新密码
	if err := s.userRepo.UpdatePassword(ctx, userID, string(hashedPassword)); err != nil {
		return fmt.Errorf("failed to update password: %w", err)
	}

	// 撤销所有 Token
	if err := s.tokenRepo.RevokeAllUserTokens(ctx, userID); err != nil {
		return fmt.Errorf("failed to revoke tokens: %w", err)
	}

	return nil
}

func (s *authService) GetDevices(ctx context.Context, userID string) ([]repository.Device, error) {
	return s.deviceRepo.GetByUserID(ctx, userID)
}

func (s *authService) RevokeDevice(ctx context.Context, userID, deviceID string) error {
	// 验证设备属于该用户
	device, err := s.deviceRepo.GetByID(ctx, deviceID)
	if err != nil {
		return fmt.Errorf("device not found: %w", err)
	}
	if device.UserID != userID {
		return errors.New("device does not belong to user")
	}

	// 撤销设备的所有 Token
	if err := s.tokenRepo.RevokeDeviceTokens(ctx, deviceID); err != nil {
		return fmt.Errorf("failed to revoke device tokens: %w", err)
	}

	// 删除设备
	if err := s.deviceRepo.Delete(ctx, deviceID); err != nil {
		return fmt.Errorf("failed to delete device: %w", err)
	}

	return nil
}

// 生成 Access Token 和 Refresh Token
func (s *authService) generateTokens(ctx context.Context, user *repository.User, deviceID string) (*TokenResponse, error) {
	now := time.Now()
	accessTokenExpiry := now.Add(time.Hour)           // Access Token 1 小时有效
	refreshTokenExpiry := now.Add(7 * 24 * time.Hour) // Refresh Token 7 天有效

	// 生成 Access Token
	accessClaims := &Claims{
		UserID:   user.UserID,
		Username: user.Username,
		DeviceID: deviceID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(accessTokenExpiry),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Issuer:    "sec-chat-auth",
			Subject:   user.UserID,
		},
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessTokenString, err := accessToken.SignedString(s.jwtSecret)
	if err != nil {
		return nil, fmt.Errorf("failed to sign access token: %w", err)
	}

	// 生成 Refresh Token
	refreshTokenString := uuid.New().String()
	refreshTokenHash := s.tokenRepo.HashToken(refreshTokenString)

	refreshTokenRecord := &repository.RefreshToken{
		TokenHash: refreshTokenHash,
		UserID:    user.UserID,
		DeviceID:  deviceID,
		ExpiresAt: refreshTokenExpiry,
	}

	if err := s.tokenRepo.SaveRefreshToken(ctx, refreshTokenRecord); err != nil {
		return nil, fmt.Errorf("failed to save refresh token: %w", err)
	}

	return &TokenResponse{
		AccessToken:  accessTokenString,
		RefreshToken: refreshTokenString,
		ExpiresIn:    int64(time.Until(accessTokenExpiry).Seconds()),
		TokenType:    "Bearer",
	}, nil
}

// 解析 Token
func (s *authService) parseToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrTokenExpired
		}
		return nil, ErrTokenInvalid
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrTokenInvalid
	}

	return claims, nil
}
