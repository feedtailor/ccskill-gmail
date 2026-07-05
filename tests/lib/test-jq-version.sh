#!/bin/bash
#
# tests/lib/test-jq-version.sh - jq バージョン判定の単体テスト (#148)
#
# jq_version_is_old: `jq --version` の生出力を受け取り、1.6 未満なら 0(古い)。
# doctor の jq バージョン警告に使う。境界値と不明形式での誤警告防止を検証する。
#
# Usage: bash tests/lib/test-jq-version.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/jq_version.sh"

# assert_old RAW  → 古い(<1.6)と判定されること
assert_old() {
    local raw="$1" rc=0
    jq_version_is_old "$raw" || rc=$?
    assert_eq "0" "$rc" "expected '$raw' to be OLD (<1.6)"
}

# assert_not_old RAW  → 古くない(>=1.6 または不明)と判定されること
assert_not_old() {
    local raw="$1" rc=0
    jq_version_is_old "$raw" || rc=$?
    assert_eq "1" "$rc" "expected '$raw' to be NOT old"
}

# ========================================
# テスト
# ========================================

test_old_versions() {
    assert_old "jq-1.5"   || return 1
    assert_old "jq-1.5.1" || return 1
    assert_old "jq-1.4"   || return 1
    assert_old "jq-1.0"   || return 1
    assert_old "jq-1.5-apple"
}

test_ok_versions() {
    assert_not_old "jq-1.6"          || return 1
    assert_not_old "jq-1.6.1"        || return 1
    assert_not_old "jq-1.7"          || return 1
    assert_not_old "jq-1.7.1-apple"  || return 1
    assert_not_old "jq-2.0"          || return 1
    assert_not_old "jq-1.10"
}

test_unknown_does_not_warn() {
    assert_not_old "unknown"  || return 1
    assert_not_old ""         || return 1
    assert_not_old "jq-"      || return 1
    assert_not_old "garbage"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-jq-version.sh (#148)"
echo ""

run_test "old versions (<1.6) are flagged"          test_old_versions
run_test "1.6+ versions are not flagged"            test_ok_versions
run_test "unknown/empty formats do not false-warn"  test_unknown_does_not_warn

test_summary
