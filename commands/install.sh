#!/bin/bash
#
# Gmail Skill - Installer (deprecated, #141)
#
# `install` は deprecated。central 構成は `bind` へ委譲し、専用 GAS の新規作成
# (--dedicated / --user) は退役した。既存インストール (central / 専用GAS / レガシー)
# は解決経路が不変で動作し続ける。畳んだのは「新規に作る手段」のみ。
#
# 推奨される導線:
#   ccskill-gmail account add        # アカウント登録 (一度きり)
#   ccskill-gmail skill install      # ユーザースキル登録 (全プロジェクトで利用可)
#   ccskill-gmail bind <email|label> # ディレクトリをアカウントに固定
#
# Usage (互換): ccskill-gmail install [--account NAME] [DIR]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========================================
# 0. ディスパッチャ経由チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail install'${NC}"
    exit 1
fi

if [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: CCSKILL_GMAIL_DIR does not exist: $CCSKILL_GMAIL_DIR${NC}"
    exit 1
fi

# ========================================
# 1. 引数パース
# ========================================

_USER_OVERRIDE=""
_ACCOUNT_OVERRIDE=""
_DEDICATED=false
_AUTO_YES=false
positional_args=()

for arg in "$@"; do
    case "$arg" in
        --user)    _next_is_user=true ;;
        --account) _next_is_account=true ;;
        --dedicated) _DEDICATED=true ;;
        --yes|-y)  _AUTO_YES=true ;;
        *)
            if [ "${_next_is_user:-}" = true ]; then
                _USER_OVERRIDE="$arg"; _next_is_user=false
            elif [ "${_next_is_account:-}" = true ]; then
                _ACCOUNT_OVERRIDE="$arg"; _next_is_account=false
            else
                positional_args+=("$arg")
            fi
            ;;
    esac
done

# --user はプロジェクト専用 GAS (旧動作) を意味するため --dedicated を含意する
if [ -n "$_USER_OVERRIDE" ]; then
    _DEDICATED=true
fi

# 互換: install [PROJECT_NAME] [DIR] の DIR 部分のみ使う
TARGET_DIR="${positional_args[1]:-.}"

# ========================================
# 2. 専用 GAS 新規作成は退役 (#141)
# ========================================

if [ "$_DEDICATED" = true ]; then
    echo -e "${RED}Error: creating a new dedicated GAS has been retired.${NC}"
    echo ""
    echo "  'install --dedicated' / 'install --user' は廃止されました。"
    echo "  既存の専用 GAS はそのまま動作し続けます (レガシー解決経路)。"
    echo ""
    echo "新しくセットアップする場合は、グローバルな導線を使ってください:"
    echo -e "  ${BLUE}ccskill-gmail account add${NC}        # アカウント登録 (一度きり)"
    echo -e "  ${BLUE}ccskill-gmail skill install${NC}      # ユーザースキル登録"
    echo -e "  ${BLUE}ccskill-gmail bind <email|label>${NC} # このディレクトリをアカウントに固定"
    exit 1
fi

# ========================================
# 3. central install は deprecated → bind へ委譲 (#141)
# ========================================

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo ""
    echo "Please install jq first:"
    echo "  brew install jq"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: TARGET_DIR does not exist: $TARGET_DIR${NC}"
    exit 1
fi
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

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
    echo "Then pin this directory with: ccskill-gmail bind <email|label>"
    exit 1
fi

# 退役予告 (deprecated)
echo -e "${YELLOW}Notice: 'ccskill-gmail install' is deprecated.${NC}"
echo "  Use 'ccskill-gmail bind' instead — it pins this directory to an account."
echo "  (Delegating to: ccskill-gmail bind $ACCOUNT_EMAIL)"
echo ""

# bind へ委譲 (binding.json の書き込み + permission の opt-in)
if [ "$_AUTO_YES" = true ]; then
    exec "$CCSKILL_GMAIL_DIR/commands/bind.sh" bind "$ACCOUNT_EMAIL" "$TARGET_DIR" --yes
else
    exec "$CCSKILL_GMAIL_DIR/commands/bind.sh" bind "$ACCOUNT_EMAIL" "$TARGET_DIR"
fi
