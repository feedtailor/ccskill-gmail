#!/bin/bash
#
# registry.sh - Installation registry helper functions
#
# Usage (source this file, then call):
#   source "$CCSKILL_GMAIL_DIR/lib/registry.sh"
#   registry_upsert "$TARGET_DIR"
#
# Registry file: $CCSKILL_GMAIL_DIR/.registry.json
#
# If jq is not available, functions show a one-time warning and skip.
# Existing functionality is never affected.
#

# Registry file path (set when sourced)
_REGISTRY_FILE="${CCSKILL_GMAIL_DIR:-.}/.registry.json"

# Flag to show jq warning only once per script execution
_REGISTRY_JQ_WARNED=false

# ========================================
# Internal helpers
# ========================================

_registry_has_jq() {
    if command -v jq &> /dev/null; then
        return 0
    fi
    if [ "$_REGISTRY_JQ_WARNED" = false ]; then
        _REGISTRY_JQ_WARNED=true
        echo -e "\033[1;33mNote: jq is not installed - registry features disabled\033[0m" >&2
    fi
    return 1
}

_registry_now() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Atomic write: write to tmpfile then mv
_registry_write() {
    local content="$1"
    local tmp
    tmp=$(mktemp)
    echo "$content" > "$tmp"
    /bin/mv -f "$tmp" "$_REGISTRY_FILE"
}

# ========================================
# Public functions
# ========================================

# Initialize registry file if it doesn't exist or is corrupted.
# Creates a new empty registry. If the file exists but is invalid JSON,
# backs it up and creates a fresh one.
registry_init() {
    _registry_has_jq || return 0

    if [ -f "$_REGISTRY_FILE" ]; then
        # Validate existing file
        if jq empty "$_REGISTRY_FILE" 2>/dev/null; then
            return 0
        fi
        # Corrupted — backup and recreate
        local backup="${_REGISTRY_FILE}.bak.$(date '+%Y%m%d%H%M%S')"
        /bin/mv -f "$_REGISTRY_FILE" "$backup"
    fi

    local now
    now=$(_registry_now)
    _registry_write "{
  \"schema_version\": \"1.0\",
  \"updated_at\": \"$now\",
  \"installations\": {}
}"
}

# Add or update an entry for $target_dir.
# Reads .ccskill-metadata.json from the target's .ccskill-gmail/ directory.
registry_upsert() {
    _registry_has_jq || return 0

    local target_dir="$1"
    if [ -z "$target_dir" ]; then
        return 1
    fi

    # Ensure absolute path
    if [ -d "$target_dir" ]; then
        target_dir=$(cd "$target_dir" && pwd)
    fi

    registry_init

    local metadata_file="$target_dir/.ccskill-gmail/.ccskill-metadata.json"
    local now
    now=$(_registry_now)

    local project_name installed_at version

    if [ -f "$metadata_file" ]; then
        project_name=$(jq -r '.project_name // empty' "$metadata_file" 2>/dev/null)
        installed_at=$(jq -r '.installed_at // empty' "$metadata_file" 2>/dev/null)
        version=$(jq -r '.version // "unknown"' "$metadata_file" 2>/dev/null)
    else
        project_name=$(basename "$target_dir")
        installed_at="$now"
        version="unknown"
    fi

    # Determine if this is an update (entry already exists)
    local existing_installed_at
    existing_installed_at=$(jq -r --arg path "$target_dir" '.installations[$path].installed_at // empty' "$_REGISTRY_FILE" 2>/dev/null)
    if [ -n "$existing_installed_at" ]; then
        installed_at="$existing_installed_at"
    fi

    local tmp
    tmp=$(mktemp)
    jq --arg path "$target_dir" \
       --arg project_name "${project_name:-$(basename "$target_dir")}" \
       --arg installed_at "${installed_at:-$now}" \
       --arg updated_at "$now" \
       --arg version "${version:-unknown}" \
       '.installations[$path] = {
          project_name: $project_name,
          installed_at: $installed_at,
          updated_at: $updated_at,
          version: $version
        } | .updated_at = $updated_at' \
       "$_REGISTRY_FILE" > "$tmp"
    /bin/mv -f "$tmp" "$_REGISTRY_FILE"
}

# Remove the entry for $target_dir.
registry_remove() {
    _registry_has_jq || return 0

    local target_dir="$1"
    if [ -z "$target_dir" ]; then
        return 1
    fi

    # Ensure absolute path
    if [ -d "$target_dir" ]; then
        target_dir=$(cd "$target_dir" && pwd)
    fi

    if [ ! -f "$_REGISTRY_FILE" ]; then
        return 0
    fi

    local now
    now=$(_registry_now)
    local tmp
    tmp=$(mktemp)
    jq --arg path "$target_dir" --arg now "$now" \
       'del(.installations[$path]) | .updated_at = $now' \
       "$_REGISTRY_FILE" > "$tmp"
    /bin/mv -f "$tmp" "$_REGISTRY_FILE"
}

# Output all entries as JSON.
registry_list() {
    _registry_has_jq || return 0

    registry_init

    jq '.' "$_REGISTRY_FILE"
}

# Verify that a registered path still has a valid installation.
# Returns: 0=valid, 1=path does not exist, 2=installation missing
registry_verify() {
    local target_dir="$1"
    if [ -z "$target_dir" ]; then
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        return 1
    fi

    if [ ! -d "$target_dir/.ccskill-gmail" ]; then
        return 2
    fi

    return 0
}

# Remove all invalid entries from the registry.
registry_clean() {
    _registry_has_jq || return 0

    if [ ! -f "$_REGISTRY_FILE" ]; then
        return 0
    fi

    local paths
    paths=$(jq -r '.installations | keys[]' "$_REGISTRY_FILE" 2>/dev/null)

    local removed=0
    for path in $paths; do
        if ! registry_verify "$path"; then
            registry_remove "$path"
            removed=$((removed + 1))
        fi
    done

    echo "$removed"
}
