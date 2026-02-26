@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo   前端项目自动化打包工具 v1.0.0
echo ========================================
echo.

set "BUILDER_DIR=%~dp0"
set "CONFIG_FILE=%BUILDER_DIR%projects.config.json"
set "BUILDER_SCRIPT=%BUILDER_DIR%frontend-builder.js"

:: 检查 Node.js 是否安装
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先安装 Node.js
    exit /b 1
)

echo [信息] Node.js 已安装
node --version
echo.

:: 检查配置文件
if not exist "%CONFIG_FILE%" (
    echo [错误] 配置文件不存在: %CONFIG_FILE%
    exit /b 1
)

:: 解析命令行参数
set "ACTION=build"
set "PROJECT_NAME="
set "SKIP_INSTALL="
set "FORCE_BUILD="

:parse_args
if "%~1"=="" goto args_done
if "%~1"=="--help" goto show_help
if "%~1"=="-h" goto show_help
if "%~1"=="build" set "ACTION=build"
if "%~1"=="list" set "ACTION=list"
if "%~1"=="history" set "ACTION=history"
if "%~1"=="validate" set "ACTION=validate"
if "%~1"=="--project" (
    set "PROJECT_NAME=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--skip-install" set "SKIP_INSTALL=true"
if "%~1"=="--force" set "FORCE_BUILD=true"
shift
goto parse_args

:args_done

:: 执行相应操作
if "%ACTION%"=="build" goto do_build
if "%ACTION%"=="list" goto do_list
if "%ACTION%"=="history" goto do_history
if "%ACTION%"=="validate" goto do_validate
goto end

:do_build
echo [开始] 构建项目...
echo.

set "BUILD_CMD=node "%BUILDER_SCRIPT%" --action build"

if defined PROJECT_NAME (
    set "BUILD_CMD=!BUILD_CMD! --project "%PROJECT_NAME%""
)

if defined SKIP_INSTALL (
    set "BUILD_CMD=!BUILD_CMD! --skip-install"
)

if defined FORCE_BUILD (
    set "BUILD_CMD=!BUILD_CMD! --force"
)

!BUILD_CMD!
goto end

:do_list
echo [可用操作]
echo   build      - 构建所有项目
echo   list       - 列出所有项目
echo   history    - 显示构建历史
echo   validate   - 验证项目配置
echo.
node "%BUILDER_SCRIPT%" --action list
goto end

:do_history
node "%BUILDER_SCRIPT%" --action history
goto end

:do_validate
node "%BUILDER_SCRIPT%" --action validate --project "%PROJECT_NAME%"
goto end

:show_help
echo.
echo 用法: build.bat [命令] [选项]
echo.
echo 命令:
echo   build        构建项目 ^(默认^)
echo   list         列出所有项目
echo   history      显示构建历史
echo   validate     验证项目配置
echo.
echo 选项:
echo   --project NAME    指定项目名称
echo   --skip-install   跳过依赖安装
echo   --force          强制构建
echo   --help, -h       显示帮助信息
echo.
echo 示例:
echo   build.bat build
echo   build.bat build --project web-client
echo   build.bat build --skip-install
echo   build.bat history
echo.
goto end

:end
echo.
echo ========================================
echo   操作完成
echo ========================================
endlocal
