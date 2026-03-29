#!/bin/bash
#
# Gmail Skill - Smoke Test
#
# デプロイ済み GAS Web App に対して全 API を叩いて ok/fail を判定する。
#
# Usage:
#   ./tests/smoke-test.sh TARGET_DIR [--read-only] [--include-destructive] [-v|--verbose]
#
# Examples:
#   ./tests/smoke-test.sh ~/projects/ftgmail
#   ./tests/smoke-test.sh ~/projects/ftgmail --read-only
#   ./tests/smoke-test.sh ~/projects/ftgmail -v
#

set -e

# ========================================
# Colors
# ========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

# ========================================
# 引数パース
# ========================================

TARGET_DIR=""
READ_ONLY=false
INCLUDE_DESTRUCTIVE=false
VERBOSE=false

for arg in "$@"; do
    case "$arg" in
        --read-only)
            READ_ONLY=true
            ;;
        --include-destructive)
            INCLUDE_DESTRUCTIVE=true
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        -*)
            echo "Unknown option: $arg"
            exit 1
            ;;
        *)
            TARGET_DIR="$arg"
            ;;
    esac
done

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: ./tests/smoke-test.sh TARGET_DIR [--read-only] [--include-destructive] [-v|--verbose]"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: directory not found: $TARGET_DIR"
    exit 1
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
API="$TARGET_DIR/.ccskill-gmail/api"

if [ ! -x "$API" ]; then
    echo "Error: api script not found or not executable: $API"
    exit 1
fi

# ========================================
# テストフレームワーク
# ========================================

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_COUNT=0

# run_test TYPE NAME COMMAND...
# TYPE: GET / POST / ERR
# 結果を表示し、PASS/FAIL カウントを更新
run_test() {
    local type="$1"
    local name="$2"
    shift 2

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # verbose: リクエスト内容を表示
    if [ "$VERBOSE" = true ]; then
        printf "  ${DIM}>>> %s${NC}\n" "$*"
    fi

    local start_time
    start_time=$(python3 -c "import time; print(time.time())" 2>/dev/null || echo "0")

    local output
    output=$("$@" 2>&1) || true

    local end_time
    end_time=$(python3 -c "import time; print(time.time())" 2>/dev/null || echo "0")

    local elapsed
    elapsed=$(python3 -c "print(f'{${end_time} - ${start_time}:.1f}')" 2>/dev/null || echo "?")

    # 結果を返す（呼び出し元が判定する）
    _LAST_OUTPUT="$output"
    _LAST_ELAPSED="$elapsed"
    _LAST_TYPE="$type"
    _LAST_NAME="$name"
}

# verbose: レスポンスを整形して表示
verbose_response() {
    if [ "$VERBOSE" = true ]; then
        echo "$_LAST_OUTPUT" | jq '.' 2>/dev/null | sed 's/^/       /' || echo "       $_LAST_OUTPUT"
        echo ""
    fi
}

# assert_ok — _LAST_OUTPUT の "ok":true を検証
assert_ok() {
    local ok
    ok=$(echo "$_LAST_OUTPUT" | jq -r '.ok' 2>/dev/null || echo "")

    if [ "$ok" = "true" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  %-4s %-22s ${GREEN}✓ ok${NC} ${DIM}(%ss)${NC}\n" "$_LAST_TYPE" "$_LAST_NAME" "$_LAST_ELAPSED"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  %-4s %-22s ${RED}✗ FAIL${NC} ${DIM}(%ss)${NC}\n" "$_LAST_TYPE" "$_LAST_NAME" "$_LAST_ELAPSED"
        # エラー詳細を表示
        local error_msg
        error_msg=$(echo "$_LAST_OUTPUT" | jq -r '.error // empty' 2>/dev/null || echo "")
        if [ -n "$error_msg" ]; then
            printf "       ${RED}→ %s${NC}\n" "$error_msg"
        else
            printf "       ${RED}→ %s${NC}\n" "$(echo "$_LAST_OUTPUT" | head -1)"
        fi
    fi
    verbose_response
}

# assert_error_code CODE — _LAST_OUTPUT の error_code が一致するか検証
assert_error_code() {
    local expected_code="$1"
    local actual_code
    actual_code=$(echo "$_LAST_OUTPUT" | jq -r '.error_code // empty' 2>/dev/null || echo "")

    if [ "$actual_code" = "$expected_code" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        printf "  %-4s %-22s ${GREEN}✓ ok${NC} ${DIM}(%ss)${NC}\n" "$_LAST_TYPE" "$_LAST_NAME" "$_LAST_ELAPSED"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        printf "  %-4s %-22s ${RED}✗ FAIL${NC} ${DIM}(%ss)${NC}\n" "$_LAST_TYPE" "$_LAST_NAME" "$_LAST_ELAPSED"
        printf "       ${RED}→ expected error_code=%s, got=%s${NC}\n" "$expected_code" "$actual_code"
    fi
    verbose_response
}

# skip_test TYPE NAME REASON
skip_test() {
    local type="$1"
    local name="$2"
    local reason="$3"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf "  %-4s %-22s ${YELLOW}⊘ skip${NC} ${DIM}(%s)${NC}\n" "$type" "$name" "$reason"
}

# jq で値を取り出すヘルパー
jq_val() {
    echo "$1" | jq -r "$2" 2>/dev/null || echo ""
}

# ========================================
# テスト開始
# ========================================

echo ""
echo "smoke-test (target: $TARGET_DIR)"
if [ "$READ_ONLY" = true ]; then
    echo "  mode: read-only (POST tests skipped)"
fi
if [ "$INCLUDE_DESTRUCTIVE" = true ]; then
    echo "  mode: include-destructive"
fi
if [ "$VERBOSE" = true ]; then
    echo "  mode: verbose"
fi
echo ""

# ========================================
# GET テスト
# ========================================

# --- 1. search ---
run_test "GET" "search" "$API" get action=search query=test maxResults=3
assert_ok

# search 結果から threadId を取得（後続テストで使用）
THREAD_ID=$(jq_val "$_LAST_OUTPUT" '.data.threads[0].id')

if [ -z "$THREAD_ID" ] || [ "$THREAD_ID" = "null" ]; then
    echo ""
    echo -e "${RED}Error: search returned no threads. Cannot continue.${NC}"
    echo "Ensure the target Gmail account has at least one email matching 'test'."
    exit 1
fi

# --- 2. get_thread ---
run_test "GET" "get_thread" "$API" get action=get_thread threadId="$THREAD_ID"
assert_ok

# get_thread 結果から messageId を取得
MESSAGE_ID=$(jq_val "$_LAST_OUTPUT" '.data.messages[0].id')

if [ -z "$MESSAGE_ID" ] || [ "$MESSAGE_ID" = "null" ]; then
    echo ""
    echo -e "${RED}Error: get_thread returned no messages. Cannot continue.${NC}"
    exit 1
fi

# --- 3. get_message ---
run_test "GET" "get_message" "$API" get action=get_message messageId="$MESSAGE_ID"
assert_ok

# --- 4. list_labels ---
run_test "GET" "list_labels" "$API" get action=list_labels
assert_ok

# --- 5. get_unread_count ---
run_test "GET" "get_unread_count" "$API" get action=get_unread_count
assert_ok

# --- 6. list_attachments ---
run_test "GET" "list_attachments" "$API" get action=list_attachments messageId="$MESSAGE_ID"
assert_ok

# --- 7. get_attachment ---
# 添付付きメールを検索して取得
ATTACH_MSG_ID=""
_attach_search=$("$API" get action=search query="has:attachment" maxResults=1 2>&1) || true
_attach_thread_id=$(echo "$_attach_search" | jq -r '.data.threads[0].id // empty' 2>/dev/null)
if [ -n "$_attach_thread_id" ]; then
    _attach_thread=$("$API" get action=get_thread threadId="$_attach_thread_id" 2>&1) || true
    # 添付ありのメッセージを探す
    ATTACH_MSG_ID=$(echo "$_attach_thread" | jq -r '[.data.messages[] | select(.attachments | length > 0)][0].id // empty' 2>/dev/null)
fi

if [ -n "$ATTACH_MSG_ID" ]; then
    run_test "GET" "get_attachment" "$API" get action=get_attachment messageId="$ATTACH_MSG_ID" attachmentIndex=0
    assert_ok
else
    skip_test "GET" "get_attachment" "no emails with attachments"
fi

# --- 8. get_message_html ---
run_test "GET" "get_message_html" "$API" get action=get_message_html messageId="$MESSAGE_ID"
assert_ok

# --- 9. list_drafts ---
run_test "GET" "list_drafts" "$API" get action=list_drafts maxResults=3
assert_ok

# --- 10. get_profile ---
run_test "GET" "get_profile" "$API" get action=get_profile
assert_ok

# ========================================
# POST テスト
# ========================================

if [ "$READ_ONLY" = true ]; then
    echo ""
    echo -e "  ${DIM}(POST tests skipped: --read-only)${NC}"
else
    echo ""

    # --- 11. create_draft → delete_draft ---
    run_test "POST" "create_draft" "$API" post '{"action":"create_draft","to":"smoke-test@example.com","subject":"[smoke-test] delete me","body":"This is a smoke test draft. Safe to delete."}'
    assert_ok

    DRAFT_ID=$(jq_val "$_LAST_OUTPUT" '.data.draftId')
    if [ -n "$DRAFT_ID" ] && [ "$DRAFT_ID" != "null" ]; then
        run_test "POST" "delete_draft" "$API" post "{\"action\":\"delete_draft\",\"draftId\":\"$DRAFT_ID\"}"
        assert_ok
    else
        skip_test "POST" "delete_draft" "no draftId from create_draft"
    fi

    # --- 12. mark_read → mark_unread ---
    run_test "POST" "mark_read" "$API" post "{\"action\":\"mark_read\",\"threadId\":\"$THREAD_ID\"}"
    assert_ok

    run_test "POST" "mark_unread" "$API" post "{\"action\":\"mark_unread\",\"threadId\":\"$THREAD_ID\"}"
    assert_ok

    # --- 13. add_label → remove_label ---
    # テスト用ラベル（add_label が自動作成し、remove_label で剥がす）
    SMOKE_LABEL="_smoke_test"
    run_test "POST" "add_label" "$API" post "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"$SMOKE_LABEL\"}"
    assert_ok

    run_test "POST" "remove_label" "$API" post "{\"action\":\"remove_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"$SMOKE_LABEL\"}"
    assert_ok

    # --- Destructive テスト ---
    if [ "$INCLUDE_DESTRUCTIVE" = true ]; then
        echo ""
        echo -e "  ${YELLOW}(destructive tests)${NC}"

        # archive（元に戻すため add_label INBOX で復帰）
        run_test "POST" "archive" "$API" post "{\"action\":\"archive\",\"threadId\":\"$THREAD_ID\"}"
        assert_ok

        run_test "POST" "unarchive (add INBOX)" "$API" post "{\"action\":\"add_label\",\"threadId\":\"$THREAD_ID\",\"label\":\"INBOX\"}"
        assert_ok
    fi
fi

# ========================================
# エラー系テスト
# ========================================

echo ""

# --- 14. GET で POST アクション → WRONG_METHOD ---
run_test "ERR" "wrong_method_get" "$API" get action=mark_read
assert_error_code "WRONG_METHOD"

# --- 15. POST で GET アクション → WRONG_METHOD ---
run_test "ERR" "wrong_method_post" "$API" post '{"action":"search"}'
assert_error_code "WRONG_METHOD"

# --- 16. 存在しないアクション → UNKNOWN_ACTION ---
run_test "ERR" "unknown_action" "$API" get action=nonexistent_action_xyz
assert_error_code "UNKNOWN_ACTION"

# --- 17. 必須パラメータなし → MISSING_PARAM ---
run_test "ERR" "missing_param" "$API" get action=get_thread
assert_error_code "MISSING_PARAM"

# ========================================
# 結果サマリー
# ========================================

echo ""

TESTED=$((PASS_COUNT + FAIL_COUNT))

if [ "$FAIL_COUNT" -eq 0 ]; then
    printf "${GREEN}Results: %d/%d passed${NC}" "$PASS_COUNT" "$TOTAL_COUNT"
else
    printf "${RED}Results: %d/%d passed (%d failed)${NC}" "$PASS_COUNT" "$TOTAL_COUNT" "$FAIL_COUNT"
fi

if [ "$SKIP_COUNT" -gt 0 ]; then
    printf " ${DIM}(%d skipped)${NC}" "$SKIP_COUNT"
fi

echo ""
echo ""

# 失敗があれば非ゼロで終了
if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
