# 前后端服务启动指南

## 快速开始

### 一键启动前后端服务

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
.\start-services.bat
```

### 停止所有服务

```powershell
.\stop-services.bat
```

---

## 服务详情

### 后端服务 (Auth Service)
- **监听地址**: `http://localhost:8081`
- **健康检查**: `http://localhost:8081/health`
- **WebSocket**: `ws://localhost:8081/api/v1/ws`
- **日志位置**: `services\auth-service\logs\`

### 前端服务 (Web Client)
- **监听地址**: `http://localhost:3000`
- **开发服务器**: Vite dev server
- **自动代理**: `/api/*` → `http://localhost:8081`

---

## 启动流程

### start-services.bat 执行步骤

1. **环境检查**
   - 检查后端可执行文件: `services\auth-service\bin\auth-service.exe`
   - 检查 Node.js 和 npm 环境

2. **目录检查**
   - 后端服务目录: `services\auth-service`
   - 前端项目目录: `..\web-client`

3. **创建必要目录**
   - `services\auth-service\uploads`
   - `services\auth-service\logs`

4. **配置环境变量**
   - SQLite 数据库
   - JWT 密钥
   - 服务器配置

5. **检查端口占用**
   - 端口 8081 (后端)
   - 端口 3000 (前端)
   - 自动释放已占用的端口

6. **启动服务**
   - 启动后端服务 (新窗口)
   - 等待 8 秒初始化
   - 健康检查验证
   - 启动前端服务 (新窗口)
   - 等待 5 秒初始化

---

## 服务访问

启动成功后，访问以下地址：

### 前端界面
```
http://localhost:3000
```

### 后端 API
```
http://localhost:8081/api/v1
```

### 常用 API 端点
```
健康检查:  http://localhost:8081/health
公共群组:  http://localhost:8081/api/v1/chat/rooms/public
用户注册:  http://localhost:8081/api/v1/auth/register
用户登录:  http://localhost:8081/api/v1/auth/login
```

---

## 服务窗口

启动后会打开两个服务窗口：

1. **SecChat Backend Service** - 后端服务日志
2. **SecChat Web Client** - 前端服务日志

---

## 停止服务

### 方法 1: 使用停止脚本
```powershell
.\stop-services.bat
```

### 方法 2: 手动停止
```powershell
# 停止后端 (8081)
netstat -ano | findstr :8081
taskkill /F /PID <进程ID>

# 停止前端 (3000)
netstat -ano | findstr :3000
taskkill /F /PID <进程ID>
```

### 方法 3: 关闭服务窗口
直接关闭两个服务窗口即可

---

## 前置要求

### 后端
- ✅ 编译好的二进制文件: `services\auth-service\bin\auth-service.exe`
- ✅ SQLite 数据库文件会自动创建

### 前端
- ✅ Node.js (已安装)
- ✅ npm (已安装)
- ✅ 首次运行会自动安装依赖

---

## 故障排查

### 后端启动失败

1. **检查可执行文件**
   ```powershell
   Test-Path services\auth-service\bin\auth-service.exe
   ```

2. **手动运行测试**
   ```powershell
   cd services\auth-service
   .\bin\auth-service.exe
   ```

3. **查看日志**
   ```powershell
   type services\auth-service\logs\server.log
   ```

### 前端启动失败

1. **检查 Node.js**
   ```powershell
   node -v
   npm -v
   ```

2. **手动安装依赖**
   ```powershell
   cd ..\web-client
   npm install
   ```

3. **手动启动前端**
   ```powershell
   cd ..\web-client
   npm run dev
   ```

### 端口被占用

```powershell
# 查看占用端口的进程
netstat -ano | findstr :8081
netstat -ano | findstr :3000

# 强制终止
taskkill /F /PID <进程ID>
```

---

## 验证服务

### 后端健康检查
```powershell
# 方法 1: 浏览器
http://localhost:8081/health

# 方法 2: curl
curl http://localhost:8081/health

# 方法 3: PowerShell
Invoke-WebRequest http://localhost:8081/health
```

预期返回：
```json
{
  "status": "ok",
  "service": "auth-service",
  "db_type": "sqlite"
}
```

### 前端访问
在浏览器中打开：
```
http://localhost:3000
```

---

## 日志查看

### 后端日志
- 位置: `services\auth-service\logs\server.log`
- 实时查看: 在 "SecChat Backend Service" 窗口中

### 前端日志
- 在 "SecChat Web Client" 窗口中实时查看

---

## 常见问题

### Q: 首次启动很慢?
A: 
- 后端需要创建数据库文件 (约 3-5 秒)
- 前端需要安装依赖 (仅首次，约 30-60 秒)

### Q: 前端无法连接后端?
A:
1. 确认后端已启动: `http://localhost:8081/health`
2. 检查前端配置: `web-client/vite.config.ts` 中的代理配置
3. 查看浏览器控制台错误信息

### Q: 需要重新编译后端吗?
A: 
- 如果修改了 Go 代码: 是，需要重新编译
- 如果只修改了配置: 否，直接重启即可

---

## 开发模式

### 仅启动后端
```powershell
.\start-auth-service.bat
```

### 仅启动前端
```powershell
cd ..\web-client
npm run dev
```

### 重新编译并启动
```powershell
# 编译后端
cd services\auth-service
go build -o bin/auth-service.exe ./cmd/main.go

# 启动服务
cd ..\..
.\start-services.bat
```

---

## 文件结构

```
secure-enterprise-chat/
├── start-services.bat          # 前后端启动脚本 ⭐
├── stop-services.bat           # 前后端停止脚本 ⭐
├── start-auth-service.bat      # 仅启动后端
├── stop-auth-service.bat       # 仅停止后端
├── services/
│   └── auth-service/
│       ├── bin/
│       │   └── auth-service.exe  # 后端可执行文件
│       ├── auth.db              # SQLite 数据库
│       ├── uploads/             # 文件上传目录
│       └── logs/                # 日志目录
└── ../web-client/              # 前端项目
    ├── src/
    ├── package.json
    └── vite.config.ts
```

---

## 支持

如有问题，请检查：
1. 服务窗口中的错误日志
2. 浏览器控制台错误信息
3. 端口占用情况
4. 文件权限

---

**祝您使用愉快！** 🚀
