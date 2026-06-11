#!/bin/bash
#
# Gmail Skill - Project Binding (#125)
#
# Usage:
#   ccskill-gmail bind <email|label> [DIR] [--yes]
#   ccskill-gmail unbind [DIR] [--yes]
#
# .ccskill-gmail/binding.json を書くだけの軽量バインド。GAS 作成は行わない。
# バインドされたディレクトリでは --account 指名がない限りそのアカウントが使われる。
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ -z "$CCSKILL_GMAIL_DIR" ] || [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail bind'${NC}"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"
source "$CCSKILL_GMAIL_DIR/lib/permissions.sh"

MODE="${1:-}"
shift || true

# 共通引数パース: 位置引数と --yes / --purge-legacy
POSITIONAL=()
YES_FLAG=""
PURGE_LEGACY=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) YES_FLAG="--yes" ;;
        --purge-legacy) PURGE_LEGACY=true ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done

case "$MODE" in
    bind)
        IDENT="${POSITIONAL[0]:-}"
        TARGET_DIR="${POSITIONAL[1]:-.}"

        if [ -z "$IDENT" ]; then
            echo -e "${RED}Error: Usage: ccskill-gmail bind <email|label> [DIR] [--yes]${NC}"
            exit 1
        fi
        if [ ! -d "$TARGET_DIR" ]; then
            echo -e "${RED}Error: directory not found: $TARGET_DIR${NC}"
            exit 1
        fi
        TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

        ENTRY=$(accounts_get "$IDENT") || {
            echo -e "${RED}Error: account not found: $IDENT${NC}"
            echo "Registered accounts:"
            "$CCSKILL_GMAIL_DIR/commands/account.sh" list || true
            exit 1
        }
        EMAIL=$(printf '%s' "$ENTRY" | jq -r '.email')

        accounts_write_binding "$TARGET_DIR" "$EMAIL"
        echo -e "${GREEN}✓ Bound: $TARGET_DIR -> $EMAIL${NC}"
        echo "  ($TARGET_DIR/.ccskill-gmail/binding.json)"
        echo ""
        echo "Calls from this directory now use $EMAIL unless --account is given."

        # permission パターンの opt-in 追加 (確認は setup_permissions 側で行う)
        setup_permissions "$TARGET_DIR" "$YES_FLAG"
        ;;

    unbind)
        TARGET_DIR="${POSITIONAL[0]:-.}"
        if [ ! -d "$TARGET_DIR" ]; then
            echo -e "${RED}Error: directory not found: $TARGET_DIR${NC}"
            exit 1
        fi
        TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
        GAS_DIR="$TARGET_DIR/.ccskill-gmail"
        BINDING_FILE="$GAS_DIR/binding.json"
        LEGACY_METADATA="$GAS_DIR/.ccskill-metadata.json"

        if [ ! -f "$BINDING_FILE" ] && [ "$PURGE_LEGACY" != true ]; then
            echo "No binding found: $BINDING_FILE"
            if [ -f "$LEGACY_METADATA" ]; then
                echo "Note: a legacy install remains here (resolves as 'binding-legacy')."
                echo "      To fully switch to central mode: ccskill-gmail unbind --purge-legacy"
            fi
            exit 0
        fi

        if [ "$YES_FLAG" != "--yes" ]; then
            if [ "$PURGE_LEGACY" = true ]; then
                read -p "Remove binding AND legacy install files in $GAS_DIR ? (y/N): " -n 1 -r
            else
                read -p "Remove binding $BINDING_FILE ? (y/N): " -n 1 -r
            fi
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Cancelled."
                exit 0
            fi
        fi

        if [ -f "$BINDING_FILE" ]; then
            /bin/rm -f "$BINDING_FILE"
            echo -e "${GREEN}✓ Unbound: $TARGET_DIR${NC}"
        fi

        if [ "$PURGE_LEGACY" = true ]; then
            # レガシー install のファイルを除去して中央モードに完全移行する (#126)。
            # 監査ログ (audit.jsonl*) と tmp/ は残す
            for f in .ccskill-metadata.json .clasp.json config.js endpoint api auth.sh history.sh api.sh .claspignore; do
                /bin/rm -f "$GAS_DIR/$f" 2>/dev/null || true
            done
            echo -e "${GREEN}✓ Legacy install files purged (audit log kept)${NC}"
            echo "This directory now follows the central account resolution (default account)."
        elif [ -f "$LEGACY_METADATA" ]; then
            echo ""
            echo -e "${YELLOW}Note: a legacy install remains in $GAS_DIR.${NC}"
            echo "Calls from this directory still resolve via the legacy metadata"
            echo "('binding-legacy' — its old per-project GAS endpoint), NOT the default account."
            echo "To fully switch to central mode: ccskill-gmail unbind --purge-legacy"
        fi
        ;;

    *)
        echo -e "${RED}Error: Unknown mode: $MODE${NC}"
        echo "Usage: ccskill-gmail bind <email|label> [DIR] [--yes]"
        echo "       ccskill-gmail unbind [DIR] [--yes]"
        exit 1
        ;;
esac
