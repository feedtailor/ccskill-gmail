#!/bin/bash
#
# Gmail Skill - Updater
#
# Usage: ccskill-gmail update [--force|-f] [--yes|-y] [TARGET_DIR]
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

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail update'"
    exit 1
fi

# フラグのパース
AUTO_YES=false
FORCE=false
TARGET_DIR="."

for arg in "$@"; do
    case "$arg" in
        --yes|-y)
            AUTO_YES=true
            ;;
        --force|-f)
            FORCE=true
            ;;
        *)
            TARGET_DIR="$arg"
            ;;
    esac
done

# 絶対パスに変換
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: TARGET_DIR does not exist: $TARGET_DIR${NC}"
    exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
echo "Updating in: $TARGET_DIR"
echo ""

# ========================================
# 2. ヘルパーロード
# ========================================

source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
source "$CCSKILL_GMAIL_DIR/lib/permissions.sh"

# ========================================
# 3. インストール存在確認
# ========================================

SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
GAS_DIR="$TARGET_DIR/.ccskill-gmail"

if [ ! -d "$SKILL_DIR" ] || [ ! -d "$GAS_DIR" ]; then
    echo -e "${RED}Error: ccskill-gmail is not installed in this directory${NC}"
    echo ""
    echo "Please install first:"
    echo "  ccskill-gmail install"
    exit 1
fi

# ========================================
# 4. メタデータ読み込み
# ========================================

# 新しいメタデータ配置場所
METADATA_FILE="$GAS_DIR/.ccskill-metadata.json"
# 旧メタデータ配置場所（src/ 内）
OLD_METADATA_FILE="$GAS_DIR/src/.ccskill-metadata.json"

# 旧メタデータファイルの移行処理
if [ ! -f "$METADATA_FILE" ] && [ -f "$OLD_METADATA_FILE" ]; then
    echo -e "${YELLOW}Migrating metadata file to new location...${NC}"
    /bin/cp "$OLD_METADATA_FILE" "$METADATA_FILE"
    echo -e "${GREEN}✓ Metadata migrated${NC}"
    echo ""
fi

CURRENT_VERSION="unknown"
CLASP_USER=""

if [ ! -f "$METADATA_FILE" ]; then
    echo -e "${YELLOW}Warning: Metadata file not found${NC}"
    echo "  Expected: $METADATA_FILE"
    echo ""
else
    if command -v jq &> /dev/null; then
        CURRENT_VERSION=$(jq -r '.version' "$METADATA_FILE" 2>/dev/null || echo "unknown")
        CLASP_USER=$(jq -r '.clasp_user // empty' "$METADATA_FILE" 2>/dev/null)
    else
        CURRENT_VERSION=$(grep -o '"version": "[^"]*"' "$METADATA_FILE" | cut -d'"' -f4 || echo "unknown")
    fi
fi

# グローバルリポジトリのバージョン
if [ -f "$CCSKILL_GMAIL_DIR/VERSION" ]; then
    GLOBAL_VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
else
    GLOBAL_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

echo "Current version: $CURRENT_VERSION"
echo "Latest version:  $GLOBAL_VERSION"
if [ "$FORCE" = true ]; then
    echo -e "${YELLOW}Force mode: skipping version check${NC}"
fi
echo ""

# ========================================
# 5. バージョン比較
# ========================================

# マイグレーション要否チェック
NEEDS_MIGRATION=false
if [ -d "$GAS_DIR/src" ]; then
    NEEDS_MIGRATION=true
fi

if [ "$CURRENT_VERSION" = "$GLOBAL_VERSION" ] && [ "$NEEDS_MIGRATION" = false ] && [ "$FORCE" = false ]; then
    echo -e "${GREEN}Already up to date${NC}"
    exit 0
fi

# 変更内容表示（git がある場合のみ）
if [ "$CURRENT_VERSION" != "unknown" ] && [ "$GLOBAL_VERSION" != "unknown" ] && [ -d "$CCSKILL_GMAIL_DIR/.git" ]; then
    TOTAL_COMMITS=$(cd "$CCSKILL_GMAIL_DIR" && git rev-list --count "${CURRENT_VERSION}..${GLOBAL_VERSION}" 2>/dev/null || echo "0")
    echo "Changes ($TOTAL_COMMITS commits):"
    echo "--------"
    (cd "$CCSKILL_GMAIL_DIR" && git --no-pager log --format="  %cd  %s" --date=short "${CURRENT_VERSION}..${GLOBAL_VERSION}" 2>/dev/null) || echo "  (Unable to show changes)"
    echo ""
fi

# ========================================
# 6. 更新確認
# ========================================

if [ "$AUTO_YES" = true ]; then
    echo "Auto-confirmed (--yes flag)"
else
    read -p "Update ccskill-gmail? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Update cancelled."
        exit 0
    fi
fi

echo ""

# ========================================
# 7. スキル定義の更新
# ========================================

echo "Step 1: Updating skill definition..."

# ソースとターゲットが同一ディレクトリの場合はスキップ
SRC_SKILL_DIR=$(cd "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" 2>/dev/null && pwd)
DST_SKILL_DIR=$(cd "$SKILL_DIR" 2>/dev/null && pwd)

if [ "$SRC_SKILL_DIR" = "$DST_SKILL_DIR" ]; then
    echo -e "${YELLOW}Skipping skill definition copy (source and target are the same)${NC}"
else
    # メタデータ以外をコピー
    find "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" -type f ! -name '.ccskill-metadata.json' | while read file; do
        filename=$(basename "$file")
        cp "$file" "$SKILL_DIR/$filename"
    done
fi

# api スクリプトを更新
if [ -f "$CCSKILL_GMAIL_DIR/lib/api" ]; then
    /bin/cp "$CCSKILL_GMAIL_DIR/lib/api" "$GAS_DIR/api"
    chmod +x "$GAS_DIR/api"
fi

# ディレクトリ保護
chmod 700 "$GAS_DIR" 2>/dev/null || true

# ---- 旧形式からの移行 ----

# endpoint ファイル → .ccskill-metadata.json に統合
if [ -f "$GAS_DIR/endpoint" ]; then
    _endpoint_val=$(tr -d '[:space:]' < "$GAS_DIR/endpoint")
    if [ -n "$_endpoint_val" ] && [ -f "$GAS_DIR/.ccskill-metadata.json" ]; then
        _has_endpoint=$(jq -r '.endpoint // ""' "$GAS_DIR/.ccskill-metadata.json" 2>/dev/null)
        if [ -z "$_has_endpoint" ]; then
            tmp=$(mktemp)
            jq --arg ep "$_endpoint_val" '. + {endpoint: $ep}' "$GAS_DIR/.ccskill-metadata.json" > "$tmp" && mv "$tmp" "$GAS_DIR/.ccskill-metadata.json"
            echo -e "${GREEN}✓ Migrated endpoint to .ccskill-metadata.json${NC}"
        fi
    fi
    rm -f "$GAS_DIR/endpoint"
fi

# 旧コピーファイルを削除（マスター参照方式に移行）
for _legacy_file in auth.sh history.sh api.sh; do
    if [ -f "$GAS_DIR/$_legacy_file" ]; then
        rm -f "$GAS_DIR/$_legacy_file"
        echo -e "${YELLOW}Removed legacy $_legacy_file${NC}"
    fi
done

echo -e "${GREEN}✓ Skill definition and helpers updated${NC}"
echo ""

# ========================================
# 8. Master Architecture マイグレーション
# ========================================

echo "Step 2: Checking architecture..."

if [ -d "$GAS_DIR/src" ]; then
    echo -e "${YELLOW}Migrating from legacy (src/) to master architecture...${NC}"

    # .clasp.json を src/ の外に移動
    if [ -f "$GAS_DIR/src/.clasp.json" ]; then
        /bin/cp "$GAS_DIR/src/.clasp.json" "$GAS_DIR/.clasp.json"
        echo "  Moved src/.clasp.json -> .clasp.json"
    elif [ -f "$GAS_DIR/.clasp.json" ] && command -v jq &> /dev/null; then
        # rootDir を更新
        tmp=$(mktemp)
        jq '.rootDir = "."' "$GAS_DIR/.clasp.json" > "$tmp"
        mv "$tmp" "$GAS_DIR/.clasp.json"
        echo "  Updated .clasp.json rootDir to \".\""
    fi

    # config.js を保護して移動
    if [ -f "$GAS_DIR/src/config.js" ]; then
        /bin/cp "$GAS_DIR/src/config.js" "$GAS_DIR/config.js"
        echo "  Moved src/config.js -> config.js"
    fi

    # src/ ディレクトリを削除
    rm -rf "$GAS_DIR/src"
    echo "  Removed src/ directory"

    # .claspignore を削除（push_gas が一時ディレクトリに配置する）
    rm -f "$GAS_DIR/.claspignore"

    echo -e "${GREEN}✓ Migration to master architecture complete${NC}"
    echo ""
fi

# config.js が存在するか確認
if [ ! -f "$GAS_DIR/config.js" ]; then
    echo -e "${RED}Error: config.js not found in $GAS_DIR${NC}"
    echo "The installation may be corrupted. Please reinstall."
    exit 1
fi

echo -e "${GREEN}✓ Architecture check passed${NC}"
echo ""

# ========================================
# 9. clasp push（push_gas 使用）
# ========================================

echo "Step 3: Pushing updated code to GAS..."

if [ ! -f "$GAS_DIR/.clasp.json" ]; then
    echo -e "${RED}Error: .clasp.json not found in $GAS_DIR${NC}"
    echo "The GAS project may not be properly configured."
    exit 1
fi

push_gas "$GAS_DIR" "$CCSKILL_GMAIL_DIR"

echo -e "${GREEN}✓ Code pushed${NC}"
echo ""

# ========================================
# 10. 自動デプロイ更新
# ========================================

DEPLOYMENT_ID=""
if [ -f "$METADATA_FILE" ] && command -v jq &> /dev/null; then
    DEPLOYMENT_ID=$(jq -r '.deployment_id // empty' "$METADATA_FILE" 2>/dev/null)
fi

if [ -n "$DEPLOYMENT_ID" ]; then
    echo "Step 4: Updating deployment..."
    if deploy_gas "$GAS_DIR" "$DEPLOYMENT_ID" "Update to $GLOBAL_VERSION"; then
        echo -e "${GREEN}✓ Deployment updated${NC}"
    else
        echo -e "${YELLOW}Warning: Auto-deploy failed. You may need to update manually.${NC}"
    fi
else
    echo -e "${YELLOW}No deployment_id in metadata. Manual deployment update required.${NC}"
    echo "  This installation was created before auto-deploy support."
    echo ""
    echo "  To update manually:"
    echo "    1. Deploy > Manage deployments"
    echo "    2. Edit > Version: 'New version' > Deploy"
    # GAS エディタ URL を表示
    SCRIPT_ID=$(jq -r '.scriptId' "$GAS_DIR/.clasp.json" 2>/dev/null)
    if [ -n "$SCRIPT_ID" ] && [ "$SCRIPT_ID" != "null" ]; then
        echo ""
        echo -e "  GAS Editor: ${BLUE}https://script.google.com/d/${SCRIPT_ID}/edit${NC}"
    fi
fi

echo ""

# ========================================
# 11. メタデータ更新
# ========================================

UPDATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
INSTALLED_AT="$UPDATE_TIME"

if [ -f "$METADATA_FILE" ]; then
    if command -v jq &> /dev/null; then
        INSTALLED_AT=$(jq -r '.installed_at' "$METADATA_FILE" 2>/dev/null || echo "$UPDATE_TIME")
    else
        INSTALLED_AT=$(grep -o '"installed_at": "[^"]*"' "$METADATA_FILE" | cut -d'"' -f4 || echo "$UPDATE_TIME")
    fi
fi

if command -v jq &> /dev/null; then
    # 既存フィールドを保持しつつ version, updated_at, architecture を更新
    tmp=$(mktemp)
    jq --arg version "$GLOBAL_VERSION" \
       --arg updated_at "$UPDATE_TIME" \
       --arg architecture "master" \
       --arg installed_from "$CCSKILL_GMAIL_DIR" \
       '.version = $version | .updated_at = $updated_at | .architecture = $architecture | .installed_from = $installed_from' \
       "$METADATA_FILE" > "$tmp"
    /bin/mv "$tmp" "$METADATA_FILE"
else
    # jq がない場合のフォールバック
    cat > "$METADATA_FILE" << EOF
{
  "installed_at": "$INSTALLED_AT",
  "updated_at": "$UPDATE_TIME",
  "installed_from": "$CCSKILL_GMAIL_DIR",
  "version": "$GLOBAL_VERSION",
  "architecture": "master"
}
EOF
fi

echo -e "${GREEN}✓ Metadata updated${NC}"
echo ""

# ========================================
# 12. 許可パターンの確認
# ========================================

if [ "$AUTO_YES" = true ]; then
    setup_permissions "$TARGET_DIR" "--yes"
else
    setup_permissions "$TARGET_DIR"
fi

# ========================================
# 13. レジストリ更新
# ========================================

registry_upsert "$TARGET_DIR"

# ========================================
# 完了メッセージ
# ========================================

echo ""
echo "================================================"
echo -e "${GREEN}  Update Complete!${NC}"
echo "================================================"
echo ""
echo "Updated to version: $GLOBAL_VERSION"
echo "Updated at: $UPDATE_TIME"
echo ""
echo "Your ccskill-gmail is now up to date."
echo ""
