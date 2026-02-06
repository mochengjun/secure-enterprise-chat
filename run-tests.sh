#!/bin/bash
# ============================================================
# Secure Enterprise Chat - Test Runner Script
# Usage: ./run-tests.sh [component] [options]
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Run Go tests
run_go_tests() {
    log_info "Running Go tests..."
    
    cd "$PROJECT_ROOT/services/auth-service"
    
    # Install test dependencies
    go mod download
    
    # Run tests with coverage
    go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
    
    # Generate coverage report
    go tool cover -html=coverage.out -o coverage.html
    
    # Show coverage summary
    go tool cover -func=coverage.out | grep total
    
    log_success "Go tests completed!"
    log_info "Coverage report: services/auth-service/coverage.html"
}

# Run Go tests with verbose output
run_go_tests_verbose() {
    log_info "Running Go tests (verbose)..."
    
    cd "$PROJECT_ROOT/services/auth-service"
    
    go test -v -race ./internal/repository/...
    go test -v -race ./internal/service/...
    go test -v -race ./internal/handler/...
    
    log_success "Go tests completed!"
}

# Run specific Go package tests
run_go_package_tests() {
    local package="$1"
    log_info "Running Go tests for package: $package"
    
    cd "$PROJECT_ROOT/services/auth-service"
    go test -v -race "./internal/$package/..."
    
    log_success "Package tests completed!"
}

# Run Flutter tests
run_flutter_tests() {
    log_info "Running Flutter tests..."
    
    cd "$PROJECT_ROOT/apps/flutter_app"
    
    # Get dependencies
    flutter pub get
    
    # Run tests with coverage
    flutter test --coverage
    
    # Generate coverage report (if lcov is installed)
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        log_info "Coverage report: apps/flutter_app/coverage/html/index.html"
    fi
    
    log_success "Flutter tests completed!"
}

# Run Flutter widget tests only
run_flutter_widget_tests() {
    log_info "Running Flutter widget tests..."
    
    cd "$PROJECT_ROOT/apps/flutter_app"
    flutter test test/widget/
    
    log_success "Widget tests completed!"
}

# Run Flutter bloc tests only
run_flutter_bloc_tests() {
    log_info "Running Flutter bloc tests..."
    
    cd "$PROJECT_ROOT/apps/flutter_app"
    flutter test test/bloc/
    
    log_success "Bloc tests completed!"
}

# Run all tests
run_all_tests() {
    log_info "Running all tests..."
    
    run_go_tests
    echo ""
    run_flutter_tests
    
    log_success "All tests completed!"
}

# Run tests in CI mode
run_ci_tests() {
    log_info "Running tests in CI mode..."
    
    # Go tests
    cd "$PROJECT_ROOT/services/auth-service"
    go test -v -race -coverprofile=coverage.out -covermode=atomic ./... 2>&1 | tee go-test-results.txt
    
    # Flutter tests
    cd "$PROJECT_ROOT/apps/flutter_app"
    flutter test --coverage --machine > flutter-test-results.json 2>&1 || true
    
    log_success "CI tests completed!"
}

# Benchmark tests
run_benchmarks() {
    log_info "Running benchmark tests..."
    
    cd "$PROJECT_ROOT/services/auth-service"
    go test -bench=. -benchmem ./...
    
    log_success "Benchmarks completed!"
}

# Show help
show_help() {
    echo "Secure Enterprise Chat - Test Runner"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  all              Run all tests (Go + Flutter)"
    echo "  go               Run Go tests with coverage"
    echo "  go-verbose       Run Go tests with verbose output"
    echo "  go-package <pkg> Run tests for specific Go package"
    echo "  flutter          Run Flutter tests with coverage"
    echo "  flutter-widget   Run Flutter widget tests only"
    echo "  flutter-bloc     Run Flutter bloc tests only"
    echo "  ci               Run tests in CI mode"
    echo "  benchmark        Run benchmark tests"
    echo "  help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all                    # Run all tests"
    echo "  $0 go                     # Run Go tests"
    echo "  $0 go-package repository  # Run repository tests"
    echo "  $0 flutter-widget         # Run Flutter widget tests"
}

# Main
case "$1" in
    all)
        run_all_tests
        ;;
    go)
        run_go_tests
        ;;
    go-verbose)
        run_go_tests_verbose
        ;;
    go-package)
        run_go_package_tests "$2"
        ;;
    flutter)
        run_flutter_tests
        ;;
    flutter-widget)
        run_flutter_widget_tests
        ;;
    flutter-bloc)
        run_flutter_bloc_tests
        ;;
    ci)
        run_ci_tests
        ;;
    benchmark)
        run_benchmarks
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
