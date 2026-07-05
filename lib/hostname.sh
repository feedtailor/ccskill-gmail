#!/bin/bash
#
# lib/hostname.sh - 短縮ホスト名 (#151)
#
# GAS プロジェクト名に付与する「作成マシン名」を得る。Tailscale 名が
# 各マシンの短縮ホスト名（om4mba / om1ms 等）と一致している前提。
#

# short_hostname_from RAW
#   `hostname` の生出力から最初のラベル（最初の '.' より前）を返す。純関数。
short_hostname_from() {
    printf '%s' "${1%%.*}"
}

# short_hostname
#   このマシンの短縮ホスト名。`hostname -s` を優先し、無ければ `hostname` の
#   先頭ラベルにフォールバックする。取得不能なら空文字。
short_hostname() {
    local h=""
    h=$(hostname -s 2>/dev/null) || h=""
    if [ -z "$h" ]; then
        h=$(hostname 2>/dev/null) || h=""
    fi
    short_hostname_from "$h"
}
