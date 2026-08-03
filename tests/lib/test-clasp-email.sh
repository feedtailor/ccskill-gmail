#!/bin/bash
#
# tests/lib/test-clasp-email.sh - clasp show-authorized-user のメール抽出 (#150)
#
# clasp_parse_authorized_email: `clasp show-authorized-user` の出力(stdin)から
# ログイン中の Google アカウントのメールを取り出す。account add の重複登録ガードで
# GAS 作成前にメールを確定するために使う。
#
# Usage: bash tests/lib/test-clasp-email.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/clasp.sh"

# ========================================
# テスト
# ========================================

test_simple_email() {
    local out
    out=$(printf 'You are logged in as oishi@feedtailor.jp.\n' | clasp_parse_authorized_email)
    assert_eq "oishi@feedtailor.jp" "$out"
}

test_email_with_trailing_error_lines() {
    # 実機（sandbox）で観測した形: メール行のあとにトークン書き込みエラーが続く
    local out
    out=$(printf '%s\n' \
        'You are logged in as info@feedtailor.jp.' \
        "Error: EPERM: operation not permitted, open '/Users/oishi/.clasprc.json'" \
        '    at Object.writeFileSync (node:fs:2398:20)' \
        | clasp_parse_authorized_email)
    assert_eq "info@feedtailor.jp" "$out"
}

test_dotted_localpart() {
    local out
    out=$(printf 'You are logged in as oishi.yuichi@gmail.com.\n' | clasp_parse_authorized_email)
    assert_eq "oishi.yuichi@gmail.com" "$out"
}

test_not_logged_in_is_empty() {
    local out
    out=$(printf 'You are not logged in.\n' | clasp_parse_authorized_email)
    assert_eq "" "$out"
}

test_empty_input_is_empty() {
    local out
    out=$(printf '' | clasp_parse_authorized_email)
    assert_eq "" "$out"
}

test_only_first_match() {
    local out
    out=$(printf '%s\n' \
        'You are logged in as first@example.com.' \
        'You are logged in as second@example.com.' \
        | clasp_parse_authorized_email)
    assert_eq "first@example.com" "$out"
}

# ========================================
# clasp_login_check (#153)
#
# doctor.sh は従来 `grep -qi "not logged in"` の有無だけで PASS/FAIL を
# 決めており、_clasp の実行自体が別の理由（モジュール欠落等）で失敗した
# 場合に、その出力が「not logged in」という文言を含まないという理由だけで
# 誤って「ログイン済み」と表示してしまっていた。
# clasp_login_check は「有効なメールアドレスが取り出せたか」だけで判定
# することで、失敗理由を問わず一貫して FAIL を返す。
# ========================================

test_login_check_success() {
    local email
    email=$(clasp_login_check 'You are logged in as oishi@feedtailor.jp.')
    assert_exit_code 0 "$?" || return 1
    assert_eq "oishi@feedtailor.jp" "$email"
}

test_login_check_not_logged_in_fails() {
    clasp_login_check 'You are not logged in.' >/dev/null
    assert_exit_code 1 "$?"
}

test_login_check_execution_error_fails() {
    # #153 で実際に観測した状況の再現: _clasp が「not logged in」という
    # 文言を含まないエラーで異常終了するケース。これを「ログイン済み」と
    # 誤判定しないことを確認する。
    local crash_output
    crash_output=$(printf '%s\n' \
        "Error [ERR_MODULE_NOT_FOUND]: Cannot find module '.../open-credentials.js'" \
        "    at finalizeResolution (node:internal/modules/esm/resolve:271:11)")
    clasp_login_check "$crash_output" >/dev/null
    assert_exit_code 1 "$?"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-clasp-email.sh (#150, #153)"
echo ""

run_test "extracts simple email"                     test_simple_email
run_test "extracts email despite trailing errors"    test_email_with_trailing_error_lines
run_test "extracts dotted local-part email"          test_dotted_localpart
run_test "not logged in -> empty"                    test_not_logged_in_is_empty
run_test "empty input -> empty"                      test_empty_input_is_empty
run_test "takes only the first match"                test_only_first_match
run_test "login check succeeds with valid email"       test_login_check_success
run_test "login check fails when not logged in"        test_login_check_not_logged_in_fails
run_test "login check fails on unrelated crash output" test_login_check_execution_error_fails

test_summary
