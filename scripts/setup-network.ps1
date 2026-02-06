# SecChat 网络配置脚本 - 需要以管理员身份运行
# 用于配置防火墙规则允许外部网络访问

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SecChat 网络配置脚本" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 检查管理员权限
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[错误] 请以管理员身份运行此脚本!" -ForegroundColor Red
    Write-Host ""
    Write-Host "右键点击 PowerShell，选择'以管理员身份运行'，然后执行:" -ForegroundColor Yellow
    Write-Host "  .\scripts\setup-network.ps1" -ForegroundColor White
    exit 1
}

Write-Host "[1/4] 添加 TCP 入站规则 (端口 8081)..." -ForegroundColor Yellow

# 删除现有规则（如果存在）
$existingRule = Get-NetFirewallRule -DisplayName "SecChat Auth Service (TCP 8081)" -ErrorAction SilentlyContinue
if ($existingRule) {
    Remove-NetFirewallRule -DisplayName "SecChat Auth Service (TCP 8081)"
    Write-Host "      已删除旧规则" -ForegroundColor Gray
}

# 添加新规则
New-NetFirewallRule -DisplayName "SecChat Auth Service (TCP 8081)" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 8081 `
    -Action Allow `
    -Profile Any `
    -Description "允许外部访问 SecChat 认证服务 (API 和 WebSocket)"

Write-Host "      [成功] TCP 8081 入站规则已添加" -ForegroundColor Green

Write-Host ""
Write-Host "[2/4] 添加 UDP 入站规则 (WebRTC/STUN)..." -ForegroundColor Yellow

# WebRTC 可能需要 UDP 端口（STUN/TURN）
$existingUdpRule = Get-NetFirewallRule -DisplayName "SecChat WebRTC (UDP)" -ErrorAction SilentlyContinue
if ($existingUdpRule) {
    Remove-NetFirewallRule -DisplayName "SecChat WebRTC (UDP)"
}

New-NetFirewallRule -DisplayName "SecChat WebRTC (UDP)" `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 3478,5349,10000-20000 `
    -Action Allow `
    -Profile Any `
    -Description "允许 WebRTC STUN/TURN 流量"

Write-Host "      [成功] UDP WebRTC 规则已添加" -ForegroundColor Green

Write-Host ""
Write-Host "[3/4] 验证规则..." -ForegroundColor Yellow

$rules = Get-NetFirewallRule -DisplayName "SecChat*" | Select-Object DisplayName, Enabled, Direction, Action
if ($rules) {
    Write-Host "      已配置的规则:" -ForegroundColor Gray
    $rules | ForEach-Object {
        Write-Host "        - $($_.DisplayName): $($_.Action) ($($_.Direction))" -ForegroundColor White
    }
} else {
    Write-Host "      [警告] 未找到规则" -ForegroundColor Red
}

Write-Host ""
Write-Host "[4/4] 获取网络信息..." -ForegroundColor Yellow

$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | 
    Where-Object { $_.InterfaceAlias -notlike '*Loopback*' -and $_.IPAddress -notlike '169.*' } |
    Select-Object IPAddress, InterfaceAlias

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  配置完成!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "服务器可用IP地址:" -ForegroundColor Yellow

$ipAddresses | ForEach-Object {
    Write-Host "  - $($_.IPAddress) ($($_.InterfaceAlias))" -ForegroundColor White
}

Write-Host ""
Write-Host "外部访问地址:" -ForegroundColor Yellow
Write-Host "  API:       http://<服务器IP>:8081/api/v1" -ForegroundColor White
Write-Host "  WebSocket: ws://<服务器IP>:8081/api/v1/ws" -ForegroundColor White
Write-Host "  健康检查: http://<服务器IP>:8081/health" -ForegroundColor White
Write-Host ""
Write-Host "测试命令:" -ForegroundColor Yellow
Write-Host "  curl http://<服务器IP>:8081/health" -ForegroundColor White
Write-Host ""
