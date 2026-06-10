#!/bin/bash
#
# Gmail Skill - History Viewer
#
# Usage: ccskill-gmail history [subcommand] [args]
#
# Subcommands:
#   (none) / list [N] [--json] [--action X] [--since DATE] [--errors]
#                  [--account EMAIL_OR_LABEL] [--all]
#                              Show history (default: 20 entries, human-readable)
#   clear --yes [--account X]  Clear history (--yes required)
#
# 表示対象の決定 (#125):
#   --account X        → そのアカウントの中央履歴 (~/.ccskill-gmail/history/<email>/)
#   --all              → 中央履歴の全アカウント + (あれば) cwd プロジェクトの履歴
#   どちらも無し       → cwd に .ccskill-gmail/ があればプロジェクト履歴 (従来)、
#                        無ければ中央履歴の全アカウント
#

set -e

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail history'"
    exit 1
fi

CENTRAL_BASE="$HOME/.ccskill-gmail/history"

# history.sh をマスターから読み込み（後方互換でローカルもフォールバック）
if [ -f "$CCSKILL_GMAIL_DIR/lib/history.sh" ]; then
    # shellcheck source=/dev/null
    source "$CCSKILL_GMAIL_DIR/lib/history.sh"
elif [ -f ".ccskill-gmail/history.sh" ]; then
    # shellcheck source=/dev/null
    source ".ccskill-gmail/history.sh"
else
    echo "Error: history.sh not found."
    echo "To update: ccskill-gmail update --force --yes ."
    exit 1
fi

# --account の解決: accounts.json で email に解決 (未登録でもディレクトリが
# 実在すればそのまま使う — remove 済みアカウントの履歴閲覧用)
resolve_account_dir() {
    local ident="$1"
    local email=""
    if [ -f "$CCSKILL_GMAIL_DIR/lib/accounts.sh" ]; then
        # shellcheck source=/dev/null
        source "$CCSKILL_GMAIL_DIR/lib/accounts.sh"
        local entry
        if entry=$(accounts_get "$ident" 2>/dev/null); then
            email=$(printf '%s' "$entry" | jq -r '.email // empty')
        fi
    fi
    [ -z "$email" ] && email="$ident"
    printf '%s/%s' "$CENTRAL_BASE" "$email"
}

# 中央履歴の全ディレクトリをコロン区切りで列挙
central_dirs() {
    local out=""
    local d
    for d in "$CENTRAL_BASE"/*/; do
        [ -d "$d" ] || continue
        out="${out}:${d%/}"
    done
    printf '%s' "${out#:}"
}

# ========================================
# 引数パース
# ========================================

SUBCMD="${1:-list}"
shift || true

case "$SUBCMD" in
    list|"")
        COUNT=20
        FORMAT="human"
        ACCOUNT_IDENT=""
        ALL_FLAG=false
        export HISTORY_FILTER_ACTION=""
        export HISTORY_FILTER_SINCE=""
        export HISTORY_FILTER_ERRORS=""

        while [ $# -gt 0 ]; do
            case "$1" in
                --json)
                    FORMAT="json"
                    ;;
                --action)
                    HISTORY_FILTER_ACTION="${2:-}"
                    shift
                    ;;
                --since)
                    HISTORY_FILTER_SINCE="${2:-}"
                    shift
                    ;;
                --errors)
                    HISTORY_FILTER_ERRORS="1"
                    ;;
                --account)
                    ACCOUNT_IDENT="${2:-}"
                    shift
                    ;;
                --all)
                    ALL_FLAG=true
                    ;;
                [0-9]*)
                    COUNT="$1"
                    ;;
                *)
                    echo "Unknown option: $1" >&2
                    echo "Usage: ccskill-gmail history list [N] [--json] [--action ACTION] [--since DATE] [--errors] [--account EMAIL_OR_LABEL] [--all]" >&2
                    exit 1
                    ;;
            esac
            shift
        done

        # 表示対象ディレクトリの決定
        unset CCSKILL_HISTORY_DIRS
        if [ -n "$ACCOUNT_IDENT" ]; then
            CCSKILL_HISTORY_DIR=$(resolve_account_dir "$ACCOUNT_IDENT")
        elif [ "$ALL_FLAG" = true ]; then
            DIRS=$(central_dirs)
            if [ -d ".ccskill-gmail" ]; then
                DIRS="$(pwd)/.ccskill-gmail${DIRS:+:$DIRS}"
            fi
            export CCSKILL_HISTORY_DIRS="$DIRS"
            CCSKILL_HISTORY_DIR="${DIRS%%:*}"
        elif [ -d ".ccskill-gmail" ]; then
            # 従来: プロジェクト履歴
            CCSKILL_HISTORY_DIR=".ccskill-gmail"
        else
            # 未インストールディレクトリ: 中央履歴の全アカウント
            DIRS=$(central_dirs)
            if [ -n "$DIRS" ]; then
                export CCSKILL_HISTORY_DIRS="$DIRS"
                CCSKILL_HISTORY_DIR="${DIRS%%:*}"
            else
                CCSKILL_HISTORY_DIR="$CENTRAL_BASE"
            fi
        fi
        export CCSKILL_HISTORY_DIR

        _ccskill_history_list "$COUNT" "$FORMAT"
        ;;

    clear)
        ACCOUNT_IDENT=""
        CLEAR_ARGS=()
        while [ $# -gt 0 ]; do
            case "$1" in
                --account)
                    ACCOUNT_IDENT="${2:-}"
                    shift
                    ;;
                *)
                    CLEAR_ARGS+=("$1")
                    ;;
            esac
            shift
        done

        if [ -n "$ACCOUNT_IDENT" ]; then
            CCSKILL_HISTORY_DIR=$(resolve_account_dir "$ACCOUNT_IDENT")
        elif [ -d ".ccskill-gmail" ]; then
            CCSKILL_HISTORY_DIR=".ccskill-gmail"
        else
            echo "Error: no project history here. Use: ccskill-gmail history clear --account <email|label> --yes" >&2
            exit 1
        fi
        export CCSKILL_HISTORY_DIR

        _ccskill_history_clear "${CLEAR_ARGS[@]+"${CLEAR_ARGS[@]}"}"
        ;;

    --help|-h|help)
        cat << 'EOF'
ccskill-gmail history - View and manage audit log

Usage:
  ccskill-gmail history [list] [N] [OPTIONS]
  ccskill-gmail history clear --yes [--account EMAIL_OR_LABEL]

Subcommands:
  list (default)       Show latest N entries (default: 20)
  clear                Clear audit log (requires --yes)

Options (list):
  N                    Number of entries to show
  --json               Output in JSONL format (suitable for jq)
  --action ACTION      Filter by action (e.g. create_draft)
  --since DATE         Show entries since date (e.g. 2026-03-17)
  --errors             Show errors only
  --account X          Show central history for one account (email or label)
  --all                Merge all central accounts (+ project history if any)

Examples:
  ccskill-gmail history                           # Latest 20 (project if installed, else central)
  ccskill-gmail history list 50                   # Latest 50
  ccskill-gmail history list --json               # JSONL format
  ccskill-gmail history list --account work       # One account's central history
  ccskill-gmail history list --all                # Everything, time-sorted
  ccskill-gmail history clear --yes               # Clear project log

Privacy:
  Recorded: action name, IDs (threadId etc.), account email, success/failure, execution time
  NOT recorded: email body, recipients, subject, search query content
  Location: .ccskill-gmail/audit.jsonl (project) or ~/.ccskill-gmail/history/<email>/ (central)
  Disable: set CCSKILL_GMAIL_HISTORY=off
EOF
        ;;

    *)
        echo "Error: Unknown subcommand '$SUBCMD'" >&2
        echo "Usage: ccskill-gmail history [list|clear] [args]" >&2
        exit 1
        ;;
esac
