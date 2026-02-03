#!/bin/bash

# 构建和打包脚本
# 用于构建应用并生成 DMG 安装包

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="Clipboard"
DISPLAY_NAME="Clip"
SCHEME="Clipboard"
CONFIGURATION="Release"
SIGNING_IDENTITY="1986443F6E94033C4968037932632037E550B7C2"
DEVELOPMENT_TEAM="40AB2EC9-58FF-4F06-B2AC-2DC16049A5B7"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      应用构建和打包工具                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

if [ $# -lt 1 ]; then
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  $0 <版本号> [构建号] [架构]"
    echo ""
    echo -e "${YELLOW}参数说明:${NC}"
    echo "  架构: arm64 | x86_64 | universal (默认: universal)"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $0 0.2.1 5 universal    # 构建通用版本"
    echo "  $0 0.2.1 5 arm64        # 只构建 Apple Silicon 版本"
    echo "  $0 0.2.1 5 x86_64       # 只构建 Intel 版本"
    echo "  $0 0.3.0                # 使用默认构建号和通用架构"
    echo ""
    exit 1
fi

VERSION=$1
BUILD=${2:-$(date +%s)}
ARCH=${3:-universal}

if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" && "$ARCH" != "universal" ]]; then
    echo -e "${RED}❌ 错误: 不支持的架构 '$ARCH'${NC}"
    echo "支持的架构: arm64, x86_64, universal"
    exit 1
fi

case "$ARCH" in
"arm64")
    BUILD_ARCHS="arm64"
    DESTINATION="platform=macOS,arch=arm64"
    ARCH_DESC="Apple Silicon (arm64)"
    ;;
"x86_64")
    BUILD_ARCHS="x86_64"
    DESTINATION="platform=macOS,arch=x86_64"
    ARCH_DESC="Intel (x86_64)"
    ;;
"universal")
    BUILD_ARCHS="arm64 x86_64"
    DESTINATION="generic/platform=macOS"
    ARCH_DESC="Universal (arm64 + x86_64)"
    ;;
esac

echo -e "${GREEN}📦 构建配置${NC}"
echo "----------------------------------------"
echo "版本号:   $VERSION"
echo "构建号:   $BUILD"
echo "架构:     $ARCH_DESC"
echo ""

echo -e "${BLUE}🧹 步骤 1/5: 清理构建目录...${NC}"
xcodebuild clean -scheme "$SCHEME" -configuration "$CONFIGURATION" >/dev/null 2>&1 || true
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

echo -e "${BLUE}🔨 步骤 2/5: 构建应用 ($ARCH_DESC)...${NC}"

xcodebuild -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath build \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    ARCHS="$BUILD_ARCHS" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    clean build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 构建完成${NC}"
echo ""

APP_PATH="build/Build/Products/$CONFIGURATION/$APP_NAME.app"

echo -e "${BLUE}🔐 步骤 3/5: 重新签名嵌入框架...${NC}"

SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "移除不需要的 Sparkle XPC Service..."
    DOWNLOADER_XPC="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
    if [ -d "$DOWNLOADER_XPC" ]; then
        rm -rf "$DOWNLOADER_XPC"
        echo "已移除 Downloader.xpc"
    fi
    
    echo "重新签名 Sparkle.framework..."
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$SPARKLE_FRAMEWORK"
fi

echo "重新签名应用..."
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_PATH"

echo "验证签名..."
if ! codesign -v "$APP_PATH"; then
    echo -e "${RED}❌ 签名验证失败${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 签名完成${NC}"
echo ""

echo -e "${BLUE}💿 步骤 4/5: 创建 DMG 安装包...${NC}"

if [ "$ARCH" = "universal" ]; then
    DMG_NAME="$DISPLAY_NAME-$VERSION.dmg"
else
    DMG_NAME="$DISPLAY_NAME-$VERSION-$ARCH.dmg"
fi
DMG_PATH="./$DMG_NAME"

rm -f "$DMG_PATH"

if command -v create-dmg &> /dev/null; then
    echo "使用 create-dmg 创建..."
    
    DMG_DIR=$(dirname "$DMG_PATH")
    mkdir -p "$DMG_DIR"
    
    # create-dmg 格式: create-dmg [options] <app> [destination]
    create-dmg --overwrite --skip-jenkins --no-code-sign --dmg-title="$DISPLAY_NAME $VERSION" "$APP_PATH" . 2>&1 | grep -v "Code signing failed" || true
    
    GENERATED_DMG=$(ls -t ${DISPLAY_NAME}*.dmg 2>/dev/null | head -n 1)
    if [ -n "$GENERATED_DMG" ] && [ "$GENERATED_DMG" != "$DMG_NAME" ]; then
        mv "$GENERATED_DMG" "$DMG_PATH"
    elif [ -n "$GENERATED_DMG" ]; then
        DMG_PATH="./$GENERATED_DMG"
    fi
else
    echo "未找到 create-dmg，使用 hdiutil..."
    DMG_TEMP_DIR="./dmg_temp"
    rm -rf "$DMG_TEMP_DIR"
    mkdir -p "$DMG_TEMP_DIR"
    
    cp -R "$APP_PATH" "$DMG_TEMP_DIR/"
    ln -s /Applications "$DMG_TEMP_DIR/Applications"
    
    hdiutil create \
        -volname "$DISPLAY_NAME $VERSION" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
    
    rm -rf "$DMG_TEMP_DIR"
fi

FILE_SIZE=$(ls -l "$DMG_PATH" | awk '{print $5}')

echo -e "${GREEN}✅ DMG 创建完成: $DMG_NAME${NC}"
echo "   大小: $FILE_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo 'N/A'))"
echo ""

echo -e "${BLUE}🧹 步骤 5/5: 清理临时文件...${NC}"
rm -rf ./dmg_temp
rm -rf ./build
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

echo -e "${GREEN}✅ 构建完成！${NC}"
echo ""
echo -e "${BLUE}📦 生成的文件:${NC}"
echo "   文件名: $DMG_NAME"
echo "   路径:   $DMG_PATH"
echo "   架构:   $ARCH_DESC"
echo "   大小:   $DMG_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $DMG_SIZE 2>/dev/null || echo 'N/A'))"
echo ""
