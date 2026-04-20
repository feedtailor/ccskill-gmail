#!/bin/bash
#
# ccskill-gmail info - Show installation details for the current project
#
# Usage: ccskill-gmail info [--json] [DIR]
#
# Options:
#   --json    Output in JSON format
#
# Shows account email, version, permissions, and unread counts
# for the ccskill-gmail installation in the current (or specified) directory.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ========================================
# 1. Environment check
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail info'"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
source "$CCSKILL_GMAIL_DIR/lib/update_check.sh"

# ========================================
# 2. Parse arguments
# ========================================

JSON_OUTPUT=false
TARGET_DIR=""

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_OUTPUT=true
            ;;
        *)
            TARGET_DIR="$arg"
            ;;
    esac
done

# Default to current directory
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$(pwd)"
fi

# Resolve to absolute path
if [ -d "$TARGET_DIR" ]; then
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
fi

# ========================================
# 3. Verify installation exists
# ========================================

CCSKILL_DIR="$TARGET_DIR/.ccskill-gmail"

if [ ! -d "$CCSKILL_DIR" ]; then
    echo -e "${RED}Error: No ccskill-gmail installation found in $TARGET_DIR${NC}"
    echo ""
    echo "  Run 'ccskill-gmail install' to install, or specify a directory:"
    echo "  ccskill-gmail info /path/to/project"
    exit 1
fi

# ========================================
# 4. Gather local information
# ========================================

# Version from registry
registry_init
INSTALLED_VERSION=""
INSTALLED_AT=""
UPDATED_AT=""

if command -v jq &>/dev/null && [ -f "$_REGISTRY_FILE" ]; then
    INSTALLED_VERSION=$(jq -r --arg p "$TARGET_DIR" '.installations[$p].version // ""' "$_REGISTRY_FILE" 2>/dev/null)
    INSTALLED_AT=$(jq -r --arg p "$TARGET_DIR" '.installations[$p].installed_at // ""' "$_REGISTRY_FILE" 2>/dev/null)
    UPDATED_AT=$(jq -r --arg p "$TARGET_DIR" '.installations[$p].updated_at // ""' "$_REGISTRY_FILE" 2>/dev/null)
fi

# Fallback: read version from metadata
if [ -z "$INSTALLED_VERSION" ] && [ -f "$CCSKILL_DIR/.ccskill-metadata.json" ] && command -v jq &>/dev/null; then
    INSTALLED_VERSION=$(jq -r '.version // "unknown"' "$CCSKILL_DIR/.ccskill-metadata.json" 2>/dev/null)
fi
INSTALLED_VERSION="${INSTALLED_VERSION:-unknown}"

# Master version
if [ -f "$CCSKILL_GMAIL_DIR/VERSION" ]; then
    MASTER_VERSION=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
else
    MASTER_VERSION=$(cd "$CCSKILL_GMAIL_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Up-to-date check
if [ "$INSTALLED_VERSION" = "$MASTER_VERSION" ]; then
    UP_TO_DATE=true
else
    UP_TO_DATE=false
fi

# Permissions from config.js
DENIED_ACTIONS=""
if [ -f "$CCSKILL_DIR/config.js" ]; then
    # Extract deny array values from config.js (JavaScript, not JSON)
    # Filter out comment-only lines (// ...) before extracting quoted strings
    DENIED_ACTIONS=$(sed -n '/deny:/,/\]/p' "$CCSKILL_DIR/config.js" \
        | grep -v '^\s*//' \
        | grep -o "'[^']*'" \
        | tr -d "'" \
        | paste -sd ',' - 2>/dev/null)
fi

# ========================================
# 5. Call get_profile API
# ========================================

ACCOUNT="(unavailable)"
INBOX_UNREAD="(unavailable)"
STARRED_UNREAD="(unavailable)"
API_OK=false

if [ -x "$CCSKILL_DIR/api" ]; then
    if [ "$JSON_OUTPUT" != true ]; then
        printf "Fetching account info..." >&2
    fi
    PROFILE_RESPONSE=$("$CCSKILL_DIR/api" get action=get_profile 2>/dev/null) || true
    if [ "$JSON_OUTPUT" != true ]; then
        printf "\r\033[K" >&2
    fi

    if [ -n "$PROFILE_RESPONSE" ] && command -v jq &>/dev/null; then
        API_STATUS=$(echo "$PROFILE_RESPONSE" | jq -r '.ok // false' 2>/dev/null)
        if [ "$API_STATUS" = "true" ]; then
            API_OK=true
            ACCOUNT=$(echo "$PROFILE_RESPONSE" | jq -r '.data.email // "(unavailable)"' 2>/dev/null)
            INBOX_UNREAD=$(echo "$PROFILE_RESPONSE" | jq -r '.data.inboxUnreadCount // "(unavailable)"' 2>/dev/null)
            STARRED_UNREAD=$(echo "$PROFILE_RESPONSE" | jq -r '.data.starredUnreadCount // "(unavailable)"' 2>/dev/null)
        fi
    fi
fi

# ========================================
# 6. Output
# ========================================

DISPLAY_DIR="${TARGET_DIR/#$HOME/~}"

if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    if ! command -v jq &>/dev/null; then
        echo '{"error": "jq is required for --json output"}'
        exit 1
    fi

    # Build denied array
    DENIED_JSON="[]"
    if [ -n "$DENIED_ACTIONS" ]; then
        DENIED_JSON=$(echo "$DENIED_ACTIONS" | tr ',' '\n' | jq -R . | jq -s .)
    fi

    jq -n \
        --arg account "$ACCOUNT" \
        --arg directory "$TARGET_DIR" \
        --arg version "$INSTALLED_VERSION" \
        --argjson upToDate "$UP_TO_DATE" \
        --arg installedAt "$INSTALLED_AT" \
        --arg updatedAt "$UPDATED_AT" \
        --argjson denied "$DENIED_JSON" \
        --arg inboxUnread "$INBOX_UNREAD" \
        --arg starredUnread "$STARRED_UNREAD" \
        '{
            account: $account,
            directory: $directory,
            version: $version,
            upToDate: $upToDate,
            installedAt: $installedAt,
            updatedAt: $updatedAt,
            permissions: { denied: $denied },
            inboxUnread: (if $inboxUnread == "(unavailable)" then null else ($inboxUnread | tonumber) end),
            starredUnread: (if $starredUnread == "(unavailable)" then null else ($starredUnread | tonumber) end)
        }'
    exit 0
fi

# Human-readable output
echo ""
echo "ccskill-gmail info"
echo "================================================"
echo ""

# Account
printf "  %-14s %s\n" "Account:" "$ACCOUNT"

# Directory
printf "  %-14s %s\n" "Directory:" "$DISPLAY_DIR"

# Version
if [ "$UP_TO_DATE" = true ]; then
    printf "  %-14s %s " "Version:" "$INSTALLED_VERSION"
    echo -e "${GREEN}(up to date)${NC}"
else
    printf "  %-14s %s " "Version:" "$INSTALLED_VERSION"
    echo -e "${YELLOW}(outdated → $MASTER_VERSION)${NC}"
fi

# Dates
if [ -n "$INSTALLED_AT" ]; then
    printf "  %-14s %s\n" "Installed:" "$INSTALLED_AT"
fi
if [ -n "$UPDATED_AT" ]; then
    printf "  %-14s %s\n" "Updated:" "$UPDATED_AT"
fi

# Permissions
echo ""
echo "  Permissions:"
if [ -n "$DENIED_ACTIONS" ]; then
    printf "    %-12s %s\n" "Denied:" "$DENIED_ACTIONS"
else
    printf "    %s\n" "All actions allowed"
fi

# Unread counts
echo ""
if [ "$INBOX_UNREAD" != "(unavailable)" ]; then
    printf "  %-14s %s unread\n" "Inbox:" "$INBOX_UNREAD"
    printf "  %-14s %s unread\n" "Starred:" "$STARRED_UNREAD"
else
    printf "  %-14s %s\n" "Inbox:" "(unavailable)"
    printf "  %-14s %s\n" "Starred:" "(unavailable)"
fi

# Master update check (silent on failure / up-to-date)
UPDATE_LINE=$(update_check_format_oneline "$CCSKILL_GMAIL_DIR" 2>/dev/null || true)
if [ -n "$UPDATE_LINE" ]; then
    echo ""
    echo -e "  ${YELLOW}${UPDATE_LINE}${NC}"
    echo "  Fix: cd $CCSKILL_GMAIL_DIR && git pull && ccskill-gmail update-all"
fi

echo ""
