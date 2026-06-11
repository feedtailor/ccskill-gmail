#!/bin/bash
#
# Gmail Skill - Installer
#
# Usage: ccskill-gmail install [--user NAME] [PROJECT_NAME] [TARGET_DIR]
#
# Arguments:
#   --user NAME   Clasp user name for multi-account support (optional)
#   PROJECT_NAME  Custom project name (optional, defaults to directory name)
#                 Use '-' to explicitly use directory name
#   TARGET_DIR    Target directory (optional, defaults to current directory)
#
# Examples:
#   ccskill-gmail install
#   ccskill-gmail install "MyProject"
#   ccskill-gmail install "MyProject" /path/to/project
#   ccskill-gmail install - /path/to/project
#   ccskill-gmail install --user work "WorkProject" /path/to/work
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
source "$CCSKILL_GMAIL_DIR/lib/clasp.sh"
source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
source "$CCSKILL_GMAIL_DIR/lib/permissions.sh"
source "$CCSKILL_GMAIL_DIR/lib/update_check.sh"

# ========================================
# 1. 引数パース
# ========================================

# フラグのパース
_USER_OVERRIDE=""
_ACCOUNT_OVERRIDE=""
_DEDICATED=false
_AUTO_YES=false
positional_args=()

for arg in "$@"; do
    case "$arg" in
        --user)
            _next_is_user=true
            ;;
        --account)
            _next_is_account=true
            ;;
        --dedicated)
            _DEDICATED=true
            ;;
        --yes|-y)
            _AUTO_YES=true
            ;;
        *)
            if [ "${_next_is_user:-}" = true ]; then
                _USER_OVERRIDE="$arg"
                _next_is_user=false
            elif [ "${_next_is_account:-}" = true ]; then
                _ACCOUNT_OVERRIDE="$arg"
                _next_is_account=false
            else
                positional_args+=("$arg")
            fi
            ;;
    esac
done

# --user はプロジェクト専用 GAS (従来動作) を意味するため --dedicated を含意する
if [ -n "$_USER_OVERRIDE" ]; then
    _DEDICATED=true
fi

PROJECT_NAME_INPUT="${positional_args[0]:-}"
TARGET_DIR="${positional_args[1]:-.}"

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

# ========================================
# 1.5 セントラルモード (デフォルト, #126)
# 専用 GAS は作らず「アカウント解決 + bind + ファイル配置」のみ行う。
# プロジェクト専用 GAS が必要な場合は --dedicated (--user 指定時も同様)。
# ========================================

if [ "$_DEDICATED" != true ]; then
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        echo ""
        echo "Please install jq first:"
        echo "  brew install jq"
        exit 1
    fi

    source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"

    # アカウント解決: --account 指定 > デフォルトアカウント
    ACCOUNT_EMAIL=""
    if [ -n "$_ACCOUNT_OVERRIDE" ]; then
        _acct_entry=$(accounts_get "$_ACCOUNT_OVERRIDE") || {
            echo -e "${RED}Error: account not found: $_ACCOUNT_OVERRIDE${NC}"
            echo ""
            echo "Registered accounts:"
            "$CCSKILL_GMAIL_DIR/commands/account.sh" list || true
            exit 1
        }
        ACCOUNT_EMAIL=$(printf '%s' "$_acct_entry" | jq -r '.email')
    elif ! ACCOUNT_EMAIL=$(accounts_resolve_default); then
        echo -e "${RED}No account registered yet.${NC}"
        echo ""
        echo "Register a Gmail account first (one-time, opens a browser):"
        echo -e "  ${BLUE}ccskill-gmail account add${NC}"
        echo ""
        echo "Then re-run: ccskill-gmail install"
        echo ""
        echo "(To create a dedicated per-project GAS instead: ccskill-gmail install --dedicated)"
        exit 1
    fi

    echo "Mode:    central account (no dedicated GAS)"
    echo "Account: $ACCOUNT_EMAIL"
    echo ""

    SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
    GAS_DIR="$TARGET_DIR/.ccskill-gmail"

    # 既存インストールチェック
    if { [ -d "$SKILL_DIR" ] || [ -d "$GAS_DIR" ]; } && [ "$_AUTO_YES" != true ]; then
        echo -e "${YELLOW}Warning: Existing installation found${NC}"
        echo ""
        read -p "Overwrite existing installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
        echo ""
    fi

    # スキル定義コピー
    echo "Step 1: Installing skill definition..."
    mkdir -p "$SKILL_DIR"
    if [ -d "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" ] && [ "$(ls -A "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail" 2>/dev/null)" ]; then
        cp -r "$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail/"* "$SKILL_DIR/" 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ Skill definition installed${NC}"

    # api スクリプト + tmp/ + ディレクトリ保護
    echo "Step 2: Setting up project files..."
    mkdir -p "$GAS_DIR/tmp"
    /bin/cp "$CCSKILL_GMAIL_DIR/lib/api" "$GAS_DIR/api"
    chmod +x "$GAS_DIR/api"
    chmod 700 "$GAS_DIR"
    _INNER_GITIGNORE="$GAS_DIR/.gitignore"
    if [ ! -f "$_INNER_GITIGNORE" ] || ! grep -qF "tmp/" "$_INNER_GITIGNORE"; then
        echo "tmp/" >> "$_INNER_GITIGNORE"
    fi
    echo -e "${GREEN}✓ Project files ready${NC}"

    # バインド
    accounts_write_binding "$TARGET_DIR" "$ACCOUNT_EMAIL"
    echo -e "${GREEN}✓ Bound to: $ACCOUNT_EMAIL${NC}"
    echo ""

    # パーミッション設定 (opt-in)
    if [ "$_AUTO_YES" = true ]; then
        setup_permissions "$TARGET_DIR" "--yes"
    else
        setup_permissions "$TARGET_DIR"
    fi
    echo ""

    # レジストリ登録
    registry_upsert "$TARGET_DIR"
    registry_update_email "$TARGET_DIR" "$ACCOUNT_EMAIL"

    # .gitignore 自動設定
    GITIGNORE="$TARGET_DIR/.gitignore"
    if [ ! -f "$GITIGNORE" ] || ! grep -qF ".ccskill-gmail/" "$GITIGNORE"; then
        echo ".ccskill-gmail/" >> "$GITIGNORE"
        echo -e "${GREEN}✓ .gitignore updated (added .ccskill-gmail/)${NC}"
    fi
    echo ""

    echo "================================================"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo "================================================"
    echo ""
    echo "Installed to: $TARGET_DIR (account: $ACCOUNT_EMAIL)"
    echo ""
    echo "Verify:"
    echo -e "  ${BLUE}ccskill-gmail api whoami${NC}"
    echo -e "  ${BLUE}ccskill-gmail api get action=get_profile${NC}"
    echo ""
    exit 0
fi

GAS_PROJECT_TITLE="Gmail Skill - $PROJECT_NAME"

# clasp --user 名を設定（プロジェクトごとに認証を分離）
# --user オプションがあればそれを使用、なければプロジェクト名から自動生成
if [ -n "$_USER_OVERRIDE" ]; then
    if [[ ! "$_USER_OVERRIDE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: --user accepts only alphanumeric characters, hyphens, and underscores${NC}"
        echo ""
        echo "  Example: ccskill-gmail install --user work"
        echo ""
        echo "  Note: Use a profile name, not an email address."
        echo "  The installer will prompt for Google login automatically."
        exit 1
    fi
    _CLASP_USER="$_USER_OVERRIDE"
else
    # ディレクトリ名から安全な clasp user 名を生成（英数字・ハイフン・アンダースコアのみ）
    _CLASP_USER="ccskill-gmail-$(echo "$PROJECT_NAME" | tr -cd 'a-zA-Z0-9_-')"
fi
export _CLASP_USER

echo "Installing to: $TARGET_DIR"
echo "GAS Project Title: $GAS_PROJECT_TITLE"
echo "Clasp user: $_CLASP_USER"
echo ""

# ========================================
# 2. 前提条件チェック
# ========================================

echo "Checking prerequisites..."

# clasp チェック（ローカル or グローバル）
if ! _clasp --version &> /dev/null; then
    echo -e "${RED}Error: clasp is not available${NC}"
    echo ""
    echo "Run setup first:"
    echo "  ccskill-gmail setup"
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

# clasp ログインチェック（--user 付きで名前付き認証を使用）
if _clasp show-authorized-user 2>&1 | grep -qi "not logged in"; then
    echo -e "${YELLOW}Google login required for project '${PROJECT_NAME}'.${NC}"
    echo "Running: clasp login --user $_CLASP_USER"
    _clasp login
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"
echo ""

# ========================================
# 2.5. マスターの更新チェック
# ========================================

UPDATE_LINE=$(update_check_format_oneline_cached "$CCSKILL_GMAIL_DIR" 2>/dev/null || true)
if [ -n "$UPDATE_LINE" ]; then
    echo -e "${YELLOW}$UPDATE_LINE${NC}"
    echo "  Master: $CCSKILL_GMAIL_DIR"
    echo ""
    read -p "Proceed with install using the current (outdated) master? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        echo "Tip: cd $CCSKILL_GMAIL_DIR && git pull, then run install again."
        exit 0
    fi
    echo ""
fi

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
if [ -f "$CCSKILL_GMAIL_DIR/VERSION" ]; then
    VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
else
    VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi
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
# 7. api スクリプトをコピー + ディレクトリ保護
# ========================================

/bin/cp "$CCSKILL_GMAIL_DIR/lib/api" "$GAS_DIR/api"
chmod +x "$GAS_DIR/api"
mkdir -p "$GAS_DIR/tmp"
chmod 700 "$GAS_DIR"

# .ccskill-gmail 内の .gitignore（tmp/ を除外）
INNER_GITIGNORE="$GAS_DIR/.gitignore"
if [ ! -f "$INNER_GITIGNORE" ] || ! grep -qF "tmp/" "$INNER_GITIGNORE"; then
    echo "tmp/" >> "$INNER_GITIGNORE"
fi

echo -e "${GREEN}✓ api script copied, directory secured${NC}"

# ========================================
# 8-12. GAS プロビジョニング (作成 → push → デプロイ → 認可 → 検証)
# ========================================

echo "Step 3: Provisioning GAS project..."

source "$CCSKILL_GMAIL_DIR/lib/provision.sh"

provision_gas "$GAS_DIR" "$GAS_PROJECT_TITLE"

DEPLOYMENT_ID="$PROVISION_DEPLOYMENT_ID"
ENDPOINT_URL="$PROVISION_ENDPOINT"
VERIFY_OK="$PROVISION_VERIFY_OK"

# ========================================
# 13. .ccskill-metadata.json 作成
# ========================================

cat > "$GAS_DIR/.ccskill-metadata.json" << EOF
{
  "installed_at": "$INSTALL_TIME",
  "updated_at": "$INSTALL_TIME",
  "installed_from": "$CCSKILL_GMAIL_DIR",
  "version": "$VERSION",
  "architecture": "master",
  "project_name": "$PROJECT_NAME",
  "clasp_user": "$_CLASP_USER",
  "deployment_id": "$DEPLOYMENT_ID",
  "endpoint": "$ENDPOINT_URL"
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

# Fetch account email and save to registry
if [ "$VERIFY_OK" = true ] && [ -x "$GAS_DIR/api" ]; then
    PROFILE_RESPONSE=$("$GAS_DIR/api" get action=get_profile 2>/dev/null) || true
    if [ -n "$PROFILE_RESPONSE" ]; then
        ACCOUNT_EMAIL=$(echo "$PROFILE_RESPONSE" | jq -r '.data.email // empty' 2>/dev/null)
        if [ -n "$ACCOUNT_EMAIL" ]; then
            registry_update_email "$TARGET_DIR" "$ACCOUNT_EMAIL"
        fi
    fi
fi

echo -e "${GREEN}✓ Registered in ccskill-gmail registry${NC}"
echo ""

# ========================================
# 17. .gitignore 自動設定
# ========================================

GITIGNORE="$TARGET_DIR/.gitignore"
if [ ! -f "$GITIGNORE" ] || ! grep -qF ".ccskill-gmail/" "$GITIGNORE"; then
    echo ".ccskill-gmail/" >> "$GITIGNORE"
    echo -e "${GREEN}✓ .gitignore updated (added .ccskill-gmail/)${NC}"
else
    echo -e "${GREEN}✓ .gitignore already contains .ccskill-gmail/${NC}"
fi
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
echo "Verify the installation:"
echo -e "  ${BLUE}.ccskill-gmail/api get action=get_profile${NC}"
echo ""
echo "For more examples:"
echo "  $SKILL_DIR/examples.md"
echo ""
echo "To run a full API test (for developers):"
echo -e "  ${BLUE}$CCSKILL_GMAIL_DIR/tests/smoke-test.sh .${NC}"
echo ""
echo "To update this skill later:"
echo "  cd $TARGET_DIR"
echo "  ccskill-gmail update"
echo ""
