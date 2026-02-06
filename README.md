# 企业级安全聊天应用

企业内部使用的安全聊天手机应用程序，支持 iOS、Android 和桌面端。

## 技术栈

- **移动端/桌面端**: Flutter + Dart
- **后端服务**: Go
- **通信协议**: Matrix 协议
- **Matrix Homeserver**: Synapse
- **数据库**: PostgreSQL + Redis
- **对象存储**: MinIO
- **音视频**: WebRTC + LiveKit SFU

## 项目结构

```
secure-enterprise-chat/
├── apps/flutter_app/          # Flutter 跨平台客户端
├── services/                  # Go 后端微服务
│   ├── auth-service/          # 认证服务
│   ├── media-proxy/           # 媒体代理服务
│   ├── webrtc-sfu/            # WebRTC SFU 服务
│   ├── push-service/          # 推送服务
│   ├── cleanup-service/       # 数据清理服务
│   ├── permission-service/    # 权限管理服务
│   └── admin-service/         # 管理后台服务
├── synapse/                   # Matrix Synapse 配置
├── admin-web/                 # 管理后台前端
├── deployments/               # 部署配置
│   ├── docker/                # Docker Compose 配置
│   └── kubernetes/            # Kubernetes 配置
├── scripts/                   # 脚本工具
└── docs/                      # 文档
```

## 快速开始

### 环境要求

- Docker & Docker Compose
- Go 1.21+
- Flutter 3.16+
- Node.js 18+ (管理后台前端)

### 启动开发环境

1. **启动基础设施服务**

```bash
cd deployments/docker
docker-compose up -d postgres redis minio synapse
```

2. **启动 Go 后端服务**

```bash
# Auth Service
cd services/auth-service
go mod tidy
go run cmd/main.go
```

3. **启动 Flutter 客户端**

```bash
cd apps/flutter_app
flutter pub get
flutter run
```

### 服务端口

| 服务 | 端口 |
|------|------|
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO API | 9000 |
| MinIO Console | 9001 |
| Synapse | 8008 |
| Auth Service | 8081 |
| Media Proxy | 8082 |
| Push Service | 8083 |
| Admin Service | 8084 |

## 核心功能

- 群组聊天管理系统
- 多媒体消息处理（文本、语音、图片、文件）
- 内置媒体播放器
- 即时语音/视频通话（最多50人）
- 可配置的消息自动删除
- 文件权限管理
- 端到端加密
- 多因素认证

## API 文档

API 文档位于 `docs/api/` 目录。

## 许可证

私有项目，仅供内部使用。
