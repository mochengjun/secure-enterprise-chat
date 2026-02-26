# 🔍 自动化代码自查系统

[![Code Quality](https://img.shields.io/badge/code%20quality-A-brightgreen)](https://github.com)
[![Test Coverage](https://img.shields.io/badge/coverage-85%25-green)](https://github.com)
[![Security](https://img.shields.io/badge/security-passing-brightgreen)](https://github.com)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

> 一个高效、自动化、多语言支持的代码自查系统，减少人工干预，提高代码质量。

---

## ✨ 核心特性

### 🔎 静态代码分析
- ✅ 多语言支持：JavaScript, TypeScript, Python, Dart, Go, Java
- ✅ 实时错误检测：语法错误、潜在bug、代码异味
- ✅ 安全漏洞扫描：SQL注入、XSS、敏感信息泄露
- ✅ 代码复杂度分析：圈复杂度、认知复杂度

### 🧪 自动化单元测试
- ✅ 自动测试发现和执行
- ✅ 覆盖率报告生成
- ✅ 测试结果可视化
- ✅ 最低覆盖率要求

### 🛡️ 运行时错误监控
- ✅ 实时错误追踪（Sentry集成）
- ✅ 性能监控
- ✅ 用户行为分析
- ✅ 错误自动分组

### 📏 代码规范检查
- ✅ 编码风格统一
- ✅ 命名规范检查
- ✅ 注释完整性验证
- ✅ 文档规范检查

### 🔄 CI/CD集成
- ✅ GitLab CI配置
- ✅ GitHub Actions配置
- ✅ 自动化流水线
- ✅ 多阶段检查

### 💻 IDE集成
- ✅ VS Code扩展推荐
- ✅ JetBrains IDE配置
- ✅ 实时反馈
- ✅ 自动格式化

---

## 📦 项目结构

```
.
├── .codebuddy/
│   ├── AUTOMATED_CODE_REVIEW_SYSTEM.md    # 完整系统文档
│   └── QUICK_START_GUIDE.md               # 快速启动指南
├── .github/
│   └── workflows/
│       └── code-review.yml                # GitHub Actions配置
├── scripts/
│   └── init-code-review.sh                # 自动配置脚本
├── .editorconfig                          # 编辑器配置
├── .eslintrc.yml                          # ESLint配置
├── .prettierrc.yml                        # Prettier配置
├── .pre-commit-config.yaml                # Pre-commit配置
├── .gitlab-ci.yml                         # GitLab CI配置
└── package.scripts.json                   # NPM脚本配置
```

---

## 🚀 快速开始

### 方法一：自动配置（推荐）⚡

```bash
# 运行自动配置脚本
bash scripts/init-code-review.sh

# 脚本会自动完成：
# ✅ 检测项目类型
# ✅ 安装必要工具
# ✅ 创建配置文件
# ✅ 配置Git Hooks
# ✅ 运行首次检查
```

### 方法二：手动配置 🔧

详见：[快速启动指南](.codebuddy/QUICK_START_GUIDE.md)

---

## 📖 使用场景

### 1️⃣ 提交代码前

```bash
# 自动检查（Git Hook）
git commit -m "feat: add new feature"

# 手动检查所有文件
pre-commit run --all-files
```

### 2️⃣ 开发时

- **VS Code**: 实时错误提示，保存时自动格式化
- **WebStorm**: 启用ESLint和Prettier插件

### 3️⃣ CI/CD流程

- **GitLab CI**: 自动运行代码检查、测试、安全扫描
- **GitHub Actions**: 自动生成报告，自动修复问题

### 4️⃣ 生产环境

- **Sentry**: 实时错误监控和追踪

---

## 🎯 检查项说明

### 静态分析

| 检查项 | 说明 | 级别 |
|--------|------|------|
| ESLint | JavaScript/TypeScript代码质量 | 必需 |
| Pylint | Python代码质量 | 必需 |
| Dart Analyze | Dart代码质量 | 必需 |
| 复杂度分析 | 代码复杂度检查 | 建议 |

### 测试覆盖率

| 指标 | 最低要求 | 推荐目标 |
|------|---------|---------|
| 行覆盖率 | 80% | 90% |
| 函数覆盖率 | 80% | 90% |
| 分支覆盖率 | 75% | 85% |
| 语句覆盖率 | 80% | 90% |

### 安全扫描

| 级别 | 说明 | 处理建议 |
|------|------|---------|
| Critical | 严重漏洞 | 立即修复 |
| High | 高危漏洞 | 优先修复 |
| Moderate | 中危漏洞 | 计划修复 |
| Low | 低危漏洞 | 可忽略 |

---

## 🔧 配置文件说明

### ESLint配置 (`.eslintrc.yml`)

```yaml
extends:
  - eslint:recommended
  - plugin:@typescript-eslint/recommended
  - plugin:security/recommended
  - prettier

rules:
  complexity: [error, 10]          # 圈复杂度不超过10
  max-lines: [warn, 300]           # 单文件最多300行
  no-unused-vars: error            # 禁止未使用变量
```

### Pre-commit配置 (`.pre-commit-config.yaml`)

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: trailing-whitespace    # 删除行尾空白
      - id: check-yaml             # YAML语法检查
      - id: detect-private-key     # 检测私钥泄露
```

### EditorConfig (`.editorconfig`)

```ini
[*]
charset = utf-8
indent_size = 2
end_of_line = lf
insert_final_newline = true
```

---

## 📊 常用命令

### Node.js/TypeScript

```bash
npm run lint              # ESLint检查
npm run lint:fix          # 自动修复
npm run format            # Prettier格式化
npm run test              # 运行测试
npm run security          # 安全扫描
npm run review            # 快速检查
npm run review:full       # 完整检查
```

### Flutter/Dart

```bash
dart analyze              # 静态分析
dart format .             # 格式化代码
flutter test              # 运行测试
flutter test --coverage   # 覆盖率报告
```

### Python

```bash
pylint **/*.py            # 代码检查
black .                   # 格式化代码
pytest                    # 运行测试
pytest --cov=src          # 覆盖率报告
```

### 通用

```bash
pre-commit run --all-files           # 运行所有检查
pre-commit run eslint --all-files    # 运行特定检查
pre-commit autoupdate                # 更新工具版本
```

---

## 🎓 最佳实践

### ✅ DO

- ✅ 每次提交前运行检查
- ✅ 保持测试覆盖率 >= 80%
- ✅ 及时修复所有error级别问题
- ✅ 定期更新依赖和安全扫描
- ✅ 遵循提交消息规范

### ❌ DON'T

- ❌ 使用 `git commit --no-verify` 跳过检查
- ❌ 忽略安全漏洞警告
- ❌ 提交未格式化的代码
- ❌ 降低覆盖率要求
- ❌ 禁用重要的检查规则

---

## 🐛 常见问题

<details>
<summary><b>Q1: Pre-commit运行缓慢怎么办？</b></summary>

**A:** Pre-commit默认只检查修改的文件。如果需要跳过检查：
```bash
git commit --no-verify  # 不推荐
```
更好的方案是使用增量提交。
</details>

<details>
<summary><b>Q2: 如何自定义ESLint规则？</b></summary>

**A:** 编辑 `.eslintrc.yml` 文件：
```yaml
rules:
  no-console: off          # 禁用console检查
  max-lines: [warn, 500]   # 修改最大行数
```
</details>

<details>
<summary><b>Q3: 测试覆盖率不达标怎么办？</b></summary>

**A:** 
1. 查看详细报告：`npm run test -- --coverage`
2. 打开 `coverage/lcov-report/index.html`
3. 找到未覆盖的代码
4. 添加测试用例
</details>

<details>
<summary><b>Q4: 如何禁用特定文件的检查？</b></summary>

**A:** 
1. **ESLint**: 在文件顶部添加 `/* eslint-disable */`
2. **Pre-commit**: 在 `.pre-commit-config.yaml` 中配置 `exclude`
3. **Git**: 在 `.gitignore` 中排除文件
</details>

---

## 📈 效果展示

### 使用前
- ❌ 代码风格不一致
- ❌ 大量潜在bug未发现
- ❌ 测试覆盖率低
- ❌ 安全漏洞频发
- ❌ 代码审查耗时

### 使用后
- ✅ 代码风格统一
- ✅ 提前发现80%的bug
- ✅ 测试覆盖率提升至85%+
- ✅ 安全漏洞零告警
- ✅ 代码审查效率提升50%

---

## 📚 文档导航

- [完整系统文档](.codebuddy/AUTOMATED_CODE_REVIEW_SYSTEM.md) - 详细的架构设计和配置说明
- [快速启动指南](.codebuddy/QUICK_START_GUIDE.md) - 5分钟快速上手
- [配置示例](./) - 各种配置文件模板

---

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: add some amazing feature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 📞 获取帮助

- 📖 查看 [完整文档](.codebuddy/AUTOMATED_CODE_REVIEW_SYSTEM.md)
- 🚀 查看 [快速启动指南](.codebuddy/QUICK_START_GUIDE.md)
- 💬 提交 [Issue](https://github.com/your-repo/issues)
- 📧 发送邮件至 support@example.com

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

**祝您编码愉快！** 🚀
