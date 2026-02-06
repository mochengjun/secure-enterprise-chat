#!/bin/bash
# 企业安全聊天应用 - macOS构建脚本
# 使用方法: 在macOS上运行此脚本
# 前提条件: Xcode、Flutter SDK

set -e

echo "============================================"
echo "  企业安全聊天应用 - macOS构建脚本"
echo "============================================"
echo ""

# 变量设置
APP_NAME="SecChat"
APP_VERSION="1.0.0"
FLUTTER_APP_DIR="apps/flutter_app"
OUTPUT_DIR="installer/macos/output"

# 检查操作系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "[错误] 此脚本只能在macOS上运行"
    exit 1
fi

# 检查Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] 未找到Flutter，请安装Flutter SDK"
    exit 1
fi

echo "[1/5] 进入Flutter项目目录..."
cd "$FLUTTER_APP_DIR"

echo "[2/5] 清理旧构建..."
flutter clean

echo "[3/5] 获取依赖..."
flutter pub get

echo "[4/5] 构建macOS Release版本..."
flutter build macos --release

echo "[5/5] 打包应用..."
cd ../..
mkdir -p "$OUTPUT_DIR"

# 复制.app包
APP_PATH="$FLUTTER_APP_DIR/build/macos/Build/Products/Release/sec_chat.app"
if [ -d "$APP_PATH" ]; then
    # 创建DMG磁盘映像
    echo "创建DMG安装包..."
    
    DMG_NAME="${APP_NAME}-macOS-${APP_VERSION}.dmg"
    DMG_TEMP="$OUTPUT_DIR/temp_dmg"
    
    # 创建临时目录
    rm -rf "$DMG_TEMP"
    mkdir -p "$DMG_TEMP"
    
    # 复制应用
    cp -R "$APP_PATH" "$DMG_TEMP/"
    
    # 创建Applications快捷方式
    ln -s /Applications "$DMG_TEMP/Applications"
    
    # 创建DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$OUTPUT_DIR/$DMG_NAME"
    
    # 清理临时目录
    rm -rf "$DMG_TEMP"
    
    echo "[成功] DMG已创建: $OUTPUT_DIR/$DMG_NAME"
    
    # 同时创建ZIP便携版
    cd "$FLUTTER_APP_DIR/build/macos/Build/Products/Release"
    zip -r "../../../../$OUTPUT_DIR/${APP_NAME}-macOS-${APP_VERSION}.zip" sec_chat.app
    cd ../../../../..
    
    echo "[成功] ZIP便携版已创建: $OUTPUT_DIR/${APP_NAME}-macOS-${APP_VERSION}.zip"
fi

echo ""
echo "============================================"
echo "  macOS构建完成!"
echo "============================================"
echo ""
echo "输出文件位置: $OUTPUT_DIR/"
echo ""
echo "分发说明:"
echo "  - DMG文件可直接分发给用户"
echo "  - 首次运行可能需要在系统偏好设置中允许"
echo "  - 如需公证(Notarization)，请使用xcrun notarytool"
echo ""
