#!/bin/bash
#
# lib/jq_version.sh - jq バージョン判定 (#148)
#
# `jq --version` の生出力（例: jq-1.7.1-apple / jq-1.6 / jq-1.5）を解析し、
# 1.6 未満かどうかを判定する。doctor の jq バージョン警告に使う。
#
# jq に依存しない純粋な文字列解析。不明・空の形式では「古い」と誤判定しない
# （= 誤警告しない）安全側に倒す。
#

# jq_version_is_old RAW
#   引数: `jq --version` の生出力
#   返り値: 0 = 1.6 未満（古い） / 1 = 1.6 以上 または 判定不能
jq_version_is_old() {
    local raw="${1:-}" ver major minor
    ver=${raw#jq-}      # 先頭 "jq-" を除去
    ver=${ver%%-*}      # "-apple" 等のサフィックスを除去
    major=${ver%%.*}
    minor=${ver#*.}
    minor=${minor%%.*}
    # major が空 or 数値でなければ判定不能 → 古くない扱い（誤警告しない）
    case "$major" in
        ''|*[!0-9]*) return 1 ;;
    esac
    # minor が非数値なら 0 とみなす
    case "$minor" in
        *[!0-9]*|'') minor=0 ;;
    esac
    if [ "$major" -lt 1 ]; then
        return 0
    fi
    if [ "$major" -eq 1 ] && [ "$minor" -lt 6 ]; then
        return 0
    fi
    return 1
}
