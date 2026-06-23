#!/bin/bash
#
# tests/lib/test-first-run-guidance.sh - 新規ユーザーの first-run 導線テスト (#132)
#
# 中央化以降、setup/release の「次の一手」案内が install 単独を指し、
# 新規ユーザーが account 未登録で行き止まる。正しい導線
# (account add -> skill install) を案内することを検証する。
#
# Usage: bash tests/lib/test-first-run-guidance.sh
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

run_cli() {
    "$REPO_DIR/ccskill-gmail" "$@" 2>&1 || true
}

# ========================================
# (1) setup の「次の一手」が正規導線を案内する
# ========================================

test_setup_guidance_mentions_account_add() {
    local f="$REPO_DIR/commands/setup.sh"
    grep -q "ccskill-gmail account add" "$f" || { echo "setup.sh lacks 'account add'" >&2; return 1; }
    grep -q "ccskill-gmail skill install" "$f" || { echo "setup.sh lacks 'skill install'" >&2; return 1; }
}

# first-run 導線に素のプロジェクト install を再登場させない (#132 の確定方針)
test_setup_guidance_excludes_project_install() {
    local f="$REPO_DIR/commands/setup.sh"
    if grep -q "ccskill-gmail install" "$f"; then
        echo "setup.sh should not steer first-run users to per-project 'install'" >&2
        return 1
    fi
    return 0
}

# ========================================
# (2) release の配布手順が正規導線を案内する
# ========================================

# #139 以降、配布手順は setup 一発に集約された (setup が skill install /
# account add を内包する)。release は setup を案内し、素のプロジェクト
# install へ誘導しないこと。
test_release_guidance_points_to_setup() {
    local f="$REPO_DIR/commands/release.sh"
    grep -q "ccskill-gmail setup" "$f" || { echo "release.sh lacks 'ccskill-gmail setup'" >&2; return 1; }
    if grep -q "ccskill-gmail install" "$f"; then
        echo "release.sh should not steer to per-project 'install'" >&2
        return 1
    fi
    return 0
}

# ========================================
# (3) トップレベル help の install 行は --account を案内し --user を露出しない
# ========================================

test_help_shows_account_not_user() {
    local out
    out=$(run_cli help)
    assert_contains "install [--account" "$out" || return 1
    case "$out" in
        *"--user"*)
            echo "    help still exposes --user at top level" >&2
            return 1
            ;;
    esac
    return 0
}

# ========================================
# (4) doctor の未設定フッターが global 導線 (account add → bind) を案内する
#     (#141: install 退役に伴い "Install first: ... install" から差し替え)
# ========================================

test_doctor_install_first_mentions_account_add() {
    use_fixture_home
    local proj out
    proj=$(test_mktemp_d)
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" doctor 2>&1) || true
    assert_contains "Set up first: ccskill-gmail account add, then: ccskill-gmail bind <email|label>" "$out"
}

# ========================================
# (5) ガード: マスター破損の Fix hint には account add を入れない (:277/:282)
# ========================================

test_doctor_master_fix_excludes_account_add() {
    local f="$REPO_DIR/commands/doctor.sh"
    local ctx
    ctx=$( { grep -A1 "auth.sh not found in master" "$f"; grep -A1 "master directory not found" "$f"; } )
    case "$ctx" in
        *"account add"*)
            echo "    master-repair Fix hint must not suggest 'account add'" >&2
            return 1
            ;;
    esac
    return 0
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-first-run-guidance.sh (#132)"
echo ""

run_test "setup guidance -> account add + skill install"   test_setup_guidance_mentions_account_add
run_test "setup guidance -> excludes per-project install"  test_setup_guidance_excludes_project_install
run_test "release guidance -> points to setup"             test_release_guidance_points_to_setup
run_test "help install line -> --account, not --user"      test_help_shows_account_not_user
run_test "doctor setup footer -> account add + bind"       test_doctor_install_first_mentions_account_add
run_test "doctor master-repair fix -> excludes account add" test_doctor_master_fix_excludes_account_add

test_summary
