#!/bin/bash
#
# ccskill-gmail apply-config - Apply config.js changes to GAS
#
# Usage: ccskill-gmail apply-config [TARGET_DIR]
#
# After manually editing .ccskill-gmail/config.js,
# run this command to push and deploy the changes to GAS.
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ========================================
# 1. Environment check
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail apply-config'"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"

# ========================================
# 2. Argument / directory validation
# ========================================

TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
GAS_DIR="$TARGET_DIR/.ccskill-gmail"

if [ ! -d "$GAS_DIR" ]; then
    echo -e "${RED}Error: .ccskill-gmail/ directory not found in $TARGET_DIR${NC}"
    echo "Run 'ccskill-gmail install' first."
    exit 1
fi

# 共有 GAS 構成 (central) はプロジェクトに config.js を持たない。
# apply-config は専用 GAS 専用なので、共有 GAS の config.js 編集 + account update を案内する。
if [ "$(ccskill_install_mode "$TARGET_DIR")" = "central" ]; then
    _bound_email=$(jq -r '.account // empty' "$GAS_DIR/binding.json" 2>/dev/null)
    _clasp_user=""
    if [ -n "$_bound_email" ]; then
        _entry=$(accounts_get "$_bound_email" 2>/dev/null) || true
        _clasp_user=$(printf '%s' "$_entry" | jq -r '.clasp_user // empty' 2>/dev/null)
    fi
    echo "This project uses the account's shared GAS (central mode)."
    echo "apply-config is for dedicated (per-project) installs only."
    echo ""
    echo "To change permissions for the shared GAS, edit its config.js and re-deploy:"
    if [ -n "$_clasp_user" ]; then
        echo -e "  1. Edit:  ${YELLOW}~/.ccskill-gmail/gas/$_clasp_user/config.js${NC}"
    else
        echo -e "  1. Edit:  ${YELLOW}~/.ccskill-gmail/gas/<clasp_user>/config.js${NC}"
    fi
    echo -e "  2. Apply: ${YELLOW}ccskill-gmail account update${NC}"
    exit 0
fi

if [ ! -f "$GAS_DIR/config.js" ]; then
    echo -e "${RED}Error: config.js not found in $GAS_DIR${NC}"
    exit 1
fi

if [ ! -f "$GAS_DIR/.clasp.json" ]; then
    echo -e "${RED}Error: .clasp.json not found in $GAS_DIR${NC}"
    exit 1
fi

echo "Applying config.js changes..."
echo ""

# ========================================
# 3. Push to GAS
# ========================================

echo "Step 1: Pushing code to GAS..."

push_gas "$GAS_DIR" "$CCSKILL_GMAIL_DIR"

echo -e "${GREEN}Code pushed${NC}"
echo ""

# ========================================
# 4. Deploy
# ========================================

METADATA_FILE="$GAS_DIR/.ccskill-metadata.json"
DEPLOYMENT_ID=""

if [ -f "$METADATA_FILE" ] && command -v jq &> /dev/null; then
    DEPLOYMENT_ID=$(jq -r '.deployment_id // empty' "$METADATA_FILE" 2>/dev/null)
fi

if [ -n "$DEPLOYMENT_ID" ]; then
    echo "Step 2: Updating deployment..."
    if deploy_gas "$GAS_DIR" "$DEPLOYMENT_ID" "Config update"; then
        echo -e "${GREEN}Deployment updated${NC}"
    else
        echo -e "${YELLOW}Warning: Auto-deploy failed. You may need to update manually.${NC}"
    fi
else
    echo -e "${YELLOW}No deployment_id in metadata. Manual deployment update required.${NC}"
    SCRIPT_ID=""
    if command -v jq &> /dev/null; then
        SCRIPT_ID=$(jq -r '.scriptId // empty' "$GAS_DIR/.clasp.json" 2>/dev/null)
    fi
    if [ -n "$SCRIPT_ID" ]; then
        echo "  https://script.google.com/d/${SCRIPT_ID}/edit"
    fi
    echo ""
    echo "Steps:"
    echo "  1. Deploy > Manage deployments"
    echo "  2. Edit > Version: 'New version' > Deploy"
fi

echo ""
echo -e "${GREEN}Done! Config changes have been applied.${NC}"
