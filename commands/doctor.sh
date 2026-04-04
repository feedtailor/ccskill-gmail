#!/bin/bash
#
# ccskill-gmail doctor - Environment Diagnostics
#
# Usage: ccskill-gmail doctor [DIR]
#
# Diagnoses common setup issues and provides fix hints.
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

# ========================================
# 0. ディスパッチャ経由チェック
# ========================================

if [ -z "$CCSKILL_GMAIL_DIR" ]; then
    echo "Error: This script should be called via 'ccskill-gmail doctor'"
    exit 1
fi

source "$CCSKILL_GMAIL_DIR/lib/clasp.sh"

# ========================================
# 1. 対象ディレクトリの決定
# ========================================

TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory not found: $TARGET_DIR${NC}"
    exit 1
fi
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo ""
echo "ccskill-gmail doctor"
echo "================================================"
echo "Checking: $TARGET_DIR"
echo ""

ERRORS=0
WARNINGS=0

# ========================================
# 2. グローバル環境チェック
# ========================================

echo "Global Environment"
echo "----------------------------------------"

# clasp
if _clasp --version &>/dev/null 2>&1; then
    clasp_version=$(_clasp --version 2>/dev/null || echo "unknown")
    local_clasp="$CCSKILL_GMAIL_DIR/node_modules/.bin/clasp"
    if [ -x "$local_clasp" ]; then
        echo -e "  $PASS clasp installed - local ($clasp_version)"
    else
        echo -e "  $PASS clasp installed - global ($clasp_version)"
    fi
else
    echo -e "  $FAIL clasp not available"
    echo "       Fix: ccskill-gmail setup"
    ERRORS=$((ERRORS + 1))
fi

# clasp login（v3: show-authorized-user で判定）
if _clasp show-authorized-user 2>&1 | grep -qi "not logged in"; then
    echo -e "  $FAIL clasp not logged in"
    echo "       Fix: ccskill-gmail install (will prompt for login)"
    ERRORS=$((ERRORS + 1))
else
    echo -e "  $PASS clasp logged in"
fi

# jq
if command -v jq &>/dev/null; then
    jq_version=$(jq --version 2>/dev/null || echo "unknown")
    echo -e "  $PASS jq installed ($jq_version)"
else
    echo -e "  $FAIL jq not installed"
    echo "       Fix: brew install jq"
    ERRORS=$((ERRORS + 1))
fi

# wkhtmltopdf (optional, for PDF)
if command -v wkhtmltopdf &>/dev/null; then
    echo -e "  $PASS wkhtmltopdf installed (enables PDF export)"
else
    echo -e "  $WARN wkhtmltopdf not installed (required for PDF export)"
    echo "       Fix: brew install wkhtmltopdf"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# ========================================
# 3. プロジェクト固有チェック
# ========================================

GAS_DIR="$TARGET_DIR/.ccskill-gmail"

echo "Project: $TARGET_DIR"
echo "----------------------------------------"

# .ccskill-gmail/ ディレクトリ
if [ ! -d "$GAS_DIR" ]; then
    echo -e "  $FAIL .ccskill-gmail/ not found"
    echo "       Fix: ccskill-gmail install"
    ERRORS=$((ERRORS + 1))
    # これ以降のチェックはスキップ
    echo ""
    echo "================================================"
    echo -e "Result: ${RED}$ERRORS error(s)${NC}, $WARNINGS warning(s)"
    echo ""
    echo "Install first: ccskill-gmail install"
    exit 1
fi

echo -e "  $PASS .ccskill-gmail/ exists"

# .clasp.json
if [ -f "$GAS_DIR/.clasp.json" ]; then
    echo -e "  $PASS .clasp.json exists"
    # rootDir チェック
    root_dir=$(jq -r '.rootDir // ""' "$GAS_DIR/.clasp.json" 2>/dev/null)
    if [ "$root_dir" = "." ]; then
        echo -e "  $PASS .clasp.json rootDir is correct"
    else
        echo -e "  $WARN .clasp.json rootDir is '$root_dir' (expected '.')"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  $FAIL .clasp.json not found"
    echo "       Fix: ccskill-gmail install (or reinstall)"
    ERRORS=$((ERRORS + 1))
fi

# endpoint（.ccskill-metadata.json 内）
if [ -f "$GAS_DIR/.ccskill-metadata.json" ]; then
    endpoint=$(jq -r '.endpoint // ""' "$GAS_DIR/.ccskill-metadata.json" 2>/dev/null)
    if [ -n "$endpoint" ]; then
        echo -e "  $PASS endpoint found in metadata"
        if echo "$endpoint" | grep -q "^https://script.google.com/"; then
            echo -e "  $PASS endpoint URL format is valid"
        else
            echo -e "  $FAIL endpoint URL format is invalid: $endpoint"
            echo "       Expected: https://script.google.com/macros/s/.../exec"
            ERRORS=$((ERRORS + 1))
        fi
    elif [ -f "$GAS_DIR/endpoint" ]; then
        echo -e "  $WARN endpoint in legacy format (run: ccskill-gmail update)"
        WARNINGS=$((WARNINGS + 1))
        endpoint=$(tr -d '[:space:]' < "$GAS_DIR/endpoint")
    else
        echo -e "  $FAIL endpoint not found"
        echo "       Fix: ccskill-gmail install"
        ERRORS=$((ERRORS + 1))
    fi
fi

# マスターディレクトリ（installed_from）
MASTER_DIR=""
if [ -f "$GAS_DIR/.ccskill-metadata.json" ]; then
    MASTER_DIR=$(jq -r '.installed_from // ""' "$GAS_DIR/.ccskill-metadata.json" 2>/dev/null)
fi
[ -z "$MASTER_DIR" ] && MASTER_DIR="${CCSKILL_GMAIL_DIR:-}"

if [ -n "$MASTER_DIR" ] && [ -d "$MASTER_DIR" ]; then
    echo -e "  $PASS master directory found ($MASTER_DIR)"
    if [ -f "$MASTER_DIR/lib/auth.sh" ]; then
        echo -e "  $PASS auth.sh found in master"
    else
        echo -e "  $FAIL auth.sh not found in master"
        echo "       Fix: ccskill-gmail install"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  $FAIL master directory not found: $MASTER_DIR"
    echo "       Fix: ccskill-gmail install"
    ERRORS=$((ERRORS + 1))
fi

# api スクリプト
if [ -f "$GAS_DIR/api" ] && [ -x "$GAS_DIR/api" ]; then
    echo -e "  $PASS api script exists and is executable"
else
    echo -e "  $FAIL api script missing or not executable"
    echo "       Fix: ccskill-gmail update --force"
    ERRORS=$((ERRORS + 1))
fi

# スキル定義
SKILL_DIR="$TARGET_DIR/.claude/skills/ccskill-gmail"
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    echo -e "  $PASS SKILL.md exists"
else
    echo -e "  $FAIL SKILL.md not found at $SKILL_DIR/"
    echo "       Fix: ccskill-gmail update --force"
    ERRORS=$((ERRORS + 1))
fi

# config.js
if [ -f "$GAS_DIR/config.js" ]; then
    echo -e "  $PASS config.js exists"
else
    echo -e "  $WARN config.js not found (default permissions will be used)"
    WARNINGS=$((WARNINGS + 1))
fi

# .gitignore チェック
if [ -d "$TARGET_DIR/.git" ]; then
    gitignore="$TARGET_DIR/.gitignore"
    if [ -f "$gitignore" ] && grep -qF ".ccskill-gmail/" "$gitignore"; then
        echo -e "  $PASS .gitignore contains .ccskill-gmail/"
    else
        echo -e "  $WARN .ccskill-gmail/ is not in .gitignore"
        echo "       Fix: echo '.ccskill-gmail/' >> $gitignore"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# ========================================
# 4. 疎通チェック（endpoint が存在する場合のみ）
# ========================================

if [ -n "${endpoint:-}" ] && [ -n "${MASTER_DIR:-}" ] && [ -f "${MASTER_DIR}/lib/auth.sh" ]; then
    echo "Connectivity"
    echo "----------------------------------------"

    source "$MASTER_DIR/lib/auth.sh"

    # トークン取得
    token=$(gas_token 2>/dev/null || true)
    if [ -n "$token" ] && [ "$token" != "" ]; then
        echo -e "  $PASS OAuth token obtained"

        # エンドポイント疎通
        response=$(curl -sL --max-time 30 \
            -H "Authorization: Bearer $token" \
            "$endpoint" 2>/dev/null || true)

        if echo "$response" | jq -e '.ok == true' >/dev/null 2>&1; then
            echo -e "  $PASS Endpoint is responding correctly"
        elif echo "$response" | grep -q "<!DOCTYPE html>" 2>/dev/null; then
            echo -e "  $FAIL Endpoint returned HTML (OAuth token may be expired)"
            echo "       Fix: ccskill-gmail setup (re-authenticate)"
            ERRORS=$((ERRORS + 1))
        elif [ -z "$response" ]; then
            echo -e "  $FAIL Endpoint did not respond (timeout)"
            echo "       Fix: Check your network, or verify endpoint URL"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "  $FAIL Endpoint returned unexpected response"
            echo "       Response: $(echo "$response" | head -c 200)"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  $FAIL Could not obtain OAuth token"
        echo "       Fix: ccskill-gmail setup"
        ERRORS=$((ERRORS + 1))
    fi

    echo ""
fi

# ========================================
# 5. 結果サマリー
# ========================================

echo "================================================"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "Result: ${GREEN}All checks passed!${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "Result: ${GREEN}No errors${NC}, ${YELLOW}$WARNINGS warning(s)${NC}"
else
    echo -e "Result: ${RED}$ERRORS error(s)${NC}, ${YELLOW}$WARNINGS warning(s)${NC}"
fi
echo ""
