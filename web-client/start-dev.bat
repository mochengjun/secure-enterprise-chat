@echo off
REM 快速启动Web客户端（用于测试）

setlocal enabledelayedexpansion

echo ============================================
echo   Web客户端 - 快速启动
echo ============================================
echo.

REM 检查是否在正确的目录
if not exist "index.html" (
    echo [错误] 请在 web-client 目录下运行此脚本
    pause
    exit /b 1
)

echo [提示] 启动Web服务器...
echo [提示] 服务地址: http://localhost:8080
echo [提示] 按 Ctrl+C 停止服务
echo.

REM 检查Python
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到Python，无法启动测试服务器
    echo.
    echo 请安装Python或使用其他Web服务器:
    echo   - Nginx
    echo   - Apache
    echo   - Node.js + Express
    echo   - Docker
    echo.
    echo 或者直接打开 index.html 文件
    pause
    exit /b 1
)

REM 启动Python HTTP服务器
python -m http.server 8080 --directory dist

pause
