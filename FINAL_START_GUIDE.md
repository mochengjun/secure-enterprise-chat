# Auth-Service 启动指南 (已验证)

## ✅ 已验证的配置

- ✅ 服务文件存在: `services\auth-service\bin\auth-service.exe` (40 MB)
- ✅ 编译时间: 2026-02-23 15:54
- ✅ 包含 SQLite 连接池配置
- ✅ 包含 PRAGMA 参数优化
- ✅ 包含数据库监控

---

## 🚀 最简单的启动方法

### 方法 1: 直接双击批处理文件

1. 打开文件夹:
   ```
   c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
   ```

2. 双击运行:
   ```
   start-auth-service.bat
   ```

3. 等待启动完成,查看健康检查结果

### 方法 2: 命令行启动

```powershell
# 打开 PowerShell 或命令提示符

cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat

# 启动服务
.\start-auth-service.bat
```

### 方法 3: 直接运行可执行文件

```powershell
# 前台运行 (可以看到日志)
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service
.\bin\auth-service.exe

# 或者在当前目录后台启动
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
start "" services\auth-service\bin\auth-service.exe
```

---

## 🛑 停止服务

### 方法 1: 使用停止脚本

双击运行:
```
stop-auth-service.bat
```

### 方法 2: 命令行停止

```powershell
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
.\stop-auth-service.bat
```

### 方法 3: 直接停止

```powershell
# 查找进程
tasklist | findstr auth-service

# 停止进程
taskkill /F /IM auth-service.exe
```

---

## ✅ 验证启动成功

服务启动后,您应该看到:

### 1. 控制台输出
```
========================================
启动 Auth-Service
========================================

检查现有服务...
无运行中的服务

启动服务...
等待启动...
检查服务状态...

========================================
服务启动成功!
========================================

进程信息:
auth-service.exe                  1234 Console                    1    100,000 K

健康检查:
  状态码: 200

日志文件: c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat\services\auth-service\server.log
```

### 2. 日志文件内容

查看日志文件应该看到:
```
Using SQLite database: ./auth.db
Applied PRAGMA: PRAGMA journal_mode=WAL;
Applied PRAGMA: PRAGMA synchronous=NORMAL;
Applied PRAGMA: PRAGMA busy_timeout=5000;
Applied PRAGMA: PRAGMA cache_size=-64000;
Applied PRAGMA: PRAGMA foreign_keys=ON;
SQLite connection pool configured: MaxOpenConns=10, MaxIdleConns=5
Auth Service starting on port 8081 (DB: sqlite)
[DB] Connections: InUse=1, Idle=4, MaxOpenConnections=10
```

### 3. 健康检查

浏览器访问:
```
http://localhost:8081/health
```

应该返回:
```json
{
  "status": "ok",
  "service": "auth-service",
  "db_type": "sqlite"
}
```

---

## 📊 查看日志

### 方法 1: 用记事本打开
```
services\auth-service\server.log
```

### 方法 2: PowerShell 查看
```powershell
# 查看最近 50 行
Get-Content services\auth-service\server.log -Tail 50

# 实时查看
Get-Content services\auth-service\server.log -Wait -Tail 50
```

### 方法 3: 搜索错误
```powershell
Select-String -Path services\auth-service\server.log -Pattern "ERROR|error|panic"
```

---

## 🔧 故障排查

### 问题 1: 双击 start-auth-service.bat 没反应

**可能原因:**
- 文件关联问题
- 执行策略限制

**解决方案:**
```powershell
# 方法 1: 右键 → 以管理员身份运行

# 方法 2: 使用命令行
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
.\start-auth-service.bat

# 方法 3: 直接运行服务
cd services\auth-service
.\bin\auth-service.exe
```

### 问题 2: 端口被占用

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

# 或者先停止现有服务
.\stop-auth-service.bat
```

### 问题 3: 服务启动后立即退出

**解决方案:**
```powershell
# 查看日志
type services\auth-service\server.log

# 检查数据库文件
Test-Path services\auth-service\auth.db

# 前台启动查看错误
cd services\auth-service
.\bin\auth-service.exe
```

### 问题 4: 权限错误

**解决方案:**
```powershell
# 以管理员身份运行
# 右键点击 start-auth-service.bat
# 选择"以管理员身份运行"

# 或者使用 PowerShell 管理员模式
# 右键 PowerShell → 以管理员身份运行
```

---

## 📝 重要文件位置

| 文件 | 位置 |
|------|------|
| 服务可执行文件 | `services\auth-service\bin\auth-service.exe` |
| 数据库文件 | `services\auth-service\auth.db` |
| 日志文件 | `services\auth-service\server.log` |
| 启动脚本 | `start-auth-service.bat` |
| 停止脚本 | `stop-auth-service.bat` |
| 验证脚本 | `verify-setup.bat` |

---

## 🔗 相关文档

| 文档 | 说明 |
|------|------|
| `FIX_SUMMARY.md` | 修复总结 |
| `BACKEND_ROLLING_ROOT_CAUSE_ANALYSIS.md` | 根因分析 |
| `MANUAL_DEPLOY.md` | 手动部署指南 |
| `QUICK_START.md` | 快速启动指南 |

---

## 💡 常用命令

```powershell
# 启动服务
cd c:\Users\MCJ\codebuddy\chat\secure-enterprise-chat
.\start-auth-service.bat

# 停止服务
.\stop-auth-service.bat

# 重启服务
.\stop-auth-service.bat
Start-Sleep -Seconds 2
.\start-auth-service.bat

# 查看日志
Get-Content services\auth-service\server.log -Tail 50

# 健康检查
Invoke-WebRequest http://localhost:8081/health

# 检查进程
tasklist | findstr auth-service

# 查看端口
netstat -ano | findstr :8081
```

---

## ✅ 检查清单

启动服务后,确认以下几点:

- [ ] 服务进程在运行
- [ ] 健康检查返回 200 OK
- [ ] 日志显示 PRAGMA 配置
- [ ] 30 秒后显示 [DB] Connections
- [ ] 端口 8081 已监听
- [ ] 无错误日志

---

## 🎯 预期效果

修复后的服务应该:

- ✅ 稳定运行,不频繁崩溃
- ✅ 内存占用稳定 (< 500MB)
- ✅ 数据库连接数正常 (< 10)
- ✅ 查询响应快速 (< 100ms)
- ✅ 支持更多并发连接 (50-100)

---

## 📞 需要帮助?

如果仍然无法启动,请提供:

1. **启动方法**: 双击还是命令行?
2. **错误信息**: 具体的错误提示
3. **日志内容**: `server.log` 文件内容
4. **进程状态**: `tasklist | findstr auth-service` 的输出
5. **端口状态**: `netstat -ano | findstr :8081` 的输出

---

**创建日期**: 2026-02-23
**版本**: 2.0 (已验证)
**状态**: ✅ 服务文件已验证存在,可以启动
