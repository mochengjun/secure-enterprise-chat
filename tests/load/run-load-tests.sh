#!/bin/bash
# k6 负载测试运行脚本
# 使用方法: ./run-load-tests.sh [场景] [负载配置] [环境]

set -e

# 默认值
SCENARIO="${1:-all}"
LOAD_PROFILE="${2:-load}"
TARGET_ENV="${3:-local}"
OUTPUT_DIR="./results"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 时间戳
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}   Secure Chat 负载测试${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "场景: ${YELLOW}$SCENARIO${NC}"
echo -e "负载配置: ${YELLOW}$LOAD_PROFILE${NC}"
echo -e "目标环境: ${YELLOW}$TARGET_ENV${NC}"
echo ""

# 检查 k6 是否安装
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}错误: k6 未安装${NC}"
    echo "请访问 https://k6.io/docs/getting-started/installation/ 安装 k6"
    exit 1
fi

echo -e "k6 版本: $(k6 version)"
echo ""

# 运行测试函数
run_test() {
    local test_name=$1
    local test_file=$2
    local output_file="${OUTPUT_DIR}/${test_name}_${TIMESTAMP}"
    
    echo -e "${YELLOW}运行测试: ${test_name}${NC}"
    echo "输出文件: ${output_file}"
    
    k6 run \
        --env TARGET_ENV="$TARGET_ENV" \
        --env LOAD_PROFILE="$LOAD_PROFILE" \
        --out json="${output_file}.json" \
        --summary-export="${output_file}_summary.json" \
        "$test_file" \
        2>&1 | tee "${output_file}.log"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ ${test_name} 测试完成${NC}"
    else
        echo -e "${RED}✗ ${test_name} 测试失败 (exit code: $exit_code)${NC}"
    fi
    
    echo ""
    return $exit_code
}

# 根据场景运行测试
case "$SCENARIO" in
    auth)
        run_test "auth" "scenarios/auth.js"
        ;;
    chat)
        run_test "chat" "scenarios/chat.js"
        ;;
    websocket|ws)
        run_test "websocket" "scenarios/websocket.js"
        ;;
    mixed)
        run_test "mixed" "scenarios/mixed.js"
        ;;
    all)
        echo -e "${GREEN}运行所有测试场景${NC}"
        echo ""
        
        run_test "auth" "scenarios/auth.js" || true
        run_test "chat" "scenarios/chat.js" || true
        run_test "websocket" "scenarios/websocket.js" || true
        run_test "mixed" "scenarios/mixed.js" || true
        ;;
    smoke)
        echo -e "${GREEN}运行冒烟测试 (快速验证)${NC}"
        LOAD_PROFILE="smoke"
        
        run_test "auth_smoke" "scenarios/auth.js"
        ;;
    stress)
        echo -e "${GREEN}运行压力测试${NC}"
        LOAD_PROFILE="stress"
        
        run_test "websocket_stress" "scenarios/websocket.js"
        ;;
    spike)
        echo -e "${GREEN}运行峰值测试${NC}"
        LOAD_PROFILE="spike"
        
        run_test "chat_spike" "scenarios/chat.js"
        ;;
    soak)
        echo -e "${YELLOW}运行浸泡测试 (长时间运行)${NC}"
        LOAD_PROFILE="soak"
        
        run_test "mixed_soak" "scenarios/mixed.js"
        ;;
    *)
        echo -e "${RED}未知场景: $SCENARIO${NC}"
        echo ""
        echo "可用场景:"
        echo "  auth      - 认证接口测试"
        echo "  chat      - 聊天接口测试"
        echo "  websocket - WebSocket 压力测试"
        echo "  mixed     - 混合场景测试"
        echo "  all       - 运行所有测试"
        echo "  smoke     - 冒烟测试"
        echo "  stress    - 压力测试"
        echo "  spike     - 峰值测试"
        echo "  soak      - 浸泡测试"
        exit 1
        ;;
esac

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}   测试完成${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "结果保存在: ${OUTPUT_DIR}"
echo ""

# 生成汇总报告
if [ -f "${OUTPUT_DIR}/auth_${TIMESTAMP}_summary.json" ] || \
   [ -f "${OUTPUT_DIR}/chat_${TIMESTAMP}_summary.json" ] || \
   [ -f "${OUTPUT_DIR}/websocket_${TIMESTAMP}_summary.json" ] || \
   [ -f "${OUTPUT_DIR}/mixed_${TIMESTAMP}_summary.json" ]; then
    echo "生成汇总报告..."
    
    cat > "${OUTPUT_DIR}/report_${TIMESTAMP}.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>k6 负载测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #ecf0f1; border-radius: 5px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #2980b9; }
        .metric-label { font-size: 12px; color: #7f8c8d; }
        .pass { color: #27ae60; }
        .fail { color: #e74c3c; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
        th { background: #34495e; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Secure Chat 负载测试报告</h1>
        <p>生成时间: <span id="timestamp"></span></p>
    </div>
    <div id="content">
        <p>请查看 JSON 结果文件获取详细数据。</p>
    </div>
    <script>
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF
    
    echo -e "HTML 报告: ${OUTPUT_DIR}/report_${TIMESTAMP}.html"
fi

echo ""
echo "完成!"
