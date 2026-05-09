#!/bin/bash
#
# tests/lib/test-update-check.sh - lib/update_check.sh の単体テスト
#
# Usage: bash tests/lib/test-update-check.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/test-helper.sh"
source "$REPO_ROOT/lib/update_check.sh"

# ========================================
# git repo セットアップ
# ========================================

REPO_BASE=""
BARE_REPO=""
LOCAL_REPO=""
INIT_CLONE=""

setup_git_repo() {
    REPO_BASE=$(test_mktemp_d)
    BARE_REPO="$REPO_BASE/origin.git"
    LOCAL_REPO="$REPO_BASE/local"
    INIT_CLONE="$REPO_BASE/init"

    git init --bare "$BARE_REPO" >/dev/null 2>&1
    git -C "$BARE_REPO" symbolic-ref HEAD refs/heads/main

    git clone "$BARE_REPO" "$INIT_CLONE" >/dev/null 2>&1
    git -C "$INIT_CLONE" config user.email "test@example.com"
    git -C "$INIT_CLONE" config user.name "Test"
    git -C "$INIT_CLONE" checkout -B main >/dev/null 2>&1
    echo "first" > "$INIT_CLONE/file.txt"
    git -C "$INIT_CLONE" add file.txt
    git -C "$INIT_CLONE" commit -q -m "initial commit"
    git -C "$INIT_CLONE" push -q -u origin main >/dev/null 2>&1

    git clone "$BARE_REPO" "$LOCAL_REPO" >/dev/null 2>&1
    git -C "$LOCAL_REPO" config user.email "test@example.com"
    git -C "$LOCAL_REPO" config user.name "Test"
}

teardown_git_repo() {
    [ -n "$REPO_BASE" ] && rm -rf "$REPO_BASE"
    REPO_BASE=""
}

add_commit_to_origin() {
    local subject="$1"
    echo "$RANDOM-$subject" >> "$INIT_CLONE/file.txt"
    git -C "$INIT_CLONE" add file.txt
    git -C "$INIT_CLONE" commit -q -m "$subject"
    git -C "$INIT_CLONE" push -q origin main >/dev/null 2>&1
}

# 各テスト前に呼ぶ: 一時キャッシュファイルパスを設定（存在しないパス）
fresh_cache_path() {
    local f
    f=$(test_mktemp_u)
    rm -f "$f"
    echo "$f"
}

# ========================================
# テスト: _update_check_format_from_json
# ========================================

test_format_returns_1_when_zero_commits() {
    local out
    out=$(echo '{"commits_behind":0,"latest_subject":"x"}' | _update_check_format_from_json)
    assert_exit_code 1 "$?" || return 1
    assert_eq "" "$out"
}

test_format_includes_count_and_subject() {
    local out
    out=$(echo '{"commits_behind":3,"latest_subject":"feat: foo"}' | _update_check_format_from_json) || return 1
    assert_contains "3 commit(s) behind" "$out" || return 1
    assert_contains "feat: foo" "$out"
}

test_format_omits_subject_when_empty() {
    local out
    out=$(echo '{"commits_behind":2,"latest_subject":""}' | _update_check_format_from_json) || return 1
    assert_contains "2 commit(s) behind" "$out" || return 1
    case "$out" in
        *"latest:"*)
            echo "    expected NOT to contain 'latest:' but got: $out" >&2
            return 1
            ;;
    esac
}

test_format_returns_1_for_empty_input() {
    local out
    out=$(echo "" | _update_check_format_from_json)
    assert_exit_code 1 "$?"
}

test_format_returns_1_for_invalid_json() {
    local out
    out=$(echo "not json" | _update_check_format_from_json)
    assert_exit_code 1 "$?"
}

# ========================================
# テスト: update_check_cached
# ========================================

test_cached_returns_1_when_no_file() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    update_check_cached "/some/master" >/dev/null
    assert_exit_code 1 "$?"
}

test_cached_returns_json_when_master_matches() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"/m","checked_at":"2026-01-01T00:00:00Z","commits_behind":5,"latest_subject":"x"}
EOF
    local out
    out=$(update_check_cached "/m") || return 1
    assert_eq "5" "$(echo "$out" | jq -r '.commits_behind')"
}

test_cached_returns_1_when_master_mismatches() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"/A","checked_at":"2026-01-01T00:00:00Z","commits_behind":5,"latest_subject":"x"}
EOF
    update_check_cached "/B" >/dev/null
    assert_exit_code 1 "$?"
}

# ========================================
# テスト: update_check_is_fresh
# ========================================

test_is_fresh_false_when_no_cache() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    update_check_is_fresh "/m"
    assert_exit_code 1 "$?"
}

test_is_fresh_true_when_recent_and_master_matches() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    local now_iso
    now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"/m","checked_at":"$now_iso","commits_behind":0,"latest_subject":""}
EOF
    update_check_is_fresh "/m"
    assert_exit_code 0 "$?"
}

test_is_fresh_false_when_master_mismatches() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    local now_iso
    now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"/A","checked_at":"$now_iso","commits_behind":0,"latest_subject":""}
EOF
    update_check_is_fresh "/B"
    assert_exit_code 1 "$?"
}

test_is_fresh_false_when_ttl_expired() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    # 2 日前
    local old_iso="2020-01-01T00:00:00Z"
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"/m","checked_at":"$old_iso","commits_behind":0,"latest_subject":""}
EOF
    update_check_is_fresh "/m"
    assert_exit_code 1 "$?"
}

# ========================================
# テスト: _update_check_fetch_and_count (実 git)
# ========================================

test_fetch_returns_1_when_no_git_dir() {
    local tmp
    tmp=$(mktemp -d)
    _update_check_fetch_and_count "$tmp" >/dev/null
    local rc=$?
    rm -rf "$tmp"
    assert_exit_code 1 "$rc"
}

test_fetch_returns_zero_commits_when_up_to_date() {
    setup_git_repo
    local out
    out=$(_update_check_fetch_and_count "$LOCAL_REPO") || { teardown_git_repo; return 1; }
    local count
    count=$(echo "$out" | jq -r '.commits_behind')
    teardown_git_repo
    assert_eq "0" "$count"
}

test_fetch_counts_new_commits_on_origin() {
    setup_git_repo
    add_commit_to_origin "feat: new feature"
    add_commit_to_origin "fix: bug"
    local out
    out=$(_update_check_fetch_and_count "$LOCAL_REPO") || { teardown_git_repo; return 1; }
    local count subject
    count=$(echo "$out" | jq -r '.commits_behind')
    subject=$(echo "$out" | jq -r '.latest_subject')
    teardown_git_repo
    assert_eq "2" "$count" || return 1
    assert_eq "fix: bug" "$subject"
}

# ========================================
# テスト: update_check_run (キャッシュ統合)
# ========================================

test_run_writes_cache_on_first_call() {
    setup_git_repo
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    add_commit_to_origin "feat: x"
    update_check_run "$LOCAL_REPO" >/dev/null || { teardown_git_repo; return 1; }
    assert_file_exists "$UPDATE_CHECK_CACHE_FILE" || { teardown_git_repo; return 1; }
    local count
    count=$(jq -r '.commits_behind' "$UPDATE_CHECK_CACHE_FILE")
    teardown_git_repo
    assert_eq "1" "$count"
}

test_run_uses_cache_when_fresh() {
    setup_git_repo
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    mkdir -p "$(dirname "$UPDATE_CHECK_CACHE_FILE")"
    local now_iso
    now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # 「9 コミット遅れ」と書き込んでおく — 実 git では 0 コミットだが、キャッシュが優先されることを確認
    cat > "$UPDATE_CHECK_CACHE_FILE" <<EOF
{"master_dir":"$LOCAL_REPO","checked_at":"$now_iso","commits_behind":9,"latest_subject":"cached"}
EOF
    local out
    out=$(update_check_run "$LOCAL_REPO") || { teardown_git_repo; return 1; }
    local count
    count=$(echo "$out" | jq -r '.commits_behind')
    teardown_git_repo
    assert_eq "9" "$count"
}

test_run_returns_1_when_master_dir_missing() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    update_check_run "/no/such/dir" >/dev/null
    assert_exit_code 1 "$?"
}

# ========================================
# テスト: update_check_format_oneline (E2E)
# ========================================

test_oneline_outputs_message_when_behind() {
    setup_git_repo
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    add_commit_to_origin "feat: shiny"
    local out
    out=$(update_check_format_oneline "$LOCAL_REPO") || { teardown_git_repo; return 1; }
    teardown_git_repo
    assert_contains "1 commit(s) behind" "$out" || return 1
    assert_contains "feat: shiny" "$out"
}

test_oneline_returns_1_when_up_to_date() {
    setup_git_repo
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    update_check_format_oneline "$LOCAL_REPO" >/dev/null
    local rc=$?
    teardown_git_repo
    assert_exit_code 1 "$rc"
}

test_oneline_cached_returns_1_when_no_cache() {
    UPDATE_CHECK_CACHE_FILE=$(fresh_cache_path)
    update_check_format_oneline_cached "/m" >/dev/null
    assert_exit_code 1 "$?"
}

# ========================================
# テスト: fetch 防御層 (BatchMode / ConnectTimeout) — #111
# ========================================

# fetch が SSH パスフレーズ要求でブロックしない、かつ到達不能ホストで長時間待たない
# ことを保証するため、git fetch には GIT_SSH_COMMAND='ssh -o BatchMode=yes ...' を
# 環境変数で適用していること。実際の SSH ハンドシェイクは sandbox 環境で再現が
# 難しいため、ソース上の契約を静的に検証する。
test_fetch_uses_batch_mode_ssh() {
    local source_file="$REPO_ROOT/lib/update_check.sh"
    grep -qE "GIT_SSH_COMMAND.*BatchMode=yes" "$source_file" || {
        echo "    expected $source_file to set GIT_SSH_COMMAND with BatchMode=yes" >&2
        return 1
    }
}

test_fetch_uses_connect_timeout() {
    local source_file="$REPO_ROOT/lib/update_check.sh"
    grep -qE "GIT_SSH_COMMAND.*ConnectTimeout" "$source_file" || {
        echo "    expected $source_file to set GIT_SSH_COMMAND with ConnectTimeout" >&2
        return 1
    }
}

# ========================================
# 実行
# ========================================

echo "Running update_check.sh tests..."
echo ""

run_test "format: zero commits returns 1"           test_format_returns_1_when_zero_commits
run_test "format: includes count and subject"        test_format_includes_count_and_subject
run_test "format: omits subject when empty"          test_format_omits_subject_when_empty
run_test "format: empty input returns 1"             test_format_returns_1_for_empty_input
run_test "format: invalid json returns 1"            test_format_returns_1_for_invalid_json

run_test "cached: returns 1 when no file"            test_cached_returns_1_when_no_file
run_test "cached: returns JSON when master matches"  test_cached_returns_json_when_master_matches
run_test "cached: returns 1 when master mismatches"  test_cached_returns_1_when_master_mismatches

run_test "is_fresh: false when no cache"             test_is_fresh_false_when_no_cache
run_test "is_fresh: true when recent and matching"   test_is_fresh_true_when_recent_and_master_matches
run_test "is_fresh: false when master mismatches"    test_is_fresh_false_when_master_mismatches
run_test "is_fresh: false when TTL expired"          test_is_fresh_false_when_ttl_expired

run_test "fetch: returns 1 when no .git"             test_fetch_returns_1_when_no_git_dir
run_test "fetch: zero commits when up to date"       test_fetch_returns_zero_commits_when_up_to_date
run_test "fetch: counts new commits on origin"       test_fetch_counts_new_commits_on_origin

run_test "run: writes cache on first call"           test_run_writes_cache_on_first_call
run_test "run: uses cache when fresh"                test_run_uses_cache_when_fresh
run_test "run: returns 1 when master dir missing"    test_run_returns_1_when_master_dir_missing

run_test "oneline: message when behind"              test_oneline_outputs_message_when_behind
run_test "oneline: returns 1 when up to date"        test_oneline_returns_1_when_up_to_date
run_test "oneline_cached: returns 1 when no cache"   test_oneline_cached_returns_1_when_no_cache

run_test "fetch: uses SSH BatchMode (#111)"          test_fetch_uses_batch_mode_ssh
run_test "fetch: uses SSH ConnectTimeout (#111)"     test_fetch_uses_connect_timeout

test_summary
