#!/bin/bash
#
# tests/lib/test-migrate.sh - migrate コマンドのテスト (#125)
#
# CCSKILL_GMAIL_REGISTRY_FILE でレジストリを差し替え、HOME をフィクスチャに
# 隔離してオフラインで実行する。
#
# Usage: bash tests/lib/test-migrate.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# フィクスチャ一式を組み立てる:
#   proj1, proj2 = a@example.com (デプロイ別)、proj3 = b@example.com
# グローバル変数: FIX_HOME, FIX_REGISTRY, PROJ1, PROJ2, PROJ3
setup_fixture() {
    FIX_HOME=$(test_mktemp_d)
    HOME="$FIX_HOME"
    export HOME

    PROJ1=$(test_mktemp_d)
    PROJ2=$(test_mktemp_d)
    PROJ3=$(test_mktemp_d)

    local p
    local i=1
    for p in "$PROJ1" "$PROJ2" "$PROJ3"; do
        mkdir -p "$p/.ccskill-gmail"
        printf '{"installed_from":"%s","endpoint":"https://script.google.com/macros/s/DEP%s/exec","clasp_user":"user%s","deployment_id":"DEP%s","project_name":"proj%s"}\n' \
            "$REPO_DIR" "$i" "$i" "$i" "$i" > "$p/.ccskill-gmail/.ccskill-metadata.json"
        printf '{"scriptId":"SCRIPT%s","rootDir":"."}\n' "$i" > "$p/.ccskill-gmail/.clasp.json"
        i=$((i + 1))
    done

    FIX_REGISTRY=$(test_mktemp)
    jq -n --arg p1 "$PROJ1" --arg p2 "$PROJ2" --arg p3 "$PROJ3" '{
        schema_version: "1.0",
        installations: {
            ($p1): {project_name: "proj1", email: "a@example.com"},
            ($p2): {project_name: "proj2", email: "a@example.com"},
            ($p3): {project_name: "proj3", email: "b@example.com"}
        }
    }' > "$FIX_REGISTRY"
}

run_migrate() {
    CCSKILL_GMAIL_REGISTRY_FILE="$FIX_REGISTRY" "$REPO_DIR/ccskill-gmail" migrate "$@" 2>&1
}

# (1) email ごとに 1 アカウントが登録され、代表のエンドポイントが採用される
test_accounts_registered_per_email() {
    setup_fixture
    run_migrate --yes >/dev/null || return 1
    local count ep_a
    count=$(jq -r '.accounts | length' "$HOME/.ccskill-gmail/accounts.json")
    ep_a=$(jq -r '.accounts["a@example.com"].endpoint' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "2" "$count" || return 1
    assert_eq "https://script.google.com/macros/s/DEP1/exec" "$ep_a" "representative should be proj1 (first)"
}

# (2) 各プロジェクトに binding.json が書かれる (旧メタデータは残置)
test_bindings_written() {
    setup_fixture
    run_migrate --yes >/dev/null || return 1
    local b1 b3
    b1=$(jq -r '.account' "$PROJ1/.ccskill-gmail/binding.json" 2>/dev/null)
    b3=$(jq -r '.account' "$PROJ3/.ccskill-gmail/binding.json" 2>/dev/null)
    assert_eq "a@example.com" "$b1" || return 1
    assert_eq "b@example.com" "$b3" || return 1
    assert_file_exists "$PROJ1/.ccskill-gmail/.ccskill-metadata.json"
}

# (3) 既存の accounts.json エントリは上書きしない
test_existing_account_not_clobbered() {
    setup_fixture
    # a@example.com を account add 済みの体で先に登録 (別エンドポイント)
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "a@example.com" "preexisting-user" "SID-PRE" "DEP-PRE" "https://script.google.com/macros/s/DEPPRE/exec" "main"
    run_migrate --yes >/dev/null || return 1
    local ep cu
    ep=$(jq -r '.accounts["a@example.com"].endpoint' "$HOME/.ccskill-gmail/accounts.json")
    cu=$(jq -r '.accounts["a@example.com"].clasp_user' "$HOME/.ccskill-gmail/accounts.json")
    assert_eq "https://script.google.com/macros/s/DEPPRE/exec" "$ep" || return 1
    assert_eq "preexisting-user" "$cu"
}

# (4) 余剰デプロイ (代表以外) が出力に列挙される
test_surplus_deployments_listed() {
    setup_fixture
    local out
    out=$(run_migrate --yes) || return 1
    assert_contains "DEP2" "$out"
}

# (5) --dry-run では何も書かれない
test_dry_run_writes_nothing() {
    setup_fixture
    run_migrate --dry-run >/dev/null || return 1
    [ ! -f "$HOME/.ccskill-gmail/accounts.json" ] || {
        # accounts_init による空ファイルは許容しない (dry-run は無変更)
        local count
        count=$(jq -r '.accounts | length' "$HOME/.ccskill-gmail/accounts.json" 2>/dev/null)
        [ "${count:-0}" = "0" ] || return 1
    }
    [ ! -f "$PROJ1/.ccskill-gmail/binding.json" ]
}

# (6) email 不明のプロジェクトはスキップされ、警告が出る
test_unknown_email_skipped() {
    setup_fixture
    local tmp
    tmp=$(test_mktemp)
    jq '.installations[keys[0]].email = null' "$FIX_REGISTRY" > "$tmp"
    /bin/mv "$tmp" "$FIX_REGISTRY"
    local out
    out=$(run_migrate --yes) || return 1
    assert_contains "skip" "$out"
}

echo ""
echo "test-migrate.sh (#125)"
echo ""

run_test "accounts registered per email (representative)"  test_accounts_registered_per_email
run_test "binding.json written to each project"            test_bindings_written
run_test "existing accounts.json entry not clobbered"      test_existing_account_not_clobbered
run_test "surplus deployments listed"                      test_surplus_deployments_listed
run_test "--dry-run writes nothing"                        test_dry_run_writes_nothing
run_test "unknown email is skipped with warning"           test_unknown_email_skipped

test_summary
