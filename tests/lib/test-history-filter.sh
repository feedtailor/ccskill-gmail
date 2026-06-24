#!/bin/bash
#
# tests/lib/test-history-filter.sh - history list のフィルタ (#145)
#
# _ccskill_history_list の --action / --since フィルタが正しく動き、
# フィルタ値に二重引用符を含んでもクエリが壊れない (jq --arg 化) ことを検証する。
#
# Usage: bash tests/lib/test-history-filter.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/history.sh"

# audit.jsonl をフィクスチャに用意（action に二重引用符を含むエントリも入れる）
seed_history() {
    HISTDIR=$(test_mktemp_d)
    export CCSKILL_HISTORY_DIR="$HISTDIR"
    unset CCSKILL_HISTORY_DIRS
    cat > "$HISTDIR/audit.jsonl" <<'EOF'
{"action":"search","timestamp":"2026-06-24T01:00:00Z","subcommand":"get","identifiers":{"threadId":"T_SEARCH"},"response_ok":true,"duration_ms":100}
{"action":"get_thread","timestamp":"2026-06-24T02:00:00Z","subcommand":"get","identifiers":{"threadId":"T_THREAD"},"response_ok":true,"duration_ms":100}
{"action":"a\"b","timestamp":"2026-06-24T03:00:00Z","subcommand":"get","identifiers":{"threadId":"T_QUOTE"},"response_ok":true,"duration_ms":100}
EOF
}

reset_filters() {
    unset HISTORY_FILTER_ACTION HISTORY_FILTER_SINCE HISTORY_FILTER_ERRORS
}

# (1) --action フィルタが該当エントリのみ返す
test_filter_by_action() {
    seed_history
    reset_filters
    HISTORY_FILTER_ACTION="search"
    local out
    out=$(_ccskill_history_list 20 json)
    assert_contains "T_SEARCH" "$out" || return 1
    case "$out" in
        *T_THREAD*) echo "    unexpected T_THREAD in: $out" >&2; return 1 ;;
    esac
    return 0
}

# (2) フィルタ値に二重引用符を含んでもクエリが壊れない（--arg 化の核心）
#     旧実装（文字列連結）では jq パースエラーで該当が返らず失敗する
test_filter_value_with_quote() {
    seed_history
    reset_filters
    HISTORY_FILTER_ACTION='a"b'
    local out
    out=$(_ccskill_history_list 20 json)
    assert_contains "T_QUOTE" "$out"
}

# (3) --since フィルタが境界以降のみ返す
test_filter_since() {
    seed_history
    reset_filters
    HISTORY_FILTER_SINCE="2026-06-24T02:00:00Z"
    local out
    out=$(_ccskill_history_list 20 json)
    assert_contains "T_THREAD" "$out" || return 1
    assert_contains "T_QUOTE" "$out" || return 1
    case "$out" in
        *T_SEARCH*) echo "    unexpected T_SEARCH in: $out" >&2; return 1 ;;
    esac
    return 0
}

echo ""
echo "test-history-filter.sh (#145)"
echo ""

run_test "filter by action returns only matches"          test_filter_by_action
run_test "filter value with double-quote is safe (--arg)"  test_filter_value_with_quote
run_test "filter --since returns entries at/after bound"   test_filter_since

test_summary
