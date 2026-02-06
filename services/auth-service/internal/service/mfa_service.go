package service

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"image/png"

	"sec-chat/auth-service/internal/repository"

	"github.com/pquerna/otp/totp"
)

// MFAService MFA 服务接口
type MFAService interface {
	GenerateSecret(ctx context.Context, userID, username string) (secret string, qrCode string, err error)
	ValidateCode(ctx context.Context, userID, code string) (bool, error)
	EnableMFA(ctx context.Context, userID, code string) error
	DisableMFA(ctx context.Context, userID, code string) error
	GetMFAStatus(ctx context.Context, userID string) (bool, error)
}

type mfaService struct {
	userRepo repository.UserRepository
}

// NewMFAService 创建 MFA 服务实例
func NewMFAService(userRepo repository.UserRepository) MFAService {
	return &mfaService{userRepo: userRepo}
}

func (s *mfaService) GenerateSecret(ctx context.Context, userID, username string) (string, string, error) {
	// 生成 TOTP 密钥
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      "SecChat",
		AccountName: username,
		Period:      30,
		Digits:      6,
	})
	if err != nil {
		return "", "", fmt.Errorf("failed to generate TOTP key: %w", err)
	}

	// 生成二维码图片
	img, err := key.Image(200, 200)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate QR code: %w", err)
	}

	// 将图片转换为 Base64
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return "", "", fmt.Errorf("failed to encode QR code: %w", err)
	}
	qrCodeBase64 := base64.StdEncoding.EncodeToString(buf.Bytes())

	return key.Secret(), "data:image/png;base64," + qrCodeBase64, nil
}

func (s *mfaService) ValidateCode(ctx context.Context, userID, code string) (bool, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return false, err
	}

	if user.MFASecret == nil {
		return false, fmt.Errorf("mfa not configured for user")
	}

	valid := totp.Validate(code, *user.MFASecret)
	return valid, nil
}

func (s *mfaService) EnableMFA(ctx context.Context, userID, code string) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}

	if user.MFASecret == nil {
		return fmt.Errorf("mfa secret not set, generate a new secret first")
	}

	// 验证代码
	if !totp.Validate(code, *user.MFASecret) {
		return fmt.Errorf("invalid verification code")
	}

	// 启用 MFA
	return s.userRepo.UpdateMFA(ctx, userID, true, user.MFASecret)
}

func (s *mfaService) DisableMFA(ctx context.Context, userID, code string) error {
	// 验证代码
	valid, err := s.ValidateCode(ctx, userID, code)
	if err != nil {
		return err
	}
	if !valid {
		return fmt.Errorf("invalid verification code")
	}

	// 禁用 MFA
	return s.userRepo.UpdateMFA(ctx, userID, false, nil)
}

func (s *mfaService) GetMFAStatus(ctx context.Context, userID string) (bool, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return false, err
	}
	return user.MFAEnabled, nil
}
