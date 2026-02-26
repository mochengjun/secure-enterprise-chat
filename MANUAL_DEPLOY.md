# 手动部署指南 (简单方法)

## 方法 1: 使用启动脚本 (推荐)

### 步骤 1: 停止现有服务
```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
.\stop-auth-service.bat
```

### 步骤 2: 启动新服务
```powershell
.\start-auth-service.bat
```

---

## 方法 2: 完全手动部署

### 步骤 1: 停止现有服务

打开 PowerShell 或命令提示符,运行:

```powershell
# 检查服务是否在运行
tasklist | findstr auth-service

# 如果找到,停止它
taskkill /F /IM auth-service.exe
```

### 步骤 2: 部署新版本

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat

# 复制新版本到目标位置
copy services\auth-service\bin\auth-service.exe bin\auth-service.exe /Y
```

### 步骤 3: 启动服务

```powershell
# 方法 A: 在后台启动
cd services\auth-service
start bin\auth-service.exe

# 方法 B: 在前台启动 (可以看到日志)
cd services\auth-service
bin\auth-service.exe

# 方法 C: 直接运行指定位置
c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\bin\auth-service.exe
```

### 步骤 4: 验证服务

打开新的 PowerShell 窗口,运行:

```powershell
# 检查健康状态
Invoke-WebRequest -Uri "http://localhost:8081/health" | Select-Object StatusCode

# 应该返回: StatusCode 200

# 检查服务进程
tasklist | findstr auth-service
```

---

## 方法 3: 直接运行编译好的版本

如果想直接运行编译好的版本,不复制到其他位置:

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service

# 启动服务
bin\auth-service.exe

# 或者使用 start 后台运行
start bin\auth-service.exe
```

---

## 查看日志

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service

# 实时查看日志
powershell -Command "Get-Content server.log -Wait -Tail 50"

# 或者使用 PowerShell 命令
Get-Content server.log -Wait -Tail 50
```

---

## 验证修复效果

新版本启动后,应该看到以下日志:

```
Using SQLite database: ./auth.db
Applied PRAGMA: PRAGMA journal_mode=WAL;
Applied PRAGMA: PRAGMA synchronous=NORMAL;
Applied PRAGMA: PRAGMA busy_timeout=5000;
Applied PRAGMA: PRAGMA cache_size=-64000;
Applied PRAGMA: PRAGMA foreign_keys=ON;
SQLite connection pool configured: MaxOpenConns=10, MaxIdleConns=5
Auth Service starting on port 8081 (DB: sqlite)
```

30秒后,应该看到:

```
[DB] Connections: InUse=1, Idle=4, MaxOpenConnections=10
```

---

## 故障排查

### 问题: 无法启动服务

**检查端口占用:**
```powershell
netstat -ano | findstr :8081
```

如果端口被占用,修改端口号或停止占用端口的进程。

### 问题: 找不到 auth-service.exe

确认文件位置:
```powershell
dir c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service\bin\auth-service.exe
```

### 问题: 启动后立即退出

查看日志文件:
```powershell
type c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service\server.log
```

---

## 推荐操作流程

1. **停止旧服务**
   ```powershell
   .\stop-auth-service.bat
   ```

2. **启动新服务**
   ```powershell
   .\start-auth-service.bat
   ```

3. **检查健康状态**
   ```powershell
   Invoke-WebRequest http://localhost:8081/health
   ```

4. **查看日志**
   ```powershell
   powershell -Command "Get-Content services\auth-service\server.log -Wait -Tail 50"
   ```

---

## 脚本说明

### start-auth-service.bat
- 自动检测服务是否已运行
- 提示是否重新启动
- 启动后进行健康检查
- 显示日志位置

### stop-auth-service.bat
- 自动检测运行中的进程
- 尝试正常停止
- 必要时强制停止
- 验证停止状态

### deploy-auth-service.bat
- 自动停止服务
- 备份旧版本
- 部署新版本
- 启动新服务
- 验证健康状态
- 显示日志
