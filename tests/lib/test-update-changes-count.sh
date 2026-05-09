#!/bin/bash
#
# tests/lib/test-update-changes-count.sh
#
# commands/update.sh:149 の count 取得式が "0\n0" のような二重出力を
# 起こさないことを保証する (#112)。
#
# 背景: `grep -c` はマッチ 0 件のとき stdout に "0" を吐きつつ exit 1 で抜けるため、
# `... || echo "0"` のフォールバックがあると、grep の "0" + echo の "0" で
# 二重出力になる。これを静的・behavioral 双方で検証する。
#
# Usage: bash tests/lib/test-update-changes-count.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/test-helper.sh"

UPDATE_SH="$REPO_ROOT/commands/update.sh"

# ========================================
# 静的検証: 旧バグパターンが残っていない
# ========================================

# `grep -cE ... || echo "0"` のような、grep -c の後にフォールバック echo が続く
# 形を NG とする。grep -c は既に "0" を吐くので echo は不要。
test_no_grep_c_with_echo_fallback() {
    if grep -nE 'grep -cE.*\|\|[[:space:]]*echo' "$UPDATE_SH" >/dev/null 2>&1; then
        {
            echo "    update.sh に 'grep -c ... || echo ...' パターンが残っています:"
            grep -nE 'grep -cE.*\|\|[[:space:]]*echo' "$UPDATE_SH" | sed 's/^/      /'
            echo "    → '|| true' に置き換えてください (#112)"
        } >&2
        return 1
    fi
    return 0
}

# ========================================
# Behavioral 検証: 修正後の式が期待通りに動作する
#
# update.sh:149 が依拠している pipeline 部分:
#   ... | grep -cE "^(feat|fix):" || true
# この末尾フラグメントを、再現性のある canned 入力で検証する。
# ========================================

test_zero_when_no_feat_or_fix() {
    local count
    count=$(printf 'docs: foo\nchore: bar\ntest: baz\n' \
        | grep -cE "^(feat|fix):" || true)
    # 期待: 単一行 "0"
    assert_eq "0" "$count"
}

test_counts_feat_and_fix_only() {
    local count
    count=$(printf 'feat: a\nfix: b\ndocs: c\nchore: d\nfix: e\n' \
        | grep -cE "^(feat|fix):" || true)
    # 期待: feat 1 + fix 2 = 3
    assert_eq "3" "$count"
}

test_zero_when_input_empty() {
    local count
    count=$(printf '' | grep -cE "^(feat|fix):" || true)
    assert_eq "0" "$count"
}

# ========================================
# 静的検証: TOTAL_COMMITS=0 のときに "Unable to show changes" が出ない (#112)
#
# grep -E (count なし) もマッチ 0 件で exit 1 を返すため、|| 側に "Unable to show
# changes" を置いていると、feat/fix が無いだけのケースで誤って「git が失敗した」
# かのように見えてしまう。TOTAL_COMMITS の値で分岐させて、変更なしのケースは
# 専用メッセージ ("(no user-facing changes ...)") を出すべき。
# ========================================

test_no_user_facing_changes_message_present() {
    if ! grep -qE 'no user-facing changes' "$UPDATE_SH"; then
        {
            echo "    update.sh に '(no user-facing changes ...)' 系メッセージが無い"
            echo "    → TOTAL_COMMITS=0 のときの専用表示を入れてください (#112)"
        } >&2
        return 1
    fi
    return 0
}

test_total_commits_zero_branch_present() {
    # TOTAL_COMMITS=0 を明示的に分岐するロジックがあるか確認
    if ! grep -qE 'TOTAL_COMMITS.*-eq[[:space:]]+0|TOTAL_COMMITS.*=[[:space:]]*"?0"?' "$UPDATE_SH"; then
        {
            echo "    update.sh に TOTAL_COMMITS が 0 のときの分岐が無い"
            echo "    → if [ \"\$TOTAL_COMMITS\" -eq 0 ]; then ... else ... fi 等で分岐させてください"
        } >&2
        return 1
    fi
    return 0
}

test_count_does_not_contain_newline() {
    # 旧バグでは "0\n0" になっていた。`wc -l` で行数が 1 かを直接検証する。
    local count
    count=$(printf 'docs: only\n' | grep -cE "^(feat|fix):" || true)
    local line_count
    line_count=$(printf '%s' "$count" | wc -l | tr -d ' ')
    # printf %s は末尾改行を出さないので、純粋に count 内部の改行数になる
    assert_eq "0" "$line_count"
}

# ========================================
# 実行
# ========================================

echo "Running update changes-count tests..."
echo ""

run_test "update.sh に 'grep -c ... || echo' が残っていない" test_no_grep_c_with_echo_fallback
run_test "feat/fix なしの入力で count は '0'"                test_zero_when_no_feat_or_fix
run_test "feat/fix あり入力で正しい件数"                      test_counts_feat_and_fix_only
run_test "空入力で count は '0'"                              test_zero_when_input_empty
run_test "count に改行が含まれない"                           test_count_does_not_contain_newline
run_test "0 件時の専用メッセージが定義されている"             test_no_user_facing_changes_message_present
run_test "TOTAL_COMMITS=0 の分岐ロジックがある"               test_total_commits_zero_branch_present

test_summary
