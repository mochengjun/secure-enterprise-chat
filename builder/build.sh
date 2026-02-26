#!/bin/bash

# 前端项目自动化打包工具 - 跨平台版本
# 支持 Linux, macOS, Windows (Git Bash/WSL)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/projects.config.json"
BUILDER_SCRIPT="$SCRIPT_DIR/frontend-builder.js"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 显示帮助
show_help() {
    echo "前端项目自动化打包工具 v1.0.0"
    echo "========================================"
    echo ""
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  build [项目名]     构建项目，不指定则构建所有"
    echo "  list              列出所有项目"
    echo "  history           显示构建历史"
    echo "  validate          验证项目配置"
    echo "  help              显示帮助信息"
    echo ""
    echo "选项:"
    echo "  --skip-install    跳过依赖安装"
    echo "  --force           强制构建"
    echo ""
    echo "示例:"
    echo "  $0 build"
    echo "  $0 build web-client"
    echo "  $0 build --skip-install"
    echo "  $0 history"
}

# 检查依赖
check_dependencies() {
    if ! command -v node &> /dev/null; then
        print_error "未检测到 Node.js，请先安装 Node.js"
        exit 1
    fi
    
    print_info "Node.js 版本: $(node --version)"
    
    if [ ! -f "$BUILDER_SCRIPT" ]; then
        print_error "构建脚本不存在: $BUILDER_SCRIPT"
        exit 1
    fi
}

# 构建项目
do_build() {
    local project_name=""
    local skip_install=""
    local force_build=""
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --project=*)
                project_name="${1#*=}"
                shift
                ;;
            --project)
                project_name="$2"
                shift 2
                ;;
            --skip-install)
                skip_install="true"
                shift
                ;;
            --force)
                force_build="true"
                shift
                ;;
            *)
                project_name="$1"
                shift
                ;;
        esac
    done
    
    print_info "开始构建项目..."
    
    local build_cmd="node '$BUILDER_SCRIPT' --action build"
    
    if [ -n "$project_name" ]; then
        build_cmd="$build_cmd --project '$project_name'"
    fi
    
    if [ -n "$skip_install" ]; then
        build_cmd="$build_cmd --skip-install"
    fi
    
    if [ -n "$force_build" ]; then
        build_cmd="$build_cmd --force"
    fi
    
    eval $build_cmd
    
    print_success "构建完成"
}

# 列出项目
do_list() {
    node "$BUILDER_SCRIPT" --action list
}

# 显示历史
do_history() {
    node "$BUILDER_SCRIPT" --action history
}

# 验证项目
do_validate() {
    local project_path="${1:-.}"
    node "$BUILDER_SCRIPT" --action validate --project "$project_path"
}

# 主函数
main() {
    local command="${1:-help}"
    shift || true
    
    check_dependencies
    
    case "$command" in
        build)
            do_build "$@"
            ;;
        list)
            do_list
            ;;
        history)
            do_history
            ;;
        validate)
            do_validate "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
