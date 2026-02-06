package handler

import (
	"io"
	"net/http"
	"strconv"
	"time"

	"sec-chat/media-proxy/internal/service"

	"github.com/gin-gonic/gin"
)

type MediaHandler struct {
	service *service.MediaService
}

func NewMediaHandler(svc *service.MediaService) *MediaHandler {
	return &MediaHandler{
		service: svc,
	}
}

// UploadFile 上传文件
// POST /api/v1/media/upload
func (h *MediaHandler) UploadFile(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	// 获取上传的文件
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file is required"})
		return
	}
	defer file.Close()

	// 获取可选参数
	roomID := c.PostForm("room_id")
	password := c.PostForm("password")
	downloadLimitStr := c.PostForm("download_limit")
	expiresInStr := c.PostForm("expires_in") // 过期时间（秒）

	var downloadLimit int
	if downloadLimitStr != "" {
		downloadLimit, _ = strconv.Atoi(downloadLimitStr)
	}

	var expiresIn time.Duration
	if expiresInStr != "" {
		seconds, _ := strconv.Atoi(expiresInStr)
		expiresIn = time.Duration(seconds) * time.Second
	}

	req := &service.UploadRequest{
		FileName:      header.Filename,
		ContentType:   header.Header.Get("Content-Type"),
		Size:          header.Size,
		Reader:        file,
		UploadedBy:    userID,
		RoomID:        roomID,
		Password:      password,
		DownloadLimit: downloadLimit,
		ExpiresIn:     expiresIn,
	}

	result, err := h.service.Upload(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, result)
}

// DownloadFile 下载文件
// GET /api/v1/media/:id/download
func (h *MediaHandler) DownloadFile(c *gin.Context) {
	mediaID := c.Param("id")
	userID := c.GetString("user_id")
	password := c.Query("password")

	req := &service.DownloadRequest{
		MediaID:   mediaID,
		UserID:    userID,
		Password:  password,
		IPAddress: c.ClientIP(),
		UserAgent: c.Request.UserAgent(),
	}

	reader, file, err := h.service.Download(c.Request.Context(), req)
	if err != nil {
		if err.Error() == "password required" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error(), "password_required": true})
			return
		}
		if err.Error() == "invalid password" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		if err.Error() == "file not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer reader.Close()

	// 设置响应头
	c.Header("Content-Type", file.MimeType)
	c.Header("Content-Disposition", "attachment; filename=\""+file.FileName+"\"")
	c.Header("Content-Length", strconv.FormatInt(file.Size, 10))

	// 流式传输文件
	c.Status(http.StatusOK)
	io.Copy(c.Writer, reader)
}

// GetFileInfo 获取文件信息
// GET /api/v1/media/:id
func (h *MediaHandler) GetFileInfo(c *gin.Context) {
	mediaID := c.Param("id")
	userID := c.GetString("user_id")

	file, err := h.service.GetFileInfo(c.Request.Context(), mediaID, userID)
	if err != nil {
		if err.Error() == "file not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, file)
}

// DeleteFile 删除文件
// DELETE /api/v1/media/:id
func (h *MediaHandler) DeleteFile(c *gin.Context) {
	mediaID := c.Param("id")
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	err := h.service.DeleteFile(c.Request.Context(), mediaID, userID)
	if err != nil {
		if err.Error() == "permission denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "file deleted successfully"})
}

// GetAccessLogs 获取访问日志
// GET /api/v1/media/:id/logs
func (h *MediaHandler) GetAccessLogs(c *gin.Context) {
	mediaID := c.Param("id")
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	logs, err := h.service.GetAccessLogs(c.Request.Context(), mediaID, userID)
	if err != nil {
		if err.Error() == "permission denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"logs": logs})
}

// SetPermission 设置文件权限
// PUT /api/v1/media/:id/permission
func (h *MediaHandler) SetPermission(c *gin.Context) {
	mediaID := c.Param("id")
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req struct {
		AllowDownload bool `json:"allow_download"`
		RequireAuth   bool `json:"require_auth"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	err := h.service.SetFilePermission(c.Request.Context(), mediaID, userID, req.AllowDownload, req.RequireAuth)
	if err != nil {
		if err.Error() == "permission denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "permission updated successfully"})
}

// RegisterRoutes 注册路由
func (h *MediaHandler) RegisterRoutes(r *gin.RouterGroup) {
	r.POST("/media/upload", h.UploadFile)
	r.GET("/media/:id", h.GetFileInfo)
	r.GET("/media/:id/download", h.DownloadFile)
	r.DELETE("/media/:id", h.DeleteFile)
	r.GET("/media/:id/logs", h.GetAccessLogs)
	r.PUT("/media/:id/permission", h.SetPermission)
}
