#!/bin/bash
#
# push_gas / deploy_gas - GAS project push and deploy helpers
#
# Usage (source this file, then call):
#   source "$CCSKILL_GMAIL_DIR/lib/push-gas.sh"
#   push_gas "$GAS_DIR" "$CCSKILL_GMAIL_DIR"
#   deploy_gas "$GAS_DIR" "$DEPLOYMENT_ID" "description" "$RESULT_FILE"
#
# push_gas arguments:
#   $1 - GAS_DIR: Project's .ccskill-gmail directory (contains config.js, .clasp.json)
#   $2 - CCSKILL_GMAIL_DIR: Master repository directory (contains gas-template/)
#
# deploy_gas arguments:
#   $1 - GAS_DIR: Project's .ccskill-gmail directory (contains .clasp.json)
#   $2 - DEPLOYMENT_ID: Existing deployment ID to update (empty for new deployment)
#   $3 - DESCRIPTION: Deploy description (default: "Auto deploy")
#   $4 - RESULT_FILE: File path to write deployment ID to (optional)
#

push_gas() {
    local GAS_DIR="$1"
    local MASTER_DIR="$2"

    if [ -z "$GAS_DIR" ] || [ -z "$MASTER_DIR" ]; then
        echo "Error: push_gas requires GAS_DIR and MASTER_DIR arguments"
        return 1
    fi

    if [ ! -d "$GAS_DIR" ]; then
        echo "Error: GAS_DIR does not exist: $GAS_DIR"
        return 1
    fi

    if [ ! -d "$MASTER_DIR/gas-template" ]; then
        echo "Error: gas-template not found in $MASTER_DIR"
        return 1
    fi

    # Create temp directory with cleanup on function return
    local TMPDIR
    TMPDIR=$(mktemp -d)
    trap "rm -rf '$TMPDIR'" RETURN

    # 1. Copy master gas-template files
    /bin/cp "$MASTER_DIR/gas-template/appsscript.json" "$TMPDIR/"
    /bin/cp "$MASTER_DIR/gas-template/main.js" "$TMPDIR/"
    /bin/cp -r "$MASTER_DIR/gas-template/handlers" "$TMPDIR/"
    /bin/cp -r "$MASTER_DIR/gas-template/utils" "$TMPDIR/"

    # 2. Copy .claspignore
    if [ -f "$MASTER_DIR/gas-template/.claspignore" ]; then
        /bin/cp "$MASTER_DIR/gas-template/.claspignore" "$TMPDIR/"
    fi

    # 3. Copy project's config.js
    if [ -f "$GAS_DIR/config.js" ]; then
        /bin/cp "$GAS_DIR/config.js" "$TMPDIR/"
    else
        echo "Error: config.js not found in $GAS_DIR"
        return 1
    fi

    # 4. Copy project's .clasp.json with rootDir="."
    if [ -f "$GAS_DIR/.clasp.json" ]; then
        if command -v jq &> /dev/null; then
            jq '.rootDir = "."' "$GAS_DIR/.clasp.json" > "$TMPDIR/.clasp.json"
        else
            /bin/cp "$GAS_DIR/.clasp.json" "$TMPDIR/"
        fi
    else
        echo "Error: .clasp.json not found in $GAS_DIR"
        return 1
    fi

    # 5. clasp push from temp directory
    (cd "$TMPDIR" && clasp push --force)
}

deploy_gas() {
    local GAS_DIR="$1"
    local DEPLOYMENT_ID="${2:-}"
    local DESCRIPTION="${3:-Auto deploy}"
    local RESULT_FILE="${4:-}"

    if [ -z "$GAS_DIR" ]; then
        echo "Error: deploy_gas requires GAS_DIR argument"
        return 1
    fi

    if [ ! -f "$GAS_DIR/.clasp.json" ]; then
        echo "Error: .clasp.json not found in $GAS_DIR"
        return 1
    fi

    # Create temp directory (manual cleanup to avoid trap RETURN conflict with push_gas)
    local TMPDIR
    TMPDIR=$(mktemp -d)

    # Copy .clasp.json with rootDir="."
    if command -v jq &> /dev/null; then
        jq '.rootDir = "."' "$GAS_DIR/.clasp.json" > "$TMPDIR/.clasp.json"
    else
        /bin/cp "$GAS_DIR/.clasp.json" "$TMPDIR/"
    fi

    local OUTPUT
    local EXIT_CODE
    if [ -n "$DEPLOYMENT_ID" ]; then
        OUTPUT=$(cd "$TMPDIR" && clasp deploy -i "$DEPLOYMENT_ID" --description "$DESCRIPTION" 2>&1)
        EXIT_CODE=$?
    else
        OUTPUT=$(cd "$TMPDIR" && clasp deploy --description "$DESCRIPTION" 2>&1)
        EXIT_CODE=$?
    fi

    # Cleanup temp directory
    rm -rf "$TMPDIR"

    # Show clasp output
    echo "$OUTPUT"

    if [ $EXIT_CODE -ne 0 ]; then
        return 1
    fi

    # Extract deployment ID from clasp output (format: "Deployed DEPLOY_ID @VERSION")
    local DEPLOY_ID
    DEPLOY_ID=$(echo "$OUTPUT" | grep -oE '^Deployed [^ ]+' | head -1 | sed 's/^Deployed //')

    if [ -z "$DEPLOY_ID" ]; then
        echo "Error: Could not extract deployment ID from clasp output"
        return 1
    fi

    # Write deployment ID to result file if specified
    if [ -n "$RESULT_FILE" ]; then
        echo "$DEPLOY_ID" > "$RESULT_FILE"
    fi

    return 0
}
