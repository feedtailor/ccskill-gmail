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

# バージョン取得（タグがあればタグ、なければ短縮ハッシュ）
IS_GIT=0
if [ -d "$CCSKILL_GMAIL_DIR/.git" ]; then
    IS_GIT=1
    VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git describe --tags --always 2>/dev/null || echo "unknown")
else
    VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION" 2>/dev/null || echo "unknown")
fi
VERSION_LONG="$VERSION"

ZIPNAME="ccskill-gmail-${VERSION}.zip"
ZIPPATH="$OUTPUT_DIR/$ZIPNAME"

echo "Creating release: $ZIPNAME"
echo ""

# 既存 zip があれば作り直す（zip は既存アーカイブに追記するため）
rm -f "$ZIPPATH"

# VERSION ファイルを一時的に作成
echo "$VERSION" > "$CCSKILL_GMAIL_DIR/VERSION"

DIRNAME=$(basename "$CCSKILL_GMAIL_DIR")
PARENT=$(dirname "$CCSKILL_GMAIL_DIR")

if [ "$IS_GIT" -eq 1 ]; then
    # git 追跡ファイルのみを同梱する。これにより .DS_Store / log/ などの
    # ローカル産物や、追跡対象外の symlink が混入しない。
    # .claude/issues は開発用なので pathspec で除外する。
    (cd "$PARENT" && \
        { git -C "$DIRNAME" ls-files -- ':!.claude/issues/'; echo "VERSION"; } \
        | sed "s,^,$DIRNAME/," \
        | zip -q "$ZIPPATH" -@ )
else
    # 非 git（zip 再配布物からの再生成）: ワークツリーを zip 化しつつ開発用ファイルを除外
    (cd "$PARENT" && zip -rq "$ZIPPATH" "$DIRNAME" \
        -x "$DIRNAME/.git/*" \
        -x "*/.DS_Store" -x "$DIRNAME/.DS_Store" \
        -x "$DIRNAME/log/*" \
        -x "$DIRNAME/.claude/issues/*" \
        -x "$DIRNAME/.claude/settings.local.json" \
        -x "$DIRNAME/.claude/skills/nano-banana-pro/*" \
        -x "$DIRNAME/.entire/*" \
        -x "$DIRNAME/.registry.json" \
        -x "$DIRNAME/review_*.md" \
        -x "$DIRNAME/IDEAS-*.md" \
        -x "$DIRNAME/MEMORY.md" \
    )
fi

# VERSION ファイルを削除（git リポジトリでは不要）
if [ "$IS_GIT" -eq 1 ]; then
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
