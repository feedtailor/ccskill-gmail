#!/bin/bash
#
# tests/lib/test-history-central.sh - 監査ログのアカウント別中央集約のテスト (#125)
#
# Usage: bash tests/lib/test-history-central.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

use_fixture_home() {
    HOME=$(test_mktemp_d)
    export HOME
}

seed_account() {
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "$1" "clasp-$1" "sid" "did" "https://example.invalid/exec" "${2:-}"
}

api_in() {
    local dir="$1"
    shift
    (cd "$dir" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" "$@" >/dev/null 2>&1) || true
}

# (1) レジストリ解決 (default) の呼び出しが中央履歴に記録される
test_central_history_written() {
    use_fixture_home
    seed_account "a@example.com"
    local empty
    empty=$(test_mktemp_d)
    api_in "$empty" api get action=search
    assert_file_exists "$HOME/.ccskill-gmail/history/a@example.com/audit.jsonl"
}

# (2) 記録に account フィールドが入る
test_record_has_account_field() {
    use_fixture_home
    seed_account "a@example.com"
    local empty acct
    empty=$(test_mktemp_d)
    api_in "$empty" api get action=search
    acct=$(tail -1 "$HOME/.ccskill-gmail/history/a@example.com/audit.jsonl" 2>/dev/null | jq -r '.account // empty')
    assert_eq "a@example.com" "$acct"
}

# (3) --account 指定の呼び出しはそのアカウントのディレクトリに記録される
test_flag_call_recorded_per_account() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local empty
    empty=$(test_mktemp_d)
    api_in "$empty" api --account work get action=search
    assert_file_exists "$HOME/.ccskill-gmail/history/b@example.com/audit.jsonl" || return 1
    [ ! -f "$HOME/.ccskill-gmail/history/a@example.com/audit.jsonl" ]
}

# (4) レガシーメタデータ経由は従来どおりプロジェクト配下に記録される (中央には書かない)
test_legacy_stays_in_project() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.ccskill-gmail"
    printf '{"installed_from":"%s","endpoint":"https://example.invalid/exec","clasp_user":"cgtest"}\n' "$REPO_DIR" \
        > "$proj/.ccskill-gmail/.ccskill-metadata.json"
    api_in "$proj" api get action=search
    assert_file_exists "$proj/.ccskill-gmail/audit.jsonl" || return 1
    [ ! -d "$HOME/.ccskill-gmail/history" ]
}

# (5) history list --account で未インストールディレクトリから閲覧できる
test_history_list_by_account() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out
    empty=$(test_mktemp_d)
    api_in "$empty" api get action=search
    out=$(cd "$empty" && "$REPO_DIR/ccskill-gmail" history list --json --account a@example.com 2>&1) || return 1
    assert_contains '"action":"search"' "$out" || return 1
    assert_contains '"account":"a@example.com"' "$out"
}

# (6) 未インストールディレクトリで history (引数なし) が中央履歴を表示する
test_history_default_central() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out
    empty=$(test_mktemp_d)
    api_in "$empty" api get action=search
    out=$(cd "$empty" && "$REPO_DIR/ccskill-gmail" history list --json 2>&1) || return 1
    assert_contains '"action":"search"' "$out"
}

echo ""
echo "test-history-central.sh (#125)"
echo ""

run_test "central history written for registry-resolved call"  test_central_history_written
run_test "record has account field"                            test_record_has_account_field
run_test "--account call recorded under that account"          test_flag_call_recorded_per_account
run_test "legacy metadata call stays in project dir"           test_legacy_stays_in_project
run_test "history list --account works without install"        test_history_list_by_account
run_test "history list defaults to central without install"    test_history_default_central

test_summary
