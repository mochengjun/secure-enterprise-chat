-- 企业安全聊天应用数据库初始化脚本
-- 此脚本在 PostgreSQL 容器首次启动时自动执行

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 用户和设备管理
-- ============================================

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    user_id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    email VARCHAR(255),
    display_name VARCHAR(255),
    avatar_url VARCHAR(500),
    mfa_enabled BOOLEAN DEFAULT false,
    mfa_secret VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 设备表
CREATE TABLE IF NOT EXISTS devices (
    device_id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    device_name VARCHAR(255),
    device_type VARCHAR(50),
    device_os_version VARCHAR(50),
    app_version VARCHAR(50),
    last_seen_ip VARCHAR(50),
    last_seen_at TIMESTAMP,
    access_token_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);

-- ============================================
-- 媒体文件管理
-- ============================================

-- 媒体文件表
CREATE TABLE IF NOT EXISTS media_files (
    file_id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id),
    room_id VARCHAR(255),
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    storage_path VARCHAR(500) NOT NULL,
    thumbnail_path VARCHAR(500),
    width INT,
    height INT,
    duration INT,
    encrypted BOOLEAN DEFAULT true,
    encryption_key TEXT,
    password_protected BOOLEAN DEFAULT false,
    password_hash VARCHAR(255),
    download_count INT DEFAULT 0,
    download_limit INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_files_user_id ON media_files(user_id);
CREATE INDEX IF NOT EXISTS idx_media_files_room_id ON media_files(room_id);
CREATE INDEX IF NOT EXISTS idx_media_files_expires_at ON media_files(expires_at);

-- 媒体访问日志
CREATE TABLE IF NOT EXISTS media_access_logs (
    log_id BIGSERIAL PRIMARY KEY,
    file_id VARCHAR(255) REFERENCES media_files(file_id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(user_id),
    device_id VARCHAR(255),
    access_type VARCHAR(20) NOT NULL,
    ip_address VARCHAR(50),
    user_agent TEXT,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_access_logs_file_id ON media_access_logs(file_id);

-- 媒体播放记录
CREATE TABLE IF NOT EXISTS media_play_logs (
    log_id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id),
    media_file_id VARCHAR(255),
    media_type VARCHAR(20) NOT NULL,
    played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    duration_played INT,
    completion_rate DECIMAL(5,2)
);

CREATE INDEX IF NOT EXISTS idx_media_play_logs_user_id ON media_play_logs(user_id);

-- ============================================
-- 通话记录
-- ============================================

-- 通话记录表
CREATE TABLE IF NOT EXISTS calls (
    call_id VARCHAR(255) PRIMARY KEY,
    room_id VARCHAR(255),
    call_type VARCHAR(20) NOT NULL,
    initiator_user_id VARCHAR(255) REFERENCES users(user_id),
    status VARCHAR(20) DEFAULT 'ringing',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    answered_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration INT,
    participants_count INT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_calls_room_id ON calls(room_id);
CREATE INDEX IF NOT EXISTS idx_calls_initiator ON calls(initiator_user_id);

-- 通话参与者
CREATE TABLE IF NOT EXISTS call_participants (
    id SERIAL PRIMARY KEY,
    call_id VARCHAR(255) REFERENCES calls(call_id) ON DELETE CASCADE,
    user_id VARCHAR(255) REFERENCES users(user_id),
    device_id VARCHAR(255),
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    left_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_call_participants_call_id ON call_participants(call_id);

-- ============================================
-- 系统配置和消息保留策略
-- ============================================

-- 全局系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value JSONB NOT NULL,
    description TEXT,
    updated_by VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 插入默认配置
INSERT INTO system_config (config_key, config_value, description) VALUES
('message_retention_default', '{"duration_hours": 72, "enabled": true}', '默认消息保留时间（小时）'),
('system_log_retention_days', '{"days": 30}', '系统日志保留天数'),
('max_file_size_mb', '{"size": 100}', '最大文件上传大小（MB）'),
('max_group_members', '{"count": 5000}', '群组最大成员数')
ON CONFLICT (config_key) DO NOTHING;

-- 群组级别保留策略表
CREATE TABLE IF NOT EXISTS room_retention_policy (
    room_id VARCHAR(255) PRIMARY KEY,
    retention_hours INT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    set_by VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 推送通知
-- ============================================

-- 推送 Token 表
CREATE TABLE IF NOT EXISTS push_tokens (
    token_id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    device_id VARCHAR(255) REFERENCES devices(device_id) ON DELETE CASCADE,
    push_token TEXT NOT NULL,
    platform VARCHAR(20) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(push_token)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON push_tokens(user_id);

-- ============================================
-- 审计日志
-- ============================================

-- 审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    details JSONB,
    ip_address VARCHAR(50),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- 系统日志表
CREATE TABLE IF NOT EXISTS system_logs (
    log_id BIGSERIAL PRIMARY KEY,
    level VARCHAR(20) NOT NULL,
    service VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_system_logs_service ON system_logs(service);
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON system_logs(created_at);

-- ============================================
-- 会话和 Token 管理
-- ============================================

-- 刷新 Token 表
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE CASCADE,
    device_id VARCHAR(255) REFERENCES devices(device_id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Token 黑名单（用于已注销但未过期的 Token）
CREATE TABLE IF NOT EXISTS token_blacklist (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires_at ON token_blacklist(expires_at);

-- ============================================
-- 更新触发器
-- ============================================

-- 创建更新时间戳的函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表添加触发器
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_room_retention_policy_updated_at
    BEFORE UPDATE ON room_retention_policy
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at
    BEFORE UPDATE ON system_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_push_tokens_updated_at
    BEFORE UPDATE ON push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 完成提示
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '数据库初始化完成！';
END $$;
