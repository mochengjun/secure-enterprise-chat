package repository

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// Device 设备模型
type Device struct {
	DeviceID        string     `gorm:"column:device_id;primaryKey" json:"device_id"`
	UserID          string     `gorm:"column:user_id;index" json:"user_id"`
	DeviceName      *string    `gorm:"column:device_name" json:"device_name,omitempty"`
	DeviceType      *string    `gorm:"column:device_type" json:"device_type,omitempty"`
	DeviceOSVersion *string    `gorm:"column:device_os_version" json:"device_os_version,omitempty"`
	AppVersion      *string    `gorm:"column:app_version" json:"app_version,omitempty"`
	LastSeenIP      *string    `gorm:"column:last_seen_ip" json:"last_seen_ip,omitempty"`
	LastSeenAt      *time.Time `gorm:"column:last_seen_at" json:"last_seen_at,omitempty"`
	AccessTokenHash *string    `gorm:"column:access_token_hash" json:"-"`
	CreatedAt       time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

func (Device) TableName() string {
	return "devices"
}

// DeviceRepository 设备仓库接口
type DeviceRepository interface {
	Create(ctx context.Context, device *Device) error
	GetByID(ctx context.Context, deviceID string) (*Device, error)
	GetByUserID(ctx context.Context, userID string) ([]Device, error)
	Update(ctx context.Context, device *Device) error
	UpdateLastSeen(ctx context.Context, deviceID, ip string) error
	Delete(ctx context.Context, deviceID string) error
	DeleteByUserID(ctx context.Context, userID string) error
}

type deviceRepository struct {
	db *gorm.DB
}

// NewDeviceRepository 创建设备仓库实例
func NewDeviceRepository(db *gorm.DB) DeviceRepository {
	return &deviceRepository{db: db}
}

func (r *deviceRepository) Create(ctx context.Context, device *Device) error {
	return r.db.WithContext(ctx).Create(device).Error
}

func (r *deviceRepository) GetByID(ctx context.Context, deviceID string) (*Device, error) {
	var device Device
	if err := r.db.WithContext(ctx).Where("device_id = ?", deviceID).First(&device).Error; err != nil {
		return nil, err
	}
	return &device, nil
}

func (r *deviceRepository) GetByUserID(ctx context.Context, userID string) ([]Device, error) {
	var devices []Device
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).Order("created_at DESC").Find(&devices).Error; err != nil {
		return nil, err
	}
	return devices, nil
}

func (r *deviceRepository) Update(ctx context.Context, device *Device) error {
	return r.db.WithContext(ctx).Save(device).Error
}

func (r *deviceRepository) UpdateLastSeen(ctx context.Context, deviceID, ip string) error {
	now := time.Now()
	updates := map[string]interface{}{
		"last_seen_at": now,
		"last_seen_ip": ip,
	}
	return r.db.WithContext(ctx).Model(&Device{}).Where("device_id = ?", deviceID).Updates(updates).Error
}

func (r *deviceRepository) Delete(ctx context.Context, deviceID string) error {
	return r.db.WithContext(ctx).Where("device_id = ?", deviceID).Delete(&Device{}).Error
}

func (r *deviceRepository) DeleteByUserID(ctx context.Context, userID string) error {
	return r.db.WithContext(ctx).Where("user_id = ?", userID).Delete(&Device{}).Error
}
