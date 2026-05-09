#!/bin/bash
#
# tests/lib/test-update-check-call-sites.sh
#
# commands/*.sh が fetch あり版 (update_check_format_oneline) を直接呼んでいないことを
# 静的に検証する。fetch あり版はディスパッチャ経由のみで使用するべき
# (#111 で導入した規約)。
#
# 背景: ディスパッチャ (ccskill-gmail) で既にキャッシュベースのバージョン行を組み立てて
# いるため、各コマンド末尾で fetch あり版を再度呼ぶと、毎回 git fetch が走り、
# パスフレーズ付き SSH 鍵やオフライン環境で UX を阻害する。
#
# Usage: bash tests/lib/test-update-check-call-sites.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/test-helper.sh"

echo "Running update-check call-site tests..."
echo ""

# fetch あり版を呼んでよいファイル (allowlist)
# - 関数定義そのもの (lib/update_check.sh)
# - 自分自身のテスト (tests/lib/test-update-check.sh)
# - 本テストファイル自身 (このファイル)
# それ以外で update_check_format_oneline (cached なし) を直接呼ぶ箇所があれば NG。

assert_no_unwrapped_fetch_caller() {
    local file="$1"
    # fetch あり版 = "update_check_format_oneline" の直後が空白か行末 (cached が続かない)
    # _cached が続くものは除外
    local hits
    hits=$(grep -nE 'update_check_format_oneline([^_a-zA-Z]|$)' "$file" 2>/dev/null || true)
    if [ -z "$hits" ]; then
        return 0
    fi
    # コメント行 (#) は除外
    hits=$(echo "$hits" | grep -vE '^[[:space:]]*[0-9]+:[[:space:]]*#' || true)
    if [ -z "$hits" ]; then
        return 0
    fi
    {
        echo "    $file が fetch あり版 update_check_format_oneline を呼んでいます:"
        echo "$hits" | sed 's/^/      /'
        echo "    → update_check_format_oneline_cached に切り替えてください"
    } >&2
    return 1
}

test_info_uses_cached_only() {
    assert_no_unwrapped_fetch_caller "$REPO_ROOT/commands/info.sh"
}

test_install_uses_cached_only() {
    assert_no_unwrapped_fetch_caller "$REPO_ROOT/commands/install.sh"
}

test_doctor_uses_cached_only() {
    assert_no_unwrapped_fetch_caller "$REPO_ROOT/commands/doctor.sh"
}

test_status_uses_cached_only() {
    assert_no_unwrapped_fetch_caller "$REPO_ROOT/commands/status.sh"
}

# 念のため、ディスパッチャだけは cached 版を使っていることを確認 (regression 防止)
test_dispatcher_uses_cached() {
    local file="$REPO_ROOT/ccskill-gmail"
    if grep -qE 'update_check_format_oneline_cached' "$file"; then
        return 0
    fi
    {
        echo "    ディスパッチャ ($file) が update_check_format_oneline_cached を呼んでいません"
    } >&2
    return 1
}

run_test "info.sh は fetch あり版を直接呼ばない" test_info_uses_cached_only
run_test "install.sh は fetch あり版を直接呼ばない" test_install_uses_cached_only
run_test "doctor.sh は fetch あり版を直接呼ばない" test_doctor_uses_cached_only
run_test "status.sh は fetch あり版を直接呼ばない" test_status_uses_cached_only
run_test "ディスパッチャは cached 版を呼んでいる" test_dispatcher_uses_cached

test_summary
