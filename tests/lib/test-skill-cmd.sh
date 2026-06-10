#!/bin/bash
#
# tests/lib/test-skill-cmd.sh - skill install/uninstall コマンドのテスト (#124)
#
# HOME をフィクスチャに差し替えてオフラインで実行する。
#
# Usage: bash tests/lib/test-skill-cmd.sh
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

SKILL_LINK_REL=".claude/skills/ccskill-gmail"

# (1) skill install で symlink が作られ、SKILL.md に到達できる
test_install_creates_symlink() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    [ -L "$HOME/$SKILL_LINK_REL" ] || {
        echo "    expected symlink at $HOME/$SKILL_LINK_REL" >&2
        return 1
    }
    assert_file_exists "$HOME/$SKILL_LINK_REL/SKILL.md"
}

# (2) 再実行しても成功する (冪等)
test_install_idempotent() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    [ -L "$HOME/$SKILL_LINK_REL" ]
}

# (3) --copy で実体コピーされる
test_install_copy_mode() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install --copy >/dev/null 2>&1 || return 1
    [ ! -L "$HOME/$SKILL_LINK_REL" ] || {
        echo "    expected real directory (not symlink) with --copy" >&2
        return 1
    }
    [ -d "$HOME/$SKILL_LINK_REL" ] || return 1
    assert_file_exists "$HOME/$SKILL_LINK_REL/SKILL.md" || return 1
    assert_file_exists "$HOME/$SKILL_LINK_REL/reference/index.md"
}

# (4) skill uninstall で削除される (symlink)
test_uninstall_removes_symlink() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    "$REPO_DIR/ccskill-gmail" skill uninstall --yes >/dev/null 2>&1 || return 1
    [ ! -e "$HOME/$SKILL_LINK_REL" ] && [ ! -L "$HOME/$SKILL_LINK_REL" ]
}

# (5) skill uninstall で削除される (--copy の実体)
test_uninstall_removes_copy() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install --copy >/dev/null 2>&1 || return 1
    "$REPO_DIR/ccskill-gmail" skill uninstall --yes >/dev/null 2>&1 || return 1
    [ ! -e "$HOME/$SKILL_LINK_REL" ]
}

# (6) symlink → --copy の切り替えができる
test_switch_symlink_to_copy() {
    use_fixture_home
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    "$REPO_DIR/ccskill-gmail" skill install --copy >/dev/null 2>&1 || return 1
    [ ! -L "$HOME/$SKILL_LINK_REL" ] && [ -d "$HOME/$SKILL_LINK_REL" ]
}

# (7) ~/.claude/settings.json には触れない
test_does_not_touch_settings() {
    use_fixture_home
    mkdir -p "$HOME/.claude"
    echo '{"sentinel": true}' > "$HOME/.claude/settings.json"
    "$REPO_DIR/ccskill-gmail" skill install >/dev/null 2>&1 || return 1
    local sentinel
    sentinel=$(jq -r '.sentinel' "$HOME/.claude/settings.json" 2>/dev/null)
    assert_eq "true" "$sentinel" "settings.json was modified"
}

echo ""
echo "test-skill-cmd.sh (#124)"
echo ""

run_test "install: creates symlink to master skill"   test_install_creates_symlink
run_test "install: idempotent"                        test_install_idempotent
run_test "install: --copy makes a real directory"     test_install_copy_mode
run_test "uninstall: removes symlink"                 test_uninstall_removes_symlink
run_test "uninstall: removes copied directory"        test_uninstall_removes_copy
run_test "install: switch symlink -> copy"            test_switch_symlink_to_copy
run_test "install: does not touch ~/.claude/settings.json" test_does_not_touch_settings

test_summary
