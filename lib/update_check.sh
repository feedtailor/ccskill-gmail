#!/bin/bash
#
# lib/update_check.sh - ccskill-gmail master のアップデート有無チェック
#
# 公開関数:
#   update_check_run <master_dir>                 必要なら fetch、キャッシュ更新、JSON 出力
#   update_check_cached <master_dir>              fetch せずキャッシュだけ読む
#   update_check_format_oneline <master_dir>      表示用 1 行（fetch あり）
#   update_check_format_oneline_cached <master>   表示用 1 行（fetch なし）
#
# 設計:
#   - 失敗は silent（stdout/stderr に何も出さず exit 1）
#   - daily キャッシュ（TTL=24h、UPDATE_CHECK_TTL_SECONDS で上書き可）
#   - キャッシュ: ~/.cache/ccskill-gmail/remote-check.json
#                  （UPDATE_CHECK_CACHE_FILE で上書き可、テスト用）
#

# 多重 source ガード
if [ -n "${_UPDATE_CHECK_LOADED:-}" ]; then
    return 0 2>/dev/null || true
fi
_UPDATE_CHECK_LOADED=1

UPDATE_CHECK_TTL_SECONDS=${UPDATE_CHECK_TTL_SECONDS:-86400}

# ----- 内部ユーティリティ -----

_update_check_cache_file() {
    if [ -n "${UPDATE_CHECK_CACHE_FILE:-}" ]; then
        echo "$UPDATE_CHECK_CACHE_FILE"
    else
        echo "${HOME}/.cache/ccskill-gmail/remote-check.json"
    fi
}

_update_check_now_epoch() {
    date -u +%s
}

_update_check_now_iso() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# ISO8601 (UTC, Z 付き) を epoch 秒に変換
# 失敗時: 空、exit 1
_update_check_iso_to_epoch() {
    local iso="$1"
    [ -z "$iso" ] && return 1
    # GNU date
    local result
    result=$(date -d "$iso" +%s 2>/dev/null) && { echo "$result"; return 0; }
    # BSD date (macOS)
    result=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null) && { echo "$result"; return 0; }
    return 1
}

# JSON から表示文字列を作る
# 引数は stdin から JSON
# commits_behind=0 や JSON 不正なら exit 1
_update_check_format_from_json() {
    local json
    json=$(cat)
    [ -n "$json" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local count subject
    count=$(echo "$json" | jq -r '.commits_behind // 0' 2>/dev/null)
    subject=$(echo "$json" | jq -r '.latest_subject // ""' 2>/dev/null)

    [ -n "$count" ] || return 1
    case "$count" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$count" -gt 0 ] || return 1

    if [ -n "$subject" ]; then
        echo "Updates available: $count commit(s) behind origin/main (latest: $subject)"
    else
        echo "Updates available: $count commit(s) behind origin/main"
    fi
}

# git fetch + rev-list で commits_behind を取得し、キャッシュ JSON 形式で出力
# 引数: <master_dir>
# 失敗時: 空、exit 1
_update_check_fetch_and_count() {
    local master_dir="$1"
    [ -d "$master_dir/.git" ] || return 1
    command -v git >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1

    # SSH 鍵にパスフレーズが付いている場合や origin が到達不能な場合に
    # 対話プロンプトでブロックさせない / 長時間待たせない (#111)。
    # 明示的な ccskill-gmail update では呼ばれないため、ユーザーが意図的に
    # fetch する経路は影響を受けない。
    GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' \
        git -C "$master_dir" fetch --quiet origin main 2>/dev/null || return 1

    local count
    count=$(git -C "$master_dir" rev-list --count HEAD..origin/main 2>/dev/null) || return 1
    [ -n "$count" ] || return 1

    local subject=""
    if [ "$count" -gt 0 ]; then
        subject=$(git -C "$master_dir" log -1 --pretty=%s origin/main 2>/dev/null) || subject=""
    fi

    jq -n \
        --arg master_dir "$master_dir" \
        --arg checked_at "$(_update_check_now_iso)" \
        --argjson commits_behind "$count" \
        --arg latest_subject "$subject" \
        '{master_dir: $master_dir, checked_at: $checked_at, commits_behind: $commits_behind, latest_subject: $latest_subject}'
}

# stdin の内容をキャッシュファイルに書き込む
_update_check_write_cache() {
    local cache
    cache=$(_update_check_cache_file)
    mkdir -p "$(dirname "$cache")" 2>/dev/null || return 1
    local tmp="${cache}.tmp.$$"
    cat > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$cache" 2>/dev/null
}

# ----- 公開関数 -----

# キャッシュが新鮮（24h 以内、master_dir 一致）か
# 引数: <master_dir>
# exit: 0=fresh, 1=stale or missing
update_check_is_fresh() {
    local master_dir="$1"
    local cache
    cache=$(_update_check_cache_file)
    [ -f "$cache" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local cached_master cached_at
    cached_master=$(jq -r '.master_dir // ""' "$cache" 2>/dev/null)
    cached_at=$(jq -r '.checked_at // ""' "$cache" 2>/dev/null)

    [ "$cached_master" = "$master_dir" ] || return 1
    [ -n "$cached_at" ] || return 1

    local now epoch
    now=$(_update_check_now_epoch)
    epoch=$(_update_check_iso_to_epoch "$cached_at") || return 1

    local age=$((now - epoch))
    [ "$age" -lt "$UPDATE_CHECK_TTL_SECONDS" ]
}

# fetch せずキャッシュ JSON だけ読む
# 引数: <master_dir>
# 出力: JSON
# exit: 0=cached, 1=missing or master mismatch
update_check_cached() {
    local master_dir="$1"
    local cache
    cache=$(_update_check_cache_file)
    [ -f "$cache" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1

    local cached_master
    cached_master=$(jq -r '.master_dir // ""' "$cache" 2>/dev/null)
    [ "$cached_master" = "$master_dir" ] || return 1

    cat "$cache"
}

# 必要なら fetch、キャッシュ更新、JSON 出力
# 引数: <master_dir>
# 出力: JSON
# exit: 0=success, 1=failure (silent)
update_check_run() {
    local master_dir="$1"
    [ -n "$master_dir" ] || return 1
    [ -d "$master_dir" ] || return 1

    if update_check_is_fresh "$master_dir"; then
        update_check_cached "$master_dir"
        return $?
    fi

    local result
    result=$(_update_check_fetch_and_count "$master_dir") || return 1
    [ -n "$result" ] || return 1

    echo "$result" | _update_check_write_cache || return 1
    echo "$result"
}

# 表示用 1 行（fetch あり）
# 引数: <master_dir>
# 出力: "Updates available: N commit(s) behind origin/main (latest: ...)" or 空
update_check_format_oneline() {
    local master_dir="$1"
    update_check_run "$master_dir" | _update_check_format_from_json
}

# 表示用 1 行（fetch なし、キャッシュ読むだけ）
# 引数: <master_dir>
update_check_format_oneline_cached() {
    local master_dir="$1"
    update_check_cached "$master_dir" | _update_check_format_from_json
}
