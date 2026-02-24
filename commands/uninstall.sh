#!/bin/bash
#
# Gmail Skill - Uninstaller
#
# Usage: ccskill-gmail uninstall [--yes|-y] [TARGET_DIR]
#
# This script uninstalls ccskill-gmail from a project directory.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  Gmail Skill - Uninstaller"
echo "================================================"
echo ""

# ========================================
# 1. 引数検証
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail uninstall'"
    exit 1
fi

# フラグのパース
AUTO_YES=false
TARGET_DIR="."

for arg in "$@"; do
    case "$arg" in
        --yes|-y)
            AUTO_YES=true
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
echo "Uninstalling from: $TARGET_DIR"
echo ""

# ========================================
# 2. レジストリヘルパーロード
# ========================================

source "$CCSKILL_GMAIL_DIR/lib/registry.sh"

# ========================================
# 3. インストール存在確認
# ========================================

SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
GAS_DIR="$TARGET_DIR/.ccskill-gmail"

if [ ! -d "$SKILL_DIR" ] && [ ! -d "$GAS_DIR" ]; then
    echo -e "${RED}Error: ccskill-gmail is not installed in this directory${NC}"
    echo ""
    echo "Nothing to uninstall."
    exit 1
fi

echo "Found installation:"
if [ -d "$SKILL_DIR" ]; then
    echo "  - $SKILL_DIR"
fi
if [ -d "$GAS_DIR" ]; then
    echo "  - $GAS_DIR"
fi
echo ""

# ========================================
# 4. GASプロジェクトID取得
# ========================================

GAS_PROJECT_ID=""
GAS_PROJECT_NAME=""
METADATA_FILE="$GAS_DIR/.ccskill-metadata.json"

# メタデータからプロジェクト名を取得
if [ -f "$METADATA_FILE" ]; then
    if command -v jq &> /dev/null; then
        GAS_PROJECT_NAME=$(jq -r '.project_name // empty' "$METADATA_FILE" 2>/dev/null)
    else
        GAS_PROJECT_NAME=$(grep -o '"project_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$METADATA_FILE" | sed 's/.*"\([^"]*\)".*/\1/')
    fi
fi

# Script ID の取得（.clasp.json の場所がアーキテクチャにより異なる）
if [ -f "$GAS_DIR/.clasp.json" ]; then
    if command -v jq &> /dev/null; then
        GAS_PROJECT_ID=$(jq -r '.scriptId // empty' "$GAS_DIR/.clasp.json" 2>/dev/null)
    else
        GAS_PROJECT_ID=$(grep -o '"scriptId"[[:space:]]*:[[:space:]]*"[^"]*"' "$GAS_DIR/.clasp.json" | sed 's/.*"\([^"]*\)".*/\1/')
    fi
elif [ -f "$GAS_DIR/src/.clasp.json" ]; then
    if command -v jq &> /dev/null; then
        GAS_PROJECT_ID=$(jq -r '.scriptId // empty' "$GAS_DIR/src/.clasp.json" 2>/dev/null)
    else
        GAS_PROJECT_ID=$(grep -o '"scriptId"[[:space:]]*:[[:space:]]*"[^"]*"' "$GAS_DIR/src/.clasp.json" | sed 's/.*"\([^"]*\)".*/\1/')
    fi
fi

if [ -z "$GAS_PROJECT_ID" ]; then
    echo -e "${YELLOW}Warning: Cannot retrieve GAS Project ID${NC}"
    echo "  .clasp.json not found or scriptId is missing"
    echo ""
fi

# ========================================
# 5. 確認プロンプト
# ========================================

echo "================================================"
echo "  Confirm Uninstallation"
echo "================================================"
echo ""
echo "The following will be deleted:"
echo "  - .claude/skills/ccskill-gmail/"
echo "  - .ccskill-gmail/"
echo "  - GMAIL_ENDPOINT entry in .env"
echo ""

if [ -n "$GAS_PROJECT_ID" ]; then
    if [ -n "$GAS_PROJECT_NAME" ]; then
        echo -e "${YELLOW}GAS Project: Gmail Skill - $GAS_PROJECT_NAME${NC}"
    fi
    echo -e "${YELLOW}GAS Project ID: $GAS_PROJECT_ID${NC}"
    echo "(You will need to manually delete this from script.google.com)"
    echo ""
fi

if [ "$AUTO_YES" = true ]; then
    echo "Auto-confirmed (--yes flag)"
else
    read -p "Are you sure you want to uninstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
fi
echo ""

# ========================================
# 6. ローカルファイル削除
# ========================================

echo "Removing local files..."
echo ""

if [ -d "$SKILL_DIR" ]; then
    echo "  Removing $SKILL_DIR"
    rm -rf "$SKILL_DIR"
    echo -e "${GREEN}✓ Skill definition removed${NC}"
fi

# Codex シンボリックリンクの削除
CODEX_SYMLINK="$TARGET_DIR/.codex/skills/ccskill-gmail"
if [ -L "$CODEX_SYMLINK" ]; then
    echo "  Removing Codex symlink: $CODEX_SYMLINK"
    rm -f "$CODEX_SYMLINK"
    echo -e "${GREEN}✓ Codex symlink removed${NC}"
fi

if [ -d "$GAS_DIR" ]; then
    echo "  Removing $GAS_DIR"
    rm -rf "$GAS_DIR"
    echo -e "${GREEN}✓ GAS code removed${NC}"
fi

echo ""

# ========================================
# 7. .env 編集
# ========================================

ENV_FILE="$TARGET_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "Removing GMAIL_ENDPOINT from .env..."

    if grep -q "GMAIL_ENDPOINT" "$ENV_FILE"; then
        # 一時ファイルに書き出し
        TMP_FILE=$(mktemp)

        # GMAIL_ENDPOINT エントリとその前のコメント行を削除
        awk '
        /^# Gmail Skill$/ {
            comment_line = $0
            getline
            if ($0 !~ /^GMAIL_ENDPOINT=/) {
                print comment_line
                print $0
            }
            next
        }
        /^GMAIL_ENDPOINT=/ {
            next
        }
        {
            print
        }
        ' "$ENV_FILE" > "$TMP_FILE"

        mv "$TMP_FILE" "$ENV_FILE"
        echo -e "${GREEN}✓ GMAIL_ENDPOINT removed from .env${NC}"
    else
        echo "  GMAIL_ENDPOINT entry not found in .env"
    fi

    echo ""
else
    echo -e "${YELLOW}.env file not found, skipping${NC}"
    echo ""
fi

# ========================================
# 8. レジストリからエントリ削除
# ========================================

registry_remove "$TARGET_DIR"
echo -e "${GREEN}✓ Registry entry removed${NC}"
echo ""

# ========================================
# 9. GASプロジェクト削除ガイダンス
# ========================================

if [ -n "$GAS_PROJECT_ID" ]; then
    echo "================================================"
    echo "  Manual GAS Project Deletion Required"
    echo "================================================"
    echo ""
    if [ -n "$GAS_PROJECT_NAME" ]; then
        echo -e "${YELLOW}GAS Project Name: Gmail Skill - $GAS_PROJECT_NAME${NC}"
    fi
    echo -e "${YELLOW}GAS Project ID: $GAS_PROJECT_ID${NC}"
    echo ""
    echo "To completely remove the skill, delete the GAS project:"
    echo ""
    echo -e "  1. Open: ${BLUE}https://script.google.com/home${NC}"
    if [ -n "$GAS_PROJECT_NAME" ]; then
        echo "  2. Search for: \"Gmail Skill - $GAS_PROJECT_NAME\" or ID: $GAS_PROJECT_ID"
    else
        echo "  2. Search for the project ID: $GAS_PROJECT_ID"
    fi
    echo "  3. Select the project and click the three-dot menu"
    echo "  4. Choose 'Remove' to delete the project"
    echo ""
    echo "This will completely revoke external access to your Gmail."
    echo ""
fi

# ========================================
# 10. 完了メッセージ
# ========================================

echo "================================================"
echo -e "${GREEN}  Uninstallation Complete!${NC}"
echo "================================================"
echo ""
echo "Local files have been removed from: $TARGET_DIR"
echo ""

if [ -n "$GAS_PROJECT_ID" ]; then
    echo -e "${YELLOW}Don't forget to delete the GAS project from script.google.com${NC}"
    echo ""
fi
