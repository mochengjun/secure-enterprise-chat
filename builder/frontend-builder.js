/**
 * 前端项目自动化打包工具
 * 支持 React、Vue、Angular 等主流框架
 * 版本: 1.0.0
 */

const fs = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');
const crypto = require('crypto');

class FrontendBuilder {
  constructor(config = {}) {
    this.config = {
      projectsDir: config.projectsDir || './projects',
      outputDir: config.outputDir || './dist-packages',
      versionFile: config.versionFile || './version.json',
      maxConcurrent: config.maxConcurrent || 3,
      timeout: config.timeout || 300000, // 5分钟超时
      ...config
    };
    
    this.supportedFrameworks = ['react', 'vue', 'angular', 'next', 'nuxt', 'vite', 'flutter'];
    this.packageManagers = ['npm', 'yarn', 'pnpm'];
    this.buildTools = {
      react: { build: 'npm run build', dev: 'npm run dev', test: 'npm run test' },
      vue: { build: 'npm run build', dev: 'npm run dev', test: 'npm run test' },
      angular: { build: 'ng build', dev: 'ng serve', test: 'ng test' },
      next: { build: 'next build', dev: 'next dev', test: 'next test' },
      nuxt: { build: 'nuxt build', dev: 'nuxt dev', test: 'nuxt test' },
      vite: { build: 'npm run build', dev: 'npm run dev', test: 'npm run test' },
      flutter: { build: 'flutter build', dev: 'flutter run', test: 'flutter test' }
    };
    
    this.versions = this.loadVersions();
  }

  // 加载版本信息
  loadVersions() {
    try {
      if (fs.existsSync(this.config.versionFile)) {
        return JSON.parse(fs.readFileSync(this.config.versionFile, 'utf-8'));
      }
    } catch (e) {
      console.warn('无法加载版本文件，将创建新的版本记录');
    }
    return { projects: {}, buildHistory: [] };
  }

  // 保存版本信息
  saveVersions() {
    fs.writeFileSync(this.config.versionFile, JSON.stringify(this.versions, null, 2));
  }

  // 生成项目ID
  generateProjectId(name) {
    return crypto.createHash('md5').update(name).digest('hex').substring(0, 8);
  }

  // 检测项目框架
  detectFramework(projectPath, userSpecifiedFramework = null) {
    // 如果用户指定了框架，优先使用
    if (userSpecifiedFramework) {
      return userSpecifiedFramework;
    }

    // 检测 Flutter 项目
    const flutterIndicators = [
      path.join(projectPath, 'pubspec.yaml'),
      path.join(projectPath, 'apps', 'flutter_app', 'pubspec.yaml'),
      path.join(projectPath, 'flutter_app', 'pubspec.yaml')
    ];
    
    for (const indicator of flutterIndicators) {
      if (fs.existsSync(indicator)) {
        return 'flutter';
      }
    }

    // 检测 Web 项目 (npm/Node.js)
    const packageJsonPath = path.join(projectPath, 'package.json');
    
    if (!fs.existsSync(packageJsonPath)) {
      return null;
    }

    try {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf-8'));
      const deps = { ...packageJson.dependencies, ...packageJson.devDependencies };
      
      // 框架检测优先级
      if (deps['next']) return 'next';
      if (deps['@nuxtjs/nuxt'] || deps['nuxt']) return 'nuxt';
      if (deps['@angular/core']) return 'angular';
      if (deps['vue']) return 'vue';
      if (deps['react']) return 'react';
      if (deps['vite']) return 'vite';
      
      return 'unknown';
    } catch (e) {
      console.error(`检测框架失败: ${e.message}`);
      return null;
    }
  }

  // 检测包管理器
  detectPackageManager(projectPath) {
    if (fs.existsSync(path.join(projectPath, 'pnpm-lock.yaml'))) return 'pnpm';
    if (fs.existsSync(path.join(projectPath, 'yarn.lock'))) return 'yarn';
    return 'npm';
  }

  // 获取项目构建命令
  getBuildCommand(framework, command = 'build', customCommand = null) {
    // 如果有自定义命令，优先使用
    if (customCommand) {
      return customCommand;
    }
    const frameworkConfig = this.buildTools[framework];
    if (!frameworkConfig) {
      return 'npm run build'; // 默认命令
    }
    return frameworkConfig[command] || 'npm run build';
  }

  // 安装依赖
  installDependencies(projectPath) {
    const packageManager = this.detectPackageManager(projectPath);
    console.log(`使用 ${packageManager} 安装依赖...`);
    
    try {
      const installCmd = packageManager === 'pnpm' ? 'pnpm install' :
                         packageManager === 'yarn' ? 'yarn install' :
                         'npm install';
      
      execSync(installCmd, {
        cwd: projectPath,
        stdio: 'inherit',
        timeout: this.config.timeout
      });
      
      return true;
    } catch (e) {
      console.error(`依赖安装失败: ${e.message}`);
      return false;
    }
  }

  // 安装 Flutter 依赖
  installFlutterDependencies(projectPath) {
    console.log('安装 Flutter 依赖...');
    
    // 尝试在多个可能的位置找到 Flutter app
    const flutterAppPaths = [
      path.join(projectPath, 'apps', 'flutter_app'),
      path.join(projectPath, 'flutter_app'),
      projectPath
    ];
    
    let flutterAppPath = null;
    for (const p of flutterAppPaths) {
      if (fs.existsSync(path.join(p, 'pubspec.yaml'))) {
        flutterAppPath = p;
        break;
      }
    }
    
    if (!flutterAppPath) {
      console.warn('未找到 Flutter 应用目录');
      return false;
    }
    
    try {
      execSync('flutter pub get', {
        cwd: flutterAppPath,
        stdio: 'inherit',
        timeout: this.config.timeout
      });
      return true;
    } catch (e) {
      console.error(`Flutter 依赖安装失败: ${e.message}`);
      return false;
    }
  }

  // 构建项目
  async buildProject(projectPath, framework, options = {}) {
    const startTime = Date.now();
    const customBuildCommand = options.buildCommand || null;
    const buildCmd = this.getBuildCommand(framework, 'build', customBuildCommand);
    
    console.log(`开始构建项目: ${path.basename(projectPath)}`);
    console.log(`构建命令: ${buildCmd}`);
    
    return new Promise((resolve, reject) => {
      exec(buildCmd, {
        cwd: projectPath,
        timeout: options.timeout || this.config.timeout,
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
      }, (error, stdout, stderr) => {
        const duration = Date.now() - startTime;
        
        if (error) {
          console.error(`构建失败: ${error.message}`);
          console.error(`stderr: ${stderr}`);
          reject({ error, duration, stdout, stderr });
        } else {
          console.log(`构建成功，耗时: ${duration}ms`);
          resolve({ success: true, duration, stdout, stderr });
        }
      });
    });
  }

  // 创建安装包
  createInstaller(projectPath, projectName, version, framework) {
    const outputPath = path.join(this.config.outputDir, projectName);
    const distPath = path.join(projectPath, 'dist');
    
    if (!fs.existsSync(outputPath)) {
      fs.mkdirSync(outputPath, { recursive: true });
    }
    
    // 复制构建产物
    if (fs.existsSync(distPath)) {
      const targetPath = path.join(outputPath, 'static');
      this.copyDirectory(distPath, targetPath);
    }
    
    // 创建版本信息文件
    const versionInfo = {
      name: projectName,
      version,
      framework,
      buildTime: new Date().toISOString(),
      buildNumber: Date.now()
    };
    
    fs.writeFileSync(
      path.join(outputPath, 'version.json'),
      JSON.stringify(versionInfo, null, 2)
    );
    
    // 创建安装配置
    const installConfig = {
      name: projectName,
      version,
      framework,
      entry: this.getEntryFile(framework),
      scripts: this.getInstallScripts(framework)
    };
    
    fs.writeFileSync(
      path.join(outputPath, 'install.config.json'),
      JSON.stringify(installConfig, null, 2)
    );
    
    return outputPath;
  }

  // 复制目录
  copyDirectory(src, dest) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    
    const entries = fs.readdirSync(src, { withFileTypes: true });
    
    for (const entry of entries) {
      const srcPath = path.join(src, entry.name);
      const destPath = path.join(dest, entry.name);
      
      if (entry.isDirectory()) {
        this.copyDirectory(srcPath, destPath);
      } else {
        fs.copyFileSync(srcPath, destPath);
      }
    }
  }

  // 获取入口文件
  getEntryFile(framework) {
    const entryFiles = {
      react: 'index.html',
      vue: 'index.html',
      angular: 'index.html',
      next: 'index.js',
      nuxt: 'index.js',
      vite: 'index.html'
    };
    return entryFiles[framework] || 'index.html';
  }

  // 获取安装脚本
  getInstallScripts(framework) {
    return {
      install: 'npm install',
      build: 'npm run build',
      start: 'npm run start'
    };
  }

  // 更新版本号
  bumpVersion(projectName, type = 'patch') {
    if (!this.versions.projects[projectName]) {
      this.versions.projects[projectName] = { version: '0.0.0', lastBuild: null };
    }
    
    const currentVersion = this.versions.projects[projectName].version;
    const [major, minor, patch] = currentVersion.split('.').map(Number);
    
    let newVersion;
    switch (type) {
      case 'major':
        newVersion = `${major + 1}.0.0`;
        break;
      case 'minor':
        newVersion = `${major}.${minor + 1}.0`;
        break;
      case 'patch':
      default:
        newVersion = `${major}.${minor}.${patch + 1}`;
        break;
    }
    
    this.versions.projects[projectName].version = newVersion;
    this.versions.projects[projectName].lastBuild = new Date().toISOString();
    this.saveVersions();
    
    return newVersion;
  }

  // 添加构建历史记录
  addBuildHistory(projectName, buildInfo) {
    this.versions.buildHistory.push({
      project: projectName,
      ...buildInfo,
      timestamp: new Date().toISOString()
    });
    
    // 保留最近100条记录
    if (this.versions.buildHistory.length > 100) {
      this.versions.buildHistory = this.versions.buildHistory.slice(-100);
    }
    
    this.saveVersions();
  }

  // 构建单个项目
  async build(projectPath, options = {}) {
    const projectName = options.name || path.basename(projectPath);
    const version = options.version || this.bumpVersion(projectName, options.bumpType || 'patch');
    const skipInstall = options.skipInstall || false;
    const userFramework = options.framework || null;
    const customBuildCommand = options.buildCommand || null;
    
    console.log(`\n========================================`);
    console.log(`开始构建项目: ${projectName}`);
    console.log(`版本: ${version}`);
    console.log(`========================================\n`);
    
    // 检测框架
    const framework = this.detectFramework(projectPath, userFramework);
    if (!framework) {
      throw new Error(`无法识别项目框架: ${projectPath}`);
    }
    console.log(`检测到框架: ${framework}`);
    
    // 安装依赖 (对于 Flutter 项目使用 flutter pub get)
    if (!skipInstall) {
      if (framework === 'flutter') {
        this.installFlutterDependencies(projectPath);
      } else {
        const installSuccess = this.installDependencies(projectPath);
        if (!installSuccess && !options.forceBuild) {
          throw new Error('依赖安装失败');
        }
      }
    } else {
      console.log('跳过依赖安装');
    }
    
    // 构建项目
    let buildResult;
    try {
      buildResult = await this.buildProject(projectPath, framework, {
        ...options,
        buildCommand: customBuildCommand
      });
    } catch (error) {
      this.addBuildHistory(projectName, {
        success: false,
        version,
        error: error.error?.message || error.message
      });
      throw error;
    }
    
    // 创建安装包
    const installerPath = this.createInstaller(projectPath, projectName, version, framework);
    
    // 记录构建历史
    this.addBuildHistory(projectName, {
      success: true,
      version,
      framework,
      duration: buildResult.duration,
      installerPath
    });
    
    return {
      success: true,
      projectName,
      version,
      framework,
      installerPath,
      duration: buildResult.duration
    };
  }

  // 批量构建项目
  async buildAll(projects, options = {}) {
    const results = [];
    
    console.log(`\n========================================`);
    console.log(`开始批量构建 ${projects.length} 个项目`);
    console.log(`========================================\n`);
    
    for (const project of projects) {
      try {
        const result = await this.build(project.path, {
          name: project.name,
          version: project.version,
          bumpType: project.bumpType,
          skipInstall: options.skipInstall,
          forceBuild: options.forceBuild
        });
        results.push(result);
      } catch (error) {
        results.push({
          success: false,
          projectName: project.name,
          error: error.message
        });
      }
    }
    
    return results;
  }

  // 获取构建历史
  getBuildHistory(projectName = null) {
    if (projectName) {
      return this.versions.buildHistory.filter(h => h.project === projectName);
    }
    return this.versions.buildHistory;
  }

  // 获取项目版本
  getProjectVersion(projectName) {
    return this.versions.projects[projectName]?.version || '0.0.0';
  }

  // 列出所有支持的项目
  listSupportedFrameworks() {
    return Object.keys(this.buildTools);
  }

  // 验证项目配置
  validateProject(projectPath) {
    const errors = [];
    const warnings = [];
    
    const packageJsonPath = path.join(projectPath, 'package.json');
    if (!fs.existsSync(packageJsonPath)) {
      errors.push('缺少 package.json 文件');
    }
    
    const srcPath = path.join(projectPath, 'src');
    if (!fs.existsSync(srcPath)) {
      warnings.push('未找到 src 目录');
    }
    
    const framework = this.detectFramework(projectPath);
    if (!framework) {
      warnings.push('无法自动识别框架');
    }
    
    return { valid: errors.length === 0, errors, warnings };
  }
}

module.exports = { FrontendBuilder };
