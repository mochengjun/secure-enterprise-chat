@echo off
REM k6 负载测试运行脚本 (Windows)
REM 使用方法: run-load-tests.bat [场景] [负载配置] [环境]

setlocal EnableDelayedExpansion

REM 默认值
set SCENARIO=%1
if "%SCENARIO%"=="" set SCENARIO=all

set LOAD_PROFILE=%2
if "%LOAD_PROFILE%"=="" set LOAD_PROFILE=load

set TARGET_ENV=%3
if "%TARGET_ENV%"=="" set TARGET_ENV=local

set OUTPUT_DIR=.\results

REM 创建输出目录
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 时间戳
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%

echo =====================================
echo    Secure Chat 负载测试
echo =====================================
echo.
echo 场景: %SCENARIO%
echo 负载配置: %LOAD_PROFILE%
echo 目标环境: %TARGET_ENV%
echo.

REM 检查 k6 是否安装
where k6 >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo 错误: k6 未安装
    echo 请访问 https://k6.io/docs/getting-started/installation/ 安装 k6
    exit /b 1
)

k6 version
echo.

REM 根据场景运行测试
if "%SCENARIO%"=="auth" goto run_auth
if "%SCENARIO%"=="chat" goto run_chat
if "%SCENARIO%"=="websocket" goto run_websocket
if "%SCENARIO%"=="ws" goto run_websocket
if "%SCENARIO%"=="mixed" goto run_mixed
if "%SCENARIO%"=="all" goto run_all
if "%SCENARIO%"=="smoke" goto run_smoke
if "%SCENARIO%"=="stress" goto run_stress
if "%SCENARIO%"=="spike" goto run_spike
if "%SCENARIO%"=="soak" goto run_soak

echo 未知场景: %SCENARIO%
echo.
echo 可用场景:
echo   auth      - 认证接口测试
echo   chat      - 聊天接口测试
echo   websocket - WebSocket 压力测试
echo   mixed     - 混合场景测试
echo   all       - 运行所有测试
echo   smoke     - 冒烟测试
echo   stress    - 压力测试
echo   spike     - 峰值测试
echo   soak      - 浸泡测试
exit /b 1

:run_auth
echo 运行认证测试...
call :run_test auth scenarios\auth.js
goto done

:run_chat
echo 运行聊天测试...
call :run_test chat scenarios\chat.js
goto done

:run_websocket
echo 运行 WebSocket 测试...
call :run_test websocket scenarios\websocket.js
goto done

:run_mixed
echo 运行混合场景测试...
call :run_test mixed scenarios\mixed.js
goto done

:run_all
echo 运行所有测试场景...
echo.
call :run_test auth scenarios\auth.js
call :run_test chat scenarios\chat.js
call :run_test websocket scenarios\websocket.js
call :run_test mixed scenarios\mixed.js
goto done

:run_smoke
echo 运行冒烟测试...
set LOAD_PROFILE=smoke
call :run_test auth_smoke scenarios\auth.js
goto done

:run_stress
echo 运行压力测试...
set LOAD_PROFILE=stress
call :run_test websocket_stress scenarios\websocket.js
goto done

:run_spike
echo 运行峰值测试...
set LOAD_PROFILE=spike
call :run_test chat_spike scenarios\chat.js
goto done

:run_soak
echo 运行浸泡测试 (长时间运行)...
set LOAD_PROFILE=soak
call :run_test mixed_soak scenarios\mixed.js
goto done

:run_test
set TEST_NAME=%1
set TEST_FILE=%2
set OUTPUT_FILE=%OUTPUT_DIR%\%TEST_NAME%_%TIMESTAMP%

echo 运行测试: %TEST_NAME%
echo 输出文件: %OUTPUT_FILE%

k6 run ^
    --env TARGET_ENV=%TARGET_ENV% ^
    --env LOAD_PROFILE=%LOAD_PROFILE% ^
    --out json=%OUTPUT_FILE%.json ^
    --summary-export=%OUTPUT_FILE%_summary.json ^
    %TEST_FILE%

if %ERRORLEVEL% equ 0 (
    echo [OK] %TEST_NAME% 测试完成
) else (
    echo [FAIL] %TEST_NAME% 测试失败
)
echo.
exit /b 0

:done
echo =====================================
echo    测试完成
echo =====================================
echo.
echo 结果保存在: %OUTPUT_DIR%
echo.
echo 完成!

endlocal
