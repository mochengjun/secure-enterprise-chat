# 客户端构建与分发指南

本文档介绍如何为各平台构建企业安全聊天应用的安装包。

## 目录

- [环境准备](#环境准备)
- [Windows构建](#windows构建)
- [Android构建](#android构建)
- [iOS构建](#ios构建)
- [macOS构建](#macos构建)
- [分发方式](#分发方式)

---

## 环境准备

### 通用要求

| 工具 | 版本 | 说明 |
|------|------|------|
| Flutter SDK | 3.16+ | 跨平台框架 |
| Git | 2.40+ | 版本控制 |

### 各平台额外要求

| 平台 | 构建环境 | 额外要求 |
|------|----------|----------|
| Windows | Windows 10/11 | Visual Studio 2022 |
| Android | Windows/macOS/Linux | Android SDK, JDK 17 |
| iOS | macOS 13+ | Xcode 15+, Apple Developer账号 |
| macOS | macOS 13+ | Xcode 15+ |

---

## Windows构建

### 快速构建

```batch
# 运行构建脚本
build-windows.bat
```

### 输出文件

| 文件 | 位置 | 说明 |
|------|------|------|
| 便携版 | `installer/windows/output/SecChat-Windows-Portable-*.zip` | 解压即用 |
| 安装版 | `installer/windows/output/SecChat-Setup-*.exe` | 需要Inno Setup |

### 创建安装程序

1. 下载安装 [Inno Setup](https://jrsoftware.org/isdl.php)
2. 运行命令:
   ```batch
   iscc installer\windows\installer.iss
   ```

---

## Android构建

### 环境配置

1. **安装Android Studio**
   - 下载: https://developer.android.com/studio
   - 安装时选择"Android SDK"

2. **配置环境变量**
   ```batch
   # Windows
   set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
   set PATH=%PATH%;%ANDROID_HOME%\tools;%ANDROID_HOME%\platform-tools
   ```

3. **接受SDK许可**
   ```bash
   flutter doctor --android-licenses
   ```

### 快速构建

```batch
# 运行构建脚本
build-android.bat
```

### 手动构建

```bash
cd apps/flutter_app

# 构建APK (直接安装)
flutter build apk --release

# 构建AAB (Google Play)
flutter build appbundle --release
```

### 输出文件

| 文件 | 位置 | 用途 |
|------|------|------|
| APK | `build/app/outputs/flutter-apk/app-release.apk` | 直接安装 |
| AAB | `build/app/outputs/bundle/release/app-release.aab` | Google Play |

### 安装说明

1. 将APK传输到Android设备
2. 在设备上启用"安装未知应用"
3. 打开APK文件进行安装

---

## iOS构建

> ⚠️ iOS构建必须在macOS上进行

### 环境配置

1. **安装Xcode**
   ```bash
   xcode-select --install
   ```

2. **安装CocoaPods**
   ```bash
   sudo gem install cocoapods
   ```

3. **配置Apple Developer账号**
   - 打开Xcode → Preferences → Accounts
   - 添加Apple ID

### 快速构建

```bash
# 运行构建脚本
chmod +x build-ios.sh
./build-ios.sh
```

### 手动构建

```bash
cd apps/flutter_app

# 安装Pod依赖
cd ios && pod install && cd ..

# 构建 (无签名)
flutter build ios --release --no-codesign

# 构建 IPA (需要签名配置)
flutter build ipa --release
```

### 分发方式

| 方式 | 适用场景 | 要求 |
|------|----------|------|
| TestFlight | 内部测试 | Apple Developer账号 |
| Ad-Hoc | 限量分发 | 设备UDID注册 |
| 企业分发 | 企业内部 | Enterprise账号 ($299/年) |
| App Store | 公开发布 | App Store审核 |

---

## macOS构建

> ⚠️ macOS构建必须在macOS上进行

### 快速构建

```bash
# 运行构建脚本
chmod +x build-macos.sh
./build-macos.sh
```

### 手动构建

```bash
cd apps/flutter_app

# 构建
flutter build macos --release

# 输出位置
# build/macos/Build/Products/Release/sec_chat.app
```

### 输出文件

| 文件 | 说明 |
|------|------|
| `.app` | macOS应用包 |
| `.dmg` | 磁盘映像安装包 |
| `.zip` | 便携版压缩包 |

### 公证 (Notarization)

发布前建议进行Apple公证:

```bash
# 创建公证
xcrun notarytool submit SecChat.dmg \
  --apple-id "your@email.com" \
  --password "app-specific-password" \
  --team-id "TEAM_ID" \
  --wait

# 装订公证票据
xcrun stapler staple SecChat.dmg
```

---

## 分发方式

### 企业内部分发

| 平台 | 推荐方式 | 说明 |
|------|----------|------|
| Windows | 内网文件服务器 / SCCM | 支持MSI/EXE静默安装 |
| Android | MDM / 企业应用商店 | APK直接分发 |
| iOS | MDM / 企业签名 | 需要Enterprise证书 |
| macOS | MDM / 内网分发 | DMG或PKG格式 |

### 版本命名规范

```
SecChat-{平台}-{版本号}.{扩展名}

示例:
- SecChat-Windows-1.0.0.exe
- SecChat-Android-1.0.0.apk
- SecChat-iOS-1.0.0.ipa
- SecChat-macOS-1.0.0.dmg
```

### 更新策略

1. **Windows**: 内置更新检查或企业软件管理
2. **Android**: Google Play自动更新或手动APK更新
3. **iOS**: TestFlight / App Store自动更新
4. **macOS**: Sparkle框架或手动更新

---

## 构建脚本汇总

| 脚本 | 平台 | 说明 |
|------|------|------|
| `build-windows.bat` | Windows | 构建Windows EXE和ZIP |
| `build-android.bat` | Windows | 构建Android APK和AAB |
| `build-ios.sh` | macOS | 构建iOS IPA |
| `build-macos.sh` | macOS | 构建macOS DMG |

---

## 常见问题

### Q: Android构建提示"Unable to locate Android SDK"

A: 需要安装Android SDK并设置ANDROID_HOME环境变量:
```batch
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
```

### Q: iOS构建提示签名错误

A: 开发测试可使用 `--no-codesign` 参数，正式发布需要配置:
1. Apple Developer账号
2. 签名证书
3. Provisioning Profile

### Q: macOS应用首次打开被阻止

A: 这是Gatekeeper安全机制，解决方法:
1. 右键点击应用 → 打开
2. 或在系统偏好设置 → 安全性与隐私 中允许

---

## 版本历史

| 版本 | 日期 | 说明 |
|------|------|------|
| 1.0.0 | 2026-02 | 初始版本 |
