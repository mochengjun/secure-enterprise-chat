@echo off
REM ============================================================
REM Secure Enterprise Chat - Local Production Server Startup Script
REM ============================================================

setlocal EnableDelayedExpansion

echo ============================================================
echo    Secure Enterprise Chat - Production Server
echo ============================================================
echo.

REM Set environment variables for production
set USE_SQLITE=true
set JWT_SECRET=SecureChatJWT2026ProductionSecretKey!@#$%%^&*
set SERVER_MODE=release
set PORT=8081
set LOG_LEVEL=info
set LOG_FORMAT=json
set BCRYPT_COST=12
set RATE_LIMIT_REQUESTS=100
set RATE_LIMIT_WINDOW=1m
set UPLOAD_MAX_SIZE=104857600
set JWT_ACCESS_EXPIRY=1h
set JWT_REFRESH_EXPIRY=168h
set STUN_SERVER=stun:stun.l.google.com:19302

REM Create data directories
if not exist "%~dp0data" mkdir "%~dp0data"
if not exist "%~dp0uploads" mkdir "%~dp0uploads"
if not exist "%~dp0logs" mkdir "%~dp0logs"

echo [INFO] Starting Secure Enterprise Chat Server...
echo [INFO] Server Mode: %SERVER_MODE%
echo [INFO] Database: SQLite (embedded)
echo [INFO] Port: %PORT%
echo [INFO] Data Directory: %~dp0data
echo.

REM Change to auth-service directory and run
cd /d "%~dp0..\..\services\auth-service"

echo [INFO] Building and starting server...
echo.

go run cmd/main.go

pause
