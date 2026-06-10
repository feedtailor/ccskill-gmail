#!/bin/bash
#
# accounts.sh - Central account registry helper functions (#123)
#
# Usage (source this file, then call):
#   source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"
#   accounts_upsert EMAIL CLASP_USER SCRIPT_ID DEPLOYMENT_ID ENDPOINT [LABEL]
#
# Registry file: ~/.ccskill-gmail/accounts.json (dir 700 / file 600)
#
# Schema (2.0):
#   {
#     "schema_version": "2.0",
#     "default_account": "you@example.com" | null,
#     "accounts": {
#       "you@example.com": {
#         "label": "personal" | null,
#         "clasp_user": "...",
#         "script_id": "...",
#         "deployment_id": "...",
#         "endpoint": "https://script.google.com/macros/s/.../exec",
#         "created_at": "...",
#         "verified_at": "...",
#         "version": "..."
#       }
#     }
#   }
#
# jq が無い場合は全関数が警告のみで何もしない (registry.sh と同じ流儀)。
#

_ACCOUNTS_JQ_WARNED=false

# ========================================
# Internal helpers
# ========================================

# HOME 依存はテスト容易性のため呼び出し時に解決する (source 時に固定しない)
_accounts_dir() {
    echo "$HOME/.ccskill-gmail"
}

_accounts_file() {
    echo "$HOME/.ccskill-gmail/accounts.json"
}

_accounts_has_jq() {
    if command -v jq &> /dev/null; then
        return 0
    fi
    if [ "$_ACCOUNTS_JQ_WARNED" = false ]; then
        _ACCOUNTS_JQ_WARNED=true
        echo -e "\033[1;33mNote: jq is not installed - account features disabled\033[0m" >&2
    fi
    return 1
}

_accounts_now() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Atomic write: write to tmpfile (同一ディレクトリ) then mv
_accounts_write() {
    local content="$1"
    local file
    file=$(_accounts_file)
    local tmp="${file}.tmp.$$"
    if printf '%s\n' "$content" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        /bin/mv -f "$tmp" "$file" && chmod 600 "$file"
    else
        /bin/rm -f "$tmp" 2>/dev/null
        return 1
    fi
}

# ========================================
# Public functions
# ========================================

# Initialize accounts file if it doesn't exist or is corrupted.
accounts_init() {
    _accounts_has_jq || return 0

    local dir file
    dir=$(_accounts_dir)
    file=$(_accounts_file)

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" && chmod 700 "$dir" || return 1
    fi

    if [ -f "$file" ]; then
        if jq empty "$file" 2>/dev/null; then
            return 0
        fi
        # Corrupted — backup and recreate
        local backup="${file}.bak.$(date '+%Y%m%d%H%M%S')"
        /bin/mv -f "$file" "$backup"
    fi

    _accounts_write "{
  \"schema_version\": \"2.0\",
  \"default_account\": null,
  \"accounts\": {}
}"
}

# Add or update an account entry.
# Usage: accounts_upsert EMAIL CLASP_USER SCRIPT_ID DEPLOYMENT_ID ENDPOINT [LABEL]
# 最初の 1 件は自動的に default_account になる。
accounts_upsert() {
    _accounts_has_jq || return 0

    local email="$1"
    local clasp_user="$2"
    local script_id="$3"
    local deployment_id="$4"
    local endpoint="$5"
    local label="${6:-}"

    if [ -z "$email" ] || [ -z "$clasp_user" ] || [ -z "$endpoint" ]; then
        echo "Error: accounts_upsert requires EMAIL, CLASP_USER and ENDPOINT" >&2
        return 1
    fi

    accounts_init || return 1

    local file now version
    file=$(_accounts_file)
    now=$(_accounts_now)
    if [ -f "${CCSKILL_GMAIL_DIR:-}/VERSION" ]; then
        version=$(cat "$CCSKILL_GMAIL_DIR/VERSION")
    else
        version=$(cd "${CCSKILL_GMAIL_DIR:-.}" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    # 既存エントリの created_at を維持
    local created_at
    created_at=$(jq -r --arg e "$email" '.accounts[$e].created_at // empty' "$file" 2>/dev/null)
    [ -z "$created_at" ] && created_at="$now"

    local content
    content=$(jq --arg email "$email" \
       --arg label "$label" \
       --arg clasp_user "$clasp_user" \
       --arg script_id "$script_id" \
       --arg deployment_id "$deployment_id" \
       --arg endpoint "$endpoint" \
       --arg created_at "$created_at" \
       --arg now "$now" \
       --arg version "$version" \
       '.accounts[$email] = {
          label: (if $label == "" then null else $label end),
          clasp_user: $clasp_user,
          script_id: (if $script_id == "" then null else $script_id end),
          deployment_id: (if $deployment_id == "" then null else $deployment_id end),
          endpoint: $endpoint,
          created_at: $created_at,
          verified_at: $now,
          version: $version
        }
        | if .default_account == null then .default_account = $email else . end' \
       "$file") || return 1
    _accounts_write "$content"
}

# Resolve EMAIL_OR_LABEL to an entry. Outputs compact JSON {email, ...entry}.
# Returns 1 if not found.
accounts_get() {
    _accounts_has_jq || return 1

    local ident="$1"
    local file
    file=$(_accounts_file)
    [ -f "$file" ] || return 1

    local entry
    entry=$(jq -c --arg i "$ident" '
        (.accounts[$i] // null) as $by_email
        | if $by_email != null then {email: $i} + $by_email
          else (
            ([.accounts | to_entries[] | select(.value.label == $i)] | first) as $m
            | if $m == null then empty else {email: $m.key} + $m.value end
          )
          end' "$file" 2>/dev/null)

    if [ -z "$entry" ]; then
        return 1
    fi
    printf '%s\n' "$entry"
}

# Output the email to use when no account is specified:
# default_account → (null なら) 登録が 1 件だけならそれ → 空 (return 1)
accounts_resolve_default() {
    _accounts_has_jq || return 1

    local file
    file=$(_accounts_file)
    [ -f "$file" ] || return 1

    local email
    email=$(jq -r '
        if .default_account != null then .default_account
        elif (.accounts | length) == 1 then (.accounts | keys[0])
        else empty
        end' "$file" 2>/dev/null)

    if [ -z "$email" ]; then
        return 1
    fi
    printf '%s\n' "$email"
}

# Set default account by email or label.
accounts_set_default() {
    _accounts_has_jq || return 0

    local ident="$1"
    local entry email
    entry=$(accounts_get "$ident") || {
        echo "Error: account not found: $ident" >&2
        return 1
    }
    email=$(printf '%s' "$entry" | jq -r '.email')

    local file content
    file=$(_accounts_file)
    content=$(jq --arg e "$email" '.default_account = $e' "$file") || return 1
    _accounts_write "$content"
}

# Remove an account by email or label.
# default を消した場合: 残りが 1 件ならそれを default に、それ以外は null。
accounts_remove() {
    _accounts_has_jq || return 0

    local ident="$1"
    local entry email
    entry=$(accounts_get "$ident") || {
        echo "Error: account not found: $ident" >&2
        return 1
    }
    email=$(printf '%s' "$entry" | jq -r '.email')

    local file content
    file=$(_accounts_file)
    content=$(jq --arg e "$email" '
        del(.accounts[$e])
        | if .default_account == $e then
            (if (.accounts | length) == 1 then .default_account = (.accounts | keys[0])
             else .default_account = null end)
          else . end' "$file") || return 1
    _accounts_write "$content"
}

# Output all accounts as JSON.
accounts_list() {
    _accounts_has_jq || return 0

    accounts_init
    jq '.' "$(_accounts_file)"
}

# Write a project binding file (.ccskill-gmail/binding.json).
# Usage: accounts_write_binding DIR EMAIL
accounts_write_binding() {
    local dir="$1"
    local email="$2"
    if [ -z "$dir" ] || [ -z "$email" ]; then
        return 1
    fi
    mkdir -p "$dir/.ccskill-gmail" || return 1
    printf '{"schema_version":"1.0","account":"%s","bound_at":"%s"}\n' \
        "$email" "$(_accounts_now)" > "$dir/.ccskill-gmail/binding.json" || return 1
    chmod 600 "$dir/.ccskill-gmail/binding.json" 2>/dev/null || true
}

# Number of registered accounts.
accounts_count() {
    _accounts_has_jq || { echo 0; return 0; }

    local file
    file=$(_accounts_file)
    if [ ! -f "$file" ]; then
        echo 0
        return 0
    fi
    jq -r '.accounts | length' "$file" 2>/dev/null || echo 0
}
