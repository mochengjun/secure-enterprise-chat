package handler

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"sec-chat/auth-service/internal/service"
)

// MediaHandler 媒体处理器
type MediaHandler struct {
	service service.MediaService
}

// NewMediaHandler 创建媒体处理器实例
func NewMediaHandler(service service.MediaService) *MediaHandler {
	return &MediaHandler{service: service}
}

// Upload 上传文件
// POST /api/v1/media/upload
func (h *MediaHandler) Upload(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no file uploaded"})
		return
	}

	roomID := c.PostForm("room_id")
	messageID := c.PostForm("message_id")

	media, err := h.service.Upload(c.Request.Context(), userID.(string), file, roomID, messageID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, media)
}

// InitiateChunkedUploadRequest 初始化分片上传请求
type InitiateChunkedUploadRequest struct {
	FileName  string `json:"file_name" binding:"required"`
	MimeType  string `json:"mime_type" binding:"required"`
	TotalSize int64  `json:"total_size" binding:"required,min=1"`
}

// InitiateChunkedUpload 初始化分片上传
// POST /api/v1/media/upload/chunked/init
func (h *MediaHandler) InitiateChunkedUpload(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req InitiateChunkedUploadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	session, err := h.service.InitiateChunkedUpload(c.Request.Context(), userID.(string), req.FileName, req.MimeType, req.TotalSize)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, session)
}

// UploadChunk 上传分片
// POST /api/v1/media/upload/chunked/:session_id/chunk/:chunk_index
func (h *MediaHandler) UploadChunk(c *gin.Context) {
	sessionID := c.Param("session_id")
	chunkIndexStr := c.Param("chunk_index")

	chunkIndex, err := strconv.Atoi(chunkIndexStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid chunk index"})
		return
	}

	if err := h.service.UploadChunk(c.Request.Context(), sessionID, chunkIndex, c.Request.Body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "chunk uploaded successfully"})
}

// CompleteChunkedUpload 完成分片上传
// POST /api/v1/media/upload/chunked/:session_id/complete
func (h *MediaHandler) CompleteChunkedUpload(c *gin.Context) {
	sessionID := c.Param("session_id")

	media, err := h.service.CompleteChunkedUpload(c.Request.Context(), sessionID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, media)
}

// GetMedia 获取媒体信息
// GET /api/v1/media/:id
func (h *MediaHandler) GetMedia(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	media, err := h.service.GetMediaWithURLs(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "access denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if media == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "media not found"})
		return
	}

	c.JSON(http.StatusOK, media)
}

// Download 下载媒体（支持断点续传）
// GET /api/v1/media/:id/download
func (h *MediaHandler) Download(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")
	ip := c.ClientIP()
	userAgent := c.Request.UserAgent()

	// 解析 Range 请求头
	rangeHeader := c.GetHeader("Range")
	var start, end int64 = 0, -1
	hasRange := false

	if rangeHeader != "" {
		// 解析 "bytes=start-end" 格式
		if strings.HasPrefix(rangeHeader, "bytes=") {
			rangeParts := strings.TrimPrefix(rangeHeader, "bytes=")
			ranges := strings.Split(rangeParts, "-")
			if len(ranges) == 2 {
				hasRange = true
				if ranges[0] != "" {
					start, _ = strconv.ParseInt(ranges[0], 10, 64)
				}
				if ranges[1] != "" {
					end, _ = strconv.ParseInt(ranges[1], 10, 64)
				}
			}
		}
	}

	// 根据是否有Range请求头选择不同的下载方式
	if hasRange {
		result, err := h.service.DownloadRange(c.Request.Context(), mediaID, userID.(string), start, end, ip, userAgent)
		if err != nil {
			if err.Error() == "download access denied" {
				c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
				return
			}
			if err.Error() == "media not found" {
				c.JSON(http.StatusNotFound, gin.H{"error": "media not found"})
				return
			}
			if err.Error() == "invalid range" {
				c.JSON(http.StatusRequestedRangeNotSatisfiable, gin.H{"error": "invalid range"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer result.Reader.Close()

		// 设置206 Partial Content响应
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", result.Media.OriginalName))
		c.Header("Content-Type", result.Media.MimeType)
		c.Header("Content-Length", strconv.FormatInt(result.ContentLength, 10))
		c.Header("Content-Range", fmt.Sprintf("bytes %d-%d/%d", result.Start, result.End, result.TotalSize))
		c.Header("Accept-Ranges", "bytes")
		c.Header("X-Checksum", result.Media.Checksum)

		c.DataFromReader(http.StatusPartialContent, result.ContentLength, result.Media.MimeType, result.Reader, nil)
	} else {
		// 普通完整下载
		file, media, err := h.service.Download(c.Request.Context(), mediaID, userID.(string), ip, userAgent)
		if err != nil {
			if err.Error() == "download access denied" {
				c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
				return
			}
			if err.Error() == "media not found" {
				c.JSON(http.StatusNotFound, gin.H{"error": "media not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer file.Close()

		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", media.OriginalName))
		c.Header("Content-Type", media.MimeType)
		c.Header("Content-Length", strconv.FormatInt(media.Size, 10))
		c.Header("Accept-Ranges", "bytes")
		c.Header("X-Checksum", media.Checksum)

		c.DataFromReader(http.StatusOK, media.Size, media.MimeType, file, nil)
	}
}

// Stream 流式播放媒体
// GET /api/v1/media/:id/stream
func (h *MediaHandler) Stream(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")
	ip := c.ClientIP()
	userAgent := c.Request.UserAgent()

	// 解析 Range 请求头（流式播放通常带Range）
	rangeHeader := c.GetHeader("Range")
	var start, end int64 = 0, -1

	if rangeHeader != "" && strings.HasPrefix(rangeHeader, "bytes=") {
		rangeParts := strings.TrimPrefix(rangeHeader, "bytes=")
		ranges := strings.Split(rangeParts, "-")
		if len(ranges) == 2 {
			if ranges[0] != "" {
				start, _ = strconv.ParseInt(ranges[0], 10, 64)
			}
			if ranges[1] != "" {
				end, _ = strconv.ParseInt(ranges[1], 10, 64)
			}
		}
	}

	result, err := h.service.DownloadRange(c.Request.Context(), mediaID, userID.(string), start, end, ip, userAgent)
	if err != nil {
		if err.Error() == "download access denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}
		if err.Error() == "media not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "media not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer result.Reader.Close()

	// 流式响应头
	c.Header("Content-Type", result.Media.MimeType)
	c.Header("Content-Length", strconv.FormatInt(result.ContentLength, 10))
	c.Header("Content-Range", fmt.Sprintf("bytes %d-%d/%d", result.Start, result.End, result.TotalSize))
	c.Header("Accept-Ranges", "bytes")
	c.Header("Cache-Control", "no-cache")

	if start == 0 && end == -1 {
		c.DataFromReader(http.StatusOK, result.ContentLength, result.Media.MimeType, result.Reader, nil)
	} else {
		c.DataFromReader(http.StatusPartialContent, result.ContentLength, result.Media.MimeType, result.Reader, nil)
	}
}

// RequestDeleteConfirm 请求删除确认令牌
// POST /api/v1/media/:id/delete-confirm
func (h *MediaHandler) RequestDeleteConfirm(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	token, expiresAt, err := h.service.GenerateDeleteToken(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "media not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "no permission to delete" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":      token,
		"expires_at": expiresAt,
		"message":    "Please confirm deletion by calling DELETE /media/:id with this token",
	})
}

// GetThumbnail 获取缩略图
// GET /api/v1/media/:id/thumbnail
func (h *MediaHandler) GetThumbnail(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	file, err := h.service.GetThumbnail(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "access denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": "access denied"})
			return
		}
		if err.Error() == "media not found" || err.Error() == "no thumbnail available" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer file.Close()

	c.Header("Content-Type", "image/jpeg")
	c.Header("Cache-Control", "public, max-age=86400")

	c.DataFromReader(http.StatusOK, -1, "image/jpeg", file, nil)
}

// ListMyMedia 列出我的媒体
// GET /api/v1/media/my
func (h *MediaHandler) ListMyMedia(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if limit > 100 {
		limit = 100
	}

	media, total, err := h.service.ListByUploader(c.Request.Context(), userID.(string), offset, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"media":  media,
		"total":  total,
		"offset": offset,
		"limit":  limit,
	})
}

// ListRoomMedia 列出聊天室媒体
// GET /api/v1/media/room/:room_id
func (h *MediaHandler) ListRoomMedia(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	roomID := c.Param("room_id")
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if limit > 100 {
		limit = 100
	}

	media, total, err := h.service.ListByRoom(c.Request.Context(), roomID, userID.(string), offset, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"media":  media,
		"total":  total,
		"offset": offset,
		"limit":  limit,
	})
}

// ListMessageMedia 列出消息媒体
// GET /api/v1/media/message/:message_id
func (h *MediaHandler) ListMessageMedia(c *gin.Context) {
	messageID := c.Param("message_id")

	media, err := h.service.ListByMessage(c.Request.Context(), messageID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"media": media,
	})
}

// GrantAccessRequest 授权请求
type GrantAccessRequest struct {
	UserID      string `json:"user_id" binding:"required"`
	CanView     bool   `json:"can_view"`
	CanDownload bool   `json:"can_download"`
	CanDelete   bool   `json:"can_delete"`
}

// GrantAccess 授予访问权限
// POST /api/v1/media/:id/access
func (h *MediaHandler) GrantAccess(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	var req GrantAccessRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.GrantAccess(c.Request.Context(), mediaID, req.UserID, userID.(string), req.CanView, req.CanDownload, req.CanDelete)
	if err != nil {
		if err.Error() == "media not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "no permission to grant access" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "access granted successfully"})
}

// RevokeAccessRequest 撤销权限请求
type RevokeAccessRequest struct {
	UserID string `json:"user_id" binding:"required"`
}

// RevokeAccess 撤销访问权限
// DELETE /api/v1/media/:id/access
func (h *MediaHandler) RevokeAccess(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	var req RevokeAccessRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.RevokeAccess(c.Request.Context(), mediaID, req.UserID, userID.(string))
	if err != nil {
		if err.Error() == "media not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "no permission to revoke access" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "access revoked successfully"})
}

// Delete 删除媒体（需要令牌确认）
// DELETE /api/v1/media/:id
func (h *MediaHandler) Delete(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")
	token := c.Query("token")
	reason := c.Query("reason")
	ip := c.ClientIP()
	userAgent := c.Request.UserAgent()

	// 如果提供了令牌，验证后执行软删除
	if token != "" {
		err := h.service.DeleteWithToken(c.Request.Context(), mediaID, userID.(string), token, reason, ip, userAgent)
		if err != nil {
			if err.Error() == "media not found" {
				c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
				return
			}
			if err.Error() == "invalid or expired delete token" {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}
			if err.Error() == "no permission to delete" {
				c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message": "media moved to trash successfully",
			"note":    "File can be restored within 30 days",
		})
		return
	}

	// 没有令牌时，返回错误提示需要先获取令牌
	c.JSON(http.StatusBadRequest, gin.H{
		"error":   "delete token required",
		"message": "Please call POST /media/:id/delete-confirm first to get a delete token",
	})
}

// ListTrash 查看回收站
// GET /api/v1/media/trash
func (h *MediaHandler) ListTrash(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if limit > 100 {
		limit = 100
	}

	media, total, err := h.service.ListTrash(c.Request.Context(), userID.(string), offset, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"media":  media,
		"total":  total,
		"offset": offset,
		"limit":  limit,
	})
}

// Restore 恢复已删除的媒体
// POST /api/v1/media/:id/restore
func (h *MediaHandler) Restore(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	err := h.service.RestoreMedia(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "media not found in trash" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "no permission to restore" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "media restored successfully"})
}

// PermanentDelete 永久删除媒体
// DELETE /api/v1/media/:id/permanent
func (h *MediaHandler) PermanentDelete(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	err := h.service.PermanentDelete(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "media not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "no permission to delete permanently" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "media permanently deleted"})
}

// UpdatePlaybackPosition 更新播放位置
// PUT /api/v1/media/:id/playback-position
func (h *MediaHandler) UpdatePlaybackPosition(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	var req struct {
		Position int `json:"position" binding:"required,min=0"`
		Duration int `json:"duration" binding:"required,min=1"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.UpdatePlaybackPosition(c.Request.Context(), mediaID, userID.(string), req.Position, req.Duration)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "playback position updated"})
}

// GetPlaybackPosition 获取播放位置
// GET /api/v1/media/:id/playback-position
func (h *MediaHandler) GetPlaybackPosition(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	position, err := h.service.GetPlaybackPosition(c.Request.Context(), mediaID, userID.(string))
	if err != nil {
		if err.Error() == "position not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, position)
}

// GetStats 获取媒体统计
// GET /api/v1/media/:id/stats
func (h *MediaHandler) GetStats(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	mediaID := c.Param("id")

	// 先检查用户是否有权限查看统计
	media, err := h.service.GetMedia(c.Request.Context(), mediaID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if media == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "media not found"})
		return
	}
	if media.UploaderID != userID.(string) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only uploader can view stats"})
		return
	}

	stats, err := h.service.GetStats(c.Request.Context(), mediaID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}
