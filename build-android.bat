@echo off
REM 企业安全聊天应用 - Android构建脚本
REM 使用方法: 安装Android SDK后运行此脚本

setlocal enabledelayedexpansion

echo ============================================
echo   企业安全聊天应用 - Android构建脚本
echo ============================================
echo.

REM 设置变量
set APP_NAME=SecChat
set APP_VERSION=1.0.0
set FLUTTER_APP_DIR=apps\flutter_app
set OUTPUT_DIR=installer\android\output

REM 检查ANDROID_HOME
if "%ANDROID_HOME%"=="" (
    echo [警告] ANDROID_HOME 未设置
    echo 尝试查找Android SDK...
    
    if exist "%LOCALAPPDATA%\Android\Sdk" (
        set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
    ) else if exist "C:\Android\Sdk" (
        set ANDROID_HOME=C:\Android\Sdk
    ) else (
        echo [错误] 未找到Android SDK
        echo.
        echo 请先安装Android Studio或Android SDK:
        echo   https://developer.android.com/studio
        echo.
        echo 安装后设置环境变量:
        echo   set ANDROID_HOME=C:\Users\你的用户名\AppData\Local\Android\Sdk
        echo.
        pause
        exit /b 1
    )
)

echo 使用Android SDK: %ANDROID_HOME%
echo.

REM 检查Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到Flutter
    exit /b 1
)

echo [1/5] 进入Flutter项目目录...
cd %FLUTTER_APP_DIR%

echo [2/5] 清理旧构建...
call flutter clean

echo [3/5] 获取依赖...
call flutter pub get

echo [4/5] 构建Android APK (Release)...
call flutter build apk --release
if %ERRORLEVEL% neq 0 (
    echo [错误] APK构建失败
    exit /b 1
)

echo [5/5] 复制输出文件...
cd ..\..
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 复制APK文件
if exist "%FLUTTER_APP_DIR%\build\app\outputs\flutter-apk\app-release.apk" (
    copy "%FLUTTER_APP_DIR%\build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.apk"
    echo [成功] APK已导出: %OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.apk
)

REM 构建App Bundle (用于Google Play)
echo.
echo 正在构建Android App Bundle...
cd %FLUTTER_APP_DIR%
call flutter build appbundle --release
cd ..\..

if exist "%FLUTTER_APP_DIR%\build\app\outputs\bundle\release\app-release.aab" (
    copy "%FLUTTER_APP_DIR%\build\app\outputs\bundle\release\app-release.aab" "%OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.aab"
    echo [成功] AAB已导出: %OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.aab
)

echo.
echo ============================================
echo   Android构建完成!
echo ============================================
echo.
echo 输出文件:
echo   - APK (直接安装): %OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.apk
echo   - AAB (Google Play): %OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%.aab
echo.
echo 安装说明:
echo   - APK可直接在Android设备上安装
echo   - 需要在设备上启用"未知来源"安装
echo   - AAB用于上传到Google Play商店
echo.

pause
