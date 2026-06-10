#!/bin/bash
#
# tests/lib/test-api-resolution.sh - lib/api のメタデータ解決チェーンのテスト (#122)
#
# ネットワーク不要のオフラインテスト。観測点:
#   - endpoint が https://script.google.com/* 以外 → "Blocked:" 応答
#     (= そのメタデータが読まれたことの証明。_assert_endpoint まで到達している)
#   - endpoint がどこにも無い → MISSING_ENDPOINT
#
# Usage: bash tests/lib/test-api-resolution.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# ========================================
# フィクスチャ生成ヘルパー
# ========================================

# make_metadata DIR ENDPOINT
# DIR/.ccskill-gmail/.ccskill-metadata.json を作る (ENDPOINT が "-" なら endpoint キーなし)
make_metadata() {
    local dir="$1"
    local endpoint="$2"
    mkdir -p "$dir/.ccskill-gmail"
    if [ "$endpoint" = "-" ]; then
        printf '{"installed_from":"%s","clasp_user":"cgtest"}\n' "$REPO_DIR" \
            > "$dir/.ccskill-gmail/.ccskill-metadata.json"
    else
        printf '{"installed_from":"%s","endpoint":"%s","clasp_user":"cgtest"}\n' "$REPO_DIR" "$endpoint" \
            > "$dir/.ccskill-gmail/.ccskill-metadata.json"
    fi
}

# make_api_copy DIR — プロジェクトコピー形式の api を配置 (レガシー install を模す)
make_api_copy() {
    local dir="$1"
    mkdir -p "$dir/.ccskill-gmail"
    /bin/cp "$REPO_DIR/lib/api" "$dir/.ccskill-gmail/api"
    chmod +x "$dir/.ccskill-gmail/api"
}

# ========================================
# テストケース
# ========================================

# (1) レガシー回帰: プロジェクトコピーの api は cwd に関係なく自身のメタデータを読む
test_legacy_script_dir_resolution() {
    local proj other out
    proj=$(test_mktemp_d)
    other=$(test_mktemp_d)
    make_api_copy "$proj"
    make_metadata "$proj" "https://example.invalid/exec"

    out=$(cd "$other" && GMAIL_ENDPOINT="" "$proj/.ccskill-gmail/api" get action=search 2>&1) || true
    assert_contains "Blocked:" "$out"
}

# (2) グローバル呼び出し: ccskill-gmail api が cwd のメタデータにフォールバックする
test_global_cwd_fallback() {
    local proj out
    proj=$(test_mktemp_d)
    make_metadata "$proj" "https://example.invalid/exec"

    out=$(cd "$proj" && GMAIL_ENDPOINT="" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    assert_contains "Blocked:" "$out"
}

# (3) グローバル呼び出し: メタデータもアカウント登録も無ければ NO_ACCOUNT (#123)
test_global_no_metadata() {
    local empty out code
    empty=$(test_mktemp_d)
    HOME=$(test_mktemp_d)   # 実環境の accounts.json を遮断
    export HOME

    out=$(cd "$empty" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" api get action=search 2>&1) || true
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    assert_eq "NO_ACCOUNT" "$code" "raw output: $out"
}

# (4) 優先順位: SCRIPT_DIR のメタデータが存在すれば cwd のメタデータは読まない
test_script_dir_wins_over_cwd() {
    local proj cwd out code
    proj=$(test_mktemp_d)
    cwd=$(test_mktemp_d)
    make_api_copy "$proj"
    make_metadata "$proj" "-"                                  # endpoint キーなし
    make_metadata "$cwd" "https://example.invalid/exec"        # cwd 側には endpoint あり

    out=$(cd "$cwd" && GMAIL_ENDPOINT="" "$proj/.ccskill-gmail/api" get action=search 2>&1) || true
    code=$(printf '%s' "$out" | jq -r '.error_code // empty' 2>/dev/null)
    # cwd 側が読まれてしまうと "Blocked:" になる。SCRIPT_DIR 優先なら MISSING_ENDPOINT
    assert_eq "MISSING_ENDPOINT" "$code" "raw output: $out"
}

# (5) グローバル呼び出しの監査ログはプロジェクトの .ccskill-gmail/ に書かれる (レガシーと同じ場所)
test_global_history_location() {
    local proj
    proj=$(test_mktemp_d)
    make_metadata "$proj" "https://example.invalid/exec"

    (cd "$proj" && GMAIL_ENDPOINT="" "$REPO_DIR/ccskill-gmail" api get action=search >/dev/null 2>&1) || true
    assert_file_exists "$proj/.ccskill-gmail/audit.jsonl"
}

# (6) ccskill-gmail api を引数なしで呼ぶと Usage エラー (JSON) を返す
test_global_usage_error() {
    local out
    out=$("$REPO_DIR/ccskill-gmail" api 2>&1) || true
    assert_contains '"ok":false' "$out" || return 1
    assert_contains "Usage" "$out"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-api-resolution.sh (#122)"
echo ""

run_test "legacy: SCRIPT_DIR metadata is used regardless of cwd" test_legacy_script_dir_resolution
run_test "global: falls back to cwd metadata"                    test_global_cwd_fallback
run_test "global: NO_ACCOUNT when no metadata/accounts"          test_global_no_metadata
run_test "precedence: SCRIPT_DIR metadata wins over cwd"         test_script_dir_wins_over_cwd
run_test "global: audit log goes to project .ccskill-gmail/"     test_global_history_location
run_test "global: usage error without subcommand"                test_global_usage_error

test_summary
