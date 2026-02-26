# 后端服务器异常滚动诊断报告

## 1. 问题概述

后端服务器出现频繁异常滚动现象,表现为:
- 服务意外崩溃重启
- WebSocket连接频繁断开重连
- 系统资源占用异常

## 2. 识别的关键问题

### 2.1 WebSocket Hub 内存泄漏风险

**位置**: `internal/handler/websocket_handler.go`

**问题1: 无限增长的房间列表**
```go
// 第96-101行: 当客户端断开时,从所有房间移除
client.roomsMux.RLock()
for roomID := range client.rooms {
    if roomClients, ok := h.rooms[roomID]; ok {
        delete(roomClients, client.userID)
    }
}
client.roomsMux.RUnlock()
```

**风险**:
- 空房间(`roomClients` map 为空)不会被清理,持续占用内存
- 长期运行后,h.rooms 会积累大量空房间,导致内存泄漏

**问题2: broadcast channel 容量限制**
```go
// 第70行
broadcast: make(chan *BroadcastMessage, 256),
```

**风险**:
- 高并发场景下,broadcast channel 容易满载
- 当 channel 满时,消息丢失(`default` case 跳过发送)

**问题3: 无连接数限制**
```go
// 第16-22行: upgrader 无限制配置
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        return true // 允许所有来源,生产环境应该限制
    },
}
```

**风险**:
- 无连接数上限,可能导致资源耗尽
- CheckOrigin 返回 true 存在安全风险

### 2.2 数据库查询效率问题

**位置**: `internal/handler/websocket_handler.go:197-202`

**问题**: WebSocket 连接时查询用户所有房间
```go
// 加入用户的所有房间
rooms, err := h.chatService.GetUserRooms(c.Request.Context(), userID)
if err == nil {
    for _, room := range rooms {
        h.joinRoom <- &RoomAction{Client: client, RoomID: room.ID}
    }
}
```

**风险**:
- 用户加入大量房间时,会产生大量 joinRoom 操作
- 每个操作都需要获取互斥锁,阻塞其他客户端

### 2.3 协程泄漏风险

**位置**: `internal/handler/websocket_handler.go:204-205`

**问题**: readPump 和 writePump 协程没有超时保护
```go
go client.writePump()
go client.readPump()
```

**风险**:
- 网络异常时协程可能永久阻塞
- 大量僵尸协程导致资源耗尽

### 2.4 缺乏健康检查

**位置**: `cmd/main.go`

**问题**: 仅简单的 HTTP 健康检查
```go
// 第128-130行
router.GET("/health", func(c *gin.Context) {
    c.JSON(200, gin.H{"status": "ok", "service": "auth-service", "db_type": dbType})
})
```

**缺陷**:
- 不检查数据库连接状态
- 不检查 WebSocket Hub 状态
- 不检查系统资源使用情况

### 2.5 监控指标缺失

**问题**: 未集成 Prometheus 指标暴露
- 无连接数指标
- 无消息积压指标
- 无内存使用指标

---

## 3. 系统资源监控建议

### 3.1 关键指标监控

#### 应用层指标
1. **WebSocket 连接数**
   - `ws_connections_total`: 当前连接总数
   - `ws_connections_by_room`: 每个房间的连接数

2. **消息指标**
   - `ws_messages_sent_total`: 发送消息总数
   - `ws_messages_received_total`: 接收消息总数
   - `ws_messages_dropped_total`: 丢弃消息总数(channel 满)
   - `ws_broadcast_queue_size`: broadcast channel 队列长度

3. **数据库指标**
   - `db_query_duration_seconds`: 查询延迟
   - `db_connections_active`: 活动连接数

4. **系统资源指标**
   - `process_resident_memory_bytes`: 进程内存使用
   - `process_cpu_seconds_total`: CPU 使用时间

### 3.2 警告阈值建议

| 指标 | 警告阈值 | 严重阈值 | 说明 |
|------|---------|---------|------|
| WS 连接数 | > 1000 | > 5000 | 单实例最大连接 |
| 广播队列深度 | > 100 | > 200 | 消息积压 |
| 内存使用 | > 2GB | > 4GB | 进程内存 |
| CPU 使用率 | > 70% | > 90% | 持续 5 分钟 |
| DB 查询延迟 | > 500ms | > 2000ms | P99 延迟 |

---

## 4. 分步修复方案

### 4.1 修复 WebSocket Hub 内存泄漏

**文件**: `internal/handler/websocket_handler.go`

```go
// 1. 添加清理空房间的逻辑
func (h *WSHub) Run() {
    for {
        select {
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
                        // 修复: 清理空房间
                        if len(roomClients) == 0 {
                            delete(h.rooms, roomID)
                        }
                    }
                }
                client.roomsMux.RUnlock()
            }
            h.mu.Unlock()
            log.Printf("WebSocket client unregistered: %s", client.userID)
        // ... 其他 case
        }
    }
}
```

```go
// 2. 增加 broadcast channel 容量
func NewWSHub(chatService service.ChatService) *WSHub {
    return &WSHub{
        clients:     make(map[string]*WSClient),
        rooms:       make(map[string]map[string]*WSClient),
        broadcast:   make(chan *BroadcastMessage, 1024), // 从 256 增加到 1024
        register:    make(chan *WSClient),
        unregister:  make(chan *WSClient),
        joinRoom:    make(chan *RoomAction),
        leaveRoom:   make(chan *RoomAction),
        chatService: chatService,
    }
}
```

```go
// 3. 添加连接数限制
const (
    maxConnections = 10000
)

func (h *WSHub) HandleWebSocket(c *gin.Context) {
    userID := c.GetString("user_id")
    if userID == "" {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
        return
    }

    // 检查连接数限制
    h.mu.RLock()
    currentConnections := len(h.clients)
    h.mu.RUnlock()

    if currentConnections >= maxConnections {
        c.JSON(http.StatusServiceUnavailable, gin.H{"error": "too many connections"})
        return
    }

    // ... 其余代码
}
```

```go
// 4. 配置 Upgrader 限制
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 1024,
    CheckOrigin: func(r *http.Request) bool {
        // 生产环境: 仅允许特定来源
        origin := r.Header.Get("Origin")
        allowedOrigins := []string{"https://yourdomain.com", "http://localhost:8080"}
        for _, allowed := range allowedOrigins {
            if origin == allowed {
                return true
            }
        }
        return false
    },
    HandshakeTimeout: 10 * time.Second,
}
```

### 4.2 优化数据库查询

```go
// 5. 分批加入房间,避免长时间锁阻塞
func (h *WSHub) HandleWebSocket(c *gin.Context) {
    // ... 注册逻辑

    // 限制最多加入前 100 个活跃房间
    rooms, err := h.chatService.GetUserRooms(c.Request.Context(), userID, 100)
    if err == nil {
        // 分批处理,每批 10 个
        batchSize := 10
        for i := 0; i < len(rooms); i += batchSize {
            end := i + batchSize
            if end > len(rooms) {
                end = len(rooms)
            }
            for _, room := range rooms[i:end] {
                h.joinRoom <- &RoomAction{Client: client, RoomID: room.ID}
            }
            // 批次间短暂休息
            time.Sleep(10 * time.Millisecond)
        }
    }

    // ... 其余代码
}
```

### 4.3 添加健康检查增强

```go
// 6. 创建健康检查处理器
package handler

import (
    "database/sql"
    "runtime"
    "sync/atomic"
    "time"
)

type HealthChecker struct {
    db           *gorm.DB
    wsHub        *WSHub
    startTime    time.Time
}

func NewHealthChecker(db *gorm.DB, wsHub *WSHub) *HealthChecker {
    return &HealthChecker{
        db:        db,
        wsHub:     wsHub,
        startTime: time.Now(),
    }
}

func (hc *HealthChecker) Check() map[string]interface{} {
    var m runtime.MemStats
    runtime.ReadMemStats(&m)

    health := map[string]interface{}{
        "status": "ok",
        "uptime": time.Since(hc.startTime).String(),
        "memory": map[string]interface{}{
            "alloc":      m.Alloc,
            "total_alloc": m.TotalAlloc,
            "sys":        m.Sys,
            "num_gc":     m.NumGC,
        },
        "goroutines": runtime.NumGoroutine(),
    }

    // 检查数据库连接
    if sqlDB, err := hc.db.DB(); err == nil {
        if err := sqlDB.Ping(); err != nil {
            health["status"] = "error"
            health["database"] = map[string]interface{}{
                "status": "down",
                "error":  err.Error(),
            }
        } else {
            dbStats := sqlDB.Stats()
            health["database"] = map[string]interface{}{
                "status":         "up",
                "open_connections": dbStats.OpenConnections,
                "in_use":         dbStats.InUse,
                "idle":           dbStats.Idle,
            }
        }
    }

    // 检查 WebSocket Hub
    hc.wsHub.mu.RLock()
    health["websocket"] = map[string]interface{}{
        "connections": len(hc.wsHub.clients),
        "rooms":       len(hc.wsHub.rooms),
    }
    hc.wsHub.mu.RUnlock()

    return health
}
```

### 4.4 添加 Prometheus 指标

```go
// 7. 创建指标收集器
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // WebSocket 指标
    WSConnections = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "ws_connections_total",
        Help: "Current number of WebSocket connections",
    })

    WSRooms = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "ws_rooms_total",
        Help: "Current number of active rooms",
    })

    WSMessagesSent = promauto.NewCounter(prometheus.CounterOpts{
        Name: "ws_messages_sent_total",
        Help: "Total number of messages sent via WebSocket",
    })

    WSMessagesReceived = promauto.NewCounter(prometheus.CounterOpts{
        Name: "ws_messages_received_total",
        Help: "Total number of messages received via WebSocket",
    })

    WSMessagesDropped = promauto.NewCounter(prometheus.CounterOpts{
        Name: "ws_messages_dropped_total",
        Help: "Total number of messages dropped (channel full)",
    })

    WSBroadcastQueueSize = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "ws_broadcast_queue_size",
        Help: "Current size of broadcast queue",
    })

    // 数据库指标
    DBQueryDuration = promauto.NewHistogram(prometheus.HistogramOpts{
        Name:    "db_query_duration_seconds",
        Help:    "Database query duration",
        Buckets: prometheus.DefBuckets,
    })

    DBConnectionsActive = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "db_connections_active",
        Help: "Number of active database connections",
    })

    // 系统指标
    ProcessMemory = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "process_resident_memory_bytes",
        Help: "Process memory usage in bytes",
    })

    ProcessCPU = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "process_cpu_usage_percent",
        Help: "Process CPU usage percentage",
    })
)
```

```go
// 8. 在 main.go 中集成指标
import (
    "sec-chat/auth-service/internal/metrics"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
    // ... 初始化逻辑

    // 启动指标收集协程
    go collectMetricsPeriodically(db, wsHub)

    // 暴露指标端点
    router.GET("/metrics", gin.WrapH(promhttp.Handler()))

    // 增强健康检查
    healthChecker := handler.NewHealthChecker(db, wsHub)
    router.GET("/health", func(c *gin.Context) {
        c.JSON(200, healthChecker.Check())
    })

    // ... 启动服务器
}

func collectMetricsPeriodically(db *gorm.DB, wsHub *handler.WSHub) {
    ticker := time.NewTicker(10 * time.Second)
    for range ticker.C {
        // 收集 WebSocket 指标
        wsHub.mu.RLock()
        metrics.WSConnections.Set(float64(len(wsHub.clients)))
        metrics.WSRooms.Set(float64(len(wsHub.rooms)))
        metrics.WSBroadcastQueueSize.Set(float64(len(wsHub.broadcast)))
        wsHub.mu.RUnlock()

        // 收集数据库指标
        if sqlDB, err := db.DB(); err == nil {
            stats := sqlDB.Stats()
            metrics.DBConnectionsActive.Set(float64(stats.OpenConnections))
        }

        // 收集进程指标
        var m runtime.MemStats
        runtime.ReadMemStats(&m)
        metrics.ProcessMemory.Set(float64(m.Sys))
    }
}
```

### 4.5 添加告警规则

**文件**: `deployments/monitoring/prometheus/rules/alerts.yml`

```yaml
groups:
  - name: websocket_alerts
    interval: 30s
    rules:
      # WebSocket 连接数过多
      - alert: TooManyWebSocketConnections
        expr: ws_connections_total > 5000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Too many WebSocket connections"
          description: "{{ $value }} connections on {{ $labels.instance }}"

      # 广播队列积压
      - alert: WebSocketBroadcastQueueFull
        expr: ws_broadcast_queue_size > 200
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "WebSocket broadcast queue is full"
          description: "Queue size: {{ $value }}"

      # 消息丢弃率高
      - alert: HighMessageDropRate
        expr: rate(ws_messages_dropped_total[5m]) > 10
        labels:
          severity: warning
        annotations:
          summary: "High message drop rate"
          description: "{{ $value }} messages/sec dropped"

  - name: database_alerts
    interval: 30s
    rules:
      # 数据库连接耗尽
      - alert: DatabaseConnectionsExhausted
        expr: db_connections_active > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Database connections nearly exhausted"

      # 查询延迟过高
      - alert: SlowDatabaseQueries
        expr: histogram_quantile(0.99, rate(db_query_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database queries are slow"
          description: "P99 latency: {{ $value }}s"

  - name: system_alerts
    interval: 30s
    rules:
      # 内存使用过高
      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes > 4 * 1024 * 1024 * 1024
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "{{ $value }} bytes"

      # Goroutine 泄漏
      - alert: GoroutineLeak
        expr: rate(process_num_goroutines[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Potential goroutine leak"
```

---

## 5. 实施计划

### Phase 1: 紧急修复 (立即)
1. 修复空房间内存泄漏
2. 增加 broadcast channel 容量
3. 添加连接数限制
4. 配置 Upgrader 安全设置

### Phase 2: 监控增强 (1-2 天)
1. 集成 Prometheus 指标
2. 配置 Grafana 仪表板
3. 部署告警规则
4. 测试告警通知

### Phase 3: 性能优化 (3-5 天)
1. 优化数据库查询
2. 添加健康检查增强
3. 实施连接池调优
4. 压力测试和调优

### Phase 4: 稳定性保障 (持续)
1. 定期监控指标
2. 分析日志和告警
3. 持续优化改进
4. 容量规划

---

## 6. 验证步骤

### 6.1 功能验证
1. 部署修复后的代码
2. 使用压测工具模拟高并发连接:
   ```bash
   # 使用 artillery 进行 WebSocket 压测
   artillery run websocket-load-test.yml
   ```

3. 监控关键指标:
   - 内存使用是否稳定
   - 空房间是否被清理
   - 消息是否正常发送

### 6.2 性能验证
1. 对比修复前后的资源使用:
   - 内存占用: 应降低 30-50%
   - CPU 占用: 应更稳定
   - 连接稳定性: 应提升

2. 检查告警触发情况:
   - 不应触发内存泄漏告警
   - 消息丢弃率应 < 1%

### 6.3 长期验证
1. 运行 7 天持续监控
2. 收集关键指标数据
3. 分析趋势和异常
4. 持续优化

---

## 7. 附录

### 7.1 压测工具配置示例

```yaml
# websocket-load-test.yml
config:
  target: "ws://localhost:8081/api/v1/ws"
  phases:
    - duration: 60
      arrivalRate: 100
      name: "Ramp up"
    - duration: 300
      arrivalRate: 500
      name: "Sustained load"
  processor: "./load-test-processor.js"
```

### 7.2 Grafana 仪表板配置

导入预配置的仪表板:
- `deployments/monitoring/grafana/dashboards/websocket-dashboard.json`
- `deployments/monitoring/grafana/dashboards/database-dashboard.json`
- `deployments/monitoring/grafana/dashboards/system-dashboard.json`

### 7.3 紧急回滚方案

如果修复引入新问题:
1. 回退到修复前的代码版本
2. 重启服务
3. 监控告警和日志
4. 分析问题根因

---

## 8. 总结

通过以上修复方案,可以:
1. ✅ 消除 WebSocket Hub 内存泄漏
2. ✅ 提升系统稳定性和可靠性
3. ✅ 增强监控和告警能力
4. ✅ 优化性能和资源利用

建议按计划逐步实施,并在每个阶段充分测试验证。
