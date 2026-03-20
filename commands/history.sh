#!/bin/bash
#
# Gmail Skill - History Viewer
#
# Usage: ccskill-gmail history [subcommand] [args]
#
# Subcommands:
#   (none) / list [N] [--json] [--action X] [--since DATE] [--errors]
#                              Show history (default: 20 entries, human-readable)
#   clear --yes                Clear history (--yes required)
#

set -e

# ========================================
# 1. ディスパッチャ経由チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail history'"
    exit 1
fi

# ========================================
# 2. カレントディレクトリのインストール確認
# ========================================

if [ ! -d ".ccskill-gmail" ]; then
    echo "Error: ccskill-gmail is not installed in this directory."
    echo ""
    echo "To install: ccskill-gmail install"
    exit 1
fi

CCSKILL_HISTORY_DIR=".ccskill-gmail"

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

# ========================================
# 3. 引数パース
# ========================================

SUBCMD="${1:-list}"
shift || true

case "$SUBCMD" in
    list|"")
        # オプション解析
        COUNT=20
        FORMAT="human"
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
                [0-9]*)
                    COUNT="$1"
                    ;;
                *)
                    echo "Unknown option: $1" >&2
                    echo "Usage: ccskill-gmail history list [N] [--json] [--action ACTION] [--since DATE] [--errors]" >&2
                    exit 1
                    ;;
            esac
            shift
        done

        _ccskill_history_list "$COUNT" "$FORMAT"
        ;;

    clear)
        _ccskill_history_clear "$@"
        ;;

    --help|-h|help)
        cat << 'EOF'
ccskill-gmail history - Gmail Skill 操作履歴の表示・管理

使用方法:
  ccskill-gmail history [list] [N] [オプション]
  ccskill-gmail history clear --yes

サブコマンド:
  list (省略可)        最新 N 件の履歴を表示（デフォルト: 20件）
  clear                履歴をクリア（--yes フラグ必須）

オプション (list):
  N                    表示件数（数値）
  --json               JSONL 形式で出力（jq での処理に適する）
  --action ACTION      指定アクションのみ表示（例: create_draft）
  --since DATE         指定日以降のみ表示（例: 2026-03-17）
  --errors             エラーのみ表示

例:
  ccskill-gmail history                           # 最新20件（人間可読）
  ccskill-gmail history list 50                   # 最新50件
  ccskill-gmail history list --json               # JSONL 形式
  ccskill-gmail history list --action search      # search のみ
  ccskill-gmail history list --since 2026-03-17   # 指定日以降
  ccskill-gmail history list --errors             # エラーのみ
  ccskill-gmail history clear --yes               # 履歴クリア

プライバシーノート:
  記録される情報: アクション名、識別ID（threadId 等）、成功/失敗、実行時間
  記録されない情報: メール本文、宛先、件名、検索クエリの内容
  保存場所: .ccskill-gmail/audit.jsonl（ローカルのみ、git 対象外）
  無効化: CCSKILL_GMAIL_HISTORY=off を設定
EOF
        ;;

    *)
        echo "Error: Unknown subcommand '$SUBCMD'" >&2
        echo "Usage: ccskill-gmail history [list|clear] [args]" >&2
        exit 1
        ;;
esac
