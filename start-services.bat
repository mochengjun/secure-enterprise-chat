@echo off
echo 正在启动企业安全聊天应用服务...
echo.

REM 检查 Docker 是否已安装
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: Docker 未安装或未在 PATH 中
    echo 请先安装 Docker Desktop 并确保其正在运行
    pause
    exit /b 1
)

REM 检查 Docker 是否正在运行
docker ps >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: Docker 未运行
    echo 请启动 Docker Desktop 并等待其完全加载
    pause
    exit /b 1
)

echo Docker 环境正常，正在启动服务...
echo.

REM 切换到项目目录
cd /d "%~dp0../.."

echo 启动基础设施服务 (PostgreSQL, Redis, MinIO)...
docker-compose -f deployments/docker/docker-compose.yml up -d postgres redis minio
if %ERRORLEVEL% neq 0 (
    echo 错误: 启动基础设施服务失败
    pause
    exit /b 1
)

echo 等待数据库服务就绪...
timeout /t 10 /nobreak >nul

echo 启动 Matrix Synapse 服务器...
docker-compose -f deployments/docker/docker-compose.yml up -d synapse
if %ERRORLEVEL% neq 0 (
    echo 错误: 启动 Synapse 服务器失败
    pause
    exit /b 1
)

echo 等待 Synapse 服务就绪...
timeout /t 15 /nobreak >ul

echo 启动 Go 微服务...
docker-compose -f deployments/docker/docker-compose.yml up -d auth-service media-proxy cleanup-service push-service admin-service permission-service
if %ERRORLEVEL% neq 0 (
    echo 错误: 启动 Go 微服务失败
    pause
    exit /b 1
)

echo.
echo 所有服务已启动！
echo.
echo 服务端口映射:
echo   PostgreSQL: 5432
echo   Redis: 6379
echo   MinIO API: 9000
echo   MinIO Console: 9001
echo   Synapse: 8008
echo   Auth Service: 8081
echo   Media Proxy: 8082
echo   Push Service: 8083
echo   Admin Service: 8084
echo   Permission Service: 8085
echo.
echo 要查看服务状态，请运行: docker-compose -f deployments/docker/docker-compose.yml ps
echo 要查看日志，请运行: docker-compose -f deployments/docker/docker-compose.yml logs -f
echo.
pause