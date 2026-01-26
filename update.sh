#!/bin/bash
#
# Gmail Skill - Updater
#
# Usage: ./update.sh [TARGET_DIR]
#
# This script updates ccskill-gmail in a project directory.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  Gmail Skill - Updater"
echo "================================================"
echo ""

# ========================================
# 1. 引数検証
# ========================================

TARGET_DIR="${1:-.}"

# 絶対パスに変換
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: TARGET_DIR does not exist: $TARGET_DIR${NC}"
    exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
echo "Updating in: $TARGET_DIR"
echo ""

# ========================================
# 2. 環境変数チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: CCSKILL_GMAIL_DIR is not set${NC}"
    echo ""
    echo "Please set the environment variable:"
    echo "  export CCSKILL_GMAIL_DIR=/path/to/ccskill-gmail"
    exit 1
fi

if [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: CCSKILL_GMAIL_DIR does not exist: $CCSKILL_GMAIL_DIR${NC}"
    exit 1
fi

# ========================================
# 3. インストール存在確認
# ========================================

SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
GAS_DIR="$TARGET_DIR/.ccskill-gmail"

if [ ! -d "$SKILL_DIR" ] || [ ! -d "$GAS_DIR" ]; then
    echo -e "${RED}Error: ccskill-gmail is not installed in this directory${NC}"
    echo ""
    echo "Please install first:"
    echo "  \$CCSKILL_GMAIL_DIR/install.sh"
    exit 1
fi

# ========================================
# 4. メタデータ読み込み
# ========================================

METADATA_FILE="$GAS_DIR/.ccskill-metadata.json"

CURRENT_VERSION="unknown"

if [ ! -f "$METADATA_FILE" ]; then
    echo -e "${YELLOW}Warning: Metadata file not found${NC}"
    echo "  Expected: $METADATA_FILE"
    echo ""
else
    if command -v jq &> /dev/null; then
        CURRENT_VERSION=$(jq -r '.version' "$METADATA_FILE" 2>/dev/null || echo "unknown")
    else
        # jq がない場合、grepで簡易的に取得
        CURRENT_VERSION=$(grep -o '"version": "[^"]*"' "$METADATA_FILE" | cut -d'"' -f4 || echo "unknown")
    fi
fi

# グローバルリポジトリのバージョン
GLOBAL_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "Current version: $CURRENT_VERSION"
echo "Latest version:  $GLOBAL_VERSION"
echo ""

# ========================================
# 5. バージョン比較
# ========================================

if [ "$CURRENT_VERSION" = "$GLOBAL_VERSION" ]; then
    echo -e "${GREEN}Already up to date${NC}"
    exit 0
fi

# 変更内容表示
if [ "$CURRENT_VERSION" != "unknown" ] && [ "$GLOBAL_VERSION" != "unknown" ]; then
    echo "Changes:"
    echo "--------"
    (cd "$CCSKILL_GMAIL_DIR" && git log --oneline "${CURRENT_VERSION}..${GLOBAL_VERSION}" 2>/dev/null) || echo "  (Unable to show changes)"
    echo ""
fi

# ========================================
# 6. 更新確認
# ========================================

read -p "Update ccskill-gmail? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Update cancelled."
    exit 0
fi

echo ""

# ========================================
# 7. スキル定義の更新
# ========================================

echo "Step 1: Updating skill definition..."

# スキル定義をコピー（referenceディレクトリも含む）
cp -r "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail/"* "$SKILL_DIR/"

# メタデータ更新
UPDATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
INSTALLED_AT="$UPDATE_TIME"

if [ -f "$METADATA_FILE" ]; then
    if command -v jq &> /dev/null; then
        INSTALLED_AT=$(jq -r '.installed_at' "$METADATA_FILE" 2>/dev/null || echo "$UPDATE_TIME")
    else
        INSTALLED_AT=$(grep -o '"installed_at": "[^"]*"' "$METADATA_FILE" | cut -d'"' -f4 || echo "$UPDATE_TIME")
    fi
fi

cat > "$METADATA_FILE" << EOF
{
  "installed_at": "$INSTALLED_AT",
  "updated_at": "$UPDATE_TIME",
  "installed_from": "$CCSKILL_GMAIL_DIR",
  "version": "$GLOBAL_VERSION"
}
EOF

echo -e "${GREEN}✓ Skill definition updated${NC}"
echo ""

# ========================================
# 8. GASコードの更新
# ========================================

echo "Step 2: Updating GAS code..."

# config.js を退避（存在する場合）
CONFIG_BACKUP=""
if [ -f "$GAS_DIR/src/config.js" ]; then
    CONFIG_BACKUP=$(mktemp)
    cp "$GAS_DIR/src/config.js" "$CONFIG_BACKUP"
fi

# GASコード更新
rm -rf "$GAS_DIR/src/"*
cp -r "$CCSKILL_GMAIL_DIR/gas-template/"* "$GAS_DIR/src/"

# .claspignore を GAS_DIR 直下にコピー
if [ -f "$CCSKILL_GMAIL_DIR/gas-template/.claspignore" ]; then
    cp "$CCSKILL_GMAIL_DIR/gas-template/.claspignore" "$GAS_DIR/.claspignore"
fi

# config.js 復元（存在した場合）
if [ -n "$CONFIG_BACKUP" ] && [ -f "$CONFIG_BACKUP" ]; then
    mv "$CONFIG_BACKUP" "$GAS_DIR/src/config.js"
fi

echo -e "${GREEN}✓ GAS code updated${NC}"
echo ""

# ========================================
# 9. clasp push
# ========================================

echo "Step 3: Pushing updated code to GAS..."

cd "$GAS_DIR"

if [ ! -f ".clasp.json" ]; then
    echo -e "${RED}Error: .clasp.json not found in $GAS_DIR${NC}"
    echo "The GAS project may not be properly configured."
    exit 1
fi

clasp push --force

echo -e "${GREEN}✓ Code pushed${NC}"
echo ""

# ========================================
# 完了メッセージ
# ========================================

echo "================================================"
echo -e "${GREEN}  Update Complete!${NC}"
echo "================================================"
echo ""
echo "Updated to version: $GLOBAL_VERSION"
echo "Updated at: $UPDATE_TIME"
echo ""
echo -e "${YELLOW}NOTE: If you added new APIs, you may need to create a new deployment${NC}"
echo "      in the GAS editor to make them available via the endpoint."
echo ""
echo "GAS Editor: https://script.google.com/"
echo ""
