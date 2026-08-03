#!/bin/bash
#
# tests/lib/test-http-retry.sh - GAS の一時的な HTML 応答に対する自動リトライ (#155)
#
# _ccskill_looks_like_html: 応答本文が HTML(Google のエラーページ等)に見えるかを判定する。
# _ccskill_fetch_with_retry: 1回のHTTP取得を行うコマンドを実行し、結果がHTMLに見える場合は
#   短い間隔を空けて最大3回まで自動的にリトライする。
#
# Usage: bash tests/lib/test-http-retry.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"
# shellcheck source=/dev/null
source "$REPO_DIR/lib/http_retry.sh"

# リトライ待機時間をテストでは0にしてテスト実行を高速化する
_CCSKILL_RETRY_DELAY=0

# ========================================
# _ccskill_looks_like_html
# ========================================

test_html_doctype_is_html() {
    _ccskill_looks_like_html '<!DOCTYPE html><html lang="ja">...'
    assert_exit_code 0 "$?"
}

test_html_doctype_lowercase_is_html() {
    _ccskill_looks_like_html '<!doctype html><html>...'
    assert_exit_code 0 "$?"
}

test_html_tag_without_doctype_is_html() {
    _ccskill_looks_like_html '<html><head></head><body>error</body></html>'
    assert_exit_code 0 "$?"
}

test_json_success_is_not_html() {
    _ccskill_looks_like_html '{"ok":true,"data":{"status":"ok"}}'
    assert_exit_code 1 "$?"
}

test_json_error_is_not_html() {
    # アプリケーションレベルの正当なエラーはリトライ対象にしない
    _ccskill_looks_like_html '{"ok":false,"error":"Unknown action: foo"}'
    assert_exit_code 1 "$?"
}

test_empty_is_not_html() {
    _ccskill_looks_like_html ''
    assert_exit_code 1 "$?"
}

# ========================================
# _ccskill_fetch_with_retry
# ========================================

# _ccskill_fetch_with_retry は response=$("$@") のようにコマンド置換(サブシェル)経由で
# フェイク関数を呼ぶため、フェイク側の呼び出し回数はシェル変数ではなくファイルで数える
# (サブシェル内の変数変更は親シェルに伝播しないため)。

# 1回目はHTML、2回目にJSONを返すフェイクの取得コマンド
_fake_fetch_html_then_json() {
    local count
    count=$(( $(cat "$FAKE_FETCH_COUNTER_FILE") + 1 ))
    echo "$count" > "$FAKE_FETCH_COUNTER_FILE"
    if [ "$count" -lt 2 ]; then
        printf '%s' '<!DOCTYPE html><html>ページが見つかりません</html>'
    else
        printf '%s' '{"ok":true,"data":{"status":"ok"}}'
    fi
}

test_retry_succeeds_after_one_html_response() {
    FAKE_FETCH_COUNTER_FILE=$(test_mktemp)
    echo 0 > "$FAKE_FETCH_COUNTER_FILE"
    local out
    out=$(_ccskill_fetch_with_retry _fake_fetch_html_then_json)
    assert_eq '{"ok":true,"data":{"status":"ok"}}' "$out" || return 1
    assert_eq "2" "$(cat "$FAKE_FETCH_COUNTER_FILE")"
}

# 常にHTMLを返すフェイクの取得コマンド
_fake_fetch_always_html() {
    local count
    count=$(( $(cat "$FAKE_FETCH_COUNTER_FILE") + 1 ))
    echo "$count" > "$FAKE_FETCH_COUNTER_FILE"
    printf '%s' '<!DOCTYPE html><html>ページが見つかりません</html>'
}

test_retry_gives_up_after_max_attempts() {
    FAKE_FETCH_COUNTER_FILE=$(test_mktemp)
    echo 0 > "$FAKE_FETCH_COUNTER_FILE"
    local out
    out=$(_ccskill_fetch_with_retry _fake_fetch_always_html)
    assert_contains "DOCTYPE" "$out" || return 1
    # 最大3回で打ち切られること(無限リトライしないこと)
    assert_eq "3" "$(cat "$FAKE_FETCH_COUNTER_FILE")"
}

# 1回目で成功する場合はリトライしないこと
_fake_fetch_immediate_success() {
    local count
    count=$(( $(cat "$FAKE_FETCH_COUNTER_FILE") + 1 ))
    echo "$count" > "$FAKE_FETCH_COUNTER_FILE"
    printf '%s' '{"ok":true,"data":{}}'
}

test_retry_does_not_retry_on_first_success() {
    FAKE_FETCH_COUNTER_FILE=$(test_mktemp)
    echo 0 > "$FAKE_FETCH_COUNTER_FILE"
    _ccskill_fetch_with_retry _fake_fetch_immediate_success > /dev/null
    assert_eq "1" "$(cat "$FAKE_FETCH_COUNTER_FILE")"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-http-retry.sh (#155)"
echo ""

run_test "DOCTYPE付きHTMLを検知する"                     test_html_doctype_is_html
run_test "小文字doctypeも検知する"                       test_html_doctype_lowercase_is_html
run_test "DOCTYPEなしhtmlタグも検知する"                 test_html_tag_without_doctype_is_html
run_test "JSON成功応答はHTMLと判定しない"                test_json_success_is_not_html
run_test "JSON失敗応答はHTMLと判定しない(リトライ対象外)" test_json_error_is_not_html
run_test "空文字列はHTMLと判定しない"                    test_empty_is_not_html
run_test "1回HTML→2回目JSONで成功する"                   test_retry_succeeds_after_one_html_response
run_test "常にHTMLなら最大3回で打ち切る"                 test_retry_gives_up_after_max_attempts
run_test "初回成功時はリトライしない"                     test_retry_does_not_retry_on_first_success

test_summary
