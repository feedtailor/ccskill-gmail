#!/bin/bash
#
# Gmail Skill - Permission Helper
#
# Claude Code の .claude/settings.local.json に ccskill-get / ccskill-post の
# 許可パターンを追加するヘルパー関数。
#
# Usage:
#   source lib/permissions.sh
#   setup_permissions /path/to/target/project [--yes]
#

# setup_permissions: ccskill-get / ccskill-post の許可パターンを追加
#
# 引数:
#   $1 - ターゲットプロジェクトのパス（必須）
#   $2 - "--yes" で確認なしに追加（オプション）
#
setup_permissions() {
    local target_dir="$1"
    local auto_yes="${2:-}"
    local settings_file="$target_dir/.claude/settings.local.json"
    local patterns=(
        "Bash(.ccskill-gmail/api *)"
        "Write(/tmp/*)"
    )
    local missing_patterns=()

    # jq が必要
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW:-}Note: jq not found. Skipping permission setup.${NC:-}"
        echo "  To manually allow ccskill commands, add the following to $settings_file:"
        echo '    "Bash(.ccskill-gmail/api *)"'
        return 0
    fi

    # 既存設定をチェックして未追加のパターンを特定
    if [ -f "$settings_file" ]; then
        for pattern in "${patterns[@]}"; do
            if ! jq -e --arg p "$pattern" '.permissions.allow // [] | index($p)' "$settings_file" > /dev/null 2>&1; then
                missing_patterns+=("$pattern")
            fi
        done
    else
        missing_patterns=("${patterns[@]}")
    fi

    # 全パターンが既に設定済み
    if [ ${#missing_patterns[@]} -eq 0 ]; then
        echo -e "${GREEN:-}✓ Permission patterns already configured${NC:-}"
        return 0
    fi

    # opt-in 確認
    echo ""
    echo "Claude Code の許可設定に以下のパターンを追加できます："
    for pattern in "${missing_patterns[@]}"; do
        echo "  - $pattern"
    done
    echo ""
    echo "これにより、Skill 使用時の確認プロンプトが軽減されます。"
    echo "設定先: $settings_file"
    echo ""

    if [ "$auto_yes" != "--yes" ] && [ "$auto_yes" != "-y" ]; then
        read -p "許可パターンを追加しますか？ (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "スキップしました。"
            return 0
        fi
    fi

    # settings.local.json の作成または更新
    if [ ! -f "$settings_file" ]; then
        # ディレクトリ作成
        mkdir -p "$(dirname "$settings_file")"

        # 新規作成
        local allow_json="[]"
        for pattern in "${missing_patterns[@]}"; do
            allow_json=$(echo "$allow_json" | jq --arg p "$pattern" '. + [$p]')
        done
        jq -n --argjson allow "$allow_json" '{"permissions": {"allow": $allow}}' > "$settings_file"
    else
        # 既存ファイルに追加
        local tmp
        tmp=$(mktemp)
        local current
        current=$(cat "$settings_file")

        for pattern in "${missing_patterns[@]}"; do
            current=$(echo "$current" | jq --arg p "$pattern" '
                .permissions.allow = ((.permissions.allow // []) + [$p])
            ')
        done

        echo "$current" > "$tmp"
        /bin/mv "$tmp" "$settings_file"
    fi

    echo -e "${GREEN:-}✓ Permission patterns added (${#missing_patterns[@]} patterns)${NC:-}"
    return 0
}
