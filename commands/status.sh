#!/bin/bash
#
# ccskill-gmail status - Installation Status
#
# Usage: ccskill-gmail status [--json] [--clean] [--refresh]
#
# Options:
#   --json      Output in JSON format
#   --clean     Remove invalid entries from the registry
#   --refresh   Fetch account email for all installations via API
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
source "$CCSKILL_GMAIL_DIR/lib/update_check.sh"

# ========================================
# 2. Parse arguments
# ========================================

JSON_OUTPUT=false
CLEAN_MODE=false
REFRESH_MODE=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_OUTPUT=true
            ;;
        --clean)
            CLEAN_MODE=true
            ;;
        --refresh)
            REFRESH_MODE=true
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Usage: ccskill-gmail status [--json] [--clean] [--refresh]"
            exit 1
            ;;
    esac
done

# ========================================
# 3. Initialize registry
# ========================================

if [ -f "$CCSKILL_GMAIL_DIR/VERSION" ]; then
    MASTER_VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
else
    MASTER_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# --clean mode
if [ "$CLEAN_MODE" = true ]; then
    registry_init
    cleaned=$(registry_clean)
    echo "Cleaned $cleaned invalid entries from the registry."
    exit 0
fi

registry_init

# ========================================
# 3.5. --refresh mode: fetch email for all installations
# ========================================

if [ "$REFRESH_MODE" = true ]; then
    echo "Refreshing account info..."
    REFRESH_COUNT=0
    while IFS= read -r rpath; do
        [ -z "$rpath" ] && continue
        API_SCRIPT="$rpath/.ccskill-gmail/api"
        if [ -x "$API_SCRIPT" ]; then
            # Subshell to isolate set -e failures from API calls
            EMAIL=$(
                PROFILE=$("$API_SCRIPT" get action=get_profile </dev/null 2>/dev/null) || true
                [ -n "$PROFILE" ] && echo "$PROFILE" | jq -r '.data.email // empty' 2>/dev/null
            ) || true
            if [ -n "$EMAIL" ]; then
                registry_update_email "$rpath" "$EMAIL"
                REFRESH_COUNT=$((REFRESH_COUNT + 1))
            fi
        fi
    done <<< "$(jq -r '.installations | keys[]' "$_REGISTRY_FILE" 2>/dev/null)"
    echo -e "${GREEN}✓ Refreshed $REFRESH_COUNT installation(s)${NC}"
    echo ""
fi

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

# Truncate path to fit within max width, collapsing middle with ...
_truncate_path() {
    local p="$1"
    local max="$2"
    if [ ${#p} -le $max ]; then
        echo "$p"
        return
    fi
    # Keep first 2 components and grow tail from end until it fits
    local head tail
    head=$(echo "$p" | cut -d'/' -f1-2)
    # Try keeping last 2, then 1 path components
    for n in 2 1; do
        tail=$(echo "$p" | rev | cut -d'/' -f1-$n | rev)
        local candidate="${head}/.../${tail}"
        if [ ${#candidate} -le $max ]; then
            echo "$candidate"
            return
        fi
    done
    # Fallback: truncate from end
    echo "${p:0:$((max-3))}..."
}

printf "  %-40s %-24s %-12s %s\n" "PATH" "ACCOUNT" "VERSION" "STATUS"
printf "  %-40s %-24s %-12s %s\n" "----" "-------" "-------" "------"

while IFS= read -r path; do
    [ -z "$path" ] && continue

    version=$(jq -r --arg p "$path" '.installations[$p].version // "unknown"' "$_REGISTRY_FILE")
    email=$(jq -r --arg p "$path" '.installations[$p].email // ""' "$_REGISTRY_FILE" 2>/dev/null)
    display_email="${email:-(unknown)}"

    # Display path with ~ shortening and truncation
    display_path="${path/#$HOME/~}"
    display_path=$(_truncate_path "$display_path" 40)

    if [ ! -d "$path" ]; then
        printf "  %-40s %-24s %-12s " "$display_path" "$display_email" "(not found)"
        echo -e "${RED}x not found${NC}"
        NOT_FOUND=$((NOT_FOUND + 1))
    elif [ ! -d "$path/.ccskill-gmail" ]; then
        printf "  %-40s %-24s %-12s " "$display_path" "$display_email" "(not found)"
        echo -e "${RED}x not found${NC}"
        NOT_FOUND=$((NOT_FOUND + 1))
    elif [ "$version" = "$MASTER_VERSION" ]; then
        printf "  %-40s %-24s %-12s " "$display_path" "$display_email" "$version"
        echo -e "${GREEN}up to date${NC}"
        UP_TO_DATE=$((UP_TO_DATE + 1))
    else
        printf "  %-40s %-24s %-12s " "$display_path" "$display_email" "$version"
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

# Master update check (silent on failure / up-to-date)
UPDATE_LINE=$(update_check_format_oneline_cached "$CCSKILL_GMAIL_DIR" 2>/dev/null || true)
if [ -n "$UPDATE_LINE" ]; then
    echo ""
    echo -e "${YELLOW}${UPDATE_LINE}${NC}"
    echo "Fix: cd $CCSKILL_GMAIL_DIR && git pull && ccskill-gmail update-all"
fi

echo ""
