#!/bin/bash
#
# provision.sh - GAS project provisioning (#123)
#
# install.sh から抽出した「GAS プロジェクト作成 → push → デプロイ →
# OAuth 認可 → エンドポイント検証」の一連の処理。
#
# Usage (source this file, then call):
#   source "$CCSKILL_GMAIL_DIR/lib/clasp.sh"
#   source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
#   source "$CCSKILL_GMAIL_DIR/lib/provision.sh"
#   provision_gas "$GAS_DIR" "$GAS_PROJECT_TITLE"
#
# 前提:
#   - _CLASP_USER が設定済み (clasp login 済み)
#   - $GAS_DIR/config.js が存在する
#
# 成果 (グローバル変数):
#   PROVISION_DEPLOYMENT_ID - デプロイメント ID
#   PROVISION_ENDPOINT      - Web App エンドポイント URL
#   PROVISION_VERIFY_OK     - 検証成功なら true / 失敗なら false
#
# 失敗時の再実行ヒントは PROVISION_RETRY_HINT / PROVISION_VERIFY_HINT で
# 上書きできる (デフォルトは install 向けの文言)。
#

_PROV_RED='\033[0;31m'
_PROV_GREEN='\033[0;32m'
_PROV_YELLOW='\033[1;33m'
_PROV_BLUE='\033[0;34m'
_PROV_NC='\033[0m'

provision_gas() {
    local GAS_DIR="$1"
    local GAS_PROJECT_TITLE="$2"

    local RETRY_HINT="${PROVISION_RETRY_HINT:-ccskill-gmail install}"
    local VERIFY_HINT="${PROVISION_VERIFY_HINT:-.ccskill-gmail/api get action=get_profile}"

    PROVISION_DEPLOYMENT_ID=""
    PROVISION_ENDPOINT=""
    PROVISION_VERIFY_OK=false

    # ========================================
    # clasp create
    # ========================================

    echo "Creating GAS project..."
    echo ""

    # clasp create を一時ディレクトリで実行
    local CLASP_TMPDIR
    CLASP_TMPDIR=$(mktemp -d)
    /bin/cp "$CCSKILL_GMAIL_DIR/gas-template/appsscript.json" "$CLASP_TMPDIR/"

    if ! (cd "$CLASP_TMPDIR" && _clasp create --type standalone --title "$GAS_PROJECT_TITLE"); then
        echo ""
        echo -e "${_PROV_RED}Error: clasp create failed${_PROV_NC}"
        echo ""
        echo "Possible causes:"
        echo "  1. Apps Script API is not enabled for this account"
        echo "     → Enable it at: https://script.google.com/home/usersettings"
        echo "  2. Google credentials have expired"
        echo "     → Run: ccskill-gmail setup"
        echo ""
        echo "After fixing, re-run: $RETRY_HINT"
        rm -rf "$CLASP_TMPDIR"
        return 1
    fi

    # 生成された .clasp.json を $GAS_DIR に保存
    if [ -f "$CLASP_TMPDIR/.clasp.json" ]; then
        /bin/cp "$CLASP_TMPDIR/.clasp.json" "$GAS_DIR/.clasp.json"
    else
        echo -e "${_PROV_RED}Error: clasp create did not produce .clasp.json${_PROV_NC}"
        echo ""
        echo "Run the following to re-authenticate:"
        echo "  ccskill-gmail setup"
        rm -rf "$CLASP_TMPDIR"
        return 1
    fi

    rm -rf "$CLASP_TMPDIR"

    # rootDir を設定
    local tmp
    tmp=$(mktemp)
    jq '.rootDir = "."' "$GAS_DIR/.clasp.json" > "$tmp"
    mv "$tmp" "$GAS_DIR/.clasp.json"

    echo -e "${_PROV_GREEN}✓ GAS project created${_PROV_NC}"
    echo ""

    # ========================================
    # push_gas で GAS コード push
    # ========================================

    echo "Pushing code to Google Apps Script..."
    push_gas "$GAS_DIR" "$CCSKILL_GMAIL_DIR"

    echo -e "${_PROV_GREEN}✓ Code pushed${_PROV_NC}"
    echo ""

    # ========================================
    # deploy_gas で自動デプロイ
    # ========================================

    echo "Deploying as Web App..."

    local RESULT_FILE
    RESULT_FILE=$(mktemp)
    if ! deploy_gas "$GAS_DIR" "" "Initial deployment" "$RESULT_FILE"; then
        echo -e "${_PROV_RED}Error: Failed to deploy. Check clasp login status.${_PROV_NC}"
        rm -f "$RESULT_FILE"
        return 1
    fi

    local DEPLOYMENT_ID
    DEPLOYMENT_ID=$(cat "$RESULT_FILE")
    rm -f "$RESULT_FILE"

    if [ -z "$DEPLOYMENT_ID" ]; then
        echo -e "${_PROV_RED}Error: Could not get deployment ID${_PROV_NC}"
        return 1
    fi

    local ENDPOINT_URL="https://script.google.com/macros/s/${DEPLOYMENT_ID}/exec"

    echo -e "${_PROV_GREEN}✓ Deployed successfully${_PROV_NC}"
    echo "  Deployment ID: $DEPLOYMENT_ID"
    echo -e "  Endpoint URL: ${_PROV_BLUE}$ENDPOINT_URL${_PROV_NC}"
    echo ""

    # ========================================
    # OAuth 認可
    # ========================================

    echo "================================================"
    echo "  Google Authorization Required (one-time only)"
    echo "================================================"
    echo ""
    echo "The Web App needs your permission to access Gmail."
    echo "A browser window will open - please click 'Allow' when prompted."
    echo ""
    echo -e "${_PROV_YELLOW}NOTE: You may see 'This app isn't verified' warning.${_PROV_NC}"
    echo "  Click 'Advanced' > 'Go to ... (unsafe)' > 'Allow'"
    echo ""

    echo "Authorization URL:"
    echo -e "  ${_PROV_BLUE}$ENDPOINT_URL${_PROV_NC}"
    echo ""
    echo "If the browser doesn't open automatically (e.g. SSH environment),"
    echo "open the URL above in your browser manually."
    echo ""
    echo -e "${_PROV_YELLOW}If you see 'Unable to open file' or a redirect loop:${_PROV_NC}"
    echo "  1. Open a private/incognito window"
    echo "  2. Go to https://accounts.google.com and sign in with"
    echo "     the Google account you want to use for this project"
    echo "  3. In the same window, paste this URL:"
    echo -e "     ${_PROV_BLUE}$ENDPOINT_URL${_PROV_NC}"
    echo ""

    read -p "Press Enter to open the authorization page..."

    open "$ENDPOINT_URL" 2>/dev/null || xdg-open "$ENDPOINT_URL" 2>/dev/null || true

    echo ""
    read -p "After the browser shows {\"ok\":true,...}, press Enter to continue..."

    # ========================================
    # エンドポイント検証（Bearer トークン付き）
    # ========================================

    echo ""
    echo "Verifying endpoint..."

    source "$CCSKILL_GMAIL_DIR/lib/auth.sh"

    local VERIFY_ATTEMPTS=0
    local VERIFY_OK=false

    while [ $VERIFY_ATTEMPTS -lt 3 ]; do
        local RESPONSE
        RESPONSE=$(curl -sL --max-time 60 \
            -H "Authorization: Bearer $(gas_token)" \
            "$ENDPOINT_URL" 2>/dev/null)

        if echo "$RESPONSE" | jq -e '.ok == true' >/dev/null 2>&1; then
            echo -e "${_PROV_GREEN}✓ Endpoint is working correctly${_PROV_NC}"
            VERIFY_OK=true
            break
        fi

        VERIFY_ATTEMPTS=$((VERIFY_ATTEMPTS + 1))

        if [ $VERIFY_ATTEMPTS -lt 3 ]; then
            echo -e "${_PROV_YELLOW}Endpoint not ready yet. This may happen if authorization is not complete.${_PROV_NC}"
            echo ""
            echo "Please make sure you:"
            echo "  1. Opened a private/incognito window"
            echo "  2. Signed in at https://accounts.google.com with the correct account"
            echo "  3. Pasted this URL in the same window:"
            echo -e "     ${_PROV_BLUE}$ENDPOINT_URL${_PROV_NC}"
            echo "  4. Clicked 'Allow' to authorize the script"
            echo "  5. The browser shows {\"ok\":true,...}"
            echo ""
            read -p "Press Enter to retry (attempt $((VERIFY_ATTEMPTS + 1))/3)..."
        fi
    done

    if [ "$VERIFY_OK" = false ]; then
        echo -e "${_PROV_YELLOW}Warning: Endpoint verification failed after 3 attempts.${_PROV_NC}"
        echo "The deployment was created but authorization may not be complete."
        echo ""
        echo "To complete setup later:"
        echo "  1. Open a private/incognito browser window"
        echo "  2. Sign in to your Google account at https://accounts.google.com"
        echo "  3. In the same window, open this URL:"
        echo -e "     ${_PROV_BLUE}$ENDPOINT_URL${_PROV_NC}"
        echo "  4. Click 'Allow' to authorize the script"
        echo "  5. Verify with:"
        echo "     $VERIFY_HINT"
    fi

    echo ""

    PROVISION_DEPLOYMENT_ID="$DEPLOYMENT_ID"
    PROVISION_ENDPOINT="$ENDPOINT_URL"
    PROVISION_VERIFY_OK="$VERIFY_OK"
    return 0
}
