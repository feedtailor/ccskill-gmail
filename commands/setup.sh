#!/bin/bash
#
# Gmail Skill - Setup
#
# One-time setup: installs clasp locally and creates a symlink
# so that 'ccskill-gmail' is available from anywhere.
#
# Usage: ./ccskill-gmail setup
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  Gmail Skill - Setup"
echo "================================================"
echo ""

# ========================================
# 0. ディスパッチャ経由チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo -e "${RED}Error: This script should be called via './ccskill-gmail setup'${NC}"
    exit 1
fi

# ========================================
# 1. npm チェック
# ========================================

echo "Checking prerequisites..."

if ! command -v npm &>/dev/null; then
    echo -e "${RED}Error: npm is not installed${NC}"
    echo ""
    echo "Node.js and npm are required."
    echo "Install from: https://nodejs.org/"
    exit 1
fi

echo -e "${GREEN}✓ npm found${NC}"

# ========================================
# 2. clasp ローカルインストール
# ========================================

echo ""
echo "Installing clasp locally..."

(cd "$CCSKILL_GMAIL_DIR" && npm install --no-fund --no-audit 2>&1) | tail -1
echo -e "${GREEN}✓ clasp installed (local)${NC}"

# ========================================
# 3. シンボリックリンク作成
# ========================================

echo ""
LINK_DIR="$HOME/.local/bin"
LINK_PATH="$LINK_DIR/ccskill-gmail"
DISPATCHER="$CCSKILL_GMAIL_DIR/ccskill-gmail"

# ~/.local/bin ディレクトリ作成
if [ ! -d "$LINK_DIR" ]; then
    mkdir -p "$LINK_DIR"
    echo "Created $LINK_DIR"
fi

# 既存シンボリックリンクの処理
if [ -L "$LINK_PATH" ]; then
    EXISTING_TARGET=$(readlink "$LINK_PATH")
    if [ "$EXISTING_TARGET" = "$DISPATCHER" ]; then
        echo -e "${GREEN}✓ Symlink already exists: $LINK_PATH${NC}"
    else
        echo -e "${YELLOW}Updating symlink: $LINK_PATH${NC}"
        echo "  Old: $EXISTING_TARGET"
        echo "  New: $DISPATCHER"
        ln -sf "$DISPATCHER" "$LINK_PATH"
        echo -e "${GREEN}✓ Symlink updated${NC}"
    fi
elif [ -e "$LINK_PATH" ]; then
    echo -e "${RED}Error: $LINK_PATH already exists and is not a symlink${NC}"
    echo "Please remove it manually and re-run setup."
    exit 1
else
    ln -s "$DISPATCHER" "$LINK_PATH"
    echo -e "${GREEN}✓ Symlink created: $LINK_PATH -> $DISPATCHER${NC}"
fi

# PATH チェック
if echo "$PATH" | tr ':' '\n' | grep -qx "$LINK_DIR"; then
    echo -e "${GREEN}✓ $LINK_DIR is in PATH${NC}"
else
    echo ""
    echo -e "${YELLOW}$LINK_DIR is not in your PATH.${NC}"
    echo ""
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        zsh)  RC_FILE="~/.zshrc" ;;
        bash) RC_FILE="~/.bashrc" ;;
        *)    RC_FILE="your shell config" ;;
    esac
    echo "Add this to $RC_FILE:"
    echo ""
    echo -e "  ${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
    echo "Then run:"
    echo ""
    echo -e "  ${BLUE}source $RC_FILE${NC}"
fi

# ========================================
# 完了
# ========================================

echo ""
echo "================================================"
echo -e "  ${GREEN}Setup complete!${NC}"
echo "================================================"
echo ""
echo -e "${YELLOW}Note:${NC} Tab completion may not work until you run 'hash -r'"
echo "or open a new terminal."
echo ""
echo "Next: install the skill to your project:"
echo ""
echo -e "  ${BLUE}cd /path/to/your-project${NC}"
echo -e "  ${BLUE}ccskill-gmail install${NC}"
echo ""
