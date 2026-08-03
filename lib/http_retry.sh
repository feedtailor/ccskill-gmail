#!/bin/bash
#
# lib/http_retry.sh - GAS の一時的な HTML 応答に対する自動リトライ (#155)
#
# ccskill-gmail api の呼び出しの一部で、GAS 側の一時的な不調により、期待する JSON の代わりに
# Google のエラーページ(HTML)が返ることがある(認証切れの場合もあれば、無関係な一時的不調の
# 場合もある)。いずれも再試行すれば大抵解消するため、呼び出し側が気づかず再試行する手間を
# なくすためのリトライラッパーをここに置く。
#
# Usage:
#   source lib/http_retry.sh
#   response=$(_ccskill_fetch_with_retry curl -sL --max-time 60 -H "Authorization: Bearer $token" "$url")
#

# リトライ間隔(秒)。テストでは 0 に上書きして高速化する。
_CCSKILL_RETRY_DELAY="${_CCSKILL_RETRY_DELAY:-1}"

# 応答本文が HTML(Google のエラーページ等)に見えるかどうかを判定する。
# JSON のエラー応答({"ok":false,...})はアプリケーションレベルの正当なエラーであり
# リトライ対象にしないため、HTML かどうかだけで判定する。
_ccskill_looks_like_html() {
    local body="$1"
    local head
    head=$(printf '%s' "$body" | head -c 32)
    case "$head" in
        '<!DOCTYPE'*|'<!doctype'*|'<html'*|'<HTML'*) return 0 ;;
        *) return 1 ;;
    esac
}

# 任意のコマンド(1回のHTTP取得を行い、応答本文をstdoutに出力するものを想定)を実行し、
# 結果がHTMLに見える場合は _CCSKILL_RETRY_DELAY 秒待ってから再試行する。
# 最大3回試行し、最後の結果をそのまま返す(3回ともHTMLならHTMLのまま返す)。
_ccskill_fetch_with_retry() {
    local response attempt max_attempts=3
    for attempt in 1 2 3; do
        response=$("$@")
        if _ccskill_looks_like_html "$response" && [ "$attempt" -lt "$max_attempts" ]; then
            sleep "$_CCSKILL_RETRY_DELAY"
            continue
        fi
        break
    done
    printf '%s' "$response"
}
