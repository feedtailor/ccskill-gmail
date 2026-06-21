#!/bin/bash
#
# tests/lib/test-install-mode.sh - 構成種別(central/dedicated)判定とバージョン誤判定の修正 (#131)
#
# 中央化以降、binding.json だけの central 構成は registry に version="unknown" が
# 入り、status/update-all/info がバージョン文字列比較で「常に outdated」と誤判定する。
# 構成種別をファイルベースで判定し、central はバージョン比較対象から外すことを検証する。
#
# Usage: bash tests/lib/test-install-mode.sh
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

# ---- 構成を持つ一時ディレクトリ生成 ----
make_central_dir() {
    local d; d=$(test_mktemp_d)
    mkdir -p "$d/.ccskill-gmail"
    printf '{"account":"a@example.com"}\n' > "$d/.ccskill-gmail/binding.json"
    printf '%s' "$d"
}
make_dedicated_dir() {
    local d; d=$(test_mktemp_d)
    mkdir -p "$d/.ccskill-gmail"
    printf '{}\n' > "$d/.ccskill-gmail/.clasp.json"
    printf '%s' "$d"
}
make_legacy_dir() {
    local d; d=$(test_mktemp_d)
    mkdir -p "$d/.ccskill-gmail"
    printf '{"endpoint":"https://example.invalid/exec"}\n' > "$d/.ccskill-gmail/.ccskill-metadata.json"
    printf '%s' "$d"
}
make_coexist_dir() {
    local d; d=$(test_mktemp_d)
    mkdir -p "$d/.ccskill-gmail"
    printf '{"account":"a@example.com"}\n' > "$d/.ccskill-gmail/binding.json"
    printf '{}\n' > "$d/.ccskill-gmail/.clasp.json"
    printf '%s' "$d"
}
make_empty_dir() {
    local d; d=$(test_mktemp_d)
    printf '%s' "$d"
}

write_registry() {
    # write_registry <regfile> <path> <version>
    jq -n --arg p "$2" --arg v "$3" \
        '{schema_version:"1.0", installations:{($p):{project_name:"t",installed_at:"x",updated_at:"x",version:$v,email:"a@example.com"}}}' \
        > "$1"
}

# ========================================
# (1) ccskill_install_mode ヘルパーの判定
# ========================================

test_mode_central() {
    source "$REPO_DIR/lib/registry.sh"
    assert_eq "central" "$(ccskill_install_mode "$(make_central_dir)")"
}
test_mode_coexist_is_central() {
    # binding + clasp 共存は central (api は binding を優先解決するため)
    source "$REPO_DIR/lib/registry.sh"
    assert_eq "central" "$(ccskill_install_mode "$(make_coexist_dir)")"
}
test_mode_dedicated() {
    source "$REPO_DIR/lib/registry.sh"
    assert_eq "dedicated" "$(ccskill_install_mode "$(make_dedicated_dir)")"
}
test_mode_legacy_is_dedicated() {
    source "$REPO_DIR/lib/registry.sh"
    assert_eq "dedicated" "$(ccskill_install_mode "$(make_legacy_dir)")"
}
test_mode_none() {
    source "$REPO_DIR/lib/registry.sh"
    assert_eq "none" "$(ccskill_install_mode "$(make_empty_dir)")"
}

# ========================================
# (2) status: central を outdated と誤判定しない
# ========================================

test_status_central_not_outdated() {
    use_fixture_home
    local cdir reg out
    cdir=$(make_central_dir)
    reg=$(test_mktemp)
    write_registry "$reg" "$cdir" "unknown"
    out=$(CCSKILL_GMAIL_REGISTRY_FILE="$reg" "$REPO_DIR/ccskill-gmail" status 2>&1) || true
    assert_contains "shared" "$out" || return 1
    assert_contains "0 outdated" "$out"
}

test_status_dedicated_still_outdated() {
    use_fixture_home
    local ddir reg out
    ddir=$(make_dedicated_dir)
    reg=$(test_mktemp)
    write_registry "$reg" "$ddir" "oldver0"
    out=$(CCSKILL_GMAIL_REGISTRY_FILE="$reg" "$REPO_DIR/ccskill-gmail" status 2>&1) || true
    assert_contains "1 outdated" "$out" || return 1
    # 専用GAS が残るときは集約 (migrate) を促す
    assert_contains "ccskill-gmail migrate" "$out"
}

# ========================================
# (3) update-all: central を更新対象に含めない
# ========================================

test_updateall_skips_central() {
    use_fixture_home
    local cdir reg out
    cdir=$(make_central_dir)
    reg=$(test_mktemp)
    write_registry "$reg" "$cdir" "unknown"
    out=$(CCSKILL_GMAIL_REGISTRY_FILE="$reg" "$REPO_DIR/ccskill-gmail" update-all 2>&1) || true
    assert_contains "Outdated:    0" "$out"
}

# ========================================
# (4) info: central は shared 表示でバージョン比較しない
# ========================================

test_info_central_shows_shared() {
    use_fixture_home
    local cdir out
    cdir=$(make_central_dir)
    out=$(CCSKILL_GMAIL_REGISTRY_FILE="$(test_mktemp)" "$REPO_DIR/ccskill-gmail" info "$cdir" 2>&1) || true
    assert_contains "shared" "$out" || return 1
    case "$out" in *"outdated"*) echo "central info must not show outdated" >&2; return 1;; esac
    return 0
}

# ========================================
# (5) ガード: update.sh の central 判定が共存 (clasp 残存) を漏らさない
# ========================================

test_update_central_uses_mode_helper() {
    local f="$REPO_DIR/commands/update.sh"
    # 旧 central ゲートの結合条件 `binding.json ... && [ ! -f ... .clasp.json` が残っていないこと
    # (dedicated パスの単独 `! -f .clasp.json` チェックは正当なので誤検出しない)
    if grep -q 'binding.json" \] && \[ ! -f' "$f"; then
        echo "update.sh still gates central mode on absence of .clasp.json" >&2
        return 1
    fi
    grep -q 'ccskill_install_mode' "$f" || { echo "update.sh should classify via ccskill_install_mode" >&2; return 1; }
}

# ========================================
# 実行
# ========================================

echo ""
echo "test-install-mode.sh (#131)"
echo ""

run_test "mode: binding -> central"              test_mode_central
run_test "mode: binding+clasp -> central"        test_mode_coexist_is_central
run_test "mode: clasp -> dedicated"              test_mode_dedicated
run_test "mode: legacy metadata -> dedicated"    test_mode_legacy_is_dedicated
run_test "mode: empty -> none"                   test_mode_none
run_test "status: central not outdated (shared)" test_status_central_not_outdated
run_test "status: dedicated still outdated"      test_status_dedicated_still_outdated
run_test "update-all: skips central"             test_updateall_skips_central
run_test "info: central shows shared"            test_info_central_shows_shared
run_test "update.sh: central via mode helper"    test_update_central_uses_mode_helper

test_summary
