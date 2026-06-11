#!/bin/bash
#
# Gmail Skill - Migrate legacy installs to the central account registry (#125)
#
# Usage: ccskill-gmail migrate [--dry-run] [--yes]
#
# .registry.json のインストール一覧を email でグルーピングし、
#   1. email ごとに代表デプロイ (レジストリ記載順の最初) を accounts.json に登録
#      (既存エントリは上書きしない。既に認可済みの GAS を再利用するため再認可は不要)
#   2. 各プロジェクトに binding.json を書く (旧メタデータは残置)
#   3. 代表以外の余剰 GAS デプロイを一覧表示 (削除はしない — 手動で)
#
# テスト用: CCSKILL_GMAIL_REGISTRY_FILE でレジストリの場所を上書きできる。
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$CCSKILL_GMAIL_DIR" ] || [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail migrate'${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for migrate${NC}"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"

REGISTRY_FILE="${CCSKILL_GMAIL_REGISTRY_FILE:-$CCSKILL_GMAIL_DIR/.registry.json}"

DRY_RUN=false
YES_FLAG=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --yes|-y)  YES_FLAG=true ;;
        *)
            echo -e "${RED}Error: Unknown option: $arg${NC}"
            echo "Usage: ccskill-gmail migrate [--dry-run] [--yes]"
            exit 1
            ;;
    esac
done

echo "================================================"
echo "  Gmail Skill - Migrate to Central Accounts"
echo "================================================"
echo ""

if [ ! -f "$REGISTRY_FILE" ]; then
    echo "No registry found ($REGISTRY_FILE). Nothing to migrate."
    exit 0
fi

# ========================================
# 1. プラン構築 (読み取りのみ)
# ========================================

# email ごとの代表 (レジストリ記載順で最初の有効プロジェクト) と所属プロジェクト
REP_EMAILS=()        # 発見順の email
REP_PATHS=()         # email ごとの代表プロジェクトパス
BIND_PLAN=()         # "path<TAB>email" の列
SKIPPED=()           # スキップしたパス
SURPLUS=()           # "deployment_id<TAB>path" (代表以外)

_email_index() {
    local e="$1"
    local i=0
    while [ $i -lt ${#REP_EMAILS[@]} ]; do
        if [ "${REP_EMAILS[$i]}" = "$e" ]; then
            echo "$i"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

PATHS=$(jq -r '.installations | keys_unsorted[]' "$REGISTRY_FILE")

while IFS= read -r path; do
    [ -z "$path" ] && continue

    email=$(jq -r --arg p "$path" '.installations[$p].email // empty' "$REGISTRY_FILE")
    if [ -z "$email" ]; then
        SKIPPED+=("$path (email unknown)")
        continue
    fi

    metadata="$path/.ccskill-gmail/.ccskill-metadata.json"
    if [ ! -f "$metadata" ]; then
        SKIPPED+=("$path (metadata not found)")
        continue
    fi

    if ! _email_index "$email" >/dev/null; then
        REP_EMAILS+=("$email")
        REP_PATHS+=("$path")
    fi
    BIND_PLAN+=("$path"$'\t'"$email")
done <<EOF
$PATHS
EOF

if [ ${#BIND_PLAN[@]} -eq 0 ]; then
    echo "No migratable installations found."
    for s in "${SKIPPED[@]+"${SKIPPED[@]}"}"; do
        echo -e "  ${YELLOW}skip:${NC} $s"
    done
    exit 0
fi

# ========================================
# 2. プラン表示
# ========================================

echo "Plan:"
echo ""

i=0
while [ $i -lt ${#REP_EMAILS[@]} ]; do
    email="${REP_EMAILS[$i]}"
    rep_path="${REP_PATHS[$i]}"
    rep_meta="$rep_path/.ccskill-gmail/.ccskill-metadata.json"
    rep_dep=$(jq -r '.deployment_id // empty' "$rep_meta")

    # 既存登録があればそれを代表として尊重する
    existing=""
    if existing=$(accounts_get "$email" 2>/dev/null); then
        rep_dep=$(printf '%s' "$existing" | jq -r '.deployment_id // empty')
        echo -e "  ${GREEN}$email${NC} — already registered (kept as-is)"
    else
        echo -e "  ${GREEN}$email${NC} — register with deployment from: $rep_path"
    fi

    # 所属プロジェクトと余剰デプロイ
    for entry in "${BIND_PLAN[@]}"; do
        p="${entry%%$'\t'*}"
        e="${entry#*$'\t'}"
        [ "$e" = "$email" ] || continue
        p_dep=$(jq -r '.deployment_id // empty' "$p/.ccskill-gmail/.ccskill-metadata.json")
        if [ -n "$p_dep" ] && [ "$p_dep" != "$rep_dep" ]; then
            SURPLUS+=("$p_dep"$'\t'"$p")
            echo "      bind: $p (surplus deployment: $p_dep)"
        else
            echo "      bind: $p"
        fi
    done
    i=$((i + 1))
done

for s in "${SKIPPED[@]+"${SKIPPED[@]}"}"; do
    echo -e "  ${YELLOW}skip:${NC} $s"
done
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "(dry-run: nothing was changed)"
    exit 0
fi

if [ "$YES_FLAG" != true ]; then
    read -p "Proceed with migration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

# ========================================
# 3. 実行
# ========================================

i=0
while [ $i -lt ${#REP_EMAILS[@]} ]; do
    email="${REP_EMAILS[$i]}"
    rep_path="${REP_PATHS[$i]}"
    rep_meta="$rep_path/.ccskill-gmail/.ccskill-metadata.json"

    if ! accounts_get "$email" >/dev/null 2>&1; then
        clasp_user=$(jq -r '.clasp_user // empty' "$rep_meta")
        deployment_id=$(jq -r '.deployment_id // empty' "$rep_meta")
        endpoint=$(jq -r '.endpoint // empty' "$rep_meta")
        script_id=$(jq -r '.scriptId // empty' "$rep_path/.ccskill-gmail/.clasp.json" 2>/dev/null)

        if [ -z "$endpoint" ]; then
            echo -e "${YELLOW}skip: $email (no endpoint in $rep_meta)${NC}"
            i=$((i + 1))
            continue
        fi

        accounts_upsert "$email" "${clasp_user:-default}" "$script_id" "$deployment_id" "$endpoint" ""
        echo -e "${GREEN}✓ Registered: $email${NC}"

        # 代表プロジェクトの config.js をアカウント GAS ディレクトリへ引き継ぐ (#126)。
        # これが無いと account update がテンプレート config を push してしまい、
        # 移行元でカスタムした permissions (move_to_trash 許可等) が失われる
        acct_gdir="$HOME/.ccskill-gmail/gas/${clasp_user:-default}"
        if [ -f "$rep_path/.ccskill-gmail/config.js" ] && [ ! -f "$acct_gdir/config.js" ]; then
            mkdir -p "$acct_gdir"
            chmod 700 "$HOME/.ccskill-gmail" "$HOME/.ccskill-gmail/gas" "$acct_gdir" 2>/dev/null || true
            /bin/cp "$rep_path/.ccskill-gmail/config.js" "$acct_gdir/config.js"
            echo "  (config.js carried over from $rep_path)"
        fi
    fi

    i=$((i + 1))
done

for entry in "${BIND_PLAN[@]}"; do
    p="${entry%%$'\t'*}"
    e="${entry#*$'\t'}"
    # アカウント登録に失敗した email の binding は書かない
    accounts_get "$e" >/dev/null 2>&1 || continue
    accounts_write_binding "$p" "$e"
    echo -e "${GREEN}✓ Bound:${NC} $p -> $e"
done

echo ""

# ========================================
# 4. 余剰デプロイの案内
# ========================================

if [ ${#SURPLUS[@]} -gt 0 ]; then
    echo "================================================"
    echo -e "${YELLOW}  Surplus GAS deployments (manual cleanup)${NC}"
    echo "================================================"
    echo ""
    echo "These projects now use the account's shared deployment. Their old"
    echo "per-project GAS projects are no longer used and can be deleted"
    echo -e "manually at ${BLUE}https://script.google.com${NC}:"
    echo ""
    for entry in "${SURPLUS[@]}"; do
        dep="${entry%%$'\t'*}"
        p="${entry#*$'\t'}"
        echo "  - $dep  ($p)"
    done
    echo ""
    echo "(Nothing was deleted automatically.)"
fi

echo ""
echo -e "${GREEN}Migration complete.${NC}"
echo "Verify with: ccskill-gmail account list / ccskill-gmail api whoami"
