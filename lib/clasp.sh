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

# Decide whether clasp is logged in, given the raw output (stdout+stderr) of
# `_clasp show-authorized-user`. Echoes the authorized email and returns 0
# when logged in; returns 1 with no output otherwise.
#
# Unlike matching only the literal string "not logged in", this treats ANY
# output lacking a valid "logged in as <email>." line as "not logged in" —
# so a _clasp execution failure (missing module, crash, etc.) is not
# mistaken for a successful login (#153: doctor.sh previously showed a
# false "PASS clasp logged in" whenever the failure message didn't happen
# to contain the words "not logged in").
clasp_login_check() {
    local raw_output="$1"
    local email
    email=$(printf '%s' "$raw_output" | clasp_parse_authorized_email)
    if [ -n "$email" ]; then
        printf '%s\n' "$email"
        return 0
    fi
    return 1
}
