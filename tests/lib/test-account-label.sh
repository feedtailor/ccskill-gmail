#!/bin/bash
#
# tests/lib/test-account-label.sh - account add の認証後ラベル指定 (#138)
#
# accounts_validate_label / accounts_label_exists / accounts_prompt_label の
# ユニットテスト。HOME をフィクスチャに差し替えてオフラインで実行する。
#
# Usage: bash tests/lib/test-account-label.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# ========================================
# ヘルパー
# ========================================

use_fixture_home() {
    HOME=$(test_mktemp_d)
    export HOME
}

load_accounts_lib() {
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
}

add_account() {
    accounts_upsert "$1" "$2" "script-id-x" "deploy-id-x" "https://example.invalid/exec" "${3:-}"
}

# ========================================
# accounts_validate_label
# ========================================

test_validate_label_empty_is_ok() {
    use_fixture_home
    load_accounts_lib
    accounts_validate_label ""
}

test_validate_label_accepts_valid() {
    use_fixture_home
    load_accounts_lib
    accounts_validate_label "work" || return 1
    accounts_validate_label "info-ft" || return 1
    accounts_validate_label "personal2" || return 1
    accounts_validate_label "a_b-C9"
}

test_validate_label_rejects_invalid() {
    use_fixture_home
    load_accounts_lib
    local rc=0
    accounts_validate_label "a b" || rc=$?
    assert_eq "1" "$rc" || return 1
    rc=0; accounts_validate_label "a@b" || rc=$?
    assert_eq "1" "$rc" || return 1
    rc=0; accounts_validate_label "ラベル" || rc=$?
    assert_eq "1" "$rc"
}

# ========================================
# accounts_label_exists
# ========================================

test_label_exists_true_for_registered() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    accounts_label_exists "work"
}

test_label_exists_false_for_unused() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    local rc=0
    accounts_label_exists "personal" || rc=$?
    assert_eq "1" "$rc"
}

test_label_exists_does_not_match_null_label() {
    use_fixture_home
    load_accounts_lib
    # a は label なし (null)。空文字での誤マッチがないことを確認
    add_account "a@example.com" "ccskill-acct-a"
    local rc=0
    accounts_label_exists "" || rc=$?
    assert_eq "1" "$rc"
}

# ========================================
# accounts_prompt_label (stdin から読む対話ループ)
# ========================================

test_prompt_label_first_input_valid() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local out
    out=$(printf 'work\n' | accounts_prompt_label "x@example.com" 2>/dev/null)
    assert_eq "work" "$out"
}

test_prompt_label_reprompts_on_invalid() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local out
    out=$(printf 'a b\nwork\n' | accounts_prompt_label "x@example.com" 2>/dev/null)
    assert_eq "work" "$out"
}

test_prompt_label_reprompts_on_duplicate() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    add_account "b@example.com" "ccskill-acct-b" "work"
    local out
    out=$(printf 'work\npersonal\n' | accounts_prompt_label "x@example.com" 2>/dev/null)
    assert_eq "personal" "$out"
}

test_prompt_label_empty_input_returns_empty() {
    use_fixture_home
    load_accounts_lib
    add_account "a@example.com" "ccskill-acct-a"
    local out
    out=$(printf '\n' | accounts_prompt_label "x@example.com" 2>/dev/null)
    assert_eq "" "$out"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-account-label.sh (#138)"
echo ""

run_test "validate_label: empty is ok"                     test_validate_label_empty_is_ok
run_test "validate_label: accepts valid labels"            test_validate_label_accepts_valid
run_test "validate_label: rejects invalid labels"          test_validate_label_rejects_invalid
run_test "label_exists: true for registered label"         test_label_exists_true_for_registered
run_test "label_exists: false for unused label"            test_label_exists_false_for_unused
run_test "label_exists: does not match null label"         test_label_exists_does_not_match_null_label
run_test "prompt_label: first valid input is taken"        test_prompt_label_first_input_valid
run_test "prompt_label: reprompts on invalid input"        test_prompt_label_reprompts_on_invalid
run_test "prompt_label: reprompts on duplicate label"      test_prompt_label_reprompts_on_duplicate
run_test "prompt_label: empty input returns empty"         test_prompt_label_empty_input_returns_empty

test_summary
