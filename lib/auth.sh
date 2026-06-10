#!/bin/bash
#
# Gmail Skill - Authentication Helper
#
# Provides gas_token() function that returns a valid access_token,
# auto-refreshing if expired.
#
# Reads from ~/.clasprc.json using _CLASP_USER to select the named entry.
# Falls back to "default" if _CLASP_USER is not set.
#
# Usage:
#   source /path/to/auth.sh
#   curl -H "Authorization: Bearer $(gas_token)" "$ENDPOINT"
#

gas_token() {
    local RC_FILE="$HOME/.clasprc.json"
    local TOKEN_URI="https://oauth2.googleapis.com/token"
    local USER="${_CLASP_USER:-default}"

    if [ ! -f "$RC_FILE" ]; then
        echo "ERROR: $RC_FILE not found. Run 'ccskill-gmail install' first." >&2
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required for gas_token." >&2
        return 1
    fi

    # tokens.<user> からトークン情報を読み取り
    local access_token expiry_date
    access_token=$(jq -r --arg u "$USER" '(.tokens[$u].access_token) // empty' "$RC_FILE")
    expiry_date=$(jq -r --arg u "$USER" '(.tokens[$u].expiry_date) // 0' "$RC_FILE")

    if [ -z "$access_token" ]; then
        echo "ERROR: No credentials for user '$USER' in $RC_FILE. Run 'ccskill-gmail install' first." >&2
        return 1
    fi

    # 期限チェック（現在時刻 + 60秒のマージン）
    local now_ms
    now_ms=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s000)

    if [ "$now_ms" -lt "$((expiry_date - 60000))" ] 2>/dev/null; then
        echo "$access_token"
        return 0
    fi

    # 期限切れ → リフレッシュ
    local client_id client_secret refresh_token
    client_id=$(jq -r --arg u "$USER" '(.tokens[$u].client_id) // empty' "$RC_FILE")
    client_secret=$(jq -r --arg u "$USER" '(.tokens[$u].client_secret) // empty' "$RC_FILE")
    refresh_token=$(jq -r --arg u "$USER" '(.tokens[$u].refresh_token) // empty' "$RC_FILE")

    if [ -z "$refresh_token" ] || [ -z "$client_id" ] || [ -z "$client_secret" ]; then
        echo "ERROR: Missing credentials for user '$USER' in $RC_FILE. Run 'ccskill-gmail install' first." >&2
        return 1
    fi

    # Google OAuth2 でリフレッシュ
    local response new_token expires_in new_expiry
    response=$(curl -s -X POST "$TOKEN_URI" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=$client_id" \
        -d "client_secret=$client_secret" \
        -d "refresh_token=$refresh_token" \
        -d "grant_type=refresh_token" 2>/dev/null)

    new_token=$(echo "$response" | jq -r '.access_token // empty')

    if [ -z "$new_token" ]; then
        local error_desc
        error_desc=$(echo "$response" | jq -r '.error_description // .error // "Unknown error"')
        echo "ERROR: Token refresh failed: $error_desc. Run 'ccskill-gmail install'." >&2
        return 1
    fi

    # ~/.clasprc.json の該当エントリを更新
    expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
    new_expiry=$((now_ms + expires_in * 1000))

    # 書き戻しは同一ディレクトリの一時ファイル経由 (atomic)。
    # sandbox 等で HOME に書き込めない場合も、リフレッシュ済みトークンで
    # 処理は続行する (次回呼び出し時に再リフレッシュされるだけ)。
    local tmp="${RC_FILE}.tmp.$$"
    if { jq --arg u "$USER" --arg token "$new_token" --argjson expiry "$new_expiry" \
        '.tokens[$u].access_token = $token | .tokens[$u].expiry_date = $expiry' \
        "$RC_FILE" > "$tmp"; } 2>/dev/null && [ -s "$tmp" ]; then
        { /bin/mv "$tmp" "$RC_FILE" && chmod 600 "$RC_FILE"; } 2>/dev/null \
            || /bin/rm -f "$tmp" 2>/dev/null
    else
        /bin/rm -f "$tmp" 2>/dev/null
    fi

    echo "$new_token"
    return 0
}
