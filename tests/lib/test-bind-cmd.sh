#!/bin/bash
#
# tests/lib/test-bind-cmd.sh - bind/unbind コマンドと binding.json 解決のテスト (#125)
#
# HOME をフィクスチャに差し替えてオフラインで実行する。
# 解決の観測点は test-api-accounts.sh と同じ (Blocked + account 注入)。
#
# Usage: bash tests/lib/test-bind-cmd.sh
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
    # $1=email $2=label
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "$1" "clasp-$1" "sid" "did-$1" "https://example.invalid/exec" "${2:-}"
}

make_legacy_metadata() {
    local dir="$1"
    mkdir -p "$dir/.ccskill-gmail"
    printf '{"installed_from":"%s","endpoint":"https://example.invalid/exec","clasp_user":"cgtest"}\n' "$REPO_DIR" \
        > "$dir/.ccskill-gmail/.ccskill-metadata.json"
}

api_in() {
    local dir="$1"
    shift
    (cd "$dir" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" "$@" 2>&1) || true
}

# (1) bind (label 指定) で binding.json に解決済み email が書かれる
test_bind_writes_email() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj acct
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    assert_file_exists "$proj/.ccskill-gmail/binding.json" || return 1
    acct=$(jq -r '.account' "$proj/.ccskill-gmail/binding.json")
    assert_eq "b@example.com" "$acct"
}

# (2) 未登録アカウントへの bind は失敗する
test_bind_unknown_fails() {
    use_fixture_home
    seed_account "a@example.com"
    local proj rc=0
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind nobody --yes >/dev/null 2>&1) || rc=$?
    [ "$rc" -ne 0 ]
}

# (3) unbind で binding.json が消える
test_unbind_removes() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind a@example.com --yes >/dev/null 2>&1) || return 1
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" unbind --yes >/dev/null 2>&1) || return 1
    [ ! -f "$proj/.ccskill-gmail/binding.json" ]
}

# (4) DIR 引数で対象ディレクトリを指定できる
test_bind_dir_argument() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    "$REPO_DIR/ccskill-gmail" bind a@example.com "$proj" --yes >/dev/null 2>&1 || return 1
    assert_file_exists "$proj/.ccskill-gmail/binding.json"
}

# (5) binding.json で解決される (注入あり、source=binding)
test_binding_resolution_with_injection() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj out
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    out=$(api_in "$proj" api get action=search)
    assert_contains "Blocked:" "$out" || return 1
    assert_contains '"account":"b@example.com"' "$out" || return 1
    assert_contains '"account_source":"binding"' "$out"
}

# (6) binding.json はデフォルトより強い
test_binding_beats_default() {
    use_fixture_home
    seed_account "a@example.com"      # default
    seed_account "b@example.com" "work"
    local proj out
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    out=$(api_in "$proj" api get action=search)
    assert_contains '"account":"b@example.com"' "$out"
}

# (7) --account フラグは binding.json より強い
test_flag_beats_binding_json() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj out
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    out=$(api_in "$proj" api --account a@example.com get action=search)
    assert_contains '"account":"a@example.com"' "$out" || return 1
    assert_contains '"account_source":"flag"' "$out"
}

# (8) binding.json の参照先が未登録なら UNKNOWN_ACCOUNT
test_binding_to_removed_account() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj out code
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    "$REPO_DIR/ccskill-gmail" account remove b@example.com --yes >/dev/null 2>&1 || return 1
    out=$(api_in "$proj" api get action=search)
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    assert_eq "UNKNOWN_ACCOUNT" "$code" "raw: $out"
}

# (9) binding.json はレガシーメタデータより強い
test_binding_json_beats_legacy_metadata() {
    use_fixture_home
    seed_account "b@example.com" "work"
    local proj out
    proj=$(test_mktemp_d)
    make_legacy_metadata "$proj"
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    out=$(api_in "$proj" api get action=search)
    # レガシーが勝つと注入なし。binding.json が勝てば account=b が注入される
    assert_contains '"account":"b@example.com"' "$out"
}

# (9.5) unbind: レガシーメタデータが残る場合は警告を出す (#126)
test_unbind_warns_about_legacy() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out
    proj=$(test_mktemp_d)
    make_legacy_metadata "$proj"
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind a@example.com --yes >/dev/null 2>&1) || return 1
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" unbind --yes 2>&1) || return 1
    assert_contains "legacy" "$out" || return 1
    assert_contains "purge-legacy" "$out"
}

# (9.6) unbind --purge-legacy: レガシー install ファイルを除去し audit は残す (#126)
test_unbind_purge_legacy() {
    use_fixture_home
    seed_account "a@example.com"
    local proj out src
    proj=$(test_mktemp_d)
    make_legacy_metadata "$proj"
    printf '{"scriptId":"S","rootDir":"."}\n' > "$proj/.ccskill-gmail/.clasp.json"
    echo "// config" > "$proj/.ccskill-gmail/config.js"
    echo '{"x":1}' > "$proj/.ccskill-gmail/audit.jsonl"
    /bin/cp "$REPO_DIR/lib/api" "$proj/.ccskill-gmail/api"
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind a@example.com --yes >/dev/null 2>&1) || return 1
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" unbind --purge-legacy --yes >/dev/null 2>&1) || return 1
    [ ! -f "$proj/.ccskill-gmail/binding.json" ] || return 1
    [ ! -f "$proj/.ccskill-gmail/.ccskill-metadata.json" ] || { echo "    metadata should be purged" >&2; return 1; }
    [ ! -f "$proj/.ccskill-gmail/.clasp.json" ] || return 1
    [ ! -f "$proj/.ccskill-gmail/config.js" ] || return 1
    assert_file_exists "$proj/.ccskill-gmail/audit.jsonl" || return 1
    # 掃除後は default 解決になる
    out=$(cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api whoami 2>&1) || true
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "default" "$src" "raw: $out"
}

# (10) whoami が binding.json 解決を報告する
test_whoami_binding_json() {
    use_fixture_home
    seed_account "b@example.com" "work"
    local proj out acct src
    proj=$(test_mktemp_d)
    (cd "$proj" && "$REPO_DIR/ccskill-gmail" bind work --yes >/dev/null 2>&1) || return 1
    out=$(api_in "$proj" api whoami)
    acct=$(printf '%s' "$out" | jq -r '.data.account // empty' 2>/dev/null)
    src=$(printf '%s' "$out" | jq -r '.data.account_source // empty' 2>/dev/null)
    assert_eq "b@example.com" "$acct" "raw: $out" || return 1
    assert_eq "binding" "$src"
}

echo ""
echo "test-bind-cmd.sh (#125)"
echo ""

run_test "bind: writes resolved email to binding.json"      test_bind_writes_email
run_test "bind: unknown account fails"                      test_bind_unknown_fails
run_test "unbind: removes binding.json"                     test_unbind_removes
run_test "bind: DIR argument"                               test_bind_dir_argument
run_test "api: binding.json resolves with injection"        test_binding_resolution_with_injection
run_test "api: binding.json beats default"                  test_binding_beats_default
run_test "api: --account flag beats binding.json"           test_flag_beats_binding_json
run_test "api: binding to removed account -> UNKNOWN"       test_binding_to_removed_account
run_test "api: binding.json beats legacy metadata"          test_binding_json_beats_legacy_metadata
run_test "unbind: warns about remaining legacy metadata"    test_unbind_warns_about_legacy
run_test "unbind --purge-legacy: cleans legacy, keeps audit" test_unbind_purge_legacy
run_test "api: whoami reports binding.json resolution"      test_whoami_binding_json

test_summary
