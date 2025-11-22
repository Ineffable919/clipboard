#!/bin/bash

# Sparkle 更新包签名脚本
# 为已构建的应用生成 Sparkle 更新签名

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="Clipboard"
SCHEME="Clipboard"
CONFIGURATION="Release"
PRIVATE_KEY_PATH="$HOME/.sparkle_private_key"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Sparkle 更新包签名工具              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  $0 <版本号> [构建号] [架构]"
    echo ""
    echo -e "${YELLOW}参数说明:${NC}"
    echo "  架构: arm64 | x86_64 | universal (默认: universal)"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $0 0.2.1 5 universal    # 签名通用版本"
    echo "  $0 0.2.1 5 arm64        # 签名 Apple Silicon 版本"
    echo "  $0 0.2.1 5 x86_64       # 签名 Intel 版本"
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
    DESTINATION="platform=macOS,arch=arm64"
    ARCH_DESC="Apple Silicon (arm64)"
    ARCH_SUFFIX="-arm64"
    ARCH_TAG="arm64"
    ;;
"x86_64")
    DESTINATION="platform=macOS,arch=x86_64"
    ARCH_DESC="Intel (x86_64)"
    ARCH_SUFFIX="-x86_64"
    ARCH_TAG="x86_64"
    ;;
"universal")
    DESTINATION="platform=macOS,name=Any Mac"
    ARCH_DESC="Universal (arm64 + x86_64)"
    ARCH_SUFFIX=""
    ARCH_TAG=""
    ;;
esac

echo -e "${GREEN}📦 签名配置${NC}"
echo "----------------------------------------"
echo "应用名称: $APP_NAME"
echo "版本号:   $VERSION"
echo "构建号:   $BUILD"
echo "架构:     $ARCH_DESC"
echo ""

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo -e "${RED}❌ 错误: 未找到私钥文件${NC}"
    echo "请先生成 Sparkle 密钥并保存到: $PRIVATE_KEY_PATH"
    echo ""
    echo "运行以下命令生成密钥:"
    echo "  ./generate_sparkle_keys.sh"
    exit 1
fi

echo -e "${GREEN}✅ 找到私钥文件${NC}"
echo ""

echo -e "${BLUE}🔍 步骤 1/3: 查找构建产物...${NC}"

DERIVED_DATA=$(xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" -configuration "$CONFIGURATION" -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | sed 's/.*= //')

if [ -z "$DERIVED_DATA" ]; then
    echo -e "${RED}❌ 错误: 未找到构建目录${NC}"
    echo "请先运行 ./build.sh $VERSION 构建应用"
    exit 1
fi

APP_PATH="$DERIVED_DATA/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ 错误: 未找到应用: $APP_PATH${NC}"
    echo "请先运行 ./build.sh $VERSION 构建应用"
    exit 1
fi

echo -e "${GREEN}✅ 找到应用: $APP_PATH${NC}"
echo ""

echo -e "${BLUE}📦 步骤 2/3: 打包 ZIP 更新包...${NC}"

ZIP_NAME="$APP_NAME-$VERSION$ARCH_SUFFIX.zip"
ZIP_PATH="./$ZIP_NAME"

rm -f "$ZIP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

ZIP_SIZE=$(ls -l "$ZIP_PATH" | awk '{print $5}')

echo -e "${GREEN}✅ ZIP 打包完成: $ZIP_NAME${NC}"
echo "   大小: $ZIP_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $ZIP_SIZE 2>/dev/null || echo 'N/A'))"
echo ""

echo -e "${BLUE}🔐 步骤 3/3: 签名更新包...${NC}"

SIGN_UPDATE_TOOL=""

SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -n 1)

if [ -n "$SPARKLE_BIN" ] && [ -x "$SPARKLE_BIN" ]; then
    SIGN_UPDATE_TOOL="$SPARKLE_BIN"
    echo -e "${GREEN}✅ 找到 Sparkle artifacts 中的 sign_update${NC}"
    echo "   路径: $SPARKLE_BIN"
else
    echo -e "${RED}❌ 错误: 无法找到签名工具${NC}"
    exit 1
fi

if [ -n "$SIGN_UPDATE_TOOL" ]; then
    SIGNATURE=$("$SIGN_UPDATE_TOOL" "$ZIP_PATH" -f "$PRIVATE_KEY_PATH" 2>&1)
fi

if [ -z "$SIGNATURE" ]; then
    echo -e "${RED}❌ 签名失败${NC}"
    echo "输出: $SIGNATURE"
    exit 1
fi

ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="\([^"]*\)"/\1/')
SIGNATURE_LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | sed 's/length="\([^"]*\)"/\1/')

if [ -z "$SIGNATURE_LENGTH" ]; then
    SIGNATURE_LENGTH="$ZIP_SIZE"
fi

echo -e "${GREEN}✅ 签名完成${NC}"
echo ""

echo -e "${BLUE}📝 生成 appcast 条目...${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}📋 将以下内容添加到 appcast.xml:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<EOF
    <item>
        <title>Version $VERSION ($ARCH_DESC)</title>
        <description>
            <![CDATA[
                <h4>更新内容</h4>
                <ul>
                    <li>新功能和改进</li>
                    <li>修复了一些问题</li>
                </ul>
            ]]>
        </description>
        <pubDate>$(date -R)</pubDate>
        <sparkle:version>$BUILD</sparkle:version>
        <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
EOF

if [ -n "$ARCH_TAG" ]; then
    echo "        <sparkle:tags>"
    echo "            <sparkle:criticalUpdate sparkle:osType=\"$ARCH_TAG\" />"
    echo "        </sparkle:tags>"
fi

cat <<EOF
        <enclosure 
            url="https://github.com/Ineffable919/clipboard/releases/download/$VERSION/$ZIP_NAME" 
            sparkle:edSignature="$ED_SIGNATURE"
            length="$SIGNATURE_LENGTH"
            type="application/octet-stream" />
    </item>
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${GREEN}✅ 签名完成！${NC}"
echo ""
echo -e "${BLUE}📦 生成的文件:${NC}"
echo "   文件名: $ZIP_NAME"
echo "   路径:   $ZIP_PATH"
echo "   大小:   $SIGNATURE_LENGTH 字节"
echo ""
echo -e "${BLUE}🔐 签名信息:${NC}"
echo "   sparkle:edSignature=\"$ED_SIGNATURE\""
echo "   length=\"$SIGNATURE_LENGTH\""
echo ""
if [ -n "$SIGN_UPDATE_TOOL" ] && [ "$SIGN_UPDATE_TOOL" != "sign_update" ]; then
    echo -e "${BLUE}🔧 使用的签名工具:${NC}"
    echo "   $SIGN_UPDATE_TOOL"
    echo ""
fi
echo -e "${BLUE}📝 下一步:${NC}"
echo "   1. 更新 appcast.xml（复制上面的 <item> 内容）"
echo "   2. 上传 $ZIP_NAME 到 GitHub Releases"
echo ""
