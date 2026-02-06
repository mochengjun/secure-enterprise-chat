# ============================================================
# Secure Enterprise Chat - Test Runner (PowerShell)
# Usage: .\run-tests.ps1 -Command <command>
# ============================================================

param(
    [Parameter(Position=0)]
    [ValidateSet('all', 'go', 'go-verbose', 'flutter', 'flutter-widget', 'flutter-bloc', 'ci', 'benchmark', 'help')]
    [string]$Command = 'help',
    
    [Parameter(Position=1)]
    [string]$Package = ''
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Run-GoTests {
    Write-Info "Running Go tests..."
    
    Push-Location "$ProjectRoot\services\auth-service"
    try {
        # Download dependencies
        go mod download
        
        # Run tests with coverage
        go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
        
        # Generate coverage report
        go tool cover -html=coverage.out -o coverage.html
        
        # Show coverage summary
        go tool cover -func=coverage.out | Select-String "total"
        
        Write-Success "Go tests completed!"
        Write-Info "Coverage report: services\auth-service\coverage.html"
    }
    finally {
        Pop-Location
    }
}

function Run-GoTestsVerbose {
    Write-Info "Running Go tests (verbose)..."
    
    Push-Location "$ProjectRoot\services\auth-service"
    try {
        go test -v -race ./internal/repository/...
        go test -v -race ./internal/service/...
        go test -v -race ./internal/handler/...
        
        Write-Success "Go tests completed!"
    }
    finally {
        Pop-Location
    }
}

function Run-GoPackageTests {
    param([string]$Pkg)
    
    Write-Info "Running Go tests for package: $Pkg"
    
    Push-Location "$ProjectRoot\services\auth-service"
    try {
        go test -v -race "./internal/$Pkg/..."
        Write-Success "Package tests completed!"
    }
    finally {
        Pop-Location
    }
}

function Run-FlutterTests {
    Write-Info "Running Flutter tests..."
    
    Push-Location "$ProjectRoot\apps\flutter_app"
    try {
        # Get dependencies
        flutter pub get
        
        # Run tests with coverage
        flutter test --coverage
        
        Write-Success "Flutter tests completed!"
    }
    finally {
        Pop-Location
    }
}

function Run-FlutterWidgetTests {
    Write-Info "Running Flutter widget tests..."
    
    Push-Location "$ProjectRoot\apps\flutter_app"
    try {
        flutter test test/widget/
        Write-Success "Widget tests completed!"
    }
    finally {
        Pop-Location
    }
}

function Run-FlutterBlocTests {
    Write-Info "Running Flutter bloc tests..."
    
    Push-Location "$ProjectRoot\apps\flutter_app"
    try {
        flutter test test/bloc/
        Write-Success "Bloc tests completed!"
    }
    finally {
        Pop-Location
    }
}

function Run-AllTests {
    Write-Info "Running all tests..."
    
    Run-GoTests
    Write-Host ""
    Run-FlutterTests
    
    Write-Success "All tests completed!"
}

function Run-CITests {
    Write-Info "Running tests in CI mode..."
    
    # Go tests
    Push-Location "$ProjectRoot\services\auth-service"
    try {
        go test -v -race -coverprofile=coverage.out -covermode=atomic ./... 2>&1 | Tee-Object -FilePath go-test-results.txt
    }
    finally {
        Pop-Location
    }
    
    # Flutter tests
    Push-Location "$ProjectRoot\apps\flutter_app"
    try {
        flutter test --coverage --machine 2>&1 | Out-File -FilePath flutter-test-results.json
    }
    catch {
        Write-Warning "Flutter tests had some failures"
    }
    finally {
        Pop-Location
    }
    
    Write-Success "CI tests completed!"
}

function Run-Benchmarks {
    Write-Info "Running benchmark tests..."
    
    Push-Location "$ProjectRoot\services\auth-service"
    try {
        go test -bench=. -benchmem ./...
        Write-Success "Benchmarks completed!"
    }
    finally {
        Pop-Location
    }
}

function Show-Help {
    Write-Host @"
Secure Enterprise Chat - Test Runner (PowerShell)

Usage: .\run-tests.ps1 -Command <command> [-Package <pkg>]

Commands:
  all              Run all tests (Go + Flutter)
  go               Run Go tests with coverage
  go-verbose       Run Go tests with verbose output
  flutter          Run Flutter tests with coverage
  flutter-widget   Run Flutter widget tests only
  flutter-bloc     Run Flutter bloc tests only
  ci               Run tests in CI mode
  benchmark        Run benchmark tests
  help             Show this help

Examples:
  .\run-tests.ps1 all                # Run all tests
  .\run-tests.ps1 go                 # Run Go tests
  .\run-tests.ps1 go-verbose         # Run Go tests verbose
  .\run-tests.ps1 flutter-widget     # Run Flutter widget tests
"@
}

# Main
switch ($Command) {
    'all' { Run-AllTests }
    'go' { Run-GoTests }
    'go-verbose' { Run-GoTestsVerbose }
    'flutter' { Run-FlutterTests }
    'flutter-widget' { Run-FlutterWidgetTests }
    'flutter-bloc' { Run-FlutterBlocTests }
    'ci' { Run-CITests }
    'benchmark' { Run-Benchmarks }
    'help' { Show-Help }
    default {
        Write-Err "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
