#!/bin/bash
#
# Gmail Skill - Account Manager (#123)
#
# Usage:
#   ccskill-gmail account add [--label NAME] [--user CLASP_USER]
#   ccskill-gmail account list
#   ccskill-gmail account default <email|label>
#   ccskill-gmail account remove <email|label> [--yes]
#
# アカウントは ~/.ccskill-gmail/accounts.json に登録され、GAS プロジェクトは
# アカウントごとに 1 つ作成・共用される (プロジェクトごとには作らない)。
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$CCSKILL_GMAIL_DIR" ] || [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail account'${NC}"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"

show_usage() {
    cat << EOF
Usage: ccskill-gmail account <subcommand> [args...]

Subcommands:
  add [--label NAME] [--user CLASP_USER]  Register a Gmail account (creates a GAS project)
  list                                    Show registered accounts
  default <email|label>                   Set the default account
  remove <email|label> [--yes]            Remove an account from the registry
  update [<email|label>] [--force]        Push & deploy the account's shared GAS (default: all)
EOF
}

# ========================================
# add
# ========================================

cmd_add() {
    local LABEL=""
    local USER_OVERRIDE=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --label)
                LABEL="${2:-}"
                shift 2
                ;;
            --user)
                USER_OVERRIDE="${2:-}"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done

    if [ -n "$LABEL" ] && [[ ! "$LABEL" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: --label accepts only alphanumeric characters, hyphens, and underscores${NC}"
        exit 1
    fi
    if [ -n "$USER_OVERRIDE" ] && [[ ! "$USER_OVERRIDE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: --user accepts only alphanumeric characters, hyphens, and underscores${NC}"
        exit 1
    fi

    # 前提条件
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        echo "  brew install jq"
        exit 1
    fi

    source "$CCSKILL_GMAIL_DIR/lib/clasp.sh"
    source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
    source "$CCSKILL_GMAIL_DIR/lib/provision.sh"

    if ! _clasp --version &> /dev/null; then
        echo -e "${RED}Error: clasp is not available${NC}"
        echo ""
        echo "Run setup first:"
        echo "  ccskill-gmail setup"
        exit 1
    fi

    # clasp user 名の決定: --user 指定 > ccskill-acct-<label|main> (衝突時は連番)
    if [ -n "$USER_OVERRIDE" ]; then
        _CLASP_USER="$USER_OVERRIDE"
    else
        local base="ccskill-acct-${LABEL:-main}"
        local candidate="$base"
        local n=2
        while jq -e --arg u "$candidate" '.tokens[$u] // empty' "$HOME/.clasprc.json" >/dev/null 2>&1; do
            candidate="${base}-${n}"
            n=$((n + 1))
        done
        _CLASP_USER="$candidate"
    fi
    export _CLASP_USER

    echo "================================================"
    echo "  Gmail Skill - Add Account"
    echo "================================================"
    echo ""
    echo "Clasp user: $_CLASP_USER"
    [ -n "$LABEL" ] && echo "Label:      $LABEL"
    echo ""

    # Google ログイン (アカウントごとに 1 回)
    if _clasp show-authorized-user 2>&1 | grep -qi "not logged in"; then
        echo -e "${YELLOW}Google login required.${NC}"
        echo "Sign in with the Gmail account you want to register."
        echo "Running: clasp login --user $_CLASP_USER"
        _clasp login
    fi

    # アカウント用 GAS ディレクトリ (~/.ccskill-gmail/gas/<clasp_user>/)
    local GAS_DIR="$HOME/.ccskill-gmail/gas/$_CLASP_USER"
    mkdir -p "$GAS_DIR"
    chmod 700 "$HOME/.ccskill-gmail" "$HOME/.ccskill-gmail/gas" "$GAS_DIR"

    if [ ! -f "$GAS_DIR/config.js" ]; then
        /bin/cp "$CCSKILL_GMAIL_DIR/gas-template/config.js.template" "$GAS_DIR/config.js"
    fi

    # プロビジョニング (作成 → push → デプロイ → 認可 → 検証)
    PROVISION_RETRY_HINT="ccskill-gmail account add"
    PROVISION_VERIFY_HINT="ccskill-gmail api get action=get_profile"
    provision_gas "$GAS_DIR" "Gmail Skill - account ${LABEL:-$_CLASP_USER}"

    if [ "$PROVISION_VERIFY_OK" != true ]; then
        echo -e "${RED}Error: Could not verify the endpoint. Account was NOT registered.${NC}"
        echo ""
        echo "Complete the authorization in the browser, then re-run:"
        echo "  ccskill-gmail account add --user $_CLASP_USER"
        exit 1
    fi

    # email を確定して登録
    source "$CCSKILL_GMAIL_DIR/lib/auth.sh"
    local EMAIL
    EMAIL=$(curl -sL --max-time 60 \
        -H "Authorization: Bearer $(gas_token)" \
        "${PROVISION_ENDPOINT}?action=get_profile" 2>/dev/null | jq -r '.data.email // empty')

    if [ -z "$EMAIL" ]; then
        echo -e "${RED}Error: Could not determine the account email. Account was NOT registered.${NC}"
        echo ""
        echo "Re-run after a while:"
        echo "  ccskill-gmail account add --user $_CLASP_USER"
        exit 1
    fi

    local SCRIPT_ID
    SCRIPT_ID=$(jq -r '.scriptId // empty' "$GAS_DIR/.clasp.json" 2>/dev/null)

    accounts_upsert "$EMAIL" "$_CLASP_USER" "$SCRIPT_ID" "$PROVISION_DEPLOYMENT_ID" "$PROVISION_ENDPOINT" "$LABEL"

    local DEFAULT_MARK=""
    if [ "$(accounts_resolve_default)" = "$EMAIL" ]; then
        DEFAULT_MARK=" (default)"
    fi

    echo "================================================"
    echo -e "${GREEN}  Account Registered!${NC}"
    echo "================================================"
    echo ""
    echo "  Email:    $EMAIL$DEFAULT_MARK"
    [ -n "$LABEL" ] && echo "  Label:    $LABEL"
    echo "  Endpoint: $PROVISION_ENDPOINT"
    echo ""
    echo "Try it from any directory:"
    echo -e "  ${BLUE}ccskill-gmail api get action=get_profile${NC}"
    if [ -n "$LABEL" ]; then
        echo -e "  ${BLUE}ccskill-gmail api --account $LABEL get action=get_profile${NC}"
    fi
    echo ""
}

# ========================================
# list
# ========================================

cmd_list() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi

    local file="$HOME/.ccskill-gmail/accounts.json"
    local count
    count=$(accounts_count)

    if [ "$count" = "0" ]; then
        echo "(no accounts registered)"
        echo ""
        echo "Register one with:"
        echo "  ccskill-gmail account add"
        return 0
    fi

    printf "  %-3s %-34s %-12s %s\n" "" "EMAIL" "LABEL" "CREATED"
    jq -r '
        .default_account as $def
        | .accounts | to_entries[]
        | [ (if .key == $def then "*" else " " end),
            .key,
            (.value.label // "-"),
            (.value.created_at // "-") ]
        | @tsv' "$file" | while IFS=$'\t' read -r mark email label created; do
        printf "  %-3s %-34s %-12s %s\n" "$mark" "$email" "$label" "$created"
    done
    echo ""
    echo "  (* = default account)"
}

# ========================================
# default
# ========================================

cmd_default() {
    local ident="${1:-}"
    if [ -z "$ident" ]; then
        echo -e "${RED}Error: Usage: ccskill-gmail account default <email|label>${NC}"
        exit 1
    fi

    accounts_set_default "$ident"
    local email
    email=$(accounts_get "$ident" | jq -r '.email')
    echo -e "${GREEN}✓ Default account: $email${NC}"
}

# ========================================
# remove
# ========================================

cmd_remove() {
    local ident=""
    local yes_flag=false
    for arg in "$@"; do
        case "$arg" in
            --yes) yes_flag=true ;;
            *) ident="$arg" ;;
        esac
    done

    if [ -z "$ident" ]; then
        echo -e "${RED}Error: Usage: ccskill-gmail account remove <email|label> [--yes]${NC}"
        exit 1
    fi

    local entry email
    entry=$(accounts_get "$ident") || {
        echo -e "${RED}Error: account not found: $ident${NC}"
        exit 1
    }
    email=$(printf '%s' "$entry" | jq -r '.email')

    if [ "$yes_flag" != true ]; then
        echo "Remove account from registry: $email"
        echo "(The GAS project itself is NOT deleted - remove it manually at"
        echo " https://script.google.com if you want it gone)"
        echo ""
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    accounts_remove "$email"
    echo -e "${GREEN}✓ Removed: $email${NC}"
    echo "Note: The GAS project still exists at https://script.google.com"
}

# ========================================
# update — アカウント共有 GAS のコード更新 (#126)
# ========================================

cmd_update() {
    local IDENT=""
    local FORCE=false
    for arg in "$@"; do
        case "$arg" in
            --force|-f) FORCE=true ;;
            *) IDENT="$arg" ;;
        esac
    done

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        exit 1
    fi

    source "$CCSKILL_GMAIL_DIR/lib/clasp.sh"
    source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"

    local file="$HOME/.ccskill-gmail/accounts.json"
    if [ ! -f "$file" ] || [ "$(accounts_count)" = "0" ]; then
        echo "(no accounts registered)"
        return 0
    fi

    local MASTER_VERSION
    if [ -f "$CCSKILL_GMAIL_DIR/VERSION" ]; then
        MASTER_VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
    else
        MASTER_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    local emails
    if [ -n "$IDENT" ]; then
        local _e
        _e=$(accounts_get "$IDENT") || {
            echo -e "${RED}Error: account not found: $IDENT${NC}"
            exit 1
        }
        emails=$(printf '%s' "$_e" | jq -r '.email')
    else
        emails=$(jq -r '.accounts | keys[]' "$file")
    fi

    local updated=0 skipped=0 failed=0
    while IFS= read -r email; do
        [ -z "$email" ] && continue
        local entry clasp_user script_id deployment_id endpoint label version
        entry=$(accounts_get "$email") || continue
        clasp_user=$(printf '%s' "$entry" | jq -r '.clasp_user // empty')
        script_id=$(printf '%s' "$entry" | jq -r '.script_id // empty')
        deployment_id=$(printf '%s' "$entry" | jq -r '.deployment_id // empty')
        endpoint=$(printf '%s' "$entry" | jq -r '.endpoint // empty')
        label=$(printf '%s' "$entry" | jq -r '.label // empty')
        version=$(printf '%s' "$entry" | jq -r '.version // empty')

        if [ "$FORCE" != true ] && [ "$version" = "$MASTER_VERSION" ]; then
            echo "  = $email (up to date: $version)"
            skipped=$((skipped + 1))
            continue
        fi
        if [ -z "$script_id" ] || [ -z "$deployment_id" ]; then
            echo -e "  ${YELLOW}! $email: script_id / deployment_id not recorded — skipped${NC}"
            echo "      (re-register with: ccskill-gmail account add --user $clasp_user)"
            failed=$((failed + 1))
            continue
        fi

        local gdir="$HOME/.ccskill-gmail/gas/$clasp_user"
        mkdir -p "$gdir"
        chmod 700 "$HOME/.ccskill-gmail" "$HOME/.ccskill-gmail/gas" "$gdir" 2>/dev/null || true
        if [ ! -f "$gdir/.clasp.json" ]; then
            printf '{"scriptId":"%s","rootDir":"."}\n' "$script_id" > "$gdir/.clasp.json"
        fi
        if [ ! -f "$gdir/config.js" ]; then
            /bin/cp "$CCSKILL_GMAIL_DIR/gas-template/config.js.template" "$gdir/config.js"
        fi

        export _CLASP_USER="$clasp_user"
        echo "Updating shared GAS for $email (${version:-unknown} -> $MASTER_VERSION)..."
        if push_gas "$gdir" "$CCSKILL_GMAIL_DIR" && deploy_gas "$gdir" "$deployment_id" "Update to $MASTER_VERSION"; then
            accounts_upsert "$email" "$clasp_user" "$script_id" "$deployment_id" "$endpoint" "$label"
            echo -e "  ${GREEN}✓ $email updated${NC}"
            updated=$((updated + 1))
        else
            echo -e "  ${RED}✗ $email update failed${NC}"
            failed=$((failed + 1))
        fi
    done <<EOF
$emails
EOF

    echo ""
    echo "Account GAS update: $updated updated, $skipped up to date, $failed failed"
    [ "$failed" -eq 0 ]
}

# ========================================
# ディスパッチ
# ========================================

SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
    add)
        cmd_add "$@"
        ;;
    list)
        cmd_list "$@"
        ;;
    default)
        cmd_default "$@"
        ;;
    remove)
        cmd_remove "$@"
        ;;
    update)
        cmd_update "$@"
        ;;
    ""|help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown subcommand: $SUBCOMMAND${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
