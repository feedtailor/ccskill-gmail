#!/bin/bash
#
# ccskill-gmail update-all - Update All Installations
#
# Usage: ccskill-gmail update-all
#
# Updates all outdated installations registered in the registry.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========================================
# 1. Environment check
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail update-all'"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for update-all.sh${NC}"
    echo ""
    echo "Install jq:"
    echo "  brew install jq    # macOS"
    echo "  apt install jq     # Debian/Ubuntu"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/registry.sh"

echo "================================================"
echo "  ccskill-gmail - Update All"
echo "================================================"
echo ""

# ========================================
# 2. Load registry
# ========================================

registry_init

MASTER_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "Master version: $MASTER_VERSION"
echo ""

# ========================================
# 2.5 アカウント共有 GAS の更新 (#126)
# ========================================

echo "Updating account-level shared GAS..."
if ! "$CCSKILL_GMAIL_DIR/commands/account.sh" update; then
    echo -e "${YELLOW}Warning: some account GAS updates failed (see above). Continuing with projects.${NC}"
fi
echo ""

# ========================================
# 3. Find update targets
# ========================================

PATHS=$(jq -r '.installations | keys[]' "$_REGISTRY_FILE" 2>/dev/null)

if [ -z "$PATHS" ]; then
    echo "No installations registered."
    exit 0
fi

declare -a TARGETS
declare -a SKIP_NOT_FOUND
SKIPPED=0

while IFS= read -r path; do
    [ -z "$path" ] && continue

    version=$(jq -r --arg p "$path" '.installations[$p].version // "unknown"' "$_REGISTRY_FILE")

    if [ ! -d "$path" ] || [ ! -d "$path/.ccskill-gmail" ]; then
        SKIP_NOT_FOUND+=("$path")
    elif [ "$(ccskill_install_mode "$path")" = "central" ]; then
        # 共有 GAS 構成。account update が面倒を見るのでプロジェクト追従の対象外
        SKIPPED=$((SKIPPED + 1))
    elif [ "$version" = "$MASTER_VERSION" ]; then
        SKIPPED=$((SKIPPED + 1))
    else
        TARGETS+=("$path")
    fi
done <<< "$PATHS"

# ========================================
# 4. Status report
# ========================================

echo "Scan results:"
echo "  Up to date:  $SKIPPED"
echo "  Outdated:    ${#TARGETS[@]}"
echo "  Not found:   ${#SKIP_NOT_FOUND[@]}"
echo ""

if [ ${#SKIP_NOT_FOUND[@]} -gt 0 ]; then
    echo -e "${YELLOW}Skipping (not found):${NC}"
    for path in "${SKIP_NOT_FOUND[@]}"; do
        display_path="${path/#$HOME/~}"
        echo "  - $display_path"
    done
    echo ""
fi

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo -e "${GREEN}All installations are up to date.${NC}"
    exit 0
fi

echo "Will update:"
for path in "${TARGETS[@]}"; do
    display_path="${path/#$HOME/~}"
    version=$(jq -r --arg p "$path" '.installations[$p].version // "unknown"' "$_REGISTRY_FILE")
    echo "  - $display_path ($version -> $MASTER_VERSION)"
done
echo ""

read -p "Proceed with updating ${#TARGETS[@]} installation(s)? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Update cancelled."
    exit 0
fi
echo ""

# ========================================
# 5. Execute updates
# ========================================

SUCCESS=0
FAILED=0
declare -a FAILED_PATHS
MANUAL_DEPLOY_NEEDED=()

for target in "${TARGETS[@]}"; do
    display_path="${target/#$HOME/~}"
    echo "----------------------------------------"
    echo "Updating: $display_path"
    echo "----------------------------------------"

    if "$CCSKILL_GMAIL_DIR/commands/update.sh" --yes "$target"; then
        SUCCESS=$((SUCCESS + 1))

        # Check if manual deploy is needed
        metadata="$target/.ccskill-gmail/.ccskill-metadata.json"
        deploy_id=$(jq -r '.deployment_id // empty' "$metadata" 2>/dev/null)
        if [ -z "$deploy_id" ]; then
            MANUAL_DEPLOY_NEEDED+=("$target")
        fi
    else
        FAILED=$((FAILED + 1))
        FAILED_PATHS+=("$target")
        echo -e "${RED}Failed to update: $display_path${NC}"
    fi

    echo ""
done

# ========================================
# 6. Summary
# ========================================

echo "================================================"
echo "  Update All - Summary"
echo "================================================"
echo ""
echo "  Updated:     $SUCCESS"
echo "  Failed:      $FAILED"
echo "  Skipped:     $SKIPPED (up to date) + ${#SKIP_NOT_FOUND[@]} (not found)"
echo ""

if [ ${#FAILED_PATHS[@]} -gt 0 ]; then
    echo -e "${RED}Failed installations:${NC}"
    for path in "${FAILED_PATHS[@]}"; do
        display_path="${path/#$HOME/~}"
        echo "  - $display_path"
    done
    echo ""
fi

if [ ${#MANUAL_DEPLOY_NEEDED[@]} -gt 0 ]; then
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}  Manual Deployment Required${NC}"
    echo -e "${YELLOW}============================================${NC}"
    echo ""
    echo "${#MANUAL_DEPLOY_NEEDED[@]} installation(s) need manual deployment update."
    echo ""
    for target in "${MANUAL_DEPLOY_NEEDED[@]}"; do
        display_path="${target/#$HOME/~}"
        echo "  - $display_path"
    done
    echo ""
    echo "For each project without auto-deploy:"
    echo "  1. Open the GAS editor (ccskill-gmail open <path>)"
    echo "  2. Deploy > Manage deployments"
    echo "  3. Edit > Version: 'New version' > Deploy"
    echo ""
fi
