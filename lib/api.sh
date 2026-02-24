#!/bin/bash
#
# Gmail Skill - API Wrapper
#
# curl の必須ルールをすべて内包するラッパー関数群。
# サブエージェントは source + ccskill-get/ccskill-post だけ覚えればよい。
#
# Usage:
#   source .ccskill-gmail/api.sh
#   ccskill-get "$GMAIL_ENDPOINT" "action=search" "query=is:unread"
#   ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"a@b.com",...}'
#

# ========================================
# 自動初期化
# ========================================
# スクリプトパスからプロジェクトルートを推定し、.env + auth.sh を自動読み込み

# トップレベルでパスを取得（bash: BASH_SOURCE, zsh: $0）
# 関数内では $0 が関数名になるため、ここで取得する必要がある
_CCSKILL_API_SH_PATH="${BASH_SOURCE[0]:-$0}"

_ccskill_init() {
    local api_sh_path="$_CCSKILL_API_SH_PATH"
    local gas_dir
    gas_dir="$(cd "$(dirname "$api_sh_path")" && pwd)"
    local project_root
    project_root="$(dirname "$gas_dir")"

    # .env を読み込み（GMAIL_ENDPOINT）
    if [ -f "$project_root/.env" ]; then
        source "$project_root/.env"
    fi

    # auth.sh を読み込み（gas_token 関数）
    if [ -f "$gas_dir/auth.sh" ]; then
        source "$gas_dir/auth.sh"
    else
        echo '{"ok":false,"error":"auth.sh not found in '"$gas_dir"'. Run: ccskill-gmail update"}' >&2
        return 1
    fi

    # gas_token 関数の存在チェック
    if ! type gas_token &>/dev/null; then
        echo '{"ok":false,"error":"gas_token function not available. Run: clasp login && ccskill-gmail update"}' >&2
        return 1
    fi

    return 0
}

_ccskill_init || return 1

# ========================================
# ccskill-assert-endpoint: エンドポイント許可リスト
# ========================================
# GAS ドメイン以外へのトークン送信を防止する

ccskill-assert-endpoint() {
    local url="$1"
    case "$url" in
        https://script.google.com/*|https://script.googleapis.com/*)
            return 0
            ;;
        *)
            echo '{"ok":false,"error":"Blocked: endpoint must be https://script.google.com/* or https://script.googleapis.com/*"}'
            return 1
            ;;
    esac
}

# ========================================
# ccskill-encode: URL エンコード
# ========================================

ccskill-encode() {
    echo -n "$1" | jq -sRr @uri
}

# ========================================
# ccskill-get: GET リクエスト
# ========================================
# Usage（推奨: key=value 形式 — 値を自動 URL エンコード、$() 不要）:
#   ccskill-get "$GMAIL_ENDPOINT" action=search query=is:unread
#   ccskill-get "$GMAIL_ENDPOINT" action=get_thread thread_id=abc123
#
# Usage（従来形式 — 後方互換）:
#   ccskill-get "$GMAIL_ENDPOINT" "action=search&query=$(ccskill-encode 'is:unread')"

ccskill-get() {
    local endpoint="$1"

    if [ -z "$endpoint" ]; then
        echo '{"ok":false,"error":"Usage: ccskill-get ENDPOINT [key=value ...]"}'
        return 1
    fi

    ccskill-assert-endpoint "$endpoint" || return $?

    local url="$endpoint"

    if [ $# -ge 3 ]; then
        # key=value 形式: 引数が 3 つ以上なら各引数をパースして値を自動エンコード
        shift
        local query_parts=()
        for arg in "$@"; do
            local key="${arg%%=*}"
            local value="${arg#*=}"
            query_parts+=("${key}=$(ccskill-encode "$value")")
        done
        local IFS='&'
        url="${endpoint}?${query_parts[*]}"
    elif [ -n "$2" ]; then
        # 従来形式: 単一クエリ文字列をそのまま使用
        url="${endpoint}?${2}"
    fi

    curl -sL --max-time 60 \
        -H "Authorization: Bearer $(gas_token)" \
        "$url"
}

# ========================================
# ccskill-post: POST リクエスト
# ========================================
# Usage:
#   ccskill-post "$GMAIL_ENDPOINT" '{"action":"create_draft","to":"a@b.com","subject":"Hi","body":"Hello"}'
#   ccskill-post "$GMAIL_ENDPOINT" @/tmp/draft.json

ccskill-post() {
    local endpoint="$1"
    local body="$2"

    if [ -z "$endpoint" ] || [ -z "$body" ]; then
        echo '{"ok":false,"error":"Usage: ccskill-post ENDPOINT JSON_BODY_OR_@FILE"}'
        return 1
    fi

    ccskill-assert-endpoint "$endpoint" || return $?

    # @file 対応: curl の --data は @file を自動認識するのでそのまま渡す
    curl -sL --max-time 60 \
        -H "Authorization: Bearer $(gas_token)" \
        -H "Content-Type: application/json" \
        --data "$body" \
        "$endpoint"
}
