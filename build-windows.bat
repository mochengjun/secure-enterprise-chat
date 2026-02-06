@echo off
REM 企业安全聊天应用 - Windows构建和打包脚本
REM 使用方法: 在项目根目录运行此脚本

setlocal enabledelayedexpansion

echo ============================================
echo   企业安全聊天应用 - Windows构建脚本
echo ============================================
echo.

REM 设置变量
set APP_NAME=SecChat
set APP_VERSION=1.0.0
set FLUTTER_APP_DIR=apps\flutter_app
set BUILD_DIR=%FLUTTER_APP_DIR%\build\windows\x64\runner\Release
set OUTPUT_DIR=installer\windows\output

REM 检查Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到Flutter，请确保Flutter已安装并添加到PATH
    exit /b 1
)

echo [1/5] 清理旧构建...
cd %FLUTTER_APP_DIR%
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter clean 失败
    exit /b 1
)

echo [2/5] 获取依赖...
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter pub get 失败
    exit /b 1
)

echo [3/5] 构建Windows Release版本...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo [错误] Flutter build 失败
    exit /b 1
)

cd ..\..

echo [4/5] 创建输出目录...
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [5/5] 创建便携版ZIP包...
set ZIP_NAME=%APP_NAME%-Windows-Portable-%APP_VERSION%.zip

REM 使用PowerShell创建ZIP
powershell -Command "Compress-Archive -Path '%BUILD_DIR%\*' -DestinationPath '%OUTPUT_DIR%\%ZIP_NAME%' -Force"
if %ERRORLEVEL% neq 0 (
    echo [警告] ZIP创建失败，请手动打包
) else (
    echo [成功] 便携版已创建: %OUTPUT_DIR%\%ZIP_NAME%
)

echo.
echo ============================================
echo   构建完成!
echo ============================================
echo.
echo 输出文件位置:
echo   - 可执行文件: %BUILD_DIR%\sec_chat.exe
echo   - 便携版ZIP: %OUTPUT_DIR%\%ZIP_NAME%
echo.
echo 如需创建安装包，请:
echo   1. 安装 Inno Setup: https://jrsoftware.org/isdl.php
echo   2. 运行: iscc installer\windows\installer.iss
echo.

pause
