#!/bin/bash
#
# tests/lib/test-accounts.sh - lib/accounts.sh と account コマンドのテスト (#123)
#
# HOME をフィクスチャに差し替えてオフラインで実行する。
#
# Usage: bash tests/lib/test-accounts.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# ========================================
# ヘルパー
# ========================================

# 隔離 HOME を作って export する (run_test はサブシェル実行なので親に漏れない)
use_fixture_home() {
    HOME=$(test_mktemp_d)
    export HOME
}

load_accounts_lib() {
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
}

# upsert ショートハンド: email clasp_user label
add_account() {
    accounts_upsert "$1" "$2" "script-id-x" "deploy-id-x" "https://example.invalid/exec" "${3:-}"
}

# ========================================
# accounts.sh CRUD
# ========================================

test_init_creates_schema() {
    use_fixture_home
    load_accounts_lib
    accounts_init
    assert_file_exists "$HOME/.ccskill-gmail/accounts.json" || return 1
    local sv
    sv=$(jq -r '.schema_version' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "2.0" "$sv"
}

test_first_account_becomes_default() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local def
    def=$(jq -r '.default_account' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "a@example.com" "$def"
}

test_second_account_keeps_default() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    local def count
    def=$(jq -r '.default_account' "$HOME/.ccskill-gmail/accounts.json")
    count=$(jq -r '.accounts | length' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "a@example.com" "$def" || return 1
    assert_eq "2" "$count"
}

test_get_by_email_and_label() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    local by_email by_label
    by_email=$(accounts_get "a@example.com" | jq -r '.email')
    by_label=$(accounts_get "work" | jq -r '.email')
    assert_eq "a@example.com" "$by_email" || return 1
    assert_eq "b@example.com" "$by_label"
}

test_get_unknown_fails() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local rc=0
    accounts_get "nobody@example.com" >/dev/null 2>&1 || rc=$?
    assert_eq "1" "$rc"
}

test_set_default_by_label() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    accounts_set_default "work"
    local def
    def=$(jq -r '.default_account' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "b@example.com" "$def"
}

test_remove_default_falls_back_to_sole_remaining() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    accounts_remove "a@example.com"
    local def count
    def=$(jq -r '.default_account' "$HOME/.ccskill-gmail/accounts.json")
    count=$(jq -r '.accounts | length' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "b@example.com" "$def" || return 1
    assert_eq "1" "$count"
}

test_corrupted_file_is_backed_up() {
    use_fixture_home
    load_accounts_lib
    mkdir -p "$HOME/.ccskill-gmail"
    echo "NOT JSON" > "$HOME/.ccskill-gmail/accounts.json"
    accounts_init
    local sv
    sv=$(jq -r '.schema_version' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "2.0" "$sv" || return 1
    ls "$HOME/.ccskill-gmail/"accounts.json.bak.* >/dev/null 2>&1
}

test_resolve_default_prefers_default_then_single() {
    use_fixture_home
    load_accounts_lib
    # アカウント 1 件 + default_account を null に細工 → single 解決
    add_account "a@example.com" "ccskill-acct-a"
    local tmp
    tmp=$(test_mktemp)
    jq '.default_account = null' "$HOME/.ccskill-gmail/accounts.json" > "$tmp"
    /bin/mv "$tmp" "$HOME/.ccskill-gmail/accounts.json"
    local resolved
    resolved=$(accounts_resolve_default)
    assert_eq "a@example.com" "$resolved"
}

# ========================================
# account コマンド (list / default / remove)
# ========================================

test_cmd_list_shows_accounts() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    local out
    out=$("$REPO_DIR/ccskill-gmail" account list 2>&1) || return 1
    assert_contains "a@example.com" "$out" || return 1
    assert_contains "b@example.com" "$out" || return 1
    assert_contains "work" "$out"
}

test_cmd_default_switches() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    "$REPO_DIR/ccskill-gmail" account default work >/dev/null 2>&1 || return 1
    local def
    def=$(jq -r '.default_account' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "b@example.com" "$def"
}

test_cmd_remove_with_yes() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    "$REPO_DIR/ccskill-gmail" account remove b@example.com --yes >/dev/null 2>&1 || return 1
    local count
    count=$(jq -r '.accounts | length' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "1" "$count"
}

test_cmd_default_unknown_fails() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local rc=0
    "$REPO_DIR/ccskill-gmail" account default nobody >/dev/null 2>&1 || rc=$?
    [ "$rc" -ne 0 ]
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-accounts.sh (#123)"
echo ""

run_test "init: creates schema 2.0 file"                       test_init_creates_schema
run_test "upsert: first account becomes default"               test_first_account_becomes_default
run_test "upsert: second account keeps default"                test_second_account_keeps_default
run_test "get: resolves by email and by label"                 test_get_by_email_and_label
run_test "get: unknown identifier fails"                       test_get_unknown_fails
run_test "set_default: switches by label"                      test_set_default_by_label
run_test "remove: default falls back to sole remaining"        test_remove_default_falls_back_to_sole_remaining
run_test "init: corrupted file is backed up"                   test_corrupted_file_is_backed_up
run_test "resolve_default: falls back to single account"       test_resolve_default_prefers_default_then_single
run_test "cmd: account list shows accounts"                    test_cmd_list_shows_accounts
run_test "cmd: account default switches"                       test_cmd_default_switches
run_test "cmd: account remove --yes"                           test_cmd_remove_with_yes
run_test "cmd: account default unknown fails"                  test_cmd_default_unknown_fails

test_summary
