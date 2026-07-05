#!/bin/bash
#
# tests/lib/test-accounts-jq-reserved.sh - jq 予約語キー回帰テスト (#147)
#
# lib/*.sh の jq プログラム内で、jq の予約語がオブジェクトのキーとして
# 「引用符なし（裸）」で使われていないことを静的に検査する。
#
# 背景: jq 1.7 はオブジェクトキーに予約語を許容するが、jq 1.5/1.6 は
# `label` 等を予約語トークンとして拒否し構文エラーになる。開発マシンの
# jq が寛容だと実行時テストでは捕捉できないため、静的検査で担保する。
#
# Usage: bash tests/lib/test-accounts-jq-reserved.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# jq 予約語のうち、シェルスクリプト中で誤検知しにくく、オブジェクトキーに
# 使うと古い jq で確実に落ちるもの。`label` が本 issue の実害。
JQ_RESERVED='label|def|reduce|foreach|import|include|catch|elif|__loc__'

# 指定ファイルから「行頭（インデント可）に 予約語: が裸で並ぶ」行を抽出する。
# 引用符付き ("label":) は対象外。jq のオブジェクトリテラル整形を前提とする。
find_bare_reserved_keys() {
    local file="$1"
    grep -nE "^[[:space:]]*(${JQ_RESERVED})[[:space:]]*:" "$file" 2>/dev/null || true
}

# jq 変数を予約語で定義している箇所 (--arg label ...) を抽出する。
# jq 1.5/1.6 では $label のように予約語名の変数を参照できない。
find_reserved_arg_vars() {
    local file="$1"
    # パターンが "--" で始まるため grep がオプションと誤認しないよう -e で明示する
    grep -nE -e "--arg[[:space:]]+(${JQ_RESERVED})[[:space:]]" "$file" 2>/dev/null || true
}

# jq のドット形式フィールドアクセス (.label / .value.label) を抽出する。
# 予約語フィールドは 1.5/1.6 で `.` 記法が使えないため .["label"] を用いる。
find_reserved_dot_fields() {
    local file="$1"
    grep -nE "\.(${JQ_RESERVED})\b" "$file" 2>/dev/null || true
}

# ========================================
# テスト
# ========================================

test_accounts_sh_has_no_bare_reserved_key() {
    local hits
    hits=$(find_bare_reserved_keys "$REPO_DIR/lib/accounts.sh")
    if [ -n "$hits" ]; then
        {
            echo "    lib/accounts.sh に jq 予約語の裸キーが残っています:"
            echo "$hits" | sed 's/^/      /'
            echo "    → キーを引用符で囲んでください（例: \"label\":）"
        } >&2
        return 1
    fi
}

test_all_lib_has_no_bare_reserved_key() {
    local f hits total=""
    for f in "$REPO_DIR"/lib/*.sh; do
        [ -f "$f" ] || continue
        hits=$(find_bare_reserved_keys "$f")
        if [ -n "$hits" ]; then
            total="${total}${f}:\n${hits}\n"
        fi
    done
    if [ -n "$total" ]; then
        {
            echo "    lib/*.sh に jq 予約語の裸キーが残っています:"
            printf "%b" "$total" | sed 's/^/      /'
        } >&2
        return 1
    fi
}

# サニティチェック: 検査ロジック自体が「裸の label:」を検出できること
test_detector_catches_bare_label() {
    local tmp
    tmp=$(test_mktemp)
    printf '%s\n' "        label: (if \$x == \"\" then null else \$x end)," > "$tmp"
    local hits
    hits=$(find_bare_reserved_keys "$tmp")
    rm -f "$tmp"
    assert_contains "label:" "$hits"
}

# サニティチェック: 引用符付き "label": は検出しないこと
test_detector_ignores_quoted_label() {
    local tmp
    tmp=$(test_mktemp)
    printf '%s\n' '        "label": (if $x == "" then null else $x end),' > "$tmp"
    local hits
    hits=$(find_bare_reserved_keys "$tmp")
    rm -f "$tmp"
    assert_eq "" "$hits"
}

# jq 変数を予約語で定義していないこと (--arg label ...) — lib + commands (#147 follow-up)
test_no_reserved_arg_vars() {
    local f hits total=""
    for f in "$REPO_DIR"/lib/*.sh "$REPO_DIR"/commands/*.sh; do
        [ -f "$f" ] || continue
        hits=$(find_reserved_arg_vars "$f")
        [ -n "$hits" ] && total="${total}${f}:\n${hits}\n"
    done
    if [ -n "$total" ]; then
        {
            echo "    jq 変数を予約語名で定義しています (jq 1.5/1.6 で \$label 等が参照不能):"
            printf "%b" "$total" | sed 's/^/      /'
            echo "    → --arg lbl 等に改名してください"
        } >&2
        return 1
    fi
}

# jq のドット形式フィールドアクセスに予約語を使っていないこと (.label) — lib + commands
test_no_reserved_dot_fields() {
    local f hits total=""
    for f in "$REPO_DIR"/lib/*.sh "$REPO_DIR"/commands/*.sh; do
        [ -f "$f" ] || continue
        hits=$(find_reserved_dot_fields "$f")
        [ -n "$hits" ] && total="${total}${f}:\n${hits}\n"
    done
    if [ -n "$total" ]; then
        {
            echo "    jq のドット形式で予約語フィールドにアクセスしています (jq 1.5/1.6 で不可):"
            printf "%b" "$total" | sed 's/^/      /'
            echo "    → .[\"label\"] のブラケット記法に変更してください"
        } >&2
        return 1
    fi
}

# サニティ: 検出器が --arg label / .label を捕捉できること
test_detector_catches_arg_and_dot() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' '   jq --arg label "$x" ".accounts"' '   select(.value.label == $i)' > "$tmp"
    hits=$(find_reserved_arg_vars "$tmp")
    assert_contains "--arg label" "$hits" || { rm -f "$tmp"; return 1; }
    hits=$(find_reserved_dot_fields "$tmp")
    rm -f "$tmp"
    assert_contains ".label" "$hits"
}

# サニティ: ブラケット記法 .["label"] と --arg lbl は捕捉しないこと
test_detector_ignores_bracket_and_alias() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' '   jq --arg lbl "$x"' '   select(.value["label"] == $i)' > "$tmp"
    hits=$(find_reserved_arg_vars "$tmp")
    assert_eq "" "$hits" || { rm -f "$tmp"; return 1; }
    hits=$(find_reserved_dot_fields "$tmp")
    rm -f "$tmp"
    assert_eq "" "$hits"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-accounts-jq-reserved.sh (#147)"
echo ""

run_test "detector: catches bare 'label:' key"              test_detector_catches_bare_label
run_test "detector: ignores quoted '\"label\":' key"        test_detector_ignores_quoted_label
run_test "detector: catches '--arg label' and '.label'"     test_detector_catches_arg_and_dot
run_test "detector: ignores bracket '.[\"label\"]'/alias"   test_detector_ignores_bracket_and_alias
run_test "lib/accounts.sh: no bare jq reserved-word key"    test_accounts_sh_has_no_bare_reserved_key
run_test "lib/*.sh: no bare jq reserved-word key"           test_all_lib_has_no_bare_reserved_key
run_test "lib+commands: no jq var named as reserved word"   test_no_reserved_arg_vars
run_test "lib+commands: no dot-form reserved field access"  test_no_reserved_dot_fields

test_summary
