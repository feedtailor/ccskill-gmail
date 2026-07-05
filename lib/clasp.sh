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

# Extract the authorized Google account email from `clasp show-authorized-user`
# output (read from stdin). Prints the email, or nothing if not logged in.
# `clasp show-authorized-user` prints "You are logged in as <email>." on success;
# trailing error lines (e.g. token write errors) are ignored, first match wins.
clasp_parse_authorized_email() {
    sed -n 's/.*logged in as \([^ ]*\)\..*/\1/p' | head -n1
}

# Return the email of the account currently authorized for $_CLASP_USER.
# Empty if not logged in. Runs clasp; not for unit tests (use the parser above).
clasp_authorized_email() {
    _clasp show-authorized-user 2>&1 | clasp_parse_authorized_email
}
