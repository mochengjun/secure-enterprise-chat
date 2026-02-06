@echo off
echo 正在停止企业安全聊天应用服务...
echo.

REM 检查 Docker 是否已安装
docker --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: Docker 未安装或未在 PATH 中
    pause
    exit /b 1
)

echo 停止所有服务...
docker-compose -f deployments/docker/docker-compose.yml down

echo.
echo 所有服务已停止！
echo.
pause