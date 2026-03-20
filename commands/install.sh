#!/bin/bash
#
# Gmail Skill - Installer
#
# Usage: ccskill-gmail install [PROJECT_NAME] [TARGET_DIR]
#
# Arguments:
#   PROJECT_NAME  Custom project name (optional, defaults to directory name)
#                 Use '-' to explicitly use directory name
#   TARGET_DIR    Target directory (optional, defaults to current directory)
#
# Examples:
#   ccskill-gmail install
#   ccskill-gmail install "MyProject"
#   ccskill-gmail install "MyProject" /path/to/project
#   ccskill-gmail install - /path/to/project
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  Gmail Skill - Installer"
echo "================================================"
echo ""

# ========================================
# 0. ディスパッチャ経由チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail install'${NC}"
    echo ""
    echo "Usage: ccskill-gmail install [PROJECT_NAME] [TARGET_DIR]"
    exit 1
fi

if [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: CCSKILL_GMAIL_DIR does not exist: $CCSKILL_GMAIL_DIR${NC}"
    exit 1
fi

# Load helpers
source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
source "$CCSKILL_GMAIL_DIR/lib/permissions.sh"

# ========================================
# 1. 引数パース
# ========================================

PROJECT_NAME_INPUT="${1:-}"
TARGET_DIR="${2:-.}"

# 絶対パスに変換
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: TARGET_DIR does not exist: $TARGET_DIR${NC}"
    exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

# プロジェクト名の決定
if [ -z "$PROJECT_NAME_INPUT" ] || [ "$PROJECT_NAME_INPUT" = "-" ]; then
    PROJECT_NAME=$(basename "$TARGET_DIR")
else
    PROJECT_NAME="$PROJECT_NAME_INPUT"
fi

GAS_PROJECT_TITLE="Gmail Skill - $PROJECT_NAME"

echo "Installing to: $TARGET_DIR"
echo "GAS Project Title: $GAS_PROJECT_TITLE"
echo ""

# ========================================
# 2. 前提条件チェック
# ========================================

echo "Checking prerequisites..."

# clasp のインストールチェック
if ! command -v clasp &> /dev/null; then
    echo -e "${RED}Error: clasp is not installed${NC}"
    echo ""
    echo "Please install clasp first:"
    echo "  npm install -g @google/clasp"
    echo ""
    echo "Then login to Google:"
    echo "  clasp login"
    exit 1
fi

# jq のチェック（必須）
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo ""
    echo "Please install jq first:"
    echo "  brew install jq"
    exit 1
fi

# clasp ログインチェック
if ! clasp login --status &> /dev/null; then
    echo -e "${YELLOW}You need to login to Google first.${NC}"
    echo "Running: clasp login"
    clasp login
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""

# ========================================
# 3. 既存インストールチェック
# ========================================

SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
GAS_DIR="$TARGET_DIR/.ccskill-gmail"

if [ -d "$SKILL_DIR" ] || [ -d "$GAS_DIR" ]; then
    echo -e "${YELLOW}Warning: Existing installation found${NC}"
    echo ""
    if [ -d "$SKILL_DIR" ]; then
        echo "  - $SKILL_DIR"
    fi
    if [ -d "$GAS_DIR" ]; then
        echo "  - $GAS_DIR"
    fi
    echo ""
    read -p "Overwrite existing installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    echo ""
fi

# ========================================
# 4. .ccskill-gmail/ ディレクトリ作成
# ========================================

echo "Step 1: Setting up project files..."

mkdir -p "$GAS_DIR"

# バージョン情報とインストール時刻を取得
VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
INSTALL_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# ========================================
# 5. config.js 生成
# ========================================

/bin/cp "$CCSKILL_GMAIL_DIR/gas-template/config.js.template" "$GAS_DIR/config.js"

echo -e "${GREEN}✓ config.js created${NC}"

# ========================================
# 6. スキル定義コピー
# ========================================

echo "Step 2: Installing skill definition..."

mkdir -p "$SKILL_DIR"

if [ -d "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" ] && [ "$(ls -A "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" 2>/dev/null)" ]; then
    cp -r "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail/"* "$SKILL_DIR/" 2>/dev/null || true
fi

echo -e "${GREEN}✓ Skill definition installed${NC}"
echo ""

# ========================================
# 7. auth.sh / api をプロジェクトにコピー
# ========================================

/bin/cp "$CCSKILL_GMAIL_DIR/lib/auth.sh" "$GAS_DIR/auth.sh"
/bin/cp "$CCSKILL_GMAIL_DIR/lib/api" "$GAS_DIR/api"
chmod +x "$GAS_DIR/api"

# history.sh をコピー
if [ -f "$CCSKILL_GMAIL_DIR/lib/history.sh" ]; then
    /bin/cp "$CCSKILL_GMAIL_DIR/lib/history.sh" "$GAS_DIR/history.sh"
fi

# history ディレクトリ作成
mkdir -p "$GAS_DIR/history"
chmod 700 "$GAS_DIR/history"

echo -e "${GREEN}✓ auth.sh / api / history.sh copied${NC}"

# ========================================
# 8. clasp create
# ========================================

echo "Step 3: Creating GAS project..."
echo ""

# clasp create を一時ディレクトリで実行
CLASP_TMPDIR=$(mktemp -d)
/bin/cp "$CCSKILL_GMAIL_DIR/gas-template/appsscript.json" "$CLASP_TMPDIR/"

(cd "$CLASP_TMPDIR" && clasp create --type standalone --title "$GAS_PROJECT_TITLE")

# 生成された .clasp.json を $GAS_DIR に保存
if [ -f "$CLASP_TMPDIR/.clasp.json" ]; then
    /bin/cp "$CLASP_TMPDIR/.clasp.json" "$GAS_DIR/.clasp.json"
else
    echo -e "${RED}Error: clasp create did not produce .clasp.json${NC}"
    rm -rf "$CLASP_TMPDIR"
    exit 1
fi

rm -rf "$CLASP_TMPDIR"

# rootDir を設定
tmp=$(mktemp)
jq '.rootDir = "."' "$GAS_DIR/.clasp.json" > "$tmp"
mv "$tmp" "$GAS_DIR/.clasp.json"

echo -e "${GREEN}✓ GAS project created${NC}"
echo ""

# ========================================
# 9. push_gas で GAS コード push
# ========================================

echo "Pushing code to Google Apps Script..."
push_gas "$GAS_DIR" "$CCSKILL_GMAIL_DIR"

echo -e "${GREEN}✓ Code pushed${NC}"
echo ""

# ========================================
# 10. deploy_gas で自動デプロイ
# ========================================

echo "Step 4: Deploying as Web App..."

RESULT_FILE=$(mktemp)
if ! deploy_gas "$GAS_DIR" "" "Initial deployment" "$RESULT_FILE"; then
    echo -e "${RED}Error: Failed to deploy. Check clasp login status.${NC}"
    rm -f "$RESULT_FILE"
    exit 1
fi

DEPLOYMENT_ID=$(cat "$RESULT_FILE")
rm -f "$RESULT_FILE"

if [ -z "$DEPLOYMENT_ID" ]; then
    echo -e "${RED}Error: Could not get deployment ID${NC}"
    exit 1
fi

ENDPOINT_URL="https://script.google.com/macros/s/${DEPLOYMENT_ID}/exec"

echo -e "${GREEN}✓ Deployed successfully${NC}"
echo "  Deployment ID: $DEPLOYMENT_ID"
echo -e "  Endpoint URL: ${BLUE}$ENDPOINT_URL${NC}"
echo ""

# ========================================
# 11. OAuth 認可
# ========================================

echo "================================================"
echo "  OAuth Authorization Required (one-time only)"
echo "================================================"
echo ""
echo "The Web App needs your permission to access Gmail."
echo "A browser window will open - please click 'Allow' when prompted."
echo ""
echo -e "${YELLOW}NOTE: You may see 'This app isn't verified' warning.${NC}"
echo "  Click 'Advanced' > 'Go to ... (unsafe)' > 'Allow'"
echo ""

read -p "Press Enter to open the authorization page..."

open "$ENDPOINT_URL" 2>/dev/null || xdg-open "$ENDPOINT_URL" 2>/dev/null || {
    echo ""
    echo "Could not open browser. Please open this URL manually:"
    echo -e "  ${BLUE}$ENDPOINT_URL${NC}"
}

echo ""
read -p "Press Enter after completing the authorization..."

# ========================================
# 12. エンドポイント検証（Bearer トークン付き）
# ========================================

echo ""
echo "Verifying endpoint..."

source "$CCSKILL_GMAIL_DIR/lib/auth.sh"

VERIFY_ATTEMPTS=0
VERIFY_OK=false

while [ $VERIFY_ATTEMPTS -lt 3 ]; do
    RESPONSE=$(curl -sL --max-time 60 \
        -H "Authorization: Bearer $(gas_token)" \
        "$ENDPOINT_URL" 2>/dev/null)

    if echo "$RESPONSE" | jq -e '.ok == true' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Endpoint is working correctly${NC}"
        VERIFY_OK=true
        break
    fi

    VERIFY_ATTEMPTS=$((VERIFY_ATTEMPTS + 1))

    if [ $VERIFY_ATTEMPTS -lt 3 ]; then
        echo -e "${YELLOW}Endpoint not ready yet. This may happen if authorization is not complete.${NC}"
        echo ""
        echo "Please make sure you:"
        echo "  1. Opened the endpoint URL in your browser"
        echo "  2. Clicked 'Allow' to authorize the script"
        echo ""
        read -p "Press Enter to retry (attempt $((VERIFY_ATTEMPTS + 1))/3)..."
    fi
done

if [ "$VERIFY_OK" = false ]; then
    echo -e "${YELLOW}Warning: Endpoint verification failed after 3 attempts.${NC}"
    echo "The deployment was created but authorization may not be complete."
    echo ""
    echo "To complete setup later:"
    echo "  1. Open $ENDPOINT_URL in your browser"
    echo "  2. Complete the authorization flow"
    echo "  3. Test with:"
    echo "     source $GAS_DIR/auth.sh && curl -sL --max-time 60 -H \"Authorization: Bearer \$(gas_token)\" \"$ENDPOINT_URL\" | jq ."
fi

echo ""

# ========================================
# 13. .env に GMAIL_ENDPOINT 保存
# ========================================

echo "Step 5: Saving endpoint..."

ENV_FILE="$TARGET_DIR/.env"

# .ccskill-gmail/endpoint ファイルに保存（api スクリプトが直接読み込む。sandbox の .env 制限を回避）
echo "$ENDPOINT_URL" > "$GAS_DIR/endpoint"
echo -e "${GREEN}✓ Endpoint saved to $GAS_DIR/endpoint${NC}"

# .env にも保存（後方互換・人間向け）
if [ -f "$ENV_FILE" ]; then
    if grep -q "^GMAIL_ENDPOINT=" "$ENV_FILE"; then
        # 既存エントリを更新
        tmp=$(mktemp)
        awk -v url="$ENDPOINT_URL" '/^GMAIL_ENDPOINT=/{print "GMAIL_ENDPOINT=" url; next} {print}' "$ENV_FILE" > "$tmp"
        /bin/mv "$tmp" "$ENV_FILE"
    else
        # エントリがない場合は追記
        echo "" >> "$ENV_FILE"
        echo "# Gmail Skill" >> "$ENV_FILE"
        echo "GMAIL_ENDPOINT=${ENDPOINT_URL}" >> "$ENV_FILE"
    fi
else
    cat > "$ENV_FILE" << EOF
# Gmail Skill
# Generated by install.sh on $INSTALL_TIME
# DO NOT commit this file to version control.

GMAIL_ENDPOINT=${ENDPOINT_URL}
EOF
fi

echo -e "${GREEN}✓ Endpoint also saved to .env (backward compat)${NC}"
echo ""

# ========================================
# 14. .ccskill-metadata.json 作成
# ========================================

cat > "$GAS_DIR/.ccskill-metadata.json" << EOF
{
  "installed_at": "$INSTALL_TIME",
  "updated_at": "$INSTALL_TIME",
  "installed_from": "$CCSKILL_GMAIL_DIR",
  "version": "$VERSION",
  "architecture": "master",
  "project_name": "$PROJECT_NAME",
  "deployment_id": "$DEPLOYMENT_ID"
}
EOF

echo -e "${GREEN}✓ Metadata saved${NC}"
echo ""

# ========================================
# 15. パーミッション設定
# ========================================

echo "Step 6: Setting up permission patterns..."
setup_permissions "$TARGET_DIR"
echo ""

# ========================================
# 16. レジストリ登録
# ========================================

registry_upsert "$TARGET_DIR"
echo -e "${GREEN}✓ Registered in ccskill-gmail registry${NC}"
echo ""

# ========================================
# 17. .gitignore 推奨表示
# ========================================

echo "================================================"
echo "  .gitignore Recommendation"
echo "================================================"
echo ""
echo "Add the following to your project's .gitignore:"
echo ""
echo -e "${YELLOW}# Gmail Skill${NC}"
echo -e "${YELLOW}.ccskill-gmail/${NC}"
echo -e "${YELLOW}.env${NC}"
echo ""
echo "The .ccskill-gmail/history/ directory contains your operation audit log."
echo "It is recommended to keep it out of version control."
echo ""

# ========================================
# 完了メッセージ
# ========================================

echo "================================================"
echo -e "${GREEN}  Installation Complete!${NC}"
echo "================================================"
echo ""
echo "Installed to: $TARGET_DIR"
echo ""
echo "You can now use Claude Code to interact with your Gmail."
echo "Try these commands:"
echo ""
echo "  \"Search for unread emails\""
echo "  \"Show me emails from boss@company.com\""
echo "  \"Create a draft reply to the latest email\""
echo ""
echo "For more examples:"
echo "  $SKILL_DIR/examples.md"
echo ""
echo "To update this skill later:"
echo "  cd $TARGET_DIR"
echo "  ccskill-gmail update"
echo ""
