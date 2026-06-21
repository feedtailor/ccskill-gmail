#!/bin/bash
#
# tests/lib/test-trash-and-prompt.sh - move_to_trash 有効化導線 + uninstall 確認プロンプト整合 (#134)
#
# D: 共有 GAS 構成では config.js が無く apply-config が dead-end する。
#    共有 GAS の config.js 編集 + account update を案内することを検証する。
# E: uninstall の確認プロンプトが実在するファイルだけを列挙することを検証する。
#
# Usage: bash tests/lib/test-trash-and-prompt.sh
#

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helper.sh
source "$SCRIPT_DIR/test-helper.sh"

use_fixture_home() {
    HOME=$(test_mktemp_d)
    export HOME
}

# ========================================
# (D) apply-config: 共有 GAS 構成での案内
# ========================================

test_applyconfig_central_guides_to_account_update() {
    use_fixture_home
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "a@example.com" "ua" "sa" "da" "https://a.invalid/exec" "alpha" >/dev/null 2>&1
    local proj
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.ccskill-gmail"
    printf '{"account":"a@example.com"}\n' > "$proj/.ccskill-gmail/binding.json"
    local out
    out=$(cd "$proj" && "$REPO_DIR/ccskill-gmail" apply-config 2>&1) || true
    assert_contains "account update" "$out" || return 1
    assert_contains "gas/ua/config.js" "$out" || return 1
    # 素っ気ない config.js 不在エラーで終わらせない
    case "$out" in
        *"Error: config.js not found"*)
            echo "central mode must not bail with a bare config.js error" >&2
            return 1
            ;;
    esac
    return 0
}

test_docs_mention_central_permission_path() {
    local d="$REPO_DIR/.claude/skills/ccskill-gmail"
    grep -q "account update" "$d/troubleshooting.md" || { echo "troubleshooting.md lacks central path" >&2; return 1; }
    grep -q "account update" "$d/reference/limitations.md" || { echo "limitations.md lacks central path" >&2; return 1; }
    grep -q "account update" "$d/reference/thread.md" || { echo "thread.md lacks central path" >&2; return 1; }
}

# ========================================
# (E) uninstall の確認プロンプト整合
# ========================================

# bind-only ディレクトリ: skill dir も .env も無い → プロンプトに列挙しない
test_uninstall_prompt_excludes_absent() {
    use_fixture_home
    local proj out
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.ccskill-gmail"
    printf '{"account":"a@example.com"}\n' > "$proj/.ccskill-gmail/binding.json"
    out=$(cd "$proj" && printf 'n\n' | "$REPO_DIR/ccskill-gmail" uninstall 2>&1) || true
    case "$out" in
        *".claude/skills/ccskill-gmail"*)
            echo "prompt should not list a skill dir that does not exist" >&2
            return 1
            ;;
    esac
    case "$out" in
        *"GMAIL_ENDPOINT entry in .env"*)
            echo "prompt should not list .env entry when .env is absent" >&2
            return 1
            ;;
    esac
    # 実在する .ccskill-gmail は列挙される
    assert_contains ".ccskill-gmail" "$out"
}

# 実在するファイルは列挙される
test_uninstall_prompt_lists_present() {
    use_fixture_home
    local proj out
    proj=$(test_mktemp_d)
    mkdir -p "$proj/.ccskill-gmail" "$proj/.claude/skills/ccskill-gmail"
    printf '{"account":"a@example.com"}\n' > "$proj/.ccskill-gmail/binding.json"
    printf 'SKILL\n' > "$proj/.claude/skills/ccskill-gmail/SKILL.md"
    out=$(cd "$proj" && printf 'n\n' | "$REPO_DIR/ccskill-gmail" uninstall 2>&1) || true
    assert_contains ".claude/skills/ccskill-gmail" "$out"
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-trash-and-prompt.sh (#134)"
echo ""

run_test "apply-config central -> guides account update"  test_applyconfig_central_guides_to_account_update
run_test "docs mention central permission path"           test_docs_mention_central_permission_path
run_test "uninstall prompt excludes absent items"         test_uninstall_prompt_excludes_absent
run_test "uninstall prompt lists present items"           test_uninstall_prompt_lists_present

test_summary
