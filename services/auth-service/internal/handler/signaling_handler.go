package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"sec-chat/auth-service/internal/repository"
	"sec-chat/auth-service/internal/service"
)

// SignalingHub 信令中心
type SignalingHub struct {
	callService service.CallService

	// 用户连接映射
	connections map[string]*SignalingClient
	mu          sync.RWMutex

	// 通道
	register   chan *SignalingClient
	unregister chan *SignalingClient
	broadcast  chan *SignalingBroadcast
}

// SignalingClient 信令客户端
type SignalingClient struct {
	hub      *SignalingHub
	conn     *websocket.Conn
	userID   string
	deviceID string
	send     chan []byte
}

// SignalingBroadcast 信令广播
type SignalingBroadcast struct {
	TargetUserID string
	Message      []byte
}

var signalingUpgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// NewSignalingHub 创建信令中心实例
func NewSignalingHub(callService service.CallService) *SignalingHub {
	return &SignalingHub{
		callService: callService,
		connections: make(map[string]*SignalingClient),
		register:    make(chan *SignalingClient),
		unregister:  make(chan *SignalingClient),
		broadcast:   make(chan *SignalingBroadcast, 256),
	}
}

// Run 运行信令中心
func (h *SignalingHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.connections[client.userID] = client
			h.mu.Unlock()
			log.Printf("Signaling client registered: %s", client.userID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.connections[client.userID]; ok {
				delete(h.connections, client.userID)
				close(client.send)
			}
			h.mu.Unlock()
			log.Printf("Signaling client unregistered: %s", client.userID)

		case broadcast := <-h.broadcast:
			h.mu.RLock()
			if client, ok := h.connections[broadcast.TargetUserID]; ok {
				select {
				case client.send <- broadcast.Message:
				default:
					// 缓冲区满，关闭连接
					h.mu.RUnlock()
					h.mu.Lock()
					close(client.send)
					delete(h.connections, broadcast.TargetUserID)
					h.mu.Unlock()
					continue
				}
			}
			h.mu.RUnlock()
		}
	}
}

// HandleSignaling WebSocket信令处理
func (h *SignalingHub) HandleSignaling(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	deviceID, _ := c.Get("device_id")

	conn, err := signalingUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}

	client := &SignalingClient{
		hub:      h,
		conn:     conn,
		userID:   userID.(string),
		deviceID: deviceID.(string),
		send:     make(chan []byte, 256),
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}

// SendToUser 发送消息给指定用户
func (h *SignalingHub) SendToUser(userID string, message *repository.SignalingMessage) error {
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	h.broadcast <- &SignalingBroadcast{
		TargetUserID: userID,
		Message:      data,
	}
	return nil
}

// SendToParticipants 发送消息给通话所有参与者
func (h *SignalingHub) SendToParticipants(callID string, message *repository.SignalingMessage, excludeUser string) {
	call, err := h.callService.GetCall(nil, callID)
	if err != nil || call == nil {
		return
	}

	data, _ := json.Marshal(message)
	for _, p := range call.Participants {
		if p.UserID != excludeUser && p.Status == repository.ParticipantStatusConnected {
			h.broadcast <- &SignalingBroadcast{
				TargetUserID: p.UserID,
				Message:      data,
			}
		}
	}
}

// readPump 读取消息
func (c *SignalingClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(65536)
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Signaling read error: %v", err)
			}
			break
		}

		c.handleMessage(message)
	}
}

// writePump 写入消息
func (c *SignalingClient) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// 批量发送队列中的消息
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleMessage 处理信令消息
func (c *SignalingClient) handleMessage(data []byte) {
	var msg repository.SignalingMessage
	if err := json.Unmarshal(data, &msg); err != nil {
		log.Printf("Invalid signaling message: %v", err)
		return
	}

	msg.FromUser = c.userID
	msg.Timestamp = time.Now()

	switch msg.Type {
	case "offer", "answer":
		// SDP交换 - 转发给目标用户
		if msg.ToUser != "" {
			c.hub.SendToUser(msg.ToUser, &msg)
		}

	case "ice-candidate":
		// ICE候选 - 转发给目标用户
		if msg.ToUser != "" {
			c.hub.SendToUser(msg.ToUser, &msg)
		}

	case "call-invite":
		// 通话邀请已通过REST API处理，这里转发通知
		c.hub.SendToParticipants(msg.CallID, &msg, c.userID)

	case "call-accept":
		// 接受通话
		if err := c.hub.callService.AcceptCall(nil, msg.CallID, c.userID); err != nil {
			log.Printf("Failed to accept call: %v", err)
			return
		}
		c.hub.SendToParticipants(msg.CallID, &msg, c.userID)

	case "call-reject":
		// 拒绝通话
		if err := c.hub.callService.RejectCall(nil, msg.CallID, c.userID); err != nil {
			log.Printf("Failed to reject call: %v", err)
			return
		}
		c.hub.SendToParticipants(msg.CallID, &msg, c.userID)

	case "call-end":
		// 结束通话
		if err := c.hub.callService.EndCall(nil, msg.CallID, c.userID, "user_ended"); err != nil {
			log.Printf("Failed to end call: %v", err)
			return
		}
		c.hub.SendToParticipants(msg.CallID, &msg, "")

	case "mute-toggle":
		// 静音切换
		if payload, ok := msg.Payload.(map[string]interface{}); ok {
			muted, _ := payload["muted"].(bool)
			c.hub.callService.ToggleMute(nil, msg.CallID, c.userID, muted)
			c.hub.SendToParticipants(msg.CallID, &msg, c.userID)
		}

	case "video-toggle":
		// 视频切换
		if payload, ok := msg.Payload.(map[string]interface{}); ok {
			videoOn, _ := payload["video_on"].(bool)
			c.hub.callService.ToggleVideo(nil, msg.CallID, c.userID, videoOn)
			c.hub.SendToParticipants(msg.CallID, &msg, c.userID)
		}

	default:
		log.Printf("Unknown signaling message type: %s", msg.Type)
	}
}

// IsUserOnline 检查用户是否在线
func (h *SignalingHub) IsUserOnline(userID string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.connections[userID]
	return ok
}
