#!/bin/bash
#
# ccskill-gmail status - Installation Status
#
# Usage: ccskill-gmail status [--json] [--clean]
#
# Options:
#   --json    Output in JSON format
#   --clean   Remove invalid entries from the registry
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
    echo "Error: This script should be called via 'ccskill-gmail status'"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for status.sh${NC}"
    echo ""
    echo "Install jq:"
    echo "  brew install jq    # macOS"
    echo "  apt install jq     # Debian/Ubuntu"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/registry.sh"

# ========================================
# 2. Parse arguments
# ========================================

JSON_OUTPUT=false
CLEAN_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_OUTPUT=true
            ;;
        --clean)
            CLEAN_MODE=true
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Usage: ccskill-gmail status [--json] [--clean]"
            exit 1
            ;;
    esac
done

# ========================================
# 3. Initialize registry
# ========================================

MASTER_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# --clean mode
if [ "$CLEAN_MODE" = true ]; then
    registry_init
    cleaned=$(registry_clean)
    echo "Cleaned $cleaned invalid entries from the registry."
    exit 0
fi

registry_init

# ========================================
# 4. JSON output
# ========================================

if [ "$JSON_OUTPUT" = true ]; then
    jq --arg master_version "$MASTER_VERSION" \
        '. + {master_version: $master_version}' \
        "$_REGISTRY_FILE"
    exit 0
fi

# ========================================
# 5. Table output
# ========================================

echo ""
echo "ccskill-gmail status (version: $MASTER_VERSION)"
echo "================================================"
echo ""

PATHS=$(jq -r '.installations | keys[]' "$_REGISTRY_FILE" 2>/dev/null)

if [ -z "$PATHS" ]; then
    echo "  No installations registered."
    echo ""
    echo "  Tip: Use 'ccskill-gmail register <path>' to register existing installations."
    exit 0
fi

UP_TO_DATE=0
OUTDATED=0
NOT_FOUND=0

printf "  %-40s %-12s %s\n" "PATH" "VERSION" "STATUS"
printf "  %-40s %-12s %s\n" "----" "-------" "------"

while IFS= read -r path; do
    [ -z "$path" ] && continue

    version=$(jq -r --arg p "$path" '.installations[$p].version // "unknown"' "$_REGISTRY_FILE")

    # Display path with ~ shortening
    display_path="${path/#$HOME/~}"

    if [ ! -d "$path" ]; then
        printf "  %-40s %-12s " "$display_path" "(not found)"
        echo -e "${RED}x not found${NC}"
        NOT_FOUND=$((NOT_FOUND + 1))
    elif [ ! -d "$path/.ccskill-gmail" ]; then
        printf "  %-40s %-12s " "$display_path" "(not found)"
        echo -e "${RED}x not found${NC}"
        NOT_FOUND=$((NOT_FOUND + 1))
    elif [ "$version" = "$MASTER_VERSION" ]; then
        printf "  %-40s %-12s " "$display_path" "$version"
        echo -e "${GREEN}up to date${NC}"
        UP_TO_DATE=$((UP_TO_DATE + 1))
    else
        printf "  %-40s %-12s " "$display_path" "$version"
        echo -e "${YELLOW}outdated${NC}"
        OUTDATED=$((OUTDATED + 1))
    fi
done <<< "$PATHS"

echo ""
echo "Summary: $UP_TO_DATE up to date, $OUTDATED outdated, $NOT_FOUND not found"

if [ "$NOT_FOUND" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Tip: Run 'ccskill-gmail status --clean' to remove invalid entries${NC}"
fi

if [ "$OUTDATED" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Tip: Run 'ccskill-gmail update-all' to update all outdated installations.${NC}"
fi

echo ""
