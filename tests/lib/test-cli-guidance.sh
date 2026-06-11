#!/bin/bash
#
# tests/lib/test-cli-guidance.sh - 二段構造の取り違えに対する相互誘導のテスト (#120)
#
# 管理系 (ccskill-gmail <cmd>) と API 系 (ccskill-gmail api <sub>) を
# 取り違えたとき、エラーメッセージが正しい系統へ誘導することを検証する。
#
# Usage: bash tests/lib/test-cli-guidance.sh
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
    accounts_upsert "a@example.com" "clasp-a" "sid" "did" "https://example.invalid/exec" "main"
}

# api 系の実行 (アカウント解決が要るため fixture HOME + 登録済みで呼ぶ)
run_api() {
    local empty
    empty=$(test_mktemp_d)
    (cd "$empty" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api "$@" 2>&1) || true
}

run_cli() {
    "$REPO_DIR/ccskill-gmail" "$@" 2>&1 || true
}

# ========================================
# (1) API 系の位置に管理コマンド → 管理系へ誘導
# ========================================

test_api_unbind_guides_to_management() {
    use_fixture_home
    seed_account
    local out
    out=$(run_api unbind)
    assert_contains '"ok":false' "$out" || return 1
    assert_contains "ccskill-gmail unbind" "$out" || return 1
    assert_contains "management" "$out"
}

test_api_info_guides_to_management() {
    use_fixture_home
    seed_account
    local out
    out=$(run_api info)
    assert_contains "ccskill-gmail info" "$out"
}

test_api_account_guides_to_management() {
    use_fixture_home
    seed_account
    local out
    out=$(run_api account list)
    assert_contains "ccskill-gmail account" "$out"
}

# 既存の正規サブコマンドは影響を受けない (whoami が通る)
test_api_whoami_still_works() {
    use_fixture_home
    seed_account
    local out ok
    out=$(run_api whoami)
    ok=$(printf '%s' "$out" | jq -r '.ok' 2>/dev/null)
    assert_eq "true" "$ok" "raw: $out"
}

# ========================================
# (2) 管理系の位置に API サブコマンド → api へ誘導
# ========================================

test_cli_get_guides_to_api() {
    local out
    out=$(run_cli get action=search)
    assert_contains "ccskill-gmail api get" "$out"
}

test_cli_whoami_guides_to_api() {
    local out
    out=$(run_cli whoami)
    assert_contains "ccskill-gmail api whoami" "$out"
}

# ========================================
# (3) action 直打ち → api get action=... へ誘導
# ========================================

test_cli_action_guides_to_api_get() {
    local out
    out=$(run_cli search query=test)
    assert_contains "action=search" "$out"
}

test_cli_get_profile_guides() {
    local out
    out=$(run_cli get_profile)
    assert_contains "action=get_profile" "$out"
}

# 未知コマンドは従来どおり help を出す (誘導なし)
test_cli_unknown_shows_help() {
    local out
    out=$(run_cli totally-bogus-cmd)
    assert_contains "Unknown command" "$out" || return 1
    assert_contains "Usage:" "$out"
}

# ========================================
# (4) account_source: binding.json とレガシーの区別 (#120 検討 6)
# ========================================

test_whoami_legacy_metadata_source() {
    use_fixture_home
    local proj out src
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.ccskill-gmail"
    printf '{"installed_from":"%s","endpoint":"https://example.invalid/exec","clasp_user":"cgtest"}\n' "$REPO_DIR" \
        > "$proj/.ccskill-gmail/.ccskill-metadata.json"
    out=$(cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api whoami 2>&1) || true
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "binding-legacy" "$src" "raw: $out"
}

test_whoami_binding_json_source_unchanged() {
    use_fixture_home
    seed_account
    local proj out src
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind main --yes >/dev/null 2>&1) || return 1
    out=$(cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api whoami 2>&1) || true
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "binding" "$src" "raw: $out"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-cli-guidance.sh (#120)"
echo ""

run_test "api unbind -> guides to management CLI"        test_api_unbind_guides_to_management
run_test "api info -> guides to management CLI"          test_api_info_guides_to_management
run_test "api account -> guides to management CLI"       test_api_account_guides_to_management
run_test "api whoami still works"                        test_api_whoami_still_works
run_test "cli get -> guides to api get"                  test_cli_get_guides_to_api
run_test "cli whoami -> guides to api whoami"            test_cli_whoami_guides_to_api
run_test "cli search -> guides to api get action=search" test_cli_action_guides_to_api_get
run_test "cli get_profile -> guides to action="          test_cli_get_profile_guides
run_test "cli unknown command -> help (no guidance)"     test_cli_unknown_shows_help
run_test "whoami: legacy metadata -> binding-legacy"     test_whoami_legacy_metadata_source
run_test "whoami: binding.json -> binding (unchanged)"   test_whoami_binding_json_source_unchanged

test_summary
