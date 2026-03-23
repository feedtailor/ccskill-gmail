#!/bin/bash
#
# Gmail Skill - Authentication Helper
#
# Provides gas_token() function that returns a valid access_token
# from ~/.clasprc.json, auto-refreshing if expired.
#
# Usage:
#   source /path/to/auth.sh
#   curl -H "Authorization: Bearer $(gas_token)" "$ENDPOINT"
#

gas_token() {
    local RC_FILE="${CLASPRC_FILE:-$HOME/.clasprc.json}"
    local TOKEN_URI="https://oauth2.googleapis.com/token"

    # clasprc.json の存在チェック
    if [ ! -f "$RC_FILE" ]; then
        echo "ERROR: $RC_FILE not found. Run 'clasp login' first." >&2
        return 1
    fi

    # jq チェック
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is required for gas_token." >&2
        return 1
    fi

    # 現在のトークン情報を読み取り
    local user="${CLASP_USER:-default}"
    local access_token expiry_date
    access_token=$(jq -r --arg user "$user" '.tokens[$user].access_token // empty' "$RC_FILE")
    expiry_date=$(jq -r --arg user "$user" '.tokens[$user].expiry_date // 0' "$RC_FILE")

    if [ -z "$access_token" ]; then
        echo "ERROR: No access_token in $RC_FILE. Run 'clasp login' first." >&2
        return 1
    fi

    # 期限チェック（現在時刻 + 60秒のマージン）
    local now_ms
    now_ms=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || date +%s000)

    if [ "$now_ms" -lt "$((expiry_date - 60000))" ] 2>/dev/null; then
        # まだ有効 → そのまま返す
        echo "$access_token"
        return 0
    fi

    # 期限切れ → リフレッシュ
    local client_id client_secret refresh_token
    client_id=$(jq -r --arg user "$user" '.tokens[$user].client_id // empty' "$RC_FILE")
    client_secret=$(jq -r --arg user "$user" '.tokens[$user].client_secret // empty' "$RC_FILE")
    refresh_token=$(jq -r --arg user "$user" '.tokens[$user].refresh_token // empty' "$RC_FILE")

    if [ -z "$refresh_token" ] || [ -z "$client_id" ] || [ -z "$client_secret" ]; then
        echo "ERROR: Missing credentials in $RC_FILE. Run 'clasp login' first." >&2
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
        echo "ERROR: Token refresh failed: $error_desc. Run 'clasp login'." >&2
        return 1
    fi

    # clasprc.json を更新
    expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
    new_expiry=$((now_ms + expires_in * 1000))

    local tmp
    tmp=$(mktemp)
    if jq --arg token "$new_token" --argjson expiry "$new_expiry" --arg user "$user" \
        '.tokens[$user].access_token = $token | .tokens[$user].expiry_date = $expiry' \
        "$RC_FILE" > "$tmp"; then
        /bin/mv "$tmp" "$RC_FILE"
        chmod 600 "$RC_FILE"
    else
        /bin/rm -f "$tmp"
    fi

    echo "$new_token"
    return 0
}
