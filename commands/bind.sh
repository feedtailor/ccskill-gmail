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

# 共通引数パース: 位置引数と --yes
POSITIONAL=()
YES_FLAG=""
for arg in "$@"; do
    case "$arg" in
        --yes|-y) YES_FLAG="--yes" ;;
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
        BINDING_FILE="$TARGET_DIR/.ccskill-gmail/binding.json"

        if [ ! -f "$BINDING_FILE" ]; then
            echo "No binding found: $BINDING_FILE"
            exit 0
        fi

        if [ "$YES_FLAG" != "--yes" ]; then
            read -p "Remove binding $BINDING_FILE ? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Cancelled."
                exit 0
            fi
        fi

        /bin/rm -f "$BINDING_FILE"
        echo -e "${GREEN}✓ Unbound: $TARGET_DIR${NC}"
        ;;

    *)
        echo -e "${RED}Error: Unknown mode: $MODE${NC}"
        echo "Usage: ccskill-gmail bind <email|label> [DIR] [--yes]"
        echo "       ccskill-gmail unbind [DIR] [--yes]"
        exit 1
        ;;
esac
