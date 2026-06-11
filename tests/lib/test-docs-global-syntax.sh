#!/bin/bash
#
# tests/lib/test-docs-global-syntax.sh - スキルドキュメントの表記不変条件 (#124)
#
# - `.ccskill-gmail/api` 呼び出し表記が残っていないこと (グローバル表記に統一)
# - `.ccskill-gmail/tmp/` (POST 用 JSON の置き場) は残っていてよい
# - SKILL.md / SKILL.ja.md にアカウント行動規範の必須要素があること
#
# Usage: bash tests/lib/test-docs-global-syntax.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_DIR="$REPO_DIR/.claude/skills/ccskill-gmail"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

# (1) 全ドキュメントに .ccskill-gmail/api の呼び出し表記が残っていない
#     (意図的な「レガシー注記」行のみ許可)
test_no_legacy_api_path() {
    local hits
    hits=$(grep -R -n -F '.ccskill-gmail/api' "$SKILL_DIR" 2>/dev/null | grep -v -e 'Legacy note' -e 'レガシー注記')
    if [ -n "$hits" ]; then
        echo "    legacy '.ccskill-gmail/api' remains:" >&2
        printf '%s\n' "$hits" | sed 's/^/      /' >&2
        return 1
    fi
    return 0
}

# (2) グローバル表記が使われている (sanity)
test_global_syntax_present() {
    grep -q 'ccskill-gmail api get action=search' "$SKILL_DIR/SKILL.md" || return 1
    grep -q 'ccskill-gmail api get action=search' "$SKILL_DIR/examples.md"
}

# (3) SKILL.md / SKILL.ja.md にアカウント行動規範の必須要素がある
test_account_rules_present_en() {
    grep -q -- '--account' "$SKILL_DIR/SKILL.md" || { echo "    missing --account" >&2; return 1; }
    grep -q 'whoami' "$SKILL_DIR/SKILL.md" || { echo "    missing whoami" >&2; return 1; }
    grep -q 'account_source' "$SKILL_DIR/SKILL.md" || { echo "    missing account_source" >&2; return 1; }
}

test_account_rules_present_ja() {
    grep -q -- '--account' "$SKILL_DIR/SKILL.ja.md" || { echo "    missing --account" >&2; return 1; }
    grep -q 'whoami' "$SKILL_DIR/SKILL.ja.md" || { echo "    missing whoami" >&2; return 1; }
    grep -q 'account_source' "$SKILL_DIR/SKILL.ja.md" || { echo "    missing account_source" >&2; return 1; }
}

# (4) POST 用 JSON の置き場 (.ccskill-gmail/tmp/) の記述は維持されている
test_tmp_dir_guidance_kept() {
    grep -q -F '.ccskill-gmail/tmp/' "$SKILL_DIR/SKILL.md" || return 1
    grep -q -F '.ccskill-gmail/tmp/' "$SKILL_DIR/SKILL.ja.md"
}

# (5) 二段構造 (管理系 / API 系) の早見表がある (#120)
test_two_families_table_present() {
    grep -q 'Two Command Families' "$SKILL_DIR/SKILL.md" || { echo "    missing 'Two Command Families' in SKILL.md" >&2; return 1; }
    grep -q 'コマンドは 2 系統' "$SKILL_DIR/SKILL.ja.md" || { echo "    missing 'コマンドは 2 系統' in SKILL.ja.md" >&2; return 1; }
}

# (6) reference/index.md に get_profile が記載されている (#120)
test_index_has_get_profile() {
    grep -q 'get_profile' "$SKILL_DIR/reference/index.md"
}

echo ""
echo "test-docs-global-syntax.sh (#124)"
echo ""

run_test "no legacy .ccskill-gmail/api in skill docs"  test_no_legacy_api_path
run_test "global syntax present in SKILL.md/examples"  test_global_syntax_present
run_test "account rules present (SKILL.md)"            test_account_rules_present_en
run_test "account rules present (SKILL.ja.md)"         test_account_rules_present_ja
run_test ".ccskill-gmail/tmp/ guidance kept"           test_tmp_dir_guidance_kept
run_test "two command families table present (#120)"   test_two_families_table_present
run_test "index.md has get_profile (#120)"             test_index_has_get_profile

test_summary
