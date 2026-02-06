@echo off
REM SecChat 防火墙配置脚本
REM 必须以管理员身份运行此脚本

echo ============================================
echo   SecChat 防火墙配置脚本
echo ============================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [错误] 请以管理员身份运行此脚本!
    echo.
    echo 右键点击此脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo [1/4] 添加入站规则 - Auth Service (TCP 8081)...
netsh advfirewall firewall delete rule name="SecChat Auth Service (TCP 8081)" >nul 2>&1
netsh advfirewall firewall add rule name="SecChat Auth Service (TCP 8081)" dir=in action=allow protocol=TCP localport=8081 profile=any
if %ERRORLEVEL% equ 0 (
    echo      [成功] TCP 8081 入站规则已添加
) else (
    echo      [失败] 无法添加规则
)

echo.
echo [2/4] 添加入站规则 - WebRTC UDP...
netsh advfirewall firewall delete rule name="SecChat WebRTC (UDP)" >nul 2>&1
netsh advfirewall firewall add rule name="SecChat WebRTC (UDP)" dir=in action=allow protocol=UDP localport=3478,5349 profile=any
if %ERRORLEVEL% equ 0 (
    echo      [成功] UDP WebRTC 规则已添加
) else (
    echo      [警告] UDP 规则添加失败
)

echo.
echo [3/4] 添加出站规则 - Auth Service (TCP 8081)...
netsh advfirewall firewall delete rule name="SecChat Auth Service Outbound" >nul 2>&1
netsh advfirewall firewall add rule name="SecChat Auth Service Outbound" dir=out action=allow protocol=TCP localport=8081 profile=any
echo      [成功] 出站规则已添加

echo.
echo [4/4] 验证规则...
netsh advfirewall firewall show rule name="SecChat Auth Service (TCP 8081)" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo      [成功] 防火墙规则已正确配置
) else (
    echo      [警告] 规则验证失败
)

echo.
echo ============================================
echo   防火墙配置完成!
echo ============================================
echo.
echo 服务器IP地址:
ipconfig | findstr /i "IPv4"
echo.
echo 其他设备访问地址:
echo   API:       http://服务器IP:8081/api/v1
echo   WebSocket: ws://服务器IP:8081/api/v1/ws
echo   健康检查: http://服务器IP:8081/health
echo.
echo 测试命令: curl http://服务器IP:8081/health
echo.

pause
