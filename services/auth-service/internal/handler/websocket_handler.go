package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"sec-chat/auth-service/internal/service"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // 允许所有来源，生产环境应该限制
	},
}

// WSMessage WebSocket 消息
type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload,omitempty"`
}

// WSClient WebSocket 客户端
type WSClient struct {
	hub      *WSHub
	conn     *websocket.Conn
	userID   string
	send     chan []byte
	rooms    map[string]bool
	roomsMux sync.RWMutex
}

// WSHub WebSocket Hub 管理所有连接
type WSHub struct {
	clients     map[string]*WSClient            // userID -> client
	rooms       map[string]map[string]*WSClient // roomID -> userID -> client
	broadcast   chan *BroadcastMessage
	register    chan *WSClient
	unregister  chan *WSClient
	joinRoom    chan *RoomAction
	leaveRoom   chan *RoomAction
	mu          sync.RWMutex
	chatService service.ChatService
}

// BroadcastMessage 广播消息
type BroadcastMessage struct {
	RoomID  string
	Message []byte
}

// RoomAction 房间操作
type RoomAction struct {
	Client *WSClient
	RoomID string
}

// NewWSHub 创建 WebSocket Hub
func NewWSHub(chatService service.ChatService) *WSHub {
	return &WSHub{
		clients:     make(map[string]*WSClient),
		rooms:       make(map[string]map[string]*WSClient),
		broadcast:   make(chan *BroadcastMessage, 256),
		register:    make(chan *WSClient),
		unregister:  make(chan *WSClient),
		joinRoom:    make(chan *RoomAction),
		leaveRoom:   make(chan *RoomAction),
		chatService: chatService,
	}
}

// Run 运行 Hub
func (h *WSHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.userID] = client
			h.mu.Unlock()
			log.Printf("WebSocket client registered: %s", client.userID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.userID]; ok {
				delete(h.clients, client.userID)
				close(client.send)
				// 从所有房间移除
				client.roomsMux.RLock()
				for roomID := range client.rooms {
					if roomClients, ok := h.rooms[roomID]; ok {
						delete(roomClients, client.userID)
					}
				}
				client.roomsMux.RUnlock()
			}
			h.mu.Unlock()
			log.Printf("WebSocket client unregistered: %s", client.userID)

		case action := <-h.joinRoom:
			h.mu.Lock()
			if _, ok := h.rooms[action.RoomID]; !ok {
				h.rooms[action.RoomID] = make(map[string]*WSClient)
			}
			h.rooms[action.RoomID][action.Client.userID] = action.Client
			h.mu.Unlock()
			action.Client.roomsMux.Lock()
			action.Client.rooms[action.RoomID] = true
			action.Client.roomsMux.Unlock()
			log.Printf("Client %s joined room %s", action.Client.userID, action.RoomID)

		case action := <-h.leaveRoom:
			h.mu.Lock()
			if roomClients, ok := h.rooms[action.RoomID]; ok {
				delete(roomClients, action.Client.userID)
			}
			h.mu.Unlock()
			action.Client.roomsMux.Lock()
			delete(action.Client.rooms, action.RoomID)
			action.Client.roomsMux.Unlock()

		case msg := <-h.broadcast:
			h.mu.RLock()
			if roomClients, ok := h.rooms[msg.RoomID]; ok {
				for _, client := range roomClients {
					select {
					case client.send <- msg.Message:
					default:
						// 发送缓冲区满，跳过
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// BroadcastToRoom 向房间广播消息
func (h *WSHub) BroadcastToRoom(roomID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.broadcast <- &BroadcastMessage{
		RoomID:  roomID,
		Message: data,
	}
}

// BroadcastToUser 向用户发送消息
func (h *WSHub) BroadcastToUser(userID string, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	if client, ok := h.clients[userID]; ok {
		select {
		case client.send <- data:
		default:
		}
	}
	h.mu.RUnlock()
}

// HandleWebSocket 处理 WebSocket 连接
func (h *WSHub) HandleWebSocket(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	client := &WSClient{
		hub:    h,
		conn:   conn,
		userID: userID,
		send:   make(chan []byte, 256),
		rooms:  make(map[string]bool),
	}

	h.register <- client

	// 加入用户的所有房间
	rooms, err := h.chatService.GetUserRooms(c.Request.Context(), userID)
	if err == nil {
		for _, room := range rooms {
			h.joinRoom <- &RoomAction{Client: client, RoomID: room.ID}
		}
	}

	go client.writePump()
	go client.readPump()
}

// readPump 读取消息
func (c *WSClient) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(512 * 1024) // 512KB
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket read error: %v", err)
			}
			break
		}

		// 解析消息
		var msg WSMessage
		if err := json.Unmarshal(message, &msg); err != nil {
			continue
		}

		// 处理不同类型的消息
		switch msg.Type {
		case "ping":
			// 回复 pong
			data, _ := json.Marshal(WSMessage{Type: "pong"})
			c.send <- data

		case "join_room":
			if roomID, ok := msg.Payload.(string); ok {
				c.hub.joinRoom <- &RoomAction{Client: c, RoomID: roomID}
			}

		case "leave_room":
			if roomID, ok := msg.Payload.(string); ok {
				c.hub.leaveRoom <- &RoomAction{Client: c, RoomID: roomID}
			}

		case "typing":
			// 转发 typing 事件到房间
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if roomID, ok := payload["room_id"].(string); ok {
					c.hub.BroadcastToRoom(roomID, WSMessage{
						Type: "typing",
						Payload: map[string]interface{}{
							"user_id": c.userID,
							"room_id": roomID,
						},
					})
				}
			}
		}
	}
}

// writePump 写入消息
func (c *WSClient) writePump() {
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

			// 合并发送队列中的消息
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
