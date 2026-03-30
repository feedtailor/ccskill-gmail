#!/bin/bash
#
# clasp helper - Resolve clasp binary and inject --user option
#
# Usage:
#   source this file, then use _clasp instead of clasp
#   Set _CLASP_USER to automatically add --user <name> to all commands
#

_clasp() {
    local clasp_bin="$CCSKILL_GMAIL_DIR/node_modules/.bin/clasp"
    if [ ! -x "$clasp_bin" ]; then
        if command -v clasp &>/dev/null; then
            clasp_bin="clasp"
        else
            echo "Error: clasp not found. Run: ccskill-gmail setup" >&2
            return 1
        fi
    fi

    if [ -n "${_CLASP_USER:-}" ]; then
        NODE_NO_WARNINGS=1 "$clasp_bin" --user "$_CLASP_USER" "$@"
    else
        NODE_NO_WARNINGS=1 "$clasp_bin" "$@"
    fi
}

# Export for use in subshells (e.g., push-gas.sh runs clasp in a subshell via cd && _clasp)
export -f _clasp
