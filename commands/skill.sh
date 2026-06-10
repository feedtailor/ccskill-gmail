#!/bin/bash
#
# Gmail Skill - User Skill Registration (#124)
#
# Usage:
#   ccskill-gmail skill install [--copy]
#   ccskill-gmail skill uninstall [--yes]
#
# ~/.claude/skills/ccskill-gmail をマスターへの symlink として登録する。
# symlink ならマスターの git pull だけでスキルが最新化される。
# symlink が使えない環境向けに --copy (実体コピー) を用意する。
#
# 注意: ~/.claude/settings.json には一切触れない (設計判断 #121)。
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$CCSKILL_GMAIL_DIR" ] || [ ! -d "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via 'ccskill-gmail skill'${NC}"
    exit 1
fi

SRC="$CCSKILL_GMAIL_DIR/.claude/skills/ccskill-gmail"
DEST_PARENT="$HOME/.claude/skills"
DEST="$DEST_PARENT/ccskill-gmail"

show_usage() {
    cat << EOF
Usage: ccskill-gmail skill <subcommand> [options]

Subcommands:
  install [--copy]    Register as a user skill (~/.claude/skills/ccskill-gmail)
                      Default is a symlink to the master; --copy makes a real copy
  uninstall [--yes]   Remove the user skill registration
EOF
}

# 既存の DEST を取り除く (当スキル以外の実体ディレクトリは壊さない)
remove_existing() {
    if [ -L "$DEST" ]; then
        /bin/rm -f "$DEST"
    elif [ -d "$DEST" ]; then
        if [ -f "$DEST/SKILL.md" ]; then
            /bin/rm -rf "$DEST"
        else
            echo -e "${RED}Error: $DEST exists but does not look like ccskill-gmail (no SKILL.md).${NC}"
            echo "Remove it manually and re-run."
            exit 1
        fi
    elif [ -e "$DEST" ]; then
        echo -e "${RED}Error: $DEST exists and is not a directory/symlink.${NC}"
        echo "Remove it manually and re-run."
        exit 1
    fi
}

cmd_install() {
    local COPY=false
    for arg in "$@"; do
        case "$arg" in
            --copy) COPY=true ;;
            *)
                echo -e "${RED}Error: Unknown option: $arg${NC}"
                show_usage
                exit 1
                ;;
        esac
    done

    if [ ! -d "$SRC" ] || [ ! -f "$SRC/SKILL.md" ]; then
        echo -e "${RED}Error: skill source not found: $SRC${NC}"
        exit 1
    fi

    mkdir -p "$DEST_PARENT"
    remove_existing

    if [ "$COPY" = true ]; then
        cp -R "$SRC" "$DEST"
        echo -e "${GREEN}✓ User skill installed (copy): $DEST${NC}"
        echo ""
        echo "Note: copies do NOT auto-update. After updating the master, re-run:"
        echo "  ccskill-gmail skill install --copy"
    else
        ln -s "$SRC" "$DEST"
        if [ ! -f "$DEST/SKILL.md" ]; then
            # symlink を辿れない環境 → 掃除して --copy を案内
            /bin/rm -f "$DEST"
            echo -e "${RED}Error: symlink could not be resolved on this filesystem.${NC}"
            echo "Try the copy mode instead:"
            echo "  ccskill-gmail skill install --copy"
            exit 1
        fi
        echo -e "${GREEN}✓ User skill installed (symlink): $DEST${NC}"
        echo "  -> $SRC"
        echo ""
        echo "The skill stays up to date automatically when you git pull the master."
    fi

    echo ""
    echo "The Gmail skill is now available in every project."
    echo "Account setup (if not done yet):"
    echo -e "  ${BLUE}ccskill-gmail account add${NC}"
    echo ""
    echo "Note: ~/.claude/settings.json is NOT modified by this command."
    echo "In projects without ccskill-gmail installed, Claude Code may ask for"
    echo "confirmation before running 'ccskill-gmail api' commands."
}

cmd_uninstall() {
    local yes_flag=false
    for arg in "$@"; do
        case "$arg" in
            --yes) yes_flag=true ;;
        esac
    done

    if [ ! -e "$DEST" ] && [ ! -L "$DEST" ]; then
        echo "User skill is not installed: $DEST"
        exit 0
    fi

    if [ "$yes_flag" != true ]; then
        read -p "Remove user skill at $DEST ? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    remove_existing
    echo -e "${GREEN}✓ User skill removed${NC}"
}

SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
    install)
        cmd_install "$@"
        ;;
    uninstall)
        cmd_uninstall "$@"
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
