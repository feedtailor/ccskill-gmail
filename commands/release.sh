#!/bin/bash
#
# ccskill-gmail release - Create a distributable zip file
#
# Usage: ccskill-gmail release [OUTPUT_DIR]
#
# Creates a zip file suitable for distribution to users who don't have
# access to the git repository. The VERSION file is auto-generated.
#

set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail release'"
    exit 1
fi

OUTPUT_DIR="${1:-.}"

# バージョン取得
if [ -d "$CCSKILL_GMAIL_DIR/.git" ]; then
    VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    VERSION_LONG=$(cd "$CCSKILL_GMAIL_DIR" && git describe --tags --always 2>/dev/null || echo "$VERSION")
else
    VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION" 2>/dev/null || echo "unknown")
    VERSION_LONG="$VERSION"
fi

ZIPNAME="ccskill-gmail-${VERSION}.zip"
ZIPPATH="$OUTPUT_DIR/$ZIPNAME"

echo "Creating release: $ZIPNAME"
echo ""

# VERSION ファイルを一時的に作成
echo "$VERSION" > "$CCSKILL_GMAIL_DIR/VERSION"

# zip 作成（開発用ファイルを除外）
(cd "$(dirname "$CCSKILL_GMAIL_DIR")" && zip -r "$ZIPPATH" "$(basename "$CCSKILL_GMAIL_DIR")" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/.git/*" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/.claude/issues/*" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/.claude/settings.local.json" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/.entire/*" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/.registry.json" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/review_*.md" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/IDEAS-*.md" \
    -x "$(basename "$CCSKILL_GMAIL_DIR")/MEMORY.md" \
)

# VERSION ファイルを削除（git リポジトリでは不要）
if [ -d "$CCSKILL_GMAIL_DIR/.git" ]; then
    rm -f "$CCSKILL_GMAIL_DIR/VERSION"
fi

echo ""
echo -e "${GREEN}✓ Release created: $ZIPPATH${NC}"
echo "  Version: $VERSION_LONG"
echo ""
echo "Distribution instructions:"
echo "  1. Send $ZIPNAME to the user"
echo "  2. User extracts:   unzip $ZIPNAME"
echo "  3. User runs setup: cd ccskill-gmail && ./ccskill-gmail setup"
echo "     (setup also registers the skill and the Gmail account)"
