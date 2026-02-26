@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo.
echo ============================================================
echo    Secure Enterprise Chat - 统一构建脚本
echo    版本: 2.1.0
echo    日期: 2026-02-26
echo ============================================================
echo.

REM 设置颜色
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "RESET=[0m"

REM 保存脚本所在目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM 设置路径
set "BACKEND_SRC=%SCRIPT_DIR%secure-enterprise-chat\services\auth-service"
set "BACKEND_BIN=%SCRIPT_DIR%secure-enterprise-chat\services\auth-service\bin"
set "FRONTEND_SRC=%SCRIPT_DIR%web-client"
set "FRONTEND_DIST=%SCRIPT_DIR%web-client\dist"
set "DIST_PACKAGES=%SCRIPT_DIR%dist-packages"

REM ============================================================
REM 步骤 1: 清理旧的构建产物
REM ============================================================

echo %CYAN%[步骤 1/5] 清理旧的构建产物...%RESET%
echo.

if exist "%BACKEND_BIN%\auth-service.exe" (
    del /f /q "%BACKEND_BIN%\auth-service.exe" 2>nul
    echo   [OK] 清理后端旧二进制文件
)

if exist "%FRONTEND_DIST%" (
    rmdir /s /q "%FRONTEND_DIST%" 2>nul
    echo   [OK] 清理前端旧构建产物
)

echo.

REM ============================================================
REM 步骤 2: 编译后端服务
REM ============================================================

echo %CYAN%[步骤 2/5] 编译后端服务...%RESET%
echo.

REM 检查 Go 环境
where go >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] Go 未安装或未添加到 PATH%RESET%
    goto :error_exit
)

for /f "tokens=*" %%v in ('go version 2^>nul') do set GO_VERSION=%%v
echo   [OK] Go 环境: %GO_VERSION%

REM 创建 bin 目录
if not exist "%BACKEND_BIN%" mkdir "%BACKEND_BIN%"

REM 编译后端
echo   [编译] 正在编译后端服务...
cd /d "%BACKEND_SRC%"
go build -ldflags="-s -w" -o "%BACKEND_BIN%\auth-service.exe" ./cmd/main.go 2>&1

if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] 后端编译失败%RESET%
    goto :error_exit
)

echo   %GREEN%[OK] 后端编译成功: services\auth-service\bin\auth-service.exe%RESET%

REM 显示文件大小
for %%F in ("%BACKEND_BIN%\auth-service.exe") do (
    set SIZE=%%~zF
    set /a SIZE_MB=!SIZE! / 1048576
    echo         文件大小: !SIZE_MB! MB
)

echo.

REM ============================================================
REM 步骤 3: 构建前端应用
REM ============================================================

echo %CYAN%[步骤 3/5] 构建前端应用...%RESET%
echo.

REM 检查 Node.js 环境
where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] Node.js 未安装或未添加到 PATH%RESET%
    goto :error_exit
)

for /f "tokens=*" %%v in ('node -v 2^>nul') do set NODE_VERSION=%%v
echo   [OK] Node.js 环境: %NODE_VERSION%

cd /d "%FRONTEND_SRC%"

REM 检查依赖
if not exist "node_modules" (
    echo   [安装] 正在安装前端依赖...
    call npm install --silent
    if %ERRORLEVEL% neq 0 (
        echo %RED%[错误] 前端依赖安装失败%RESET%
        goto :error_exit
    )
)

REM 构建前端
echo   [构建] 正在构建前端应用...
call npm run build 2>&1

if %ERRORLEVEL% neq 0 (
    echo %RED%[错误] 前端构建失败%RESET%
    goto :error_exit
)

echo   %GREEN%[OK] 前端构建成功: web-client\dist\%RESET%

REM 显示构建产物
if exist "%FRONTEND_DIST%\assets" (
    for %%F in ("%FRONTEND_DIST%\assets\*.js") do (
        set JS_FILE=%%~nxF
        set JS_SIZE=%%~zF
        set /a JS_SIZE_KB=!JS_SIZE! / 1024
        echo         JS: !JS_FILE! (!JS_SIZE_KB! KB)
    )
)

echo.

REM ============================================================
REM 步骤 4: 复制到统一部署目录
REM ============================================================

echo %CYAN%[步骤 4/5] 复制到统一部署目录...%RESET%
echo.

REM 创建 dist-packages 目录结构
if not exist "%DIST_PACKAGES%" mkdir "%DIST_PACKAGES%"
if not exist "%DIST_PACKAGES%\services" mkdir "%DIST_PACKAGES%\services"
if not exist "%DIST_PACKAGES%\services\auth-service" mkdir "%DIST_PACKAGES%\services\auth-service"
if not exist "%DIST_PACKAGES%\web" mkdir "%DIST_PACKAGES%\web"

REM 复制后端可执行文件
copy /y "%BACKEND_BIN%\auth-service.exe" "%DIST_PACKAGES%\services\auth-service\" >nul
echo   [OK] 复制后端可执行文件到 dist-packages\services\auth-service\

REM 复制前端构建产物
xcopy /s /e /y /q "%FRONTEND_DIST%\*" "%DIST_PACKAGES%\web\" >nul
echo   [OK] 复制前端构建产物到 dist-packages\web\

REM 复制配置文件
if exist "%SCRIPT_DIR%version.json" (
    copy /y "%SCRIPT_DIR%version.json" "%DIST_PACKAGES%\" >nul
    echo   [OK] 复制版本配置文件
)

echo.

REM ============================================================
REM 步骤 5: 生成构建报告
REM ============================================================

echo %CYAN%[步骤 5/5] 生成构建报告...%RESET%
echo.

REM 写入版本信息
echo {> "%DIST_PACKAGES%\build-info.json"
echo   "buildTime": "%date% %time%",>> "%DIST_PACKAGES%\build-info.json"
echo   "backend": {>> "%DIST_PACKAGES%\build-info.json"
echo     "path": "services/auth-service/auth-service.exe",>> "%DIST_PACKAGES%\build-info.json"
for %%F in ("%BACKEND_BIN%\auth-service.exe") do (
    set SIZE=%%~zF
    echo     "size": !SIZE!,>> "%DIST_PACKAGES%\build-info.json"
)
echo     "goVersion": "%GO_VERSION%">> "%DIST_PACKAGES%\build-info.json"
echo   },>> "%DIST_PACKAGES%\build-info.json"
echo   "frontend": {>> "%DIST_PACKAGES%\build-info.json"
echo     "path": "web/",>> "%DIST_PACKAGES%\build-info.json"
echo     "nodeVersion": "%NODE_VERSION%">> "%DIST_PACKAGES%\build-info.json"
echo   }>> "%DIST_PACKAGES%\build-info.json"
echo }>> "%DIST_PACKAGES%\build-info.json"

echo   [OK] 构建报告: dist-packages\build-info.json

echo.

REM ============================================================
REM 显示最终目录结构
REM ============================================================

echo ============================================================
echo %GREEN%   构建完成！%RESET%
echo ============================================================
echo.
echo   部署目录结构:
echo   ------------------------------------------------------------
echo   dist-packages/
echo   ├── services/
echo   │   └── auth-service/
echo   │       └── auth-service.exe    (后端服务)
echo   ├── web/
echo   │   ├── index.html              (前端入口)
echo   │   └── assets/                 (静态资源)
echo   └── build-info.json             (构建信息)
echo   ------------------------------------------------------------
echo.
echo   开发环境目录:
echo   ------------------------------------------------------------
echo   secure-enterprise-chat/services/auth-service/bin/
echo   └── auth-service.exe            (后端二进制)
echo.
echo   web-client/dist/
echo   ├── index.html
echo   └── assets/
echo   ------------------------------------------------------------
echo.
echo   启动服务: 运行 secure-enterprise-chat\start-services.bat
echo.

goto :end

:error_exit
echo.
echo %RED%[错误] 构建失败，请检查上述错误信息%RESET%
echo.
pause
exit /b 1

:end
endlocal
