#!/bin/bash
#
# tests/lib/test-remove-warning.sh - account remove の繰り上げ警告 + permission 撤去 (#133)
#
# B: account remove で既定アカウントを消すと残り1件が無言で既定に繰り上がる。
#    繰り上げと影響件数を事前に警告することを検証する。
# E: uninstall が setup_permissions の追加した allow パターンを撤去することを検証する。
#
# Usage: bash tests/lib/test-remove-warning.sh
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

seed_two_accounts() {
    # a@ が既定 (最初の upsert), b@ が2件目
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "a@example.com" "ua" "sa" "da" "https://a.invalid/exec" "alpha" >/dev/null 2>&1
    accounts_upsert "b@example.com" "ub" "sb" "db" "https://b.invalid/exec" "beta" >/dev/null 2>&1
}

# ========================================
# (B) account remove の繰り上げ警告
# ========================================

test_remove_default_warns_promotion() {
    use_fixture_home
    seed_two_accounts
    local out
    out=$("$REPO_DIR/ccskill-gmail" account remove a@example.com --yes 2>&1) || true
    assert_contains "current default" "$out" || return 1
    assert_contains "becomes: b@example.com" "$out"
}

test_remove_nondefault_no_warning() {
    use_fixture_home
    seed_two_accounts
    local out
    out=$("$REPO_DIR/ccskill-gmail" account remove b@example.com --yes 2>&1) || true
    case "$out" in
        *"current default"*)
            echo "removing a non-default account must not warn about default promotion" >&2
            return 1
            ;;
    esac
    return 0
}

test_remove_default_reports_affected() {
    use_fixture_home
    seed_two_accounts
    local reg
    reg=$(test_mktemp)
    jq -n '{schema_version:"1.0", installations:{
        "/p1":{project_name:"p1",installed_at:"x",updated_at:"x",version:"unknown",email:"a@example.com"},
        "/p2":{project_name:"p2",installed_at:"x",updated_at:"x",version:"unknown",email:"a@example.com"}
    }}' > "$reg"
    local out
    out=$(CCSKILL_GMAIL_REGISTRY_FILE="$reg" "$REPO_DIR/ccskill-gmail" account remove a@example.com --yes 2>&1) || true
    assert_contains "2 registered" "$out" || return 1
    assert_contains "reference this account" "$out"
}

# ========================================
# (E) uninstall の permission 撤去
# ========================================

test_remove_permissions_strips_ccskill_patterns() {
    source "$REPO_DIR/lib/permissions.sh"
    local proj
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.claude"
    jq -n '{permissions:{allow:[
        "Bash(.ccskill-gmail/api *)",
        "Bash(ccskill-gmail api *)",
        "Write(.ccskill-gmail/tmp/*)",
        "Bash(ls *)"
    ]}}' > "$proj/.claude/settings.local.json"
    remove_permissions "$proj" >/dev/null 2>&1
    local out
    out=$(cat "$proj/.claude/settings.local.json")
    case "$out" in
        *"ccskill-gmail/api"*) echo "ccskill api pattern not removed" >&2; return 1 ;;
        *".ccskill-gmail/tmp"*) echo "tmp write pattern not removed" >&2; return 1 ;;
    esac
    # 無関係なパターンは保持する
    assert_contains "Bash(ls *)" "$out"
}

test_remove_permissions_no_file_is_noop() {
    source "$REPO_DIR/lib/permissions.sh"
    local proj
    proj=$(test_mktemp_d)
    remove_permissions "$proj"  # settings.local.json 不在でもエラーにしない
    assert_eq "0" "$?"
}

test_uninstall_calls_remove_permissions() {
    grep -q 'remove_permissions' "$REPO_DIR/commands/uninstall.sh" \
        || { echo "uninstall.sh should call remove_permissions" >&2; return 1; }
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-remove-warning.sh (#133)"
echo ""

run_test "remove default -> warns promotion to next"     test_remove_default_warns_promotion
run_test "remove non-default -> no promotion warning"    test_remove_nondefault_no_warning
run_test "remove default -> reports affected installs"   test_remove_default_reports_affected
run_test "remove_permissions strips ccskill patterns"    test_remove_permissions_strips_ccskill_patterns
run_test "remove_permissions no file -> noop"            test_remove_permissions_no_file_is_noop
run_test "uninstall calls remove_permissions"            test_uninstall_calls_remove_permissions

test_summary
