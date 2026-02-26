# 🚀 代码自查系统快速启动指南

## 📋 前置要求

确保您的系统已安装以下工具：

- **Git** - 版本控制
- **Node.js** >= 18.0.0 - JavaScript运行时
- **Python** >= 3.11 - Python运行时（如果使用Python）
- **Flutter SDK** >= 3.16.0 - Flutter开发工具（如果使用Flutter）

---

## ⚡ 快速开始（5分钟）

### 方法一：自动配置（推荐）

```bash
# 1. 进入项目目录
cd /path/to/your/project

# 2. 运行自动配置脚本
bash scripts/init-code-review.sh

# 3. 根据提示完成配置
# 脚本会自动：
# - 检测项目类型
# - 安装必要工具
# - 创建配置文件
# - 配置Git Hooks
# - 运行首次检查
```

### 方法二：手动配置

#### 1. 安装Pre-commit（通用）

```bash
# macOS/Linux
pip3 install pre-commit

# Windows
pip install pre-commit

# 安装Git Hooks
pre-commit install
pre-commit install --hook-type commit-msg
```

#### 2. 配置Node.js项目

```bash
cd web-client
npm install
npm run setup  # 运行配置脚本
```

#### 3. 配置Flutter项目

```bash
cd secure-enterprise-chat/apps/flutter_app
flutter pub get
dart analyze
```

#### 4. 配置Python项目

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install pylint flake8 black pytest
```

---

## 🎯 使用场景

### 场景1：提交代码前检查

```bash
# 自动运行（Git Hook）
git commit -m "feat: add new feature"
# Pre-commit会自动运行检查

# 手动运行所有检查
pre-commit run --all-files

# 手动运行特定检查
pre-commit run eslint --all-files
```

### 场景2：开发时实时检查

#### VS Code

1. 安装推荐扩展：
   - ESLint
   - Prettier
   - Python
   - Dart/Flutter

2. 保存时自动格式化（已配置）

3. 实时错误提示（已启用）

#### WebStorm/IntelliJ IDEA

1. 启用ESLint：
   - Settings → Languages & Frameworks → JavaScript → Code Quality Tools → ESLint

2. 启用Prettier：
   - Settings → Languages & Frameworks → JavaScript → Prettier

### 场景3：CI/CD集成

#### GitLab CI

配置文件已创建：`.gitlab-ci.yml`

自动运行：
- 代码规范检查
- 单元测试
- 安全扫描
- 代码质量分析

#### GitHub Actions

配置文件已创建：`.github/workflows/code-review.yml`

### 场景4：运行时监控

#### Sentry集成

```typescript
// Node.js
import * as Sentry from '@sentry/node';
Sentry.init({ dsn: process.env.SENTRY_DSN });

// Flutter
import 'package:sentry_flutter/sentry_flutter.dart';
await SentryFlutter.init((options) {
  options.dsn = 'YOUR_DSN';
});
```

---

## 📊 检查结果解读

### ESLint结果

```
error   - 必须修复（阻止提交）
warning - 建议修复（允许提交）
off     - 不检查
```

### 测试覆盖率

```
80%  - 最低要求
90%  - 推荐目标
100% - 理想目标
```

### 安全扫描

```
Critical  - 严重漏洞，必须立即修复
High      - 高危漏洞，优先修复
Moderate  - 中危漏洞，计划修复
Low       - 低危漏洞，可忽略
```

---

## 🔧 常用命令速查

### Node.js/TypeScript

```bash
npm run lint              # 运行ESLint检查
npm run lint:fix          # 自动修复ESLint问题
npm run format            # 格式化代码
npm run format:check      # 检查代码格式
npm run test              # 运行测试
npm run test:watch        # 监听模式运行测试
npm run security          # 安全扫描
npm run review            # 快速检查
npm run review:full       # 完整检查
```

### Flutter/Dart

```bash
dart analyze              # 静态分析
dart format .             # 格式化代码
flutter test              # 运行测试
flutter test --coverage   # 运行测试并生成覆盖率报告
```

### Python

```bash
pylint **/*.py            # 代码检查
flake8                    # 风格检查
black .                   # 格式化代码
isort .                   # 导入排序
pytest                    # 运行测试
pytest --cov=src          # 测试覆盖率
```

### 通用

```bash
pre-commit run --all-files           # 运行所有检查
pre-commit run eslint --all-files    # 运行特定检查
pre-commit autoupdate                # 更新pre-commit版本
```

---

## 🐛 常见问题

### Q1: Pre-commit运行缓慢

**解决方案：**
```bash
# 只检查修改的文件（默认行为）
git commit -m "message"

# 如果需要检查所有文件
pre-commit run --all-files
```

### Q2: ESLint报错但代码能运行

**原因：** ESLint检查的是代码质量，不是语法错误

**解决方案：**
```bash
# 查看具体错误
npm run lint

# 自动修复
npm run lint:fix
```

### Q3: 测试覆盖率不达标

**解决方案：**
```bash
# 查看详细覆盖率报告
npm run test -- --coverage --open

# 查看未覆盖的代码
# 打开 coverage/lcov-report/index.html
```

### Q4: Git Hooks不生效

**解决方案：**
```bash
# 重新安装Git Hooks
pre-commit uninstall
pre-commit install
pre-commit install --hook-type commit-msg
```

### Q5: 依赖冲突

**解决方案：**
```bash
# 清除依赖缓存
rm -rf node_modules package-lock.json
npm install

# 或使用pnpm
pnpm install
```

---

## 📝 自定义配置

### 自定义ESLint规则

编辑 `.eslintrc.yml`:

```yaml
rules:
  # 禁用规则
  no-console: off
  
  # 修改严重级别
  no-unused-vars: warn
  
  # 自定义参数
  max-lines: [error, 500]
```

### 自定义Prettier格式

编辑 `.prettierrc.yml`:

```yaml
printWidth: 120
singleQuote: false
semi: false
```

### 自定义Pre-commit钩子

编辑 `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: local
    hooks:
      - id: custom-check
        name: My Custom Check
        entry: ./scripts/custom-check.sh
        language: script
```

---

## 🎓 最佳实践

### 1. 提交前检查

✅ **推荐：**
```bash
# 提交前运行
npm run review
```

❌ **不推荐：**
```bash
# 跳过检查（仅在紧急情况使用）
git commit --no-verify
```

### 2. 保持依赖更新

```bash
# 更新npm依赖
npm update

# 更新pre-commit工具
pre-commit autoupdate

# 检查过期依赖
npm outdated
```

### 3. 定期安全扫描

```bash
# 每周运行
npm audit
npm audit fix
```

### 4. 代码审查清单

- [ ] 所有ESLint错误已修复
- [ ] 测试覆盖率 >= 80%
- [ ] 无安全漏洞
- [ ] 代码格式规范
- [ ] 提交消息规范
- [ ] 文档已更新

---

## 📚 相关资源

- [完整文档](.codebuddy/AUTOMATED_CODE_REVIEW_SYSTEM.md)
- [ESLint文档](https://eslint.org/)
- [Prettier文档](https://prettier.io/)
- [Pre-commit文档](https://pre-commit.com/)
- [Jest文档](https://jestjs.io/)

---

## 💬 获取帮助

遇到问题？

1. 查看完整文档：`.codebuddy/AUTOMATED_CODE_REVIEW_SYSTEM.md`
2. 查看配置文件中的注释
3. 运行 `npm run help` 查看所有可用命令
4. 检查CI/CD日志

---

## 🎉 开始使用

```bash
# 一键配置
bash scripts/init-code-review.sh

# 开始编码
npm run dev

# 提交代码（自动检查）
git commit -m "feat: implement new feature"
```

祝您编码愉快！🚀
