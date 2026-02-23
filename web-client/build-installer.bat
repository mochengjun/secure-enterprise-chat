@echo off
REM Web客户端 - 构建和打包脚本
REM 使用方法: 在 web-client 目录运行此脚本

setlocal enabledelayedexpansion

echo ============================================
echo   Web客户端 - 构建和打包脚本
echo ============================================
echo.

REM 切换到脚本所在目录（确保相对路径正确）
cd /d "%~dp0"

REM 设置变量
set APP_NAME=secure-chat-web
set APP_VERSION=1.0.0
set DOCKER_IMAGE=%APP_NAME%:%APP_VERSION%
set OUTPUT_DIR=installer\windows\output

echo [1/4] 清理旧构建...
if exist dist rmdir /s /q dist

echo [2/4] 安装依赖...
call npm install
if %ERRORLEVEL% neq 0 (
    echo [错误] npm install 失败
    exit /b 1
)

echo [3/4] 构建生产版本...
call npm run build
if %ERRORLEVEL% neq 0 (
    echo [错误] npm run build 失败
    exit /b 1
)

echo [4/4] 创建安装包...

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 1. 创建便携版ZIP（静态文件）
set ZIP_NAME=%APP_NAME%-Static-%APP_VERSION%.zip
powershell -Command "Compress-Archive -Path 'dist\*' -DestinationPath '%OUTPUT_DIR%\%ZIP_NAME%' -Force"
if %ERRORLEVEL% neq 0 (
    echo [警告] 静态文件ZIP创建失败
) else (
    echo [成功] 静态文件ZIP已创建: %OUTPUT_DIR%\%ZIP_NAME%
)

REM 2. 创建Docker镜像
echo [5/5] 创建Docker镜像...
docker build -t %DOCKER_IMAGE% .
if %ERRORLEVEL% neq 0 (
    echo [警告] Docker镜像创建失败
) else (
    echo [成功] Docker镜像已创建: %DOCKER_IMAGE%

    REM 导出Docker镜像为tar文件
    set TARBALL=%APP_NAME%-Docker-%APP_VERSION%.tar
    docker save %DOCKER_IMAGE% -o "%OUTPUT_DIR%\%TARBALL%"
    if %ERRORLEVEL% neq 0 (
        echo [警告] Docker镜像导出失败
    ) else (
        echo [成功] Docker镜像已导出: %OUTPUT_DIR%\%TARBALL%
    )
)

echo.
echo ============================================
echo   构建完成!
echo ============================================
echo.
echo 输出文件位置:
echo   - 静态文件ZIP: %OUTPUT_DIR%\%ZIP_NAME%
echo   - Docker镜像: %DOCKER_IMAGE%
echo   - Docker镜像TAR: %OUTPUT_DIR%\%TARBALL%
echo.
echo 部署方式:
echo   1. 静态文件: 解压ZIP到任意Web服务器
echo   2. Docker: docker run -p 80:80 %DOCKER_IMAGE%
echo.

pause
