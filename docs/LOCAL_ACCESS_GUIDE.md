# Secure Enterprise Chat - 本地服务访问指南

本文档提供本地部署服务器的访问方式和使用说明。

## 服务状态

| 服务 | 本地地址 | 局域网地址 | 状态 |
|------|----------|------------|------|
| Auth Service API | http://localhost:8081 | http://192.168.0.39:8081 | 运行中 |
| WebSocket | ws://localhost:8081/api/v1/ws | ws://192.168.0.39:8081/api/v1/ws | 可用 |
| 健康检查 | http://localhost:8081/health | http://192.168.0.39:8081/health | 正常 |

---

## 外部网络访问配置

### 步骤 1: 配置防火墙

**以管理员身份运行** `scripts/setup-firewall.bat`，或手动执行：

```batch
netsh advfirewall firewall add rule name="SecChat Auth Service (TCP 8081)" dir=in action=allow protocol=TCP localport=8081 profile=any
```

### 步骤 2: 获取服务器IP地址

```batch
ipconfig | findstr IPv4
```

记录局域网IP地址（通常是 192.168.x.x 或 10.x.x.x）。

### 步骤 3: 更新客户端配置

修改 `apps/flutter_app/lib/core/di/injection.dart` 中的服务器地址：

```dart
const String _serverHost = '192.168.0.39';  // 替换为实际服务器IP
const int _serverPort = 8081;
```

### 步骤 4: 重新构建客户端

```batch
cd apps/flutter_app
flutter build windows --release   # Windows客户端
flutter build apk --release       # Android客户端
```

### 步骤 5: 验证连接

从其他设备测试：

```bash
curl http://192.168.0.39:8081/health
```

预期响应：`{"db_type":"sqlite","service":"auth-service","status":"ok"}`

---

## 路由器端口转发（可选 - 互联网访问）

如需从互联网访问，需要在路由器配置端口转发：

| 外部端口 | 内部IP | 内部端口 | 协议 |
|----------|--------|----------|------|
| 8081 | 192.168.0.39 | 8081 | TCP |

配置步骤：
1. 登录路由器管理界面（通常是 192.168.0.1 或 192.168.1.1）
2. 找到"端口转发"或"虚拟服务器"设置
3. 添加上述端口转发规则
4. 保存并重启路由器

获取公网IP：
```bash
curl ifconfig.me
```

---

## CORS 配置

服务器已配置允许跨域访问：

```go
// 已在 main.go 中配置
c.Header("Access-Control-Allow-Origin", "*")
c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
```

## 快速开始

### 1. 检查服务状态

```bash
curl http://localhost:8081/health
```

预期响应:
```json
{"db_type":"sqlite","service":"auth-service","status":"ok"}
```

### 2. 用户注册

```bash
curl -X POST http://localhost:8081/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "your_username",
    "password": "YourPassword@123",
    "email": "your_email@example.com"
  }'
```

成功响应:
```json
{
  "user_id": "@your_username:sec-chat.local",
  "username": "your_username",
  "device_id": "uuid-device-id"
}
```

### 3. 用户登录

```bash
curl -X POST http://localhost:8081/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "your_username",
    "password": "YourPassword@123"
  }'
```

成功响应:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "uuid-refresh-token",
  "expires_in": 3599,
  "token_type": "Bearer"
}
```

### 4. 使用认证令牌

获取登录令牌后，在后续请求中添加 Authorization 头:

```bash
# 设置令牌变量
TOKEN="your_access_token_here"

# 获取聊天室列表
curl http://localhost:8081/api/v1/chat/rooms \
  -H "Authorization: Bearer $TOKEN"
```

## API 端点参考

### 认证接口

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | /api/v1/auth/register | 用户注册 |
| POST | /api/v1/auth/login | 用户登录 |
| POST | /api/v1/auth/refresh | 刷新令牌 |
| POST | /api/v1/auth/logout | 用户登出 |
| GET | /api/v1/auth/me | 获取当前用户信息 |

### 聊天接口

| 方法 | 端点 | 描述 |
|------|------|------|
| GET | /api/v1/chat/rooms | 获取聊天室列表 |
| POST | /api/v1/chat/rooms | 创建聊天室 |
| GET | /api/v1/chat/rooms/:id | 获取聊天室详情 |
| PUT | /api/v1/chat/rooms/:id | 更新聊天室 |
| DELETE | /api/v1/chat/rooms/:id | 删除聊天室 |
| GET | /api/v1/chat/rooms/:id/messages | 获取消息列表 |
| POST | /api/v1/chat/rooms/:id/messages | 发送消息 |
| POST | /api/v1/chat/rooms/:id/members | 添加成员 |
| DELETE | /api/v1/chat/rooms/:id/members/:userId | 移除成员 |

### 媒体接口

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | /api/v1/media/upload | 上传媒体文件 |
| GET | /api/v1/media/:id | 获取媒体文件 |
| GET | /api/v1/media/:id/thumbnail | 获取缩略图 |

### 通话接口

| 方法 | 端点 | 描述 |
|------|------|------|
| POST | /api/v1/calls | 发起通话 |
| POST | /api/v1/calls/:id/accept | 接受通话 |
| POST | /api/v1/calls/:id/reject | 拒绝通话 |
| POST | /api/v1/calls/:id/end | 结束通话 |

### WebSocket 接口

| 端点 | 描述 |
|------|------|
| /api/v1/ws | 实时消息 WebSocket |
| /api/v1/signaling | WebRTC 信令 WebSocket |

## 常用操作示例

### 创建群聊

```bash
curl -X POST http://localhost:8081/api/v1/chat/rooms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "项目讨论群",
    "type": "group"
  }'
```

### 发送消息

```bash
curl -X POST http://localhost:8081/api/v1/chat/rooms/{room_id}/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Hello, World!",
    "type": "text"
  }'
```

### 上传文件

```bash
curl -X POST http://localhost:8081/api/v1/media/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/your/file.jpg" \
  -F "type=image"
```

### WebSocket 连接

使用任意 WebSocket 客户端连接:

```
URL: ws://localhost:8081/api/v1/ws?token={your_access_token}
```

连接后发送消息格式:
```json
{
  "type": "message",
  "room_id": "room-uuid",
  "content": "消息内容"
}
```

## Flutter 客户端连接

### 配置 API 端点

在 Flutter 应用中，确保 API 基础地址配置正确:

**文件**: `lib/core/constants/api_constants.dart`
```dart
class ApiConstants {
  static const String baseUrl = 'http://localhost:8081';
  static const String wsUrl = 'ws://localhost:8081/api/v1/ws';
}
```

### 启动 Windows 客户端

```bash
cd secure-enterprise-chat
flutter run -d windows
```

### 启动 Android 客户端

对于 Android 模拟器连接本地服务:
```dart
// Android 模拟器需要使用 10.0.2.2 访问主机 localhost
static const String baseUrl = 'http://10.0.2.2:8081';
```

## 测试账户

以下测试账户已创建可直接使用:

| 用户名 | 密码 | 说明 |
|--------|------|------|
| testuser1 | Test@123456 | 测试用户1 |
| testuser2 | Test@123456 | 测试用户2 |
| alice | Test@123456 | Alice Wang |

## 服务管理

### 查看服务状态

```bash
# Windows
netstat -ano | findstr :8081

# 健康检查
curl http://localhost:8081/health
```

### 重启服务

```bash
cd secure-enterprise-chat/deployments/local
start-server.bat
```

### 查看日志

日志文件位置: `services/auth-service/logs/`

## 故障排除

### 1. 连接被拒绝

**症状**: `Connection refused` 或无法连接

**解决方案**:
- 确认服务正在运行: `curl http://localhost:8081/health`
- 检查端口是否被占用: `netstat -ano | findstr :8081`
- 重启服务: 运行 `start-server.bat`

### 2. 认证失败

**症状**: `401 Unauthorized`

**解决方案**:
- 检查 Authorization 头格式: `Bearer {token}`
- 确认令牌未过期 (默认1小时有效期)
- 使用 refresh_token 刷新访问令牌

### 3. 用户名已存在

**症状**: `{"error":"username already exists"}`

**解决方案**:
- 使用不同的用户名注册
- 或直接使用已存在账户登录

### 4. WebSocket 连接失败

**症状**: WebSocket 无法建立连接

**解决方案**:
- 确认使用正确的 URL 格式: `ws://localhost:8081/api/v1/ws`
- 在 URL 参数中包含有效令牌: `?token={access_token}`
- 检查防火墙是否允许 WebSocket 连接

## 数据持久化

当前部署使用 SQLite 数据库，数据文件位置:

| 数据类型 | 文件位置 |
|----------|----------|
| 数据库 | `services/auth-service/auth.db` |
| 上传文件 | `services/auth-service/uploads/` |
| 日志文件 | `services/auth-service/logs/` |

## 安全注意事项

1. **本地开发环境**: 当前配置适用于本地开发和测试
2. **生产部署**: 生产环境请参考 `DEPLOYMENT.md` 使用 Docker 部署
3. **HTTPS**: 生产环境必须启用 HTTPS
4. **密钥管理**: 生产环境需要更换所有默认密钥

## 联系支持

如遇问题，请查看:
- 完整部署文档: `docs/DEPLOYMENT.md`
- 构建指南: `docs/BUILD_GUIDE.md`
- 环境配置: `docs/SETUP.md`
