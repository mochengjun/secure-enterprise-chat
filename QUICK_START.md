# 快速启动指南 (PowerShell 脚本)

## 🚀 启动服务

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
powershell -ExecutionPolicy Bypass -File start-auth-service.ps1
```

## 🛑 停止服务

```powershell
powershell -ExecutionPolicy Bypass -File stop-auth-service.ps1
```

## 📊 查看实时日志

```powershell
powershell -ExecutionPolicy Bypass -File watch-logs.ps1
```

---

## 📝 注意事项

### 1. 执行策略
如果遇到"无法加载脚本"错误,请运行:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

或者使用 `-ExecutionPolicy Bypass` 参数绕过限制(已在命令中包含)

### 2. 服务文件位置
服务应该在以下位置:
```
c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service\bin\auth-service.exe
```

如果不存在,需要先编译:
```powershell
cd services\auth-service
.\build.bat
```

### 3. 端口占用
服务默认使用端口 8081。检查端口占用:
```powershell
netstat -ano | findstr :8081
```

---

## ✅ 启动成功标志

服务启动成功后,您应该看到:

### 1. 启动日志
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

### 2. 连接监控 (30秒后)
```
[DB] Connections: InUse=1, Idle=4, MaxOpenConnections=10
```

### 3. 健康检查
```
✓ 健康检查通过 (200 OK)
```

---

## 🔧 故障排查

### 问题 1: 无法加载脚本

**错误信息:**
```
无法加载文件，因为在此系统上禁止运行脚本
```

**解决方案:**
```powershell
# 方法 1: 临时绕过 (推荐)
powershell -ExecutionPolicy Bypass -File start-auth-service.ps1

# 方法 2: 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 问题 2: 找不到服务文件

**错误信息:**
```
错误: 找不到服务文件
```

**解决方案:**
```powershell
# 检查文件是否存在
Test-Path "services\auth-service\bin\auth-service.exe"

# 如果不存在,重新编译
cd services\auth-service
.\build.bat

# 或手动编译
go build -o bin\auth-service.exe ./cmd/main.go
```

### 问题 3: 端口被占用

**错误信息:**
```
bind: address already in use
```

**解决方案:**
```powershell
# 查找占用端口的进程
netstat -ano | findstr :8081

# 停止占用端口的进程 (将 PID 替换为实际值)
taskkill /F /PID <PID>

# 或者修改服务端口 (需要修改代码)
```

### 问题 4: 数据库错误

**错误信息:**
```
Failed to connect to database
```

**解决方案:**
```powershell
# 检查数据库文件
Test-Path "services\auth-service\auth.db"

# 检查文件权限
Get-Acl "services\auth-service\auth.db" | Format-List

# 如果数据库损坏,备份并删除
Copy-Item "services\auth-service\auth.db" "services\auth-service\auth.db.backup" -Force
Remove-Item "services\auth-service\auth.db" -Force
Remove-Item "services\auth-service\auth.db-wal" -Force -ErrorAction SilentlyContinue
Remove-Item "services\auth-service\auth.db-shm" -Force -ErrorAction SilentlyContinue
```

---

## 📊 监控服务状态

### 1. 检查进程
```powershell
Get-Process auth-service | Format-Table Id, CPU, WorkingSet, StartTime
```

### 2. 检查端口
```powershell
Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue
```

### 3. 健康检查
```powershell
Invoke-WebRequest -Uri "http://localhost:8081/health" | Select-Object StatusCode, Content
```

### 4. 查看日志
```powershell
# 实时查看
powershell -ExecutionPolicy Bypass -File watch-logs.ps1

# 查看最近 50 行
Get-Content services\auth-service\server.log -Tail 50

# 搜索错误
Select-String -Path services\auth-service\server.log -Pattern "ERROR|error" -Context 2
```

---

## 🔄 常用命令

```powershell
# 启动服务
powershell -ExecutionPolicy Bypass -File start-auth-service.ps1

# 停止服务
powershell -ExecutionPolicy Bypass -File stop-auth-service.ps1

# 重启服务
powershell -ExecutionPolicy Bypass -File stop-auth-service.ps1; Start-Sleep -Seconds 2; powershell -ExecutionPolicy Bypass -File start-auth-service.ps1

# 查看日志
powershell -ExecutionPolicy Bypass -File watch-logs.ps1

# 健康检查
Invoke-WebRequest http://localhost:8081/health

# 检查进程
tasklist | findstr auth-service
```

---

## 📝 日志文件位置

```
services\auth-service\server.log
```

---

## 🔗 相关文件

| 文件 | 说明 |
|------|------|
| `start-auth-service.ps1` | 启动服务脚本 |
| `stop-auth-service.ps1` | 停止服务脚本 |
| `watch-logs.ps1` | 实时查看日志 |
| `services/auth-service/bin/auth-service.exe` | 服务可执行文件 |
| `services/auth-service/auth.db` | SQLite 数据库文件 |
| `services/auth-service/server.log` | 服务日志文件 |

---

## 💡 提示

1. **首次启动**: 建议先查看日志确认没有错误
2. **开发调试**: 使用前台启动可以看到实时日志:
   ```powershell
   cd services\auth-service
   .\bin\auth-service.exe
   ```
3. **生产环境**: 使用后台启动和日志监控
4. **性能监控**: 观察 `[DB] Connections` 日志,确保连接数正常

---

## 🎯 验证修复效果

启动服务后,检查以下几点:

- [ ] 看到 PRAGMA 配置日志 (journal_mode=WAL 等)
- [ ] 健康检查返回 200 OK
- [ ] 30 秒后看到 `[DB] Connections` 日志
- [ ] 连接数保持在 10 以内
- [ ] 内存占用稳定 (< 500MB)
- [ ] 无崩溃或重启

---

## 📞 需要帮助?

如果遇到问题,请提供:
1. 错误信息截图
2. 日志文件内容 (server.log)
3. 执行的命令
4. PowerShell 版本 (`$PSVersionTable.PSVersion`)

---

**创建日期**: 2026-02-23
**版本**: 1.0
