/**
 * 前端打包工具命令行接口
 * 提供交互式菜单和命令支持
 */

const { FrontendBuilder } = require('./frontend-builder');
const fs = require('fs');
const path = require('path');

class BuilderCLI {
  constructor() {
    this.builder = new FrontendBuilder();
    this.config = this.loadConfig();
  }

  loadConfig() {
    const configPath = path.join(__dirname, 'projects.config.json');
    try {
      return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
    } catch (e) {
      return { projects: [], global: {} };
    }
  }

  saveConfig() {
    const configPath = path.join(__dirname, 'projects.config.json');
    fs.writeFileSync(configPath, JSON.stringify(this.config, null, 2));
  }

  // 列出所有项目
  listProjects() {
    console.log('\n已配置的项目:');
    console.log('========================================');
    
    if (this.config.projects.length === 0) {
      console.log('暂无配置的项目');
      return;
    }
    
    this.config.projects.forEach((project, index) => {
      const status = project.enabled ? '✓' : '✗';
      const version = this.builder.getProjectVersion(project.name);
      console.log(`${index + 1}. [${status}] ${project.name}`);
      console.log(`   版本: ${version}`);
      console.log(`   路径: ${project.path}`);
      console.log(`   升级: ${project.bumpType}`);
      console.log();
    });
  }

  // 显示帮助
  showHelp() {
    console.log(`
前端项目自动化打包工具
========================================

用法: node cli.js [命令] [选项]

命令:
  build [项目名]     构建项目，不指定则构建所有
  add                添加新项目
  remove             移除项目
  list               列出所有项目
  history            显示构建历史
  version            显示版本信息
  validate           验证项目配置

选项:
  --skip-install     跳过依赖安装
  --force            强制构建
  --bump [type]      版本升级类型: major|minor.patch

示例:
  node cli.js build
  node cli.js build web-client
  node cli.js build --skip-install
  node cli.js add
  node cli.js history
`);
  }

  // 添加项目
  async addProject() {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    const question = (prompt) => new Promise((resolve) => {
      readline.question(prompt, resolve);
    });

    try {
      console.log('\n添加新项目');
      console.log('========================================');
      
      const name = await question('项目名称: ');
      if (!name) {
        console.log('项目名称不能为空');
        return;
      }
      
      const projectPath = await question('项目路径: ');
      if (!projectPath) {
        console.log('项目路径不能为空');
        return;
      }
      
      const bumpType = await question('版本升级类型 (major/minor/patch) [patch]: ') || 'patch';
      
      const project = {
        name,
        path: projectPath,
        bumpType,
        enabled: true,
        buildOptions: {
          skipInstall: false,
          forceBuild: false
        }
      };
      
      this.config.projects.push(project);
      this.saveConfig();
      
      console.log(`\n项目 "${name}" 已添加`);
      
    } finally {
      readline.close();
    }
  }

  // 移除项目
  removeProject(name) {
    const index = this.config.projects.findIndex(p => p.name === name);
    
    if (index === -1) {
      console.log(`未找到项目: ${name}`);
      return;
    }
    
    this.config.projects.splice(index, 1);
    this.saveConfig();
    
    console.log(`项目 "${name}" 已移除`);
  }

  // 构建项目
  async buildProject(projectName, options = {}) {
    const projects = projectName 
      ? this.config.projects.filter(p => p.name === projectName && p.enabled)
      : this.config.projects.filter(p => p.enabled);
    
    if (projects.length === 0) {
      console.log('没有可构建的项目');
      return;
    }
    
    const results = await this.builder.buildAll(projects, {
      skipInstall: options.skipInstall,
      forceBuild: options.force
    });
    
    console.log('\n========================================');
    console.log('构建结果汇总');
    console.log('========================================');
    
    let successCount = 0;
    let failCount = 0;
    
    results.forEach(result => {
      if (result.success) {
        successCount++;
        console.log(`✓ ${result.projectName} v${result.version} - ${result.duration}ms`);
      } else {
        failCount++;
        console.log(`✗ ${result.projectName} - ${result.error}`);
      }
    });
    
    console.log(`\n成功: ${successCount}, 失败: ${failCount}`);
  }

  // 显示历史
  showHistory(projectName) {
    const history = this.builder.getBuildHistory(projectName);
    
    console.log('\n构建历史');
    console.log('========================================');
    
    if (history.length === 0) {
      console.log('暂无构建记录');
      return;
    }
    
    history.slice(-20).reverse().forEach(h => {
      const status = h.success ? '✓' : '✗';
      console.log(`[${status}] ${h.project} v${h.version} - ${h.timestamp}`);
      if (h.duration) {
        console.log(`   耗时: ${h.duration}ms`);
      }
      if (h.error) {
        console.log(`   错误: ${h.error}`);
      }
      console.log();
    });
  }

  // 验证项目
  validateProject(projectPath) {
    const result = this.builder.validateProject(projectPath);
    
    console.log('\n验证结果');
    console.log('========================================');
    
    if (result.valid) {
      console.log('✓ 项目配置有效');
    } else {
      console.log('✗ 项目配置无效');
    }
    
    if (result.errors.length > 0) {
      console.log('\n错误:');
      result.errors.forEach(e => console.log(`  - ${e}`));
    }
    
    if (result.warnings.length > 0) {
      console.log('\n警告:');
      result.warnings.forEach(w => console.log(`  - ${w}`));
    }
  }
}

// 主函数
async function main() {
  const args = process.argv.slice(2);
  const cli = new BuilderCLI();
  
  const command = args[0] || 'help';
  
  switch (command) {
    case 'build': {
      const projectName = args[1]?.replace('--project=', '') || args[1];
      const options = {
        skipInstall: args.includes('--skip-install'),
        force: args.includes('--force')
      };
      await cli.buildProject(projectName, options);
      break;
    }
    
    case 'list':
      cli.listProjects();
      break;
    
    case 'add':
      await cli.addProject();
      break;
    
    case 'remove':
      if (args[1]) {
        cli.removeProject(args[1]);
      } else {
        console.log('请指定项目名称');
      }
      break;
    
    case 'history':
      cli.showHistory(args[1]);
      break;
    
    case 'validate':
      cli.validateProject(args[1] || './');
      break;
    
    case 'version':
      console.log('前端项目自动化打包工具 v1.0.0');
      break;
    
    default:
      cli.showHelp();
  }
}

main().catch(console.error);
