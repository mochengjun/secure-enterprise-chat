# 开发环境配置指南

## 已安装

- [x] Go 1.25.6

## 需要安装

### 1. Docker Desktop (正在安装中...)

Docker Desktop 正在通过 winget 后台安装。安装完成后：

1. **启动 Docker Desktop**
2. **确保 WSL 2 已启用**（Docker Desktop 会提示）
3. **重启电脑**（如果需要）

如果安装失败，请手动下载安装：
- 下载地址：https://www.docker.com/products/docker-desktop/

### 2. Flutter SDK

请手动安装 Flutter SDK：

**方法 1：使用 Puro（推荐）**
```powershell
# 安装 Puro（Flutter 版本管理器）
winget install pingbird.Puro

# 安装 Flutter
puro create my_env stable
puro use my_env
```

**方法 2：手动下载**
1. 访问 https://docs.flutter.dev/get-started/install/windows
2. 下载 Flutter SDK zip 文件
3. 解压到 `C:\flutter`
4. 添加 `C:\flutter\bin` 到系统 PATH 环境变量

**验证安装**
```powershell
flutter doctor
```

## 启动服务

### 1. 启动基础设施 (Docker)

```powershell
cd c:\Users\MCJ\source\quest\secure-enterprise-chat\deployments\docker
docker-compose up -d postgres redis minio
```

等待服务启动后，启动 Synapse：
```powershell
docker-compose up -d synapse
```

### 2. 初始化 Synapse

首次运行需要生成配置：
```powershell
docker-compose exec synapse generate
```

### 3. 启动 Auth Service

```powershell
cd c:\Users\MCJ\source\quest\secure-enterprise-chat\services\auth-service

# 下载依赖
go mod tidy

# 运行服务
go run cmd/main.go
```

### 4. 启动 Flutter 客户端

```powershell
cd c:\Users\MCJ\source\quest\secure-enterprise-chat\apps\flutter_app

# 下载依赖
flutter pub get

# 运行（选择目标平台）
flutter run -d windows  # Windows 桌面
flutter run -d chrome   # Web 浏览器
flutter run             # 连接的设备
```

## 服务端口

| 服务 | 端口 | URL |
|------|------|-----|
| PostgreSQL | 5432 | - |
| Redis | 6379 | - |
| MinIO API | 9000 | http://localhost:9000 |
| MinIO Console | 9001 | http://localhost:9001 |
| Synapse | 8008 | http://localhost:8008 |
| Auth Service | 8081 | http://localhost:8081 |

## 测试 API

```powershell
# 健康检查
curl http://localhost:8081/health

# 注册用户
curl -X POST http://localhost:8081/api/v1/auth/register `
  -H "Content-Type: application/json" `
  -d '{"username":"testuser","password":"password123"}'

# 登录
curl -X POST http://localhost:8081/api/v1/auth/login `
  -H "Content-Type: application/json" `
  -d '{"username":"testuser","password":"password123"}'
```

## 常见问题

### Docker 启动失败
- 确保 WSL 2 已安装并更新
- 运行 `wsl --update`
- 在 BIOS 中启用虚拟化

### Go 命令找不到
- 重新打开终端窗口以加载新的 PATH
- 或手动添加 `C:\Program Files\Go\bin` 到 PATH

### Flutter 命令找不到
- 确保 Flutter SDK 路径已添加到 PATH
- 重新打开终端窗口
