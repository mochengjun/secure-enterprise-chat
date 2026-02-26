/**
 * 安装包生成器
 * 支持生成 Windows、macOS、Linux 安装包
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class PackageBuilder {
  constructor(options = {}) {
    this.options = {
      outputDir: options.outputDir || './installer',
      tempDir: options.tempDir || './temp',
      compressionLevel: options.compressionLevel || 9,
      ...options
    };
    
    this.ensureDirectories();
  }

  ensureDirectories() {
    [this.options.outputDir, this.options.tempDir].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });
  }

  // 创建 ZIP 安装包
  createZip(sourceDir, outputName) {
    const os = require('os');
    const archiver = require('archiver');
    
    return new Promise((resolve, reject) => {
      const outputPath = path.join(this.options.outputDir, `${outputName}.zip`);
      const output = fs.createWriteStream(outputPath);
      const archive = archiver('zip', {
        zlib: { level: this.options.compressionLevel }
      });

      output.on('close', () => {
        console.log(`安装包已创建: ${outputPath}`);
        console.log(`大小: ${(archive.pointer() / 1024 / 1024).toFixed(2)} MB`);
        resolve(outputPath);
      });

      archive.on('error', reject);

      archive.pipe(output);
      archive.directory(sourceDir, false);
      archive.finalize();
    });
  }

  // 创建 tar.gz 安装包
  createTarGz(sourceDir, outputName) {
    const os = require('os');
    const archiver = require('archiver');
    
    return new Promise((resolve, reject) => {
      const outputPath = path.join(this.options.outputDir, `${outputName}.tar.gz`);
      const output = fs.createWriteStream(outputPath);
      const archive = archiver('tar', {
        gzip: true,
        gzipOptions: { level: this.options.compressionLevel }
      });

      output.on('close', () => {
        console.log(`安装包已创建: ${outputPath}`);
        console.log(`大小: ${(archive.pointer() / 1024 / 1024).toFixed(2)} MB`);
        resolve(outputPath);
      });

      archive.on('error', reject);

      archive.pipe(output);
      archive.directory(sourceDir, false);
      archive.finalize();
    });
  }

  // 创建 Windows NSIS 安装程序
  async createNSIS(sourceDir, outputName, appName, options = {}) {
    // 需要 electron-builder 支持
    const config = {
      appId: options.appId || `com.builder.${outputName}`,
      productName: appName || outputName,
      directories: {
        output: this.options.outputDir,
        buildResources: path.join(__dirname, 'resources')
      },
      files: [
        `${sourceDir}/**/*`
      ],
      win: {
        target: [
          {
            target: 'nsis',
            arch: ['x64']
          }
        ],
        artifactName: `${outputName}-Setup-\${version}.\`ext\``
      },
      nsis: {
        oneClick: false,
        allowToChangeInstallationDirectory: true,
        createDesktopShortcut: true,
        createStartMenuShortcut: true,
        shortcutName: appName
      }
    };

    const configPath = path.join(this.options.tempDir, 'electron-builder.json');
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

    try {
      execSync(`npx electron-builder --config "${configPath}"`, {
        stdio: 'inherit'
      });
    } catch (e) {
      console.error('创建 NSIS 安装程序失败:', e.message);
      throw e;
    }
  }

  // 创建自解压安装程序
  async createSelfExtracting(sourceDir, outputName) {
    // 使用 7z sfx 创建自解压程序 (Windows)
    const os = require('os');
    
    if (os.platform() === 'win32') {
      const sevenZipSfx = path.join(__dirname, 'tools', '7zS.sfx');
      
      if (fs.existsSync(sevenZipSfx)) {
        const archivePath = path.join(this.options.tempDir, `${outputName}.7z`);
        const sfxPath = path.join(this.options.tempDir, 'config.txt');
        
        // 创建配置文件
        const sfxConfig = `;!@Install@!UTF-8!\nTitle="${outputName}"\nBeginPrompt="是否安装 ${outputName}?"\nRunProgram="install.bat"\n;!@InstallEnd@!`;
        fs.writeFileSync(sfxConfig, sfxConfig);
        
        // 创建 7z 压缩包
        execSync(`7z a "${archivePath}" "${sourceDir}\\*"`, { stdio: 'inherit' });
        
        // 合并 sfx 和压缩包
        const finalPath = path.join(this.options.outputDir, `${outputName}-Setup.exe`);
        const sfxContent = fs.readFileSync(sevenZipSfx);
        const archiveContent = fs.readFileSync(archivePath);
        
        fs.writeFileSync(finalPath, Buffer.concat([sfxContent, archiveContent]));
        
        console.log(`自解压安装程序已创建: ${finalPath}`);
        return finalPath;
      } else {
        console.warn('7z sfx 不可用，使用 ZIP 格式');
        return this.createZip(sourceDir, outputName);
      }
    } else {
      return this.createTarGz(sourceDir, outputName);
    }
  }

  // 生成版本清单
  generateManifest(projects) {
    const manifest = {
      generated: new Date().toISOString(),
      generator: 'Frontend Package Builder v1.0.0',
      packages: projects.map(p => ({
        name: p.name,
        version: p.version,
        platform: process.platform,
        path: path.join(this.options.outputDir, `${p.name}-${p.version}.zip`)
      }))
    };

    const manifestPath = path.join(this.options.outputDir, 'manifest.json');
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
    
    console.log(`清单文件已生成: ${manifestPath}`);
    return manifest;
  }
}

module.exports = { PackageBuilder };
