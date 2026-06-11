#!/bin/bash
#
# tests/lib/test-install-central.sh - install のセントラルモード (#126) のテスト
#
# GAS を新規作成しない軽量 install (アカウント解決 + bind + ファイル配置)。
# HOME とレジストリをフィクスチャに隔離してオフラインで実行する。
#
# Usage: bash tests/lib/test-install-central.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

use_fixture_home() {
    HOME=$(test_mktemp_d)
    export HOME
    FIX_REGISTRY=$(test_mktemp_u)
    export CCSKILL_GMAIL_REGISTRY_FILE="$FIX_REGISTRY"
}

seed_account() {
    # $1=email $2=label
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "$1" "clasp-$1" "sid" "did" "https://example.invalid/exec" "${2:-}"
}

run_install() {
    local dir="$1"
    shift
    (cd "$dir" && "$REPO_DIR/ccskill-gmail" install --yes "$@" 2>&1) || true
}

# (1) アカウント登録済みなら install --yes でセントラルモード一式が揃う
test_central_install_layout() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    out=$(run_install "$proj")
    assert_file_exists "$proj/.ccskill-gmail/binding.json" || { echo "    out: $out" >&2; return 1; }
    assert_file_exists "$proj/.claude/skills/ccskill-gmail/SKILL.md" || return 1
    [ -x "$proj/.ccskill-gmail/api" ] || { echo "    api not executable" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/.clasp.json" ] || { echo "    .clasp.json should NOT exist (no dedicated GAS)" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/config.js" ] || { echo "    config.js should NOT exist (account-level)" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/.ccskill-metadata.json" ] || { echo "    metadata should NOT exist" >&2; return 1; }
}

# (2) binding はデフォルトアカウントの email
test_central_install_binds_default() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj acct
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    acct=$(jq -r '.account' "$proj/.ccskill-gmail/binding.json")
    assert_eq "a@example.com" "$acct"
}

# (3) --account label で別アカウントに bind できる
test_central_install_with_account_flag() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj acct
    proj=$(test_mktemp_d)
    run_install "$proj" --account work >/dev/null
    acct=$(jq -r '.account' "$proj/.ccskill-gmail/binding.json")
    assert_eq "b@example.com" "$acct"
}

# (4) アカウント未登録 + --yes → 非ゼロ終了で account add を案内
test_central_install_without_accounts() {
    use_fixture_home
    local proj out rc=0
    proj=$(test_mktemp_d)
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" install --yes 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || { echo "    expected non-zero exit" >&2; return 1; }
    assert_contains "account add" "$out"
}

# (5) install 後の api がバインドで解決される (Blocked + 注入で観測)
test_central_install_api_resolution() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    out=$(cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    assert_contains "Blocked:" "$out" || return 1
    assert_contains '"account":"a@example.com"' "$out" || return 1
    assert_contains '"account_source":"binding"' "$out"
}

# (6) レジストリに email 付きで登録される
test_central_install_registry() {
    use_fixture_home
    seed_account "a@example.com"
    local proj email
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    email=$(jq -r --arg p "$proj" '.installations[$p].email // empty' "$FIX_REGISTRY" 2>/dev/null)
    assert_eq "a@example.com" "$email"
}

# (7) .gitignore に .ccskill-gmail/ が追記される
test_central_install_gitignore() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    grep -qF ".ccskill-gmail/" "$proj/.gitignore"
}

# (8) --user は従来どおり専用 GAS パス (--dedicated 暗黙) に入る
#     ネットワークに出る前の clasp 前提チェックで止まることだけ確認する
test_user_flag_implies_dedicated() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    out=$(run_install "$proj" --user testuser)
    # セントラルモードの成果物 (binding.json) を作らないこと
    [ ! -f "$proj/.ccskill-gmail/binding.json" ] || { echo "    dedicated path should not bind; out: $out" >&2; return 1; }
}

# (9) update がセントラルモードを GAS push なしで完走する
test_update_central_mode() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" update --force --yes 2>&1) || {
        echo "    update failed: $out" >&2
        return 1
    }
    assert_contains "Central-account mode" "$out" || { echo "    out: $out" >&2; return 1; }
    assert_contains "Update Complete" "$out"
}

echo ""
echo "test-install-central.sh (#126)"
echo ""

run_test "central install: file layout"                    test_central_install_layout
run_test "central install: binds default account"          test_central_install_binds_default
run_test "central install: --account flag"                 test_central_install_with_account_flag
run_test "central install: no accounts -> guide to add"    test_central_install_without_accounts
run_test "central install: api resolves via binding"       test_central_install_api_resolution
run_test "central install: registry entry with email"      test_central_install_registry
run_test "central install: .gitignore updated"             test_central_install_gitignore
run_test "--user implies dedicated path (no binding)"      test_user_flag_implies_dedicated
run_test "update: central mode completes without GAS push" test_update_central_mode

test_summary
