package repository

import (
	"database/sql"
	"time"

	_ "github.com/lib/pq"
)

type CleanupRepository struct {
	db *sql.DB
}

func NewCleanupRepository(databaseURL string) (*CleanupRepository, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, err
	}

	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &CleanupRepository{db: db}, nil
}

func (r *CleanupRepository) Close() error {
	return r.db.Close()
}

// GetRoomRetentionPolicies 获取所有群组的消息保留策略
func (r *CleanupRepository) GetRoomRetentionPolicies() ([]RoomRetentionPolicy, error) {
	query := `
		SELECT room_id, retention_hours, enabled, created_at, updated_at
		FROM room_retention_policy
		WHERE enabled = true
	`

	rows, err := r.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var policies []RoomRetentionPolicy
	for rows.Next() {
		var policy RoomRetentionPolicy
		err := rows.Scan(
			&policy.RoomID,
			&policy.RetentionHours,
			&policy.Enabled,
			&policy.CreatedAt,
			&policy.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		policies = append(policies, policy)
	}

	return policies, rows.Err()
}

// GetGlobalRetentionHours 获取全局默认保留时间
func (r *CleanupRepository) GetGlobalRetentionHours() (int, error) {
	query := `
		SELECT config_value
		FROM system_config
		WHERE config_key = 'default_retention_hours'
	`

	var hours int
	err := r.db.QueryRow(query).Scan(&hours)
	if err == sql.ErrNoRows {
		return 72, nil // 默认72小时
	}
	if err != nil {
		return 0, err
	}
	return hours, nil
}

// DeleteExpiredMessages 删除指定群组的过期消息
func (r *CleanupRepository) DeleteExpiredMessages(roomID string, beforeTime time.Time) (int64, error) {
	query := `
		DELETE FROM events
		WHERE room_id = $1
		AND origin_server_ts < $2
		AND type IN ('m.room.message', 'm.room.encrypted')
	`

	result, err := r.db.Exec(query, roomID, beforeTime.UnixMilli())
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredMessagesGlobal 删除所有无特定策略群组的过期消息
func (r *CleanupRepository) DeleteExpiredMessagesGlobal(beforeTime time.Time, excludeRooms []string) (int64, error) {
	query := `
		DELETE FROM events
		WHERE origin_server_ts < $1
		AND type IN ('m.room.message', 'm.room.encrypted')
		AND ($2::text[] IS NULL OR room_id != ALL($2))
	`

	var excludeArray interface{}
	if len(excludeRooms) > 0 {
		excludeArray = excludeRooms
	}

	result, err := r.db.Exec(query, beforeTime.UnixMilli(), excludeArray)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredMediaFiles 删除过期的媒体文件记录
func (r *CleanupRepository) DeleteExpiredMediaFiles(beforeTime time.Time) ([]string, error) {
	// 先获取要删除的文件路径
	query := `
		SELECT storage_path
		FROM media_files
		WHERE expires_at IS NOT NULL
		AND expires_at < $1
	`

	rows, err := r.db.Query(query, beforeTime)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var paths []string
	for rows.Next() {
		var path string
		if err := rows.Scan(&path); err != nil {
			return nil, err
		}
		paths = append(paths, path)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	// 删除记录
	deleteQuery := `
		DELETE FROM media_files
		WHERE expires_at IS NOT NULL
		AND expires_at < $1
	`
	_, err = r.db.Exec(deleteQuery, beforeTime)
	if err != nil {
		return nil, err
	}

	return paths, nil
}

// DeleteOldAuditLogs 删除旧的审计日志
func (r *CleanupRepository) DeleteOldAuditLogs(beforeTime time.Time) (int64, error) {
	query := `
		DELETE FROM audit_logs
		WHERE created_at < $1
	`

	result, err := r.db.Exec(query, beforeTime)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// DeleteExpiredTokens 删除过期的Token
func (r *CleanupRepository) DeleteExpiredTokens() (int64, error) {
	query := `
		DELETE FROM refresh_tokens
		WHERE expires_at < NOW()
		OR revoked = true
	`

	result, err := r.db.Exec(query)
	if err != nil {
		return 0, err
	}

	return result.RowsAffected()
}

// GetCleanupStats 获取清理统计
func (r *CleanupRepository) GetCleanupStats() (*CleanupStats, error) {
	stats := &CleanupStats{}

	// 统计过期消息数量
	msgQuery := `
		SELECT COUNT(*)
		FROM events
		WHERE type IN ('m.room.message', 'm.room.encrypted')
	`
	r.db.QueryRow(msgQuery).Scan(&stats.TotalMessages)

	// 统计媒体文件数量
	mediaQuery := `SELECT COUNT(*) FROM media_files`
	r.db.QueryRow(mediaQuery).Scan(&stats.TotalMediaFiles)

	// 统计审计日志数量
	logQuery := `SELECT COUNT(*) FROM audit_logs`
	r.db.QueryRow(logQuery).Scan(&stats.TotalAuditLogs)

	return stats, nil
}

// RoomRetentionPolicy 群组消息保留策略
type RoomRetentionPolicy struct {
	RoomID         string
	RetentionHours int
	Enabled        bool
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// CleanupStats 清理统计
type CleanupStats struct {
	TotalMessages   int64
	TotalMediaFiles int64
	TotalAuditLogs  int64
}
