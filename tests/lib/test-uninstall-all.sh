#!/bin/bash
#
# tests/lib/test-uninstall-all.sh - central フル撤去 (#140)
#
# lib/teardown.sh の中核関数を、HOME をフィクスチャに差し替えて検証する。
# 実 GAS / clasp は伴わない（ファイル操作のみ）。
#
# Usage: bash tests/lib/test-uninstall-all.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

load_teardown_lib() {
    CCSKILL_GMAIL_DIR="$REPO_DIR"
    export CCSKILL_GMAIL_DIR
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/teardown.sh"
}

# central footprint をフィクスチャ HOME に作る
make_footprint() {
    HOME=$(test_mktemp_d)
    export HOME
    mkdir -p "$HOME/.claude/skills"
    ln -s "$REPO_DIR/.claude/skills/ccskill-gmail" "$HOME/.claude/skills/ccskill-gmail"
    mkdir -p "$HOME/.ccskill-gmail/gas/acct" "$HOME/.ccskill-gmail/history"
    printf '{"schema_version":"2.0","default_account":"a@x","accounts":{"a@x":{}}}\n' \
        > "$HOME/.ccskill-gmail/accounts.json"
    mkdir -p "$HOME/.local/bin"
    ln -s "$REPO_DIR/ccskill-gmail" "$HOME/.local/bin/ccskill-gmail"
    printf '{"tokens":{}}\n' > "$HOME/.clasprc.json"
}

# ========================================
# 列挙
# ========================================

test_list_targets_includes_all_three() {
    make_footprint
    load_teardown_lib
    local out
    out=$(teardown_list_targets)
    assert_contains "skill:" "$out" || return 1
    assert_contains "registry:" "$out" || return 1
    assert_contains "cli:" "$out"
}

# ========================================
# dry-run は何も消さない
# ========================================

test_dry_run_removes_nothing() {
    make_footprint
    load_teardown_lib
    teardown_execute true
    [ -d "$HOME/.ccskill-gmail" ] || { echo "registry removed in dry-run" >&2; return 1; }
    [ -L "$HOME/.claude/skills/ccskill-gmail" ] || { echo "skill removed in dry-run" >&2; return 1; }
    [ -L "$HOME/.local/bin/ccskill-gmail" ] || { echo "cli removed in dry-run" >&2; return 1; }
}

# ========================================
# 実削除: 3 対象が消え、clasprc は残る
# ========================================

test_execute_removes_targets_keeps_clasprc() {
    make_footprint
    load_teardown_lib
    teardown_execute false
    [ ! -e "$HOME/.claude/skills/ccskill-gmail" ] || { echo "skill not removed" >&2; return 1; }
    [ ! -d "$HOME/.ccskill-gmail" ] || { echo "registry not removed" >&2; return 1; }
    [ ! -e "$HOME/.local/bin/ccskill-gmail" ] || { echo "cli not removed" >&2; return 1; }
    assert_file_exists "$HOME/.clasprc.json"
}

# ========================================
# CLI symlink が自分のものでなければ消さない
# ========================================

test_foreign_cli_link_is_kept() {
    make_footprint
    load_teardown_lib
    # symlink を別実体に張り替える
    rm -f "$HOME/.local/bin/ccskill-gmail"
    ln -s "/bin/ls" "$HOME/.local/bin/ccskill-gmail"
    teardown_execute false
    [ -L "$HOME/.local/bin/ccskill-gmail" ] || { echo "foreign cli link was removed" >&2; return 1; }
}

# ========================================
# 対象不在でも冪等
# ========================================

test_idempotent_on_empty_home() {
    HOME=$(test_mktemp_d)
    export HOME
    load_teardown_lib
    teardown_execute false   # 何も無い状態で実行してもエラーにならない
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-uninstall-all.sh (#140)"
echo ""

run_test "list: includes skill / registry / cli"        test_list_targets_includes_all_three
run_test "dry-run: removes nothing"                      test_dry_run_removes_nothing
run_test "execute: removes targets, keeps clasprc"       test_execute_removes_targets_keeps_clasprc
run_test "execute: foreign cli symlink is kept"          test_foreign_cli_link_is_kept
run_test "execute: idempotent on empty HOME"             test_idempotent_on_empty_home

test_summary
