#!/bin/bash
# 企业安全聊天应用 - iOS构建脚本
# 使用方法: 在macOS上运行此脚本
# 前提条件: Xcode、Flutter SDK、Apple Developer账号

set -e

echo "============================================"
echo "  企业安全聊天应用 - iOS构建脚本"
echo "============================================"
echo ""

# 变量设置
APP_NAME="SecChat"
APP_VERSION="1.0.0"
FLUTTER_APP_DIR="apps/flutter_app"
OUTPUT_DIR="installer/ios/output"

# 检查操作系统
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "[错误] 此脚本只能在macOS上运行"
    exit 1
fi

# 检查Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "[错误] 未找到Xcode，请安装Xcode"
    exit 1
fi

# 检查Flutter
if ! command -v flutter &> /dev/null; then
    echo "[错误] 未找到Flutter，请安装Flutter SDK"
    exit 1
fi

echo "[1/6] 进入Flutter项目目录..."
cd "$FLUTTER_APP_DIR"

echo "[2/6] 清理旧构建..."
flutter clean

echo "[3/6] 获取依赖..."
flutter pub get

echo "[4/6] 安装CocoaPods依赖..."
cd ios
pod install --repo-update
cd ..

echo "[5/6] 构建iOS Release版本..."
# 构建不签名的IPA (用于企业分发或Ad-Hoc)
flutter build ios --release --no-codesign

# 如果有开发者证书，使用以下命令构建签名版本:
# flutter build ipa --release

echo "[6/6] 导出IPA..."
cd ../..
mkdir -p "$OUTPUT_DIR"

# 创建未签名的.app归档
if [ -d "$FLUTTER_APP_DIR/build/ios/iphoneos/Runner.app" ]; then
    # 打包为zip
    cd "$FLUTTER_APP_DIR/build/ios/iphoneos"
    zip -r "../../../$OUTPUT_DIR/${APP_NAME}-iOS-${APP_VERSION}.app.zip" Runner.app
    cd ../../..
    echo "[成功] iOS应用已导出: $OUTPUT_DIR/${APP_NAME}-iOS-${APP_VERSION}.app.zip"
fi

# 如果使用 flutter build ipa，IPA会在这里:
if [ -f "$FLUTTER_APP_DIR/build/ios/ipa/sec_chat.ipa" ]; then
    cp "$FLUTTER_APP_DIR/build/ios/ipa/sec_chat.ipa" "$OUTPUT_DIR/${APP_NAME}-iOS-${APP_VERSION}.ipa"
    echo "[成功] IPA已导出: $OUTPUT_DIR/${APP_NAME}-iOS-${APP_VERSION}.ipa"
fi

echo ""
echo "============================================"
echo "  iOS构建完成!"
echo "============================================"
echo ""
echo "输出文件位置: $OUTPUT_DIR/"
echo ""
echo "注意事项:"
echo "  - 企业内部分发需要Apple企业开发者账号"
echo "  - 测试分发可使用TestFlight或Ad-Hoc描述文件"
echo "  - 正式签名需要配置ExportOptions.plist"
echo ""
