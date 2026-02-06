# ============================================================
# Secure Enterprise Chat - Deployment Script (PowerShell)
# Usage: .\deploy.ps1 -Command <command> [options]
# ============================================================

param(
    [Parameter(Position=0)]
    [ValidateSet('init', 'build', 'start', 'stop', 'restart', 'status', 'logs', 'backup', 'restore', 'update', 'cleanup', 'help')]
    [string]$Command = 'help',
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ComposeFile = Join-Path $ScriptDir "docker-compose.yml"
$EnvFile = Join-Path $ScriptDir ".env"

# Functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    }
    
    Write-Success "All prerequisites met."
}

function Initialize-Environment {
    Write-Info "Initializing environment..."
    
    if (-not (Test-Path $EnvFile)) {
        Write-Info "Creating .env file from template..."
        Copy-Item (Join-Path $ScriptDir ".env.example") $EnvFile
        Write-Warning "Please edit $EnvFile and configure your environment before deploying."
        return
    }
    
    # Create necessary directories
    $dirs = @(
        (Join-Path $ScriptDir "nginx\ssl"),
        (Join-Path $ScriptDir "keys"),
        (Join-Path $ScriptDir "backups")
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Success "Environment initialized."
}

function Invoke-Build {
    Write-Info "Building Docker images..."
    
    docker compose -f $ComposeFile build --no-cache $Args
    
    Write-Success "Images built successfully."
}

function Start-Services {
    Write-Info "Starting services..."
    
    docker compose -f $ComposeFile up -d $Args
    
    Write-Success "Services started."
    Write-Info "Waiting for services to be healthy..."
    Start-Sleep -Seconds 10
    
    docker compose -f $ComposeFile ps
}

function Stop-Services {
    Write-Info "Stopping services..."
    
    docker compose -f $ComposeFile down $Args
    
    Write-Success "Services stopped."
}

function Restart-Services {
    Write-Info "Restarting services..."
    
    Stop-Services
    Start-Services
    
    Write-Success "Services restarted."
}

function Get-Status {
    Write-Info "Service status:"
    docker compose -f $ComposeFile ps
}

function Get-Logs {
    docker compose -f $ComposeFile logs -f $Args
}

function Backup-Database {
    $BackupDir = Join-Path $ScriptDir "backups"
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupFile = Join-Path $BackupDir "backup_$Timestamp.sql"
    
    if (-not (Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    Write-Info "Creating database backup..."
    
    # Load environment variables
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
            }
        }
    }
    
    $PgUser = $env:POSTGRES_USER
    $PgDb = $env:POSTGRES_DB
    
    docker compose -f $ComposeFile exec -T postgres pg_dump -U $PgUser $PgDb | Out-File -FilePath $BackupFile -Encoding UTF8
    
    Write-Success "Backup created: $BackupFile"
}

function Update-Deployment {
    Write-Info "Updating deployment..."
    
    Invoke-Build
    Restart-Services
    
    Write-Success "Deployment updated."
}

function Invoke-Cleanup {
    Write-Info "Cleaning up unused Docker resources..."
    
    docker system prune -f
    docker volume prune -f
    
    Write-Success "Cleanup completed."
}

function Show-Help {
    Write-Host @"
Secure Enterprise Chat - Deployment Script (PowerShell)

Usage: .\deploy.ps1 -Command <command> [options]

Commands:
  init          Initialize environment (create .env from template)
  build         Build Docker images
  start         Start all services
  stop          Stop all services
  restart       Restart all services
  status        Show service status
  logs          View service logs
  backup        Create database backup
  update        Update deployment (build, restart)
  cleanup       Clean up unused Docker resources
  help          Show this help message

Examples:
  .\deploy.ps1 init                    # Initialize environment
  .\deploy.ps1 build                   # Build all images
  .\deploy.ps1 start                   # Start all services
  .\deploy.ps1 logs auth-service       # View auth-service logs
"@
}

# Main
switch ($Command) {
    'init' {
        Test-Prerequisites
        Initialize-Environment
    }
    'build' {
        Test-Prerequisites
        Invoke-Build
    }
    'start' {
        Test-Prerequisites
        Start-Services
    }
    'stop' {
        Stop-Services
    }
    'restart' {
        Restart-Services
    }
    'status' {
        Get-Status
    }
    'logs' {
        Get-Logs
    }
    'backup' {
        Backup-Database
    }
    'update' {
        Update-Deployment
    }
    'cleanup' {
        Invoke-Cleanup
    }
    'help' {
        Show-Help
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
