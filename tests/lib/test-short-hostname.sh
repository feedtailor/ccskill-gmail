#!/bin/bash
#
# tests/lib/test-short-hostname.sh - 短縮ホスト名ヘルパ (#151)
#
# short_hostname_from: `hostname` の生出力（例 om4mba.local）から最初のラベル
# （om4mba）を取り出す純関数。GAS プロジェクト名に付与するマシン名に使う。
#
# Usage: bash tests/lib/test-short-hostname.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/hostname.sh"

# ========================================
# テスト
# ========================================

test_strips_domain_suffix() {
    assert_eq "om4mba" "$(short_hostname_from 'om4mba.local')"
}

test_bare_name_unchanged() {
    assert_eq "om1ms" "$(short_hostname_from 'om1ms')"
}

test_multi_dot_takes_first_label() {
    assert_eq "host" "$(short_hostname_from 'host.sub.example.com')"
}

test_empty_stays_empty() {
    assert_eq "" "$(short_hostname_from '')"
}

test_alnum_dash_preserved() {
    assert_eq "om4mba-2" "$(short_hostname_from 'om4mba-2.local')"
}

# short_hostname() 自体はこのマシンで非空を返すこと（値は環境依存なので中身は問わない）
test_short_hostname_nonempty_here() {
    local h
    h=$(short_hostname)
    [ -n "$h" ]
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-short-hostname.sh (#151)"
echo ""

run_test "strips domain suffix (.local)"        test_strips_domain_suffix
run_test "bare name unchanged"                  test_bare_name_unchanged
run_test "multi-dot takes first label"          test_multi_dot_takes_first_label
run_test "empty stays empty"                    test_empty_stays_empty
run_test "alnum/dash preserved"                 test_alnum_dash_preserved
run_test "short_hostname() nonempty here"       test_short_hostname_nonempty_here

test_summary
