#!/bin/bash
# 代码自查系统快速启动脚本
# 自动检测项目类型并配置相应的工具

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示横幅
show_banner() {
    cat << "EOF"
  ____           _    ____          _____           _           
 / ___| ___ _ __| |_ / ___|___  _ __| ____|_ __   __| | _____  __
| |  _ / _ \ '__| __| |   / _ \| '__|  _| | '_ \ / _` |/ _ \ \/ /
| |_| |  __/ |  | |_| |__| (_) | |  | |___| | | | (_| |  __/>  < 
 \____|\___|_|   \__|\____\___/|_|  |_____|_| |_|\__,_|\___/_/\_\
                                                                 
            🔍 自动化代码自查系统配置工具 v1.0
EOF
    echo ""
}

# 检测项目类型
detect_project_types() {
    PROJECT_TYPES=()
    
    # 检测Node.js项目
    if [ -f "package.json" ]; then
        PROJECT_TYPES+=("nodejs")
        log_info "检测到 Node.js/TypeScript 项目"
    fi
    
    # 检测Flutter项目
    if [ -f "secure-enterprise-chat/apps/flutter_app/pubspec.yaml" ]; then
        PROJECT_TYPES+=("flutter")
        log_info "检测到 Flutter/Dart 项目"
    fi
    
    # 检测Python项目
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        PROJECT_TYPES+=("python")
        log_info "检测到 Python 项目"
    fi
    
    # 检测Go项目
    if [ -f "go.mod" ]; then
        PROJECT_TYPES+=("go")
        log_info "检测到 Go 项目"
    fi
    
    if [ ${#PROJECT_TYPES[@]} -eq 0 ]; then
        log_warning "未检测到已知的项目类型，将配置通用工具"
        PROJECT_TYPES+=("generic")
    fi
}

# 安装通用工具
install_generic_tools() {
    log_info "安装通用工具..."
    
    # 安装pre-commit（如果未安装）
    if ! command -v pre-commit &> /dev/null; then
        log_info "安装 pre-commit..."
        if command -v pip3 &> /dev/null; then
            pip3 install pre-commit
        elif command -v pip &> /dev/null; then
            pip install pre-commit
        else
            log_warning "未找到pip，跳过pre-commit安装"
        fi
    else
        log_success "pre-commit 已安装"
    fi
    
    # 安装pre-commit hooks
    if command -v pre-commit &> /dev/null; then
        log_info "配置 Git Hooks..."
        pre-commit install
        pre-commit install --hook-type commit-msg
        log_success "Git Hooks 配置完成"
    fi
}

# 配置Node.js项目
setup_nodejs_project() {
    log_info "配置 Node.js/TypeScript 项目..."
    
    cd web-client 2>/dev/null || return
    
    # 安装依赖
    if [ -f "package.json" ]; then
        log_info "安装 Node.js 依赖..."
        npm install
        
        # 安装开发依赖
        log_info "安装代码质量工具..."
        npm install --save-dev \
            eslint \
            prettier \
            @typescript-eslint/eslint-plugin \
            @typescript-eslint/parser \
            eslint-plugin-security \
            eslint-plugin-sonarjs \
            eslint-config-prettier \
            @trivago/prettier-plugin-sort-imports \
            husky \
            lint-staged \
            @commitlint/cli \
            @commitlint/config-conventional \
            jest \
            @types/jest \
            ts-jest \
            --legacy-peer-deps
        
        # 初始化Husky
        if [ -d ".git" ] || [ -f "../.git" ]; then
            log_info "初始化 Husky..."
            npm run prepare 2>/dev/null || npx husky install
        fi
        
        log_success "Node.js/TypeScript 项目配置完成"
    fi
    
    cd ..
}

# 配置Flutter项目
setup_flutter_project() {
    log_info "配置 Flutter/Dart 项目..."
    
    cd secure-enterprise-chat/apps/flutter_app 2>/dev/null || return
    
    if [ -f "pubspec.yaml" ]; then
        # 获取依赖
        log_info "安装 Flutter 依赖..."
        flutter pub get
        
        # 添加开发依赖
        log_info "添加代码质量工具依赖..."
        flutter pub add --dev lints test mockito build_runner coverage
        
        # 运行dart analyze验证配置
        log_info "验证 Dart 分析配置..."
        dart analyze --fatal-infos 2>/dev/null || true
        
        log_success "Flutter/Dart 项目配置完成"
    fi
    
    cd ../../../..
}

# 配置Python项目
setup_python_project() {
    log_info "配置 Python 项目..."
    
    # 创建虚拟环境
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv || python -m venv venv
    fi
    
    # 激活虚拟环境
    source venv/bin/activate 2>/dev/null || source venv/Scripts/activate 2>/dev/null
    
    # 安装工具
    log_info "安装 Python 代码质量工具..."
    pip install --upgrade pip
    pip install \
        pylint \
        flake8 \
        black \
        isort \
        mypy \
        pytest \
        pytest-cov \
        pytest-junit \
        bandit \
        safety \
        pre-commit
    
    log_success "Python 项目配置完成"
}

# 创建配置文件
create_config_files() {
    log_info "创建配置文件..."
    
    # 创建.vscode目录
    mkdir -p .vscode
    
    # 创建VS Code配置
    if [ ! -f ".vscode/settings.json" ]; then
        cat > .vscode/settings.json << 'EOF'
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },
  "eslint.validate": [
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact"
  ],
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.formatOnType": true,
    "editor.rulers": [80],
    "editor.selectionHighlight": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": "off"
  }
}
EOF
        log_success "创建 VS Code 配置"
    fi
    
    # 创建VS Code扩展推荐
    if [ ! -f ".vscode/extensions.json" ]; then
        cat > .vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "dart-code.dart-code",
    "dart-code.flutter",
    "editorconfig.editorconfig",
    "sonarsource.sonarlint-vscode"
  ]
}
EOF
        log_success "创建 VS Code 扩展推荐"
    fi
    
    # 创建.gitignore增强
    if [ -f ".gitignore" ]; then
        if ! grep -q "# Code Review System" .gitignore; then
            cat >> .gitignore << 'EOF'

# Code Review System
node_modules/
venv/
.venv/
__pycache__/
*.pyc
.pytest_cache/
.coverage
htmlcov/
coverage/
.nyc_output/
junit.xml
*.log
.DS_Store
EOF
            log_success "增强 .gitignore 配置"
        fi
    fi
}

# 运行首次检查
run_initial_check() {
    log_info "运行首次代码检查..."
    
    if command -v pre-commit &> /dev/null; then
        log_info "运行 pre-commit 检查所有文件..."
        pre-commit run --all-files --show-diff-on-failure || true
        log_success "首次检查完成"
    fi
}

# 显示后续步骤
show_next_steps() {
    cat << EOF

${GREEN}✅ 代码自查系统配置完成！${NC}

${BLUE}📋 后续步骤：${NC}

1. ${YELLOW}IDE集成${NC}
   - 安装推荐的VS Code扩展
   - 重启IDE使配置生效

2. ${YELLOW}提交代码${NC}
   - 每次提交时会自动运行检查
   - 如需跳过检查（不推荐）: git commit --no-verify

3. ${YELLOW}手动运行检查${NC}
   - pre-commit run --all-files
   - npm run lint (Node.js项目)
   - dart analyze (Dart项目)
   - pylint **/*.py (Python项目)

4. ${YELLOW}查看文档${NC}
   - 详细文档: .codebuddy/AUTOMATED_CODE_REVIEW_SYSTEM.md

5. ${YELLOW}自定义配置${NC}
   - ESLint规则: .eslintrc.yml
   - Prettier配置: .prettierrc.yml
   - Pre-commit配置: .pre-commit-config.yaml

${BLUE}🔍 支持的功能：${NC}
  ✅ 静态代码分析
  ✅ 自动化单元测试
  ✅ 代码规范检查
  ✅ 安全漏洞扫描
  ✅ Git Hooks集成
  ✅ CI/CD集成

${BLUE}💡 提示：${NC}
  - 配置文件已添加到项目根目录
  - Git Hooks已自动安装
  - 首次运行可能需要较长时间下载依赖

${GREEN}祝您编码愉快！🎉${NC}
EOF
}

# 主函数
main() {
    show_banner
    
    log_info "开始配置代码自查系统..."
    echo ""
    
    # 检测项目类型
    detect_project_types
    echo ""
    
    # 安装通用工具
    install_generic_tools
    echo ""
    
    # 根据项目类型配置
    for type in "${PROJECT_TYPES[@]}"; do
        case $type in
            "nodejs")
                setup_nodejs_project
                ;;
            "flutter")
                setup_flutter_project
                ;;
            "python")
                setup_python_project
                ;;
            "go")
                log_info "Go项目配置开发中..."
                ;;
        esac
        echo ""
    done
    
    # 创建配置文件
    create_config_files
    echo ""
    
    # 运行首次检查
    read -p "是否运行首次代码检查？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_initial_check
        echo ""
    fi
    
    # 显示后续步骤
    show_next_steps
}

# 运行主函数
main
