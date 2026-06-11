#!/bin/bash
#
# tests/lib/test-api-accounts.sh - lib/api のアカウント解決チェーンのテスト (#123)
#
# オフラインテスト。HOME をフィクスチャに差し替え、endpoint に
# https://example.invalid を使うことで「どのアカウントが解決されたか」を
# レスポンス注入 (account / account_source) と "Blocked:" で観測する。
#
# 解決優先順位 (#121):
#   --account フラグ > CCSKILL_GMAIL_ACCOUNT > GMAIL_ENDPOINT (レガシー)
#   > cwd バインド > default_account > 単一アカウント > NO_ACCOUNT
#
# Usage: bash tests/lib/test-api-accounts.sh
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

# アカウントをフィクスチャ HOME に登録する
seed_account() {
    # $1=email $2=label
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "$1" "clasp-$1" "sid" "did" "https://example.invalid/exec" "${2:-}"
}

# cwd バインド (メタデータ) を作る
make_metadata() {
    local dir="$1"
    mkdir -p "$dir/.ccskill-gmail"
    printf '{"installed_from":"%s","endpoint":"https://example.invalid/exec","clasp_user":"cgtest"}\n' "$REPO_DIR" \
        > "$dir/.ccskill-gmail/.ccskill-metadata.json"
}

# api 呼び出し (環境変数の混入を防ぐため GMAIL_ENDPOINT と CCSKILL_GMAIL_ACCOUNT は明示)
api_in() {
    local dir="$1"
    shift
    (cd "$dir" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" "$@" 2>&1) || true
}

assert_not_contains() {
    local needle="$1"
    local haystack="$2"
    case "$haystack" in
        *"$needle"*)
            echo "    expected NOT to contain: '$needle'" >&2
            return 1
            ;;
        *) return 0 ;;
    esac
}

# ========================================
# テストケース
# ========================================

# (1) default アカウント解決: メタデータなし + default → Blocked + source=default
test_default_account_resolution() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api get action=search)
    assert_contains "Blocked:" "$out" || return 1
    assert_contains '"account":"a@example.com"' "$out" || return 1
    assert_contains '"account_source":"default"' "$out"
}

# (2) --account フラグ (label) で特定アカウントを解決
test_flag_resolution_by_label() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local empty out
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api --account work get action=search)
    assert_contains '"account":"b@example.com"' "$out" || return 1
    assert_contains '"account_source":"flag"' "$out"
}

# (3) --account 不明 → UNKNOWN_ACCOUNT
test_flag_unknown_account() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out code
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api --account nobody get action=search)
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    assert_eq "UNKNOWN_ACCOUNT" "$code" "raw: $out"
}

# (4) 環境変数 CCSKILL_GMAIL_ACCOUNT → source=env
test_env_resolution() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local empty out
    empty=$(test_mktemp_d)
    out=$(cd "$empty" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="work" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    assert_contains '"account":"b@example.com"' "$out" || return 1
    assert_contains '"account_source":"env"' "$out"
}

# (5) フラグはバインドより強い
test_flag_beats_binding() {
    use_fixture_home
    seed_account "b@example.com" "work"
    local proj out
    proj=$(test_mktemp_d)
    make_metadata "$proj"
    out=$(api_in "$proj" api --account work get action=search)
    assert_contains '"account":"b@example.com"' "$out" || return 1
    assert_contains '"account_source":"flag"' "$out"
}

# (6) バインドは default より強い (レガシー経路は注入なし)
test_binding_beats_default_without_injection() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    make_metadata "$proj"
    out=$(api_in "$proj" api get action=search)
    assert_contains "Blocked:" "$out" || return 1
    assert_not_contains '"account_source"' "$out"
}

# (7) メタデータなし + アカウント登録なし → NO_ACCOUNT
test_no_account_error() {
    use_fixture_home
    local empty out code
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api get action=search)
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    assert_eq "NO_ACCOUNT" "$code" "raw: $out"
}

# (8) default_account が null でもアカウントが 1 件なら single 解決
test_single_account_resolution() {
    use_fixture_home
    seed_account "a@example.com"
    local tmp
    tmp=$(test_mktemp)
    jq '.default_account = null' "$HOME/.ccskill-gmail/accounts.json" > "$tmp"
    /bin/mv "$tmp" "$HOME/.ccskill-gmail/accounts.json"
    local empty out
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api get action=search)
    assert_contains '"account":"a@example.com"' "$out" || return 1
    assert_contains '"account_source":"single"' "$out"
}

# (9) GMAIL_ENDPOINT 環境変数 (レガシー) はアカウント解決より前に効き、注入なし
test_endpoint_env_escape_hatch() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out
    empty=$(test_mktemp_d)
    out=$(cd "$empty" && GMAIL_ENDPOINT="https://example.invalid/exec" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    assert_contains "Blocked:" "$out" || return 1
    assert_not_contains '"account_source"' "$out"
}

# (9.5) メタデータ無し解決ではマスターの lib/ に監査ログを作らない
test_no_audit_log_in_master_lib() {
    use_fixture_home
    seed_account "a@example.com"
    local empty
    empty=$(test_mktemp_d)
    [ -f "$REPO_DIR/lib/audit.jsonl" ] && {
        echo "    pre-existing $REPO_DIR/lib/audit.jsonl - remove it first" >&2
        return 1
    }
    api_in "$empty" api get action=search >/dev/null
    if [ -f "$REPO_DIR/lib/audit.jsonl" ]; then
        echo "    audit.jsonl was created in master lib/" >&2
        /bin/rm -f "$REPO_DIR/lib/audit.jsonl"
        return 1
    fi
    return 0
}

# (10) whoami: default アカウント
test_whoami_default() {
    use_fixture_home
    seed_account "a@example.com"
    local empty out acct src
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api whoami)
    acct=$(printf '%s' "$out" | jq -r '.data.account // empty' 2>/dev/null)
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "a@example.com" "$acct" "raw: $out" || return 1
    assert_eq "default" "$src"
}

# (11) whoami: レガシーバインド (メタデータ) は binding-legacy (#120)
test_whoami_binding() {
    use_fixture_home
    local proj out src
    proj=$(test_mktemp_d)
    make_metadata "$proj"
    out=$(api_in "$proj" api whoami)
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "binding-legacy" "$src" "raw: $out"
}

# (12) whoami: 未設定なら NO_ACCOUNT
test_whoami_no_account() {
    use_fixture_home
    local empty out code
    empty=$(test_mktemp_d)
    out=$(api_in "$empty" api whoami)
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    assert_eq "NO_ACCOUNT" "$code" "raw: $out"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-api-accounts.sh (#123)"
echo ""

run_test "default account resolves with injection"        test_default_account_resolution
run_test "--account flag resolves by label"               test_flag_resolution_by_label
run_test "--account unknown -> UNKNOWN_ACCOUNT"           test_flag_unknown_account
run_test "CCSKILL_GMAIL_ACCOUNT env resolves"             test_env_resolution
run_test "flag beats binding"                             test_flag_beats_binding
run_test "binding beats default (no injection)"           test_binding_beats_default_without_injection
run_test "no metadata + no accounts -> NO_ACCOUNT"        test_no_account_error
run_test "single account resolves when default is null"   test_single_account_resolution
run_test "GMAIL_ENDPOINT env escape hatch (no injection)" test_endpoint_env_escape_hatch
run_test "no audit log in master lib/ without metadata"   test_no_audit_log_in_master_lib
run_test "whoami: default account"                        test_whoami_default
run_test "whoami: binding"                                test_whoami_binding
run_test "whoami: NO_ACCOUNT when unconfigured"           test_whoami_no_account

test_summary
