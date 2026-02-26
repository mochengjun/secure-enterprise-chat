#!/bin/bash
# 代码检查报告生成脚本
# 生成HTML格式的综合报告

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 报告输出目录
REPORT_DIR="code-review-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${REPORT_DIR}/report_${TIMESTAMP}.html"

# 创建报告目录
mkdir -p "$REPORT_DIR"

echo -e "${BLUE}🔍 生成代码检查报告...${NC}"
echo ""

# 收集统计数据
TOTAL_FILES=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.dart" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/venv/*" ! -path "*/dist/*" | wc -l)
TOTAL_LINES=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.dart" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/venv/*" ! -path "*/dist/*" -exec wc -l {} + | tail -1 | awk '{print $1}')

# 运行ESLint检查
echo -e "${BLUE}运行 ESLint 检查...${NC}"
ESLINT_OUTPUT=$(npm run lint 2>&1 || true)
ESLINT_ERRORS=$(echo "$ESLINT_OUTPUT" | grep -c "error" || echo "0")
ESLINT_WARNINGS=$(echo "$ESLINT_OUTPUT" | grep -c "warning" || echo "0")

# 运行测试
echo -e "${BLUE}运行单元测试...${NC}"
TEST_OUTPUT=$(npm test 2>&1 || true)
TEST_PASSED=$(echo "$TEST_OUTPUT" | grep -o "passed" | wc -l || echo "0")
TEST_FAILED=$(echo "$TEST_OUTPUT" | grep -o "failed" | wc -l || echo "0")

# 运行安全扫描
echo -e "${BLUE}运行安全扫描...${NC}"
SECURITY_OUTPUT=$(npm audit --audit-level=moderate 2>&1 || true)
SECURITY_ISSUES=$(echo "$SECURITY_OUTPUT" | grep -c "vulnerabilities" || echo "0")

# 生成HTML报告
cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>代码自查报告 - ${TIMESTAMP}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .card {
            background: #f8f9fa;
            padding: 25px;
            border-radius: 10px;
            border-left: 5px solid #667eea;
            transition: transform 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .card h3 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 1.3em;
        }
        .card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
        }
        .card.success {
            border-left-color: #28a745;
        }
        .card.success h3 {
            color: #28a745;
        }
        .card.warning {
            border-left-color: #ffc107;
        }
        .card.warning h3 {
            color: #ffc107;
        }
        .card.error {
            border-left-color: #dc3545;
        }
        .card.error h3 {
            color: #dc3545;
        }
        .section {
            margin-bottom: 40px;
        }
        .section h2 {
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #667eea;
        }
        .issue-list {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
        }
        .issue {
            background: white;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 5px;
            border-left: 4px solid;
            box-shadow: 0 2px 5px rgba(0,0,0,0.05);
        }
        .issue.error {
            border-left-color: #dc3545;
            background: #fff5f5;
        }
        .issue.warning {
            border-left-color: #ffc107;
            background: #fff9e6;
        }
        .issue.info {
            border-left-color: #17a2b8;
            background: #e8f4f8;
        }
        .issue strong {
            color: #333;
        }
        .timestamp {
            text-align: center;
            color: #666;
            margin-top: 20px;
            font-size: 0.9em;
        }
        .progress-bar {
            background: #e9ecef;
            border-radius: 10px;
            height: 20px;
            margin: 10px 0;
            overflow: hidden;
        }
        .progress-bar .progress {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            transition: width 0.5s ease;
        }
        .badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            color: white;
        }
        .badge.success {
            background: #28a745;
        }
        .badge.warning {
            background: #ffc107;
        }
        .badge.error {
            background: #dc3545;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 代码自查报告</h1>
            <p>自动化代码质量检查报告</p>
        </div>
        
        <div class="content">
            <!-- 总览 -->
            <div class="summary">
                <div class="card">
                    <h3>📁 分析文件数</h3>
                    <div class="value">${TOTAL_FILES}</div>
                </div>
                <div class="card">
                    <h3>📝 代码行数</h3>
                    <div class="value">${TOTAL_LINES}</div>
                </div>
                <div class="card ${ESLINT_ERRORS}">
                    <h3>❌ 错误数</h3>
                    <div class="value">${ESLINT_ERRORS}</div>
                </div>
                <div class="card ${TEST_FAILED}">
                    <h3>⚠️ 警告数</h3>
                    <div class="value">${ESLINT_WARNINGS}</div>
                </div>
            </div>
            
            <!-- 测试结果 -->
            <div class="section">
                <h2>✅ 测试结果</h2>
                <div class="issue-list">
                    <div class="issue success">
                        <strong>通过的测试:</strong> ${TEST_PASSED} 个
                    </div>
                    <div class="issue ${TEST_FAILED}">
                        <strong>失败的测试:</strong> ${TEST_FAILED} 个
                    </div>
                </div>
            </div>
            
            <!-- 安全扫描 -->
            <div class="section">
                <h2>🔒 安全扫描</h2>
                <div class="issue-list">
                    <div class="issue ${SECURITY_ISSUES}">
                        <strong>发现的安全问题:</strong> ${SECURITY_ISSUES} 个
                    </div>
                </div>
            </div>
            
            <!-- ESLint问题 -->
            <div class="section">
                <h2>🔍 ESLint检查结果</h2>
                <div class="issue-list">
                    <div class="issue info">
                        <strong>错误:</strong> ${ESLINT_ERRORS} 个<br>
                        <strong>警告:</strong> ${ESLINT_WARNINGS} 个
                    </div>
                </div>
            </div>
            
            <!-- 建议 -->
            <div class="section">
                <h2>💡 改进建议</h2>
                <div class="issue-list">
                    <div class="issue info">
                        <strong>建议:</strong> 
                        <ul>
                            <li>修复所有error级别的问题</li>
                            <li>提高测试覆盖率至80%以上</li>
                            <li>修复安全漏洞</li>
                            <li>优化代码复杂度</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="timestamp">
            报告生成时间: $(date "+%Y-%m-%d %H:%M:%S")
        </div>
    </div>
</body>
</html>
EOF

echo ""
echo -e "${GREEN}✅ 报告已生成: ${REPORT_FILE}${NC}"
echo -e "${BLUE}📊 在浏览器中打开报告以查看详细信息${NC}"
echo ""

# 打开报告（可选）
if [[ "$1" == "--open" ]]; then
    if command -v open &> /dev/null; then
        open "$REPORT_FILE"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$REPORT_FILE"
    fi
fi
