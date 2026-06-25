#!/bin/bash
#
# tests/lib/test-release-hygiene.sh - 配布 zip の健全性テスト
#
# `ccskill-gmail release` が生成する配布 zip に、git 管理外のローカル産物
# （.DS_Store / log/ / ローカルスキルへの symlink 等）が混入しないことを検証する。
# 製品ファイルと VERSION は含まれること、VERSION の中身がタグ由来であることも確認する。
#
# Usage: bash tests/lib/test-release-hygiene.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# release を実行し、生成された zip の中身一覧を ZIP_LIST に格納する。
# 失敗時に詳細を出せるよう RELEASE_OUT も保持する。
ZIP_LIST=""
ZIP_VERSION=""
ZIP_PATH=""
build_release() {
    local out
    out=$(test_mktemp_d)
    ZIP_VERSION=$(cd "$REPO_DIR" && git describe --tags --always 2>/dev/null || echo unknown)
    ZIP_PATH="$out/ccskill-gmail-${ZIP_VERSION}.zip"
    RELEASE_OUT=$(cd "$REPO_DIR" && "$REPO_DIR/ccskill-gmail" release "$out" 2>&1) || return 1
    [ -f "$ZIP_PATH" ] || { echo "    zip not created: $ZIP_PATH" >&2; echo "$RELEASE_OUT" >&2; return 1; }
    ZIP_LIST=$(unzip -Z1 "$ZIP_PATH")
}

# (1) ローカル skill への symlink (nano-banana-pro) を含まない
test_no_stray_skill_symlink() {
    build_release || return 1
    case "$ZIP_LIST" in
        *nano-banana-pro*) echo "    zip contains stray skill: nano-banana-pro" >&2; return 1 ;;
    esac
}

# (2) OS / 開発ローカル産物 (.DS_Store, log/) を含まない
test_no_local_junk() {
    build_release || return 1
    case "$ZIP_LIST" in
        *.DS_Store*) echo "    zip contains .DS_Store" >&2; return 1 ;;
    esac
    case "$ZIP_LIST" in
        */log/*) echo "    zip contains log/ artifacts" >&2; return 1 ;;
    esac
}

# (3) 製品ファイルと VERSION は含む
test_has_product_files() {
    build_release || return 1
    assert_contains "ccskill-gmail/README.md" "$ZIP_LIST" || return 1
    assert_contains "ccskill-gmail/.claude/skills/ccskill-gmail/SKILL.md" "$ZIP_LIST" || return 1
    assert_contains "ccskill-gmail/VERSION" "$ZIP_LIST" || return 1
}

# (4) VERSION の中身が git describe（タグ）由来
test_version_content_is_tag() {
    build_release || return 1
    local content
    content=$(unzip -p "$ZIP_PATH" ccskill-gmail/VERSION | tr -d '\n')
    assert_eq "$ZIP_VERSION" "$content" "VERSION should match git describe"
}

echo ""
echo "test-release-hygiene.sh"
echo ""

run_test "release zip: no stray skill symlink (nano-banana-pro)" test_no_stray_skill_symlink
run_test "release zip: no .DS_Store / log artifacts"            test_no_local_junk
run_test "release zip: contains product files + VERSION"        test_has_product_files
run_test "release zip: VERSION content is the tag"              test_version_content_is_tag

test_summary
