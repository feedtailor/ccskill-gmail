#!/bin/bash
#
# tests/lib/test-command-audit.sh - 管理コマンドの実行履歴 (command audit log) のテスト (#135)
#
# Usage: bash tests/lib/test-command-audit.sh
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

seed_account() {
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/accounts.sh"
    accounts_upsert "$1" "clasp-$1" "sid" "did" "https://example.invalid/exec" "${2:-}"
}

# ccskill-gmail を fixture ディレクトリで実行 (出力は捨てる、終了コードは保持)
cg() {
    local dir="$1"
    shift
    (cd "$dir" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" "$REPO_DIR/ccskill-gmail" "$@" >/dev/null 2>&1)
}

COMMANDS_FILE() { printf '%s/.ccskill-gmail/history/commands.jsonl' "$HOME"; }

# (1) 状態を変える管理コマンド (bind) が commands.jsonl に記録される
test_recordable_command_written() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" bind a@example.com "$proj" --yes || return 1
    assert_file_exists "$(COMMANDS_FILE)" || return 1
    local cmd
    cmd=$(tail -1 "$(COMMANDS_FILE)" | jq -r '.command')
    assert_eq "bind" "$cmd" || return 1
    local ok
    ok=$(tail -1 "$(COMMANDS_FILE)" | jq -r '.success')
    assert_eq "true" "$ok"
}

# (2) 読み取り専用コマンド (account list) は記録されない
test_readonly_not_recorded() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" account list || true
    # commands.jsonl が存在しない、または bind/account 記録がないこと
    if [ -f "$(COMMANDS_FILE)" ]; then
        local n
        n=$(wc -l < "$(COMMANDS_FILE)" | tr -d ' ')
        assert_eq "0" "$n" "account list should not be recorded"
    fi
}

# (3) status (読み取り専用) も記録されない
test_status_not_recorded() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" status || true
    [ ! -f "$(COMMANDS_FILE)" ]
}

# (4) 失敗した管理コマンドは success=false で記録される
test_failure_recorded() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" bind nonexistent@example.com "$proj" --yes && return 1  # 失敗するはず
    assert_file_exists "$(COMMANDS_FILE)" || return 1
    local ok err
    ok=$(tail -1 "$(COMMANDS_FILE)" | jq -r '.success')
    assert_eq "false" "$ok" || return 1
    err=$(tail -1 "$(COMMANDS_FILE)" | jq -r '.error // ""')
    assert_contains "exit code" "$err"
}

# (5) account add 等の二階層目が subcommand に入る (default を seed 済みアカウントで)
test_subcommand_captured() {
    use_fixture_home
    seed_account "a@example.com"
    seed_account "b@example.com" "work"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" account default work || return 1
    local sub
    sub=$(tail -1 "$(COMMANDS_FILE)" | jq -r '.subcommand')
    assert_eq "default" "$sub"
}

# (6) 記録に機微情報フィールド (api ログの contentKeys 等) が混ざらない / 想定スキーマである
test_record_schema() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" bind a@example.com "$proj" --yes || return 1
    local line keys
    line=$(tail -1 "$(COMMANDS_FILE)")
    # api ログ固有のキー (contentKeys / identifiers) を含まないこと
    keys=$(printf '%s' "$line" | jq -r 'keys | join(",")')
    case "$keys" in
        *contentKeys*|*identifiers*) echo "    unexpected api-log key in: $keys" >&2; return 1 ;;
    esac
    # 想定キーが揃っていること
    printf '%s' "$line" | jq -e 'has("command") and has("subcommand") and has("args") and has("success") and has("error") and has("duration_ms")' >/dev/null
}

# (7) command audit は api 監査ログ (history/<email>/audit.jsonl) に影響しない
test_does_not_touch_api_log() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    cg "$proj" bind a@example.com "$proj" --yes || return 1
    [ ! -f "$HOME/.ccskill-gmail/history/a@example.com/audit.jsonl" ]
}

# (8) 書き込めない環境では無言スキップし、コマンド自体は成功する
test_silent_skip_on_unwritable() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    # mkdir -p が失敗するパス (通常ファイル配下)
    (cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" \
        CCSKILL_COMMANDS_HISTORY_FILE="/dev/null/nope/commands.jsonl" \
        "$REPO_DIR/ccskill-gmail" bind a@example.com "$proj" --yes >/dev/null 2>&1)
}

# (9) 機微フラグの値が伏字になる (関数の単体テスト)
test_redact_sensitive_flags() {
    # shellcheck source=/dev/null
    source "$REPO_DIR/lib/history.sh"
    local out
    out=$(_ccskill_history_redact_args --token secret123 foo --password=pw bar)
    assert_contains '"***"' "$out" || return 1
    case "$out" in
        *secret123*|*pw*) echo "    secret leaked: $out" >&2; return 1 ;;
    esac
    # 通常引数は残る
    assert_contains '"foo"' "$out"
}

# (10) CCSKILL_GMAIL_HISTORY=off で記録されない
test_opt_out() {
    use_fixture_home
    seed_account "a@example.com"
    local proj
    proj=$(test_mktemp_d)
    (cd "$proj" && GMAIL_ENDPOINT="" CCSKILL_GMAIL_ACCOUNT="" CCSKILL_GMAIL_HISTORY=off \
        "$REPO_DIR/ccskill-gmail" bind a@example.com "$proj" --yes >/dev/null 2>&1) || return 1
    [ ! -f "$(COMMANDS_FILE)" ]
}

echo ""
echo "test-command-audit.sh (#135)"
echo ""

run_test "recordable command (bind) is written"            test_recordable_command_written
run_test "read-only (account list) is NOT recorded"        test_readonly_not_recorded
run_test "read-only (status) is NOT recorded"              test_status_not_recorded
run_test "failed command recorded with success=false"      test_failure_recorded
run_test "second-level subcommand captured"                test_subcommand_captured
run_test "record uses command schema, no api-log keys"     test_record_schema
run_test "does not touch api audit log"                     test_does_not_touch_api_log
run_test "silent skip on unwritable target"                test_silent_skip_on_unwritable
run_test "sensitive flag values are redacted"              test_redact_sensitive_flags
run_test "CCSKILL_GMAIL_HISTORY=off disables recording"    test_opt_out

test_summary
