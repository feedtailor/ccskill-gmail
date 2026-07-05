#!/bin/bash
#
# tests/lib/test-accounts-jq-reserved.sh - jq 予約語識別子の回帰テスト (#147 / #149)
#
# jq の予約語 (label / def / end ...) を「識別子」として使っている箇所を静的に検査する。
#
# 実 jq 1.5 での検証で判明した事実:
#   - 予約語を「変数名」に使うと必ず落ちる:  --arg label → $label / .x as $def
#     （エラー: unexpected label, expecting IDENT or __loc__）… これが実害。
#   - 予約語を「オブジェクトキー」や「.field アクセス」に使うのは jq 1.5 でも動く
#     （{label:1} も .value.label も OK）。ただしキーの引用符付けは無害な防御として維持する。
# 開発機の jq が新しいと実行時テストでは変数名問題を捕捉できないため、静的検査で担保する。
#
# Usage: bash tests/lib/test-accounts-jq-reserved.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# オブジェクトキーの防御チェック用（誤検出しにくい予約語のみ）
JQ_RESERVED='label|def|reduce|foreach|import|include|catch|elif|__loc__'
# jq の全予約語。変数名 (--arg <kw> / as $<kw>) に使うと jq 1.5/1.6 で必ず落ちる。
JQ_KEYWORDS='as|def|if|then|elif|else|end|and|or|reduce|foreach|try|catch|label|import|include|__loc__'

# 「行頭（インデント可）に 予約語: が裸で並ぶ」オブジェクトキーを抽出する（防御的スタイル）。
# 引用符付き ("label":) は対象外。
find_bare_reserved_keys() {
    local file="$1"
    grep -nE "^[[:space:]]*(${JQ_RESERVED})[[:space:]]*:" "$file" 2>/dev/null || true
}

# jq 変数を予約語名で束縛している箇所 (--arg label ... / .foo as $def) を抽出する。
# jq 1.5/1.6 では $label / $def のように予約語名の変数を参照できない（実害）。
find_reserved_bound_vars() {
    local file="$1"
    # パターンが "--" で始まるため grep がオプションと誤認しないよう -e で明示する
    grep -nE -e "--arg[[:space:]]+(${JQ_KEYWORDS})[[:space:]]" \
             -e "as[[:space:]]+\\\$(${JQ_KEYWORDS})\b" "$file" 2>/dev/null || true
}

# ========================================
# テスト
# ========================================

# --- オブジェクトキー（防御チェック） ---

test_all_lib_has_no_bare_reserved_key() {
    local f hits total=""
    for f in "$REPO_DIR"/lib/*.sh; do
        [ -f "$f" ] || continue
        hits=$(find_bare_reserved_keys "$f")
        [ -n "$hits" ] && total="${total}${f}:\n${hits}\n"
    done
    if [ -n "$total" ]; then
        {
            echo "    lib/*.sh に jq 予約語の裸キーが残っています（防御的に引用符推奨）:"
            printf "%b" "$total" | sed 's/^/      /'
        } >&2
        return 1
    fi
}

test_detector_catches_bare_label() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' "        label: (if \$x == \"\" then null else \$x end)," > "$tmp"
    hits=$(find_bare_reserved_keys "$tmp")
    rm -f "$tmp"
    assert_contains "label:" "$hits"
}

test_detector_ignores_quoted_label() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' '        "label": (if $x == "" then null else $x end),' > "$tmp"
    hits=$(find_bare_reserved_keys "$tmp")
    rm -f "$tmp"
    assert_eq "" "$hits"
}

# --- 予約語変数名（実害の本丸） ---

test_no_reserved_bound_vars() {
    local f hits total=""
    for f in "$REPO_DIR"/lib/*.sh "$REPO_DIR"/commands/*.sh; do
        [ -f "$f" ] || continue
        hits=$(find_reserved_bound_vars "$f")
        [ -n "$hits" ] && total="${total}${f}:\n${hits}\n"
    done
    if [ -n "$total" ]; then
        {
            echo "    jq 変数を予約語名で束縛しています (jq 1.5/1.6 で \$label / \$def 等が参照不能):"
            printf "%b" "$total" | sed 's/^/      /'
            echo "    → --arg lbl / as \$defacct のように非予約語へ改名してください"
        } >&2
        return 1
    fi
}

# サニティ: --arg label / as $def を捕捉できること
test_detector_catches_reserved_vars() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' '   jq --arg label "$x" ".accounts"' \
                  '   .default_account as $def' > "$tmp"
    hits=$(find_reserved_bound_vars "$tmp")
    rm -f "$tmp"
    assert_contains "--arg label" "$hits" || return 1
    assert_contains "as \$def" "$hits"
}

# サニティ: 別名 --arg lbl / as $defacct は捕捉しないこと（誤検出防止）
test_detector_ignores_aliases() {
    local tmp hits
    tmp=$(test_mktemp)
    printf '%s\n' '   jq --arg lbl "$x"' \
                  '   .default_account as $defacct' > "$tmp"
    hits=$(find_reserved_bound_vars "$tmp")
    rm -f "$tmp"
    assert_eq "" "$hits"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-accounts-jq-reserved.sh (#147 / #149)"
echo ""

run_test "detector: catches bare 'label:' key"              test_detector_catches_bare_label
run_test "detector: ignores quoted '\"label\":' key"        test_detector_ignores_quoted_label
run_test "detector: catches '--arg label' / 'as \$def'"     test_detector_catches_reserved_vars
run_test "detector: ignores '--arg lbl' / 'as \$defacct'"   test_detector_ignores_aliases
run_test "lib/*.sh: no bare jq reserved-word key"           test_all_lib_has_no_bare_reserved_key
run_test "lib+commands: no jq var named as reserved word"   test_no_reserved_bound_vars

test_summary
