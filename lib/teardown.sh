#!/bin/bash
#
# teardown.sh - central フル撤去のヘルパー (#140)
#
# `ccskill-gmail uninstall --all` の中核。HOME 配下の central フットプリント
# (ユーザースキル / レジストリ一式 / CLI symlink) を列挙・削除する。
# GAS 本体と clasp トークン (~/.clasprc.json) は対象にしない。
#
# 使い方:
#   source "$CCSKILL_GMAIL_DIR/lib/teardown.sh"
#   teardown_list_targets          # 既存の削除対象を 1 行ずつ出力
#   teardown_execute [true|false]  # true=dry-run(消さない) / false=実削除
#

# 各対象パス (HOME は呼び出し時に解決する)
_teardown_skill_dir()    { echo "$HOME/.claude/skills/ccskill-gmail"; }
_teardown_registry_dir() { echo "$HOME/.ccskill-gmail"; }
_teardown_cli_link()     { echo "$HOME/.local/bin/ccskill-gmail"; }

# CLI symlink が本ツール (ディスパッチャ実体) を指しているか
teardown_cli_link_is_ours() {
    local link
    link=$(_teardown_cli_link)
    [ -L "$link" ] || return 1
    local target
    target=$(readlink "$link")
    [ "$target" = "$CCSKILL_GMAIL_DIR/ccskill-gmail" ]
}

# 既存の削除対象を 1 行ずつ出力する (タグ付き)。
#   skill:     <path>   ユーザースキル
#   registry:  <path>   ~/.ccskill-gmail 一式
#   cli:       <path>   本ツールが張った CLI symlink (削除対象)
#   cli-skip:  <path>   別実体を指す CLI symlink (削除しない)
teardown_list_targets() {
    local s r l
    s=$(_teardown_skill_dir)
    r=$(_teardown_registry_dir)
    l=$(_teardown_cli_link)

    if [ -e "$s" ] || [ -L "$s" ]; then
        echo "skill: $s"
    fi
    if [ -d "$r" ]; then
        echo "registry: $r"
    fi
    if [ -L "$l" ]; then
        if teardown_cli_link_is_ours; then
            echo "cli: $l"
        else
            echo "cli-skip: $l"
        fi
    fi
}

# 削除を実行する。
#   $1 = dry_run ("true" なら表示のみで削除しない。既定 false)
# 対象が無い場合も何もせず正常終了する (冪等)。
teardown_execute() {
    local dry_run="${1:-false}"
    local s r l
    s=$(_teardown_skill_dir)
    r=$(_teardown_registry_dir)
    l=$(_teardown_cli_link)

    # ユーザースキル (symlink / 実体コピーのどちらも)
    if [ -e "$s" ] || [ -L "$s" ]; then
        [ "$dry_run" = true ] || rm -rf "$s"
    fi
    # レジストリ一式 (accounts.json / gas/ / history/)
    if [ -d "$r" ]; then
        [ "$dry_run" = true ] || rm -rf "$r"
    fi
    # CLI symlink は本ツールが張ったものだけ
    if [ -L "$l" ] && teardown_cli_link_is_ours; then
        [ "$dry_run" = true ] || rm -f "$l"
    fi
}
