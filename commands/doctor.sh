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
if command -v clasp &>/dev/null; then
    clasp_version=$(clasp --version 2>/dev/null || echo "unknown")
    echo -e "  $PASS clasp installed ($clasp_version)"
else
    echo -e "  $FAIL clasp not installed"
    echo "       Fix: npm install -g @google/clasp"
    ERRORS=$((ERRORS + 1))
fi

# clasp login
if clasp login --status &>/dev/null 2>&1; then
    echo -e "  $PASS clasp logged in"
else
    echo -e "  $FAIL clasp not logged in"
    echo "       Fix: clasp login"
    ERRORS=$((ERRORS + 1))
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
    echo -e "  $PASS wkhtmltopdf installed (PDF保存が使えます)"
else
    echo -e "  $WARN wkhtmltopdf not installed (PDF保存には必要)"
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

# endpoint
if [ -f "$GAS_DIR/endpoint" ]; then
    endpoint=$(cat "$GAS_DIR/endpoint")
    echo -e "  $PASS endpoint file exists"
    # URL 形式チェック
    if echo "$endpoint" | grep -q "^https://script.google.com/"; then
        echo -e "  $PASS endpoint URL format is valid"
    else
        echo -e "  $FAIL endpoint URL format is invalid: $endpoint"
        echo "       Expected: https://script.google.com/macros/s/.../exec"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  $FAIL endpoint file not found"
    echo "       Fix: ccskill-gmail install (or check .env for GMAIL_ENDPOINT)"
    ERRORS=$((ERRORS + 1))
fi

# auth.sh
if [ -f "$GAS_DIR/auth.sh" ]; then
    echo -e "  $PASS auth.sh exists"
else
    echo -e "  $FAIL auth.sh not found"
    echo "       Fix: ccskill-gmail update --force"
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

# history ディレクトリ
if [ -d "$GAS_DIR/history" ]; then
    echo -e "  $PASS history/ directory exists"
else
    echo -e "  $WARN history/ directory not found (audit log won't be recorded)"
    echo "       Fix: mkdir -p $GAS_DIR/history && chmod 700 $GAS_DIR/history"
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

if [ -f "$GAS_DIR/endpoint" ] && [ -f "$GAS_DIR/auth.sh" ]; then
    echo "Connectivity"
    echo "----------------------------------------"

    source "$GAS_DIR/auth.sh"

    # トークン取得
    token=$(gas_token 2>/dev/null || true)
    if [ -n "$token" ] && [ "$token" != "" ]; then
        echo -e "  $PASS OAuth token obtained"

        # エンドポイント疎通
        endpoint=$(cat "$GAS_DIR/endpoint")
        response=$(curl -sL --max-time 30 \
            -H "Authorization: Bearer $token" \
            "$endpoint" 2>/dev/null || true)

        if echo "$response" | jq -e '.ok == true' >/dev/null 2>&1; then
            echo -e "  $PASS Endpoint is responding correctly"
        elif echo "$response" | grep -q "<!DOCTYPE html>" 2>/dev/null; then
            echo -e "  $FAIL Endpoint returned HTML (OAuth token may be expired)"
            echo "       Fix: clasp login (re-authenticate)"
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
        echo "       Fix: clasp login"
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
