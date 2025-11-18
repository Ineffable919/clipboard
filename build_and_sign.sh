#!/bin/bash

# 自动化构建、打包和签名脚本
# 用于快速生成 Sparkle 更新包

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
echo -e "${BLUE}║   Sparkle 更新包构建和签名工具        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  $0 <版本号> [构建号]"
    echo ""
    echo -e "${YELLOW}示例:${NC}"
    echo "  $0 0.2.1 5"
    echo "  $0 0.3.0"
    echo ""
    exit 1
fi

VERSION=$1
BUILD=${2:-$(date +%s)}

echo -e "${GREEN}📦 构建配置${NC}"
echo "----------------------------------------"
echo "应用名称: $APP_NAME"
echo "版本号:   $VERSION"
echo "构建号:   $BUILD"
echo "配置:     $CONFIGURATION"
echo ""

# 检查私钥
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

# 查找 Xcode 项目
if [ ! -f "$APP_NAME.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ 错误: 未找到 Xcode 项目${NC}"
    exit 1
fi

# 步骤 1: 清理构建目录
echo -e "${BLUE}🧹 步骤 1/6: 清理构建目录...${NC}"
xcodebuild clean -scheme "$SCHEME" -configuration "$CONFIGURATION" > /dev/null 2>&1 || true
echo -e "${GREEN}✅ 清理完成${NC}"
echo ""

# 步骤 2: 构建应用
echo -e "${BLUE}🔨 步骤 2/6: 构建应用...${NC}"
echo "这可能需要几分钟..."

xcodebuild \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    clean build | grep -E '^(Build|=|❌|⚠️)' || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 构建完成${NC}"
echo ""

# 步骤 3: 查找构建产物
echo -e "${BLUE}🔍 步骤 3/6: 查找构建产物...${NC}"

# 查找 DerivedData 中的应用
DERIVED_DATA=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings | grep " BUILT_PRODUCTS_DIR" | sed 's/.*= //')

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
echo ""

# 步骤 4: 打包应用
echo -e "${BLUE}📦 步骤 4/6: 打包应用...${NC}"

ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="./$ZIP_NAME"

# 删除旧的 zip 文件
rm -f "$ZIP_PATH"

# 使用 ditto 打包（保留资源和元数据）
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

ZIP_SIZE=$(ls -l "$ZIP_PATH" | awk '{print $5}')

echo -e "${GREEN}✅ 打包完成: $ZIP_NAME${NC}"
echo "   大小: $ZIP_SIZE 字节 ($(numfmt --to=iec-i --suffix=B $ZIP_SIZE 2>/dev/null || echo 'N/A'))"
echo ""

# 步骤 5: 签名更新包
echo -e "${BLUE}🔐 步骤 5/6: 签名更新包...${NC}"

# 查找 sign_update 工具的多个可能位置
SIGN_UPDATE_TOOL=""

# 方法 1: 检查是否在 PATH 中
if command -v sign_update &> /dev/null; then
    SIGN_UPDATE_TOOL="sign_update"
    echo -e "${GREEN}✅ 找到系统安装的 sign_update${NC}"
else
    echo -e "${YELLOW}⚠️  系统 PATH 中未找到 sign_update${NC}"
    echo "正在搜索 Xcode DerivedData..."
    
    # 方法 2: 在 DerivedData 中查找 Sparkle artifacts
    SPARKLE_BIN=$(find ~/Library/Developer/Xcode/DerivedData -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -n 1)
    
    if [ -n "$SPARKLE_BIN" ] && [ -x "$SPARKLE_BIN" ]; then
        SIGN_UPDATE_TOOL="$SPARKLE_BIN"
        echo -e "${GREEN}✅ 找到 Sparkle artifacts 中的 sign_update${NC}"
        echo "   路径: $SPARKLE_BIN"
    else
        # 方法 3: 在 checkouts 中查找 Sparkle 源码
        SPARKLE_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Sparkle" -type d | grep "checkouts/Sparkle$" | head -n 1)
        
        if [ -n "$SPARKLE_PATH" ]; then
            echo -e "${YELLOW}尝试使用 Swift 运行 sign_update...${NC}"
            SIGNATURE=$(cd "$SPARKLE_PATH" && swift run sign_update "$ZIP_PATH" -f "$PRIVATE_KEY_PATH" 2>&1)
        else
            echo -e "${RED}❌ 错误: 无法找到签名工具${NC}"
            echo ""
            echo "请尝试以下方法之一："
            echo "  1. 安装 Sparkle 工具: brew install sparkle"
            echo "  2. 在 Xcode 中构建项目以下载 Sparkle"
            echo "  3. 手动指定 sign_update 路径"
            exit 1
        fi
    fi
fi

# 使用找到的工具进行签名
if [ -n "$SIGN_UPDATE_TOOL" ]; then
    SIGNATURE=$("$SIGN_UPDATE_TOOL" "$ZIP_PATH" -f "$PRIVATE_KEY_PATH" 2>&1)
fi

if [ -z "$SIGNATURE" ]; then
    echo -e "${RED}❌ 签名失败${NC}"
    echo "输出: $SIGNATURE"
    exit 1
fi

# 提取签名和文件大小
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="\([^"]*\)"/\1/')
SIGNATURE_LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | sed 's/length="\([^"]*\)"/\1/')

# 如果没有从输出中提取到文件大小，使用之前计算的
if [ -z "$SIGNATURE_LENGTH" ]; then
    SIGNATURE_LENGTH="$ZIP_SIZE"
fi

echo -e "${GREEN}✅ 签名完成${NC}"
echo ""

# 步骤 6: 生成 appcast 条目
echo -e "${BLUE}📝 步骤 6/6: 生成 appcast 条目...${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}📋 将以下内容添加到 appcast.xml:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat << EOF
    <item>
        <title>Version $VERSION</title>
        <description>
            <![CDATA[
                <h2>更新内容</h2>
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
        <enclosure 
            url="url="https://github.com/Ineffable919/clipboard/releases/download/v$VERSION/$ZIP_NAME"" 
            sparkle:edSignature="$ED_SIGNATURE"
            length="$SIGNATURE_LENGTH"
            type="application/octet-stream" />
    </item>
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 总结
echo -e "${GREEN}✅ 全部完成！${NC}"
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
echo "   2. 启动测试服务器: ./test_sparkle_local.sh"
echo "   3. 运行应用并点击「检查更新」"
echo ""

