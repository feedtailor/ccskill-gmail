#!/bin/bash
#
# tests/lib/test-install-deprecation.sh - install の deprecated 化と
# --dedicated / --user 新規作成の退役 (#141, 方針 #136) のテスト
#
# install(central) は警告を表示し bind へ委譲する（binding.json + permissions のみ）。
# install --dedicated / --user は退役エラーで止まる。
# HOME とレジストリをフィクスチャに隔離してオフラインで実行する。
#
# Usage: bash tests/lib/test-install-deprecation.sh
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

# (1) install(central) は退役警告を出し bind 委譲する（binding.json のみ）
test_deprecated_warns_and_binds() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    out=$(run_install "$proj")
    assert_contains "deprecated" "$out" || { echo "    out: $out" >&2; return 1; }
    assert_file_exists "$proj/.ccskill-gmail/binding.json" || { echo "    out: $out" >&2; return 1; }
    # 旧モデルの産物は作らない
    [ ! -e "$proj/.claude/skills/ccskill-gmail/SKILL.md" ] || { echo "    skill copy should NOT be created" >&2; return 1; }
    [ ! -e "$proj/.ccskill-gmail/api" ] || { echo "    project api should NOT be created" >&2; return 1; }
}

# (2) registry / .gitignore は触らない（bind 委譲なので）
test_deprecated_no_registry_no_gitignore() {
    use_fixture_home
    seed_account "a@example.com"
    local proj reg_email
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    reg_email=$(jq -r --arg p "$proj" '.installations[$p].email // empty' "$FIX_REGISTRY" 2>/dev/null || true)
    assert_eq "" "$reg_email" "deprecated install must not register" || return 1
    [ ! -f "$proj/.gitignore" ] || { echo "    deprecated install must not write .gitignore" >&2; return 1; }
}

# (3) binding はデフォルトアカウントの email
test_deprecated_binds_default() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj acct
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    acct=$(jq -r '.account' "$proj/.ccskill-gmail/binding.json")
    assert_eq "a@example.com" "$acct"
}

# (4) --account label で別アカウントに bind できる
test_deprecated_with_account_flag() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj acct
    proj=$(test_mktemp_d)
    run_install "$proj" --account work >/dev/null
    acct=$(jq -r '.account' "$proj/.ccskill-gmail/binding.json")
    assert_eq "b@example.com" "$acct"
}

# (5) アカウント未登録 + --yes → 非ゼロ終了で account add を案内
test_deprecated_without_accounts() {
    use_fixture_home
    local proj out rc=0
    proj=$(test_mktemp_d)
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" install --yes 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || { echo "    expected non-zero exit" >&2; return 1; }
    assert_contains "account add" "$out"
}

# (6) install 後の global api がバインドで解決される
test_deprecated_api_resolution() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    run_install "$proj" >/dev/null
    out=$(cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    assert_contains "Blocked:" "$out" || { echo "    out: $out" >&2; return 1; }
    assert_contains '"account":"a@example.com"' "$out" || return 1
    assert_contains '"account_source":"binding"' "$out"
}

# (7) install --dedicated は退役エラーで止まり、何も作らない
test_dedicated_retired() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out rc=0
    proj=$(test_mktemp_d)
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" install --yes --dedicated 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || { echo "    expected non-zero exit; out: $out" >&2; return 1; }
    assert_contains "retired" "$out" || { echo "    out: $out" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/binding.json" ] || { echo "    must not bind" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/.clasp.json" ] || { echo "    must not create GAS" >&2; return 1; }
}

# (8) install --user も退役エラーで止まる
test_user_flag_retired() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out rc=0
    proj=$(test_mktemp_d)
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" install --yes --user testuser 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || { echo "    expected non-zero exit; out: $out" >&2; return 1; }
    assert_contains "retired" "$out" || { echo "    out: $out" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/binding.json" ] || { echo "    must not bind" >&2; return 1; }
}

# (9) 退役した 'ccskill-gmail install' をユーザー向け復旧ヒントとして案内していない (#144)
#     install.sh 本体（deprecated 通知）と 'installation/installed' の説明的記述は除外。
test_no_stale_install_hints() {
    local hits
    hits=$(grep -rnE "ccskill-gmail install([^a-zA-Z]|$)" "$REPO_DIR/lib" "$REPO_DIR/commands" \
        | grep -v "/commands/install.sh:" || true)
    if [ -n "$hits" ]; then
        echo "    stale 'ccskill-gmail install' recovery hints found:" >&2
        printf '%s\n' "$hits" | sed 's/^/      /' >&2
        return 1
    fi
}

echo ""
echo "test-install-deprecation.sh (#141, #144)"
echo ""

run_test "install(central): warns deprecated + binds"      test_deprecated_warns_and_binds
run_test "install(central): no registry / no .gitignore"   test_deprecated_no_registry_no_gitignore
run_test "install(central): binds default account"         test_deprecated_binds_default
run_test "install(central): --account flag"                test_deprecated_with_account_flag
run_test "install(central): no accounts -> guide to add"   test_deprecated_without_accounts
run_test "install(central): api resolves via binding"      test_deprecated_api_resolution
run_test "install --dedicated: retired (no creation)"      test_dedicated_retired
run_test "install --user: retired (no creation)"           test_user_flag_retired
run_test "no stale 'ccskill-gmail install' recovery hints"  test_no_stale_install_hints

test_summary
