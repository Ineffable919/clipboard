#!/bin/bash

# 构建和打包脚本
# 用于构建应用并生成 DMG 安装包

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}📂 项目根目录: $PROJECT_ROOT${NC}"
echo ""

# 配置
APP_NAME="Clipboard"      # 项目/Target 名称（.app 文件名）
DISPLAY_NAME="Clip"       # 显示名称（DMG 文件名使用）
SCHEME="Clipboard"
CONFIGURATION="Release"

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
    DESTINATION="platform=macOS,name=Any Mac"
    ARCH_DESC="Universal (arm64 + x86_64)"
    ;;
esac

echo -e "${GREEN}📦 构建配置${NC}"
echo "----------------------------------------"
echo "应用名称: $APP_NAME"
echo "版本号:   $VERSION"
echo "构建号:   $BUILD"
echo "架构:     $ARCH_DESC"
echo "配置:     $CONFIGURATION"
echo ""

if [ ! -f "$APP_NAME.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ 错误: 未找到 Xcode 项目${NC}"
    exit 1
fi

XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
if [[ "$XCODE_PATH" == *"CommandLineTools"* ]] || [ -z "$XCODE_PATH" ]; then
    echo -e "${YELLOW}⚠️  检测到使用命令行工具,尝试切换到 Xcode.app...${NC}"

    if [ -d "/Applications/Xcode.app" ]; then
        echo "找到 Xcode.app,正在切换..."
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
        echo -e "${GREEN}✅ 已切换到 Xcode.app${NC}"
        echo ""
    else
        echo -e "${RED}❌ 错误: 未找到 Xcode.app${NC}"
        echo "请安装 Xcode 或在 Xcode 中手动构建项目"
        exit 1
    fi
fi

echo -e "${BLUE}🧹 步骤 1/5: 清理构建目录...${NC}"
xcodebuild clean -scheme "$SCHEME" -configuration "$CONFIGURATION" >/dev/null 2>&1 || true
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

echo -e "${BLUE}🔨 步骤 2/5: 构建应用 ($ARCH_DESC)...${NC}"
echo "这可能需要几分钟..."

xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    ARCHS="$BUILD_ARCHS" \
    ONLY_ACTIVE_ARCH=NO \
    clean build | grep -E '^(Build|=|❌|⚠️)' || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 构建完成${NC}"
echo ""

echo -e "${BLUE}🔍 步骤 3/5: 查找构建产物...${NC}"

DERIVED_DATA=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "$DESTINATION" -showBuildSettings | grep " BUILT_PRODUCTS_DIR" | sed 's/.*= //')

if [ -z "$DERIVED_DATA" ]; then
    echo -e "${RED}❌ 错误: 未找到构建目录${NC}"
    exit 1
fi

APP_PATH="$DERIVED_DATA/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ 错误: 未找到应用: $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 找到应用: $APP_PATH${NC}"

# 验证构建的架构
if [ -f "$APP_PATH/Contents/MacOS/$APP_NAME" ]; then
    BUILT_ARCHS=$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || echo "未知")
    echo "实际构建架构: $BUILT_ARCHS"
fi
echo ""

# 移除 Sparkle Downloader XPC Service（沙盒应用不需要）
echo -e "${BLUE}🗑️  移除不需要的 Sparkle XPC Service...${NC}"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
DOWNLOADER_XPC="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"

if [ -d "$SPARKLE_FRAMEWORK" ]; then
    if [ -e "$DOWNLOADER_XPC" ]; then
        echo "移除 Downloader XPC Service: $DOWNLOADER_XPC"
        rm -rf "$DOWNLOADER_XPC"
        echo -e "${GREEN}✅ Downloader XPC Service 已移除${NC}"
    else
        echo -e "${YELLOW}⚠️  Downloader XPC Service 不存在，跳过${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  未找到 Sparkle.framework，跳过 XPC 移除${NC}"
fi
echo ""

echo -e "${BLUE}🔐 步骤 4/5: 重新签名应用...${NC}"

xattr -cr "$APP_PATH" 2>/dev/null || true

ENTITLEMENTS_PATH=""
for path in "./Clipboard/Clipboard.entitlements" "./Clipboard.entitlements" "./entitlements.plist"; do
    if [ -f "$path" ]; then
        if grep -q "com.apple.security.app-sandbox" "$path"; then
            ENTITLEMENTS_PATH="$path"
            echo "使用本地 entitlements: $ENTITLEMENTS_PATH"
            break
        else
            echo -e "${YELLOW}⚠️  $path 缺少沙盒配置，跳过${NC}"
        fi
    fi
done

if [ -z "$ENTITLEMENTS_PATH" ]; then
    EXTRACTED_ENTITLEMENTS="/tmp/${APP_NAME}_entitlements.plist"
    if codesign -d --entitlements :"$EXTRACTED_ENTITLEMENTS" "$APP_PATH" 2>/dev/null; then
        if [ -s "$EXTRACTED_ENTITLEMENTS" ] && grep -q "com.apple.security.app-sandbox" "$EXTRACTED_ENTITLEMENTS" 2>/dev/null; then
            echo "从构建产物提取 entitlements 成功"
            ENTITLEMENTS_PATH="$EXTRACTED_ENTITLEMENTS"
        else
            echo -e "${YELLOW}⚠️  提取的 entitlements 不包含沙盒配置${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  无法从构建产物提取 entitlements${NC}"
    fi
fi

# 签名应用
if [ -n "$ENTITLEMENTS_PATH" ] && [ -f "$ENTITLEMENTS_PATH" ]; then
    echo "使用 entitlements 重签名..."
    codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS_PATH" \
        --timestamp=none \
        "$APP_PATH"
    echo -e "${GREEN}✅ 使用 entitlements 签名成功（沙盒已启用）${NC}"
else
    echo -e "${RED}❌ 错误: 未找到有效的 entitlements 文件，无法启用沙盒${NC}"
    echo "请确保 Clipboard/Clipboard.entitlements 文件存在且包含 com.apple.security.app-sandbox"
    exit 1
fi

rm -f "/tmp/${APP_NAME}_entitlements.plist" 2>/dev/null

if codesign --verify --verbose "$APP_PATH" 2>&1; then
    echo -e "${GREEN}✅ 应用签名完成并验证通过${NC}"
else
    echo -e "${YELLOW}⚠️  签名验证警告，但继续执行${NC}"
fi
echo ""

echo -e "${BLUE}💿 步骤 5/5: 创建 DMG 安装包...${NC}"

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

DMG_SIZE=$(ls -l "$DMG_PATH" | awk '{print $5}')

echo -e "${GREEN}✅ DMG 创建完成: $DMG_NAME${NC}"
echo "   大小: $DMG_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $DMG_SIZE 2>/dev/null || echo 'N/A'))"
echo ""

echo -e "${GREEN}✅ 构建完成！${NC}"
echo ""
echo -e "${BLUE}📦 生成的文件:${NC}"
echo "   文件名: $DMG_NAME"
echo "   路径:   $DMG_PATH"
echo "   架构:   $ARCH_DESC"
echo "   大小:   $DMG_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $DMG_SIZE 2>/dev/null || echo 'N/A'))"
echo ""
