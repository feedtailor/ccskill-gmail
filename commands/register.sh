#!/bin/bash
#
# ccskill-gmail register - Register Existing Installations
#
# Usage: ccskill-gmail register PATH [PATH...]
#
# Registers existing installations (installed before registry feature)
# into .registry.json so they appear in status and update-all.
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
    echo "Error: This script should be called via 'ccskill-gmail register'"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required for register.sh${NC}"
    echo ""
    echo "Install jq:"
    echo "  brew install jq    # macOS"
    echo "  apt install jq     # Debian/Ubuntu"
    exit 1
fi

# ========================================
# 2. Argument validation
# ========================================

if [ $# -eq 0 ]; then
    echo "Usage: ccskill-gmail register PATH [PATH...]"
    echo ""
    echo "Register existing ccskill-gmail installations into the registry."
    echo ""
    echo "Examples:"
    echo "  ccskill-gmail register /path/to/project-a"
    echo "  ccskill-gmail register ~/projects/project-a ~/projects/project-b"
    echo "  ccskill-gmail register .    # register current directory"
    exit 1
fi

# ========================================
# 3. Initialize registry
# ========================================

source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
registry_init

# ========================================
# 4. Process each path
# ========================================

REGISTERED=0
SKIPPED=0
declare -a REGISTERED_PATHS
declare -a SKIPPED_PATHS

for input_path in "$@"; do
    # Convert to absolute path
    if [ -d "$input_path" ]; then
        abs_path=$(cd "$input_path" && pwd)
    else
        abs_path="$input_path"
    fi

    display_path="${abs_path/#$HOME/~}"

    # Check .ccskill-gmail/ exists
    if [ ! -d "$abs_path/.ccskill-gmail" ]; then
        echo -e "${YELLOW}Skip: $display_path (.ccskill-gmail/ not found)${NC}"
        SKIPPED=$((SKIPPED + 1))
        SKIPPED_PATHS+=("$display_path")
        continue
    fi

    # Register
    registry_upsert "$abs_path"
    echo -e "${GREEN}Registered: $display_path${NC}"
    REGISTERED=$((REGISTERED + 1))
    REGISTERED_PATHS+=("$display_path")
done

# ========================================
# 5. Summary
# ========================================

echo ""
echo "Results: $REGISTERED registered, $SKIPPED skipped"

if [ "$REGISTERED" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Registered:${NC}"
    for p in "${REGISTERED_PATHS[@]}"; do
        echo "  - $p"
    done
fi

if [ "$SKIPPED" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Skipped (no .ccskill-gmail/ directory):${NC}"
    for p in "${SKIPPED_PATHS[@]}"; do
        echo "  - $p"
    done
fi

if [ "$REGISTERED" -gt 0 ]; then
    echo ""
    echo "Run 'ccskill-gmail status' to verify."
fi
