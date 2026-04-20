#!/bin/bash
#
# tests/lib/test-helper.sh - シェル関数の単体テスト用簡易ヘルパー
#
# Usage:
#   source tests/lib/test-helper.sh
#   run_test "case name" my_test_func
#   ...
#   test_summary
#

TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_NC='\033[0m'

TEST_PASS=0
TEST_FAIL=0
TEST_TOTAL=0

# Sandbox-friendly mktemp ラッパー
# 引数なし mktemp は macOS では /var/folders/... を使うが、sandbox では拒否されるため
# 必ず TMPDIR 配下にテンプレートを切る
test_mktemp() {
    local tmpdir="${TMPDIR:-/tmp}"
    mktemp "$tmpdir/cgtest.XXXXXXXX"
}

test_mktemp_d() {
    local tmpdir="${TMPDIR:-/tmp}"
    mktemp -d "$tmpdir/cgtest.XXXXXXXX"
}

test_mktemp_u() {
    local tmpdir="${TMPDIR:-/tmp}"
    mktemp -u "$tmpdir/cgtest.XXXXXXXX"
}

# 失敗詳細の蓄積（後でまとめて表示）
TEST_FAIL_DETAILS=""

# assert_eq EXPECTED ACTUAL [MSG]
# 等しければ 0、異なれば詳細を stderr に出して 1
assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        return 0
    fi
    {
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
        [ -n "$msg" ] && echo "    note:     $msg"
    } >&2
    return 1
}

# assert_contains NEEDLE HAYSTACK
assert_contains() {
    local needle="$1"
    local haystack="$2"
    case "$haystack" in
        *"$needle"*) return 0 ;;
        *)
            {
                echo "    expected to contain: '$needle'"
                echo "    in: '$haystack'"
            } >&2
            return 1
            ;;
    esac
}

# assert_exit_code EXPECTED ACTUAL
assert_exit_code() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" = "$actual" ]; then
        return 0
    fi
    {
        echo "    expected exit code: $expected"
        echo "    actual exit code:   $actual"
    } >&2
    return 1
}

# assert_file_exists PATH
assert_file_exists() {
    local path="$1"
    if [ -f "$path" ]; then
        return 0
    fi
    echo "    expected file to exist: $path" >&2
    return 1
}

# run_test "name" test_func
# テスト関数を実行し、結果を表示
run_test() {
    local name="$1"
    local fn="$2"
    TEST_TOTAL=$((TEST_TOTAL + 1))

    local stderr_file
    stderr_file=$(test_mktemp)

    if ( "$fn" ) 2>"$stderr_file"; then
        TEST_PASS=$((TEST_PASS + 1))
        printf "  ${TEST_GREEN}✓${TEST_NC} %s\n" "$name"
    else
        TEST_FAIL=$((TEST_FAIL + 1))
        printf "  ${TEST_RED}✗${TEST_NC} %s\n" "$name"
        if [ -s "$stderr_file" ]; then
            cat "$stderr_file"
        fi
    fi

    rm -f "$stderr_file"
}

# テスト終了時のサマリー
test_summary() {
    echo ""
    echo "================================================"
    if [ "$TEST_FAIL" -eq 0 ]; then
        printf "${TEST_GREEN}All %d tests passed${TEST_NC}\n" "$TEST_TOTAL"
        return 0
    else
        printf "${TEST_RED}%d of %d tests failed${TEST_NC}\n" "$TEST_FAIL" "$TEST_TOTAL"
        return 1
    fi
}
