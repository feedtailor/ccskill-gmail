#!/bin/bash
#
# Gmail Skill - Audit Log / History Module
#
# このファイルは lib/api からの source を想定している。
# CCSKILL_HISTORY_DIR を呼び出し元（api スクリプト）が設定してから source すること。
#
# 関数一覧:
#   _ccskill_history_gen_id       - 一意 ID 生成
#   _ccskill_history_record       - JSONL に1行追記
#   _ccskill_history_rotate       - 行数超過時のローテーション
#   _ccskill_history_list         - 履歴表示
#   _ccskill_history_clear        - ログクリア（--yes 必須）
#

# ========================================
# Opt-out チェック
# ========================================

if [ "${CCSKILL_GMAIL_HISTORY:-}" = "off" ]; then
    _ccskill_history_record() { :; }
    return 0
fi

# ========================================
# jq 存在確認（なければ記録をスキップ）
# ========================================

if ! command -v jq &>/dev/null; then
    _ccskill_history_record() { :; }
    return 0
fi

# ========================================
# ディレクトリ初期化
# ========================================

_ccskill_history_init_dir() {
    local dir="${CCSKILL_HISTORY_DIR:-}"
    if [ -z "$dir" ]; then
        return 1
    fi
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" && chmod 700 "$dir" || return 1
    fi
    return 0
}

# ========================================
# 1. _ccskill_history_gen_id
#    形式: YYYYMMDDTHHMMSS_XXXXXX（6桁ランダム hex）
# ========================================

_ccskill_history_gen_id() {
    local ts
    ts=$(date '+%Y%m%dT%H%M%S')

    # /dev/urandom が使えれば使う、なければ $RANDOM で代替
    local rand_hex
    if [ -r /dev/urandom ]; then
        rand_hex=$(dd if=/dev/urandom bs=3 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | head -c 6)
    else
        # $RANDOM は 0-32767 → 2つ組み合わせて hex 化
        rand_hex=$(printf '%04x%02x' "$RANDOM" "$(( RANDOM % 256 ))")
    fi

    printf '%s_%s\n' "$ts" "$rand_hex"
}

# ========================================
# 2. _ccskill_history_record
#    $1: subcommand
#    $2: exit_code
#    $3: response body (stdout from the subcommand)
#    $4+: original args passed to the subcommand
# ========================================

_ccskill_history_record() {
    local subcommand="$1"
    local exit_code="$2"
    local response_body="$3"
    shift 3
    # $@ = original args

    _ccskill_history_init_dir || return 0

    local audit_file="${CCSKILL_HISTORY_DIR}/audit.jsonl"

    # ファイル新規作成時にパーミッション設定
    local file_is_new=false
    if [ ! -f "$audit_file" ]; then
        file_is_new=true
    fi

    # ---- action を決定 ----
    local action=""
    case "$subcommand" in
        get)
            # key=value 引数から action=XXX を探す
            for arg in "$@"; do
                case "$arg" in
                    action=*)
                        action="${arg#action=}"
                        break
                        ;;
                esac
            done
            ;;
        post)
            # JSON ボディ（$1）から .action を抽出
            local post_body="${1:-}"
            if [ -n "$post_body" ]; then
                if [ "${post_body:0:1}" = "@" ]; then
                    # @file 形式
                    local file_path="${post_body:1}"
                    if [ -f "$file_path" ]; then
                        action=$(jq -r '.action // ""' "$file_path" 2>/dev/null || true)
                    fi
                else
                    action=$(printf '%s' "$post_body" | jq -r '.action // ""' 2>/dev/null || true)
                fi
            fi
            ;;
        download|save-html|save-pdf)
            action="$subcommand"
            ;;
        *)
            action="unknown:${subcommand}"
            ;;
    esac

    # ---- パラメータ分類（jq で一括処理、bash 3.2 互換） ----
    # 全パラメータを JSON オブジェクトに収集し、jq で3分類する
    local all_params_json="{}"

    case "$subcommand" in
        get)
            # key=value 形式の引数を JSON オブジェクトに変換
            for arg in "$@"; do
                local key="${arg%%=*}"
                local val="${arg#*=}"
                if [ "$key" != "$val" ] && [ "$key" != "action" ]; then
                    all_params_json=$(printf '%s' "$all_params_json" | \
                        jq --arg k "$key" --arg v "$val" '. + {($k): $v}')
                fi
            done
            ;;
        post)
            local post_body="${1:-}"
            local json_body=""
            if [ -n "$post_body" ]; then
                if [ "${post_body:0:1}" = "@" ]; then
                    local file_path="${post_body:1}"
                    if [ -f "$file_path" ]; then
                        json_body=$(cat "$file_path" 2>/dev/null || true)
                    fi
                else
                    json_body="$post_body"
                fi
            fi
            if [ -n "$json_body" ]; then
                # action キーを除外して全パラメータを取得（値は文字列に統一）
                all_params_json=$(printf '%s' "$json_body" | jq -c 'del(.action) | with_entries(.value = (.value | tostring))' 2>/dev/null || echo "{}")
            fi
            ;;
        download)
            all_params_json=$(jq -cn \
                --arg messageId "${1:-}" \
                --arg attachmentIndex "${2:-}" \
                '{messageId: $messageId, attachmentIndex: $attachmentIndex}')
            ;;
        save-html)
            all_params_json=$(jq -cn \
                --arg messageId "${1:-}" \
                --arg includeHeaders "${3:-true}" \
                '{messageId: $messageId, includeHeaders: $includeHeaders}')
            ;;
        save-pdf)
            all_params_json=$(jq -cn \
                --arg messageId "${1:-}" \
                '{messageId: $messageId}')
            ;;
    esac

    # jq で3分類（識別/内容/制御）
    local classified_json
    classified_json=$(printf '%s' "$all_params_json" | jq -c '
        def id_keys: ["threadId","messageId","draftId","label","attachmentIndex","thread_id","message_id","draft_id","attachment_index"];
        def content_keys: ["body","subject","to","cc","bcc","htmlBody","query","attachments"];
        def control_keys: ["maxResults","includeHeaders","replyAll","skipSelf","max_results","include_headers","reply_all","skip_self"];
        {
            identifiers: with_entries(select(.key | IN(id_keys[]))),
            contentKeys: [keys[] | select(IN(content_keys[]))],
            controls: with_entries(select(.key | IN(control_keys[])))
        }
    ' 2>/dev/null || echo '{"identifiers":{},"contentKeys":[],"controls":{}}')

    local identifiers_json=$(printf '%s' "$classified_json" | jq -c '.identifiers')
    local content_keys_json=$(printf '%s' "$classified_json" | jq -c '.contentKeys')
    local controls_json=$(printf '%s' "$classified_json" | jq -c '.controls')

    # ---- response_ok / error を解析 ----
    local response_ok="false"
    local error_msg="null"

    if [ -n "$response_body" ]; then
        if printf '%s' "$response_body" | jq -e '.ok == true' >/dev/null 2>&1; then
            response_ok="true"
        else
            response_ok="false"
            local extracted_error
            extracted_error=$(printf '%s' "$response_body" | jq -r '.error // ""' 2>/dev/null || true)
            if [ -n "$extracted_error" ]; then
                error_msg=$(printf '%s' "$extracted_error" | jq -Rs .)
            fi
        fi
    fi

    # ---- duration_ms を計算 ----
    local duration_ms="null"
    if [ -n "${_LOG_START_MS:-}" ] && [ "$_LOG_START_MS" != "0" ]; then
        local now_ms=""
        if command -v python3 &>/dev/null; then
            now_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
        fi
        if [ -n "$now_ms" ]; then
            duration_ms=$(( now_ms - _LOG_START_MS ))
        fi
    fi

    # ---- メタ情報 ----
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S%z')
    local project="$PWD"
    local record_id
    record_id=$(_ccskill_history_gen_id)

    # ---- JSONL 1行を構築 ----
    local json_line
    json_line=$(jq -cn \
        --arg id          "$record_id" \
        --arg timestamp   "$timestamp" \
        --arg project     "$project" \
        --arg subcommand  "$subcommand" \
        --arg action      "$action" \
        --argjson identifiers  "$identifiers_json" \
        --argjson contentKeys  "$content_keys_json" \
        --argjson controls     "$controls_json" \
        --argjson response_ok  "$response_ok" \
        --argjson error        "$error_msg" \
        --argjson duration_ms  "$duration_ms" \
        '{
            id:          $id,
            timestamp:   $timestamp,
            project:     $project,
            subcommand:  $subcommand,
            action:      $action,
            identifiers: $identifiers,
            contentKeys: $contentKeys,
            controls:    $controls,
            response_ok: $response_ok,
            error:       $error,
            duration_ms: $duration_ms
        }')

    # ---- ファイルに追記 ----
    printf '%s\n' "$json_line" >> "$audit_file"

    # 新規ファイルにパーミッション設定
    if [ "$file_is_new" = true ]; then
        chmod 600 "$audit_file"
    fi

    # ---- ローテーション ----
    _ccskill_history_rotate
}

# ========================================
# 3. _ccskill_history_rotate
#    1000行超過時に audit.jsonl → audit.jsonl.1 に退避
# ========================================

_ccskill_history_rotate() {
    local dir="${CCSKILL_HISTORY_DIR:-}"
    [ -z "$dir" ] && return 0

    local audit_file="${dir}/audit.jsonl"
    [ ! -f "$audit_file" ] && return 0

    local line_count
    line_count=$(wc -l < "$audit_file")

    if [ "$line_count" -gt 1000 ]; then
        local backup="${dir}/audit.jsonl.1"
        # atomic: mv は同一ファイルシステム内で atomic
        mv "$audit_file" "$backup"
        # 新しい空ファイルを作成してパーミッション設定
        : > "$audit_file"
        chmod 600 "$audit_file"
    fi
}

# ========================================
# 4. _ccskill_history_list
#    $1: count（デフォルト 20）
#    $2: format（"human" または "json"、デフォルト "human"）
#    env: HISTORY_FILTER_ACTION, HISTORY_FILTER_SINCE, HISTORY_FILTER_ERRORS
# ========================================

_ccskill_history_list() {
    local count="${1:-20}"
    local format="${2:-human}"

    local dir="${CCSKILL_HISTORY_DIR:-}"
    if [ -z "$dir" ]; then
        printf 'Error: CCSKILL_HISTORY_DIR is not set\n' >&2
        return 1
    fi

    local audit_file="${dir}/audit.jsonl"
    local backup_file="${dir}/audit.jsonl.1"

    # バックアップ + 現行ファイルを連結して末尾 N 行を取得
    local combined_lines=""
    if [ -f "$backup_file" ] && [ -f "$audit_file" ]; then
        combined_lines=$(cat "$backup_file" "$audit_file")
    elif [ -f "$audit_file" ]; then
        combined_lines=$(cat "$audit_file")
    elif [ -f "$backup_file" ]; then
        combined_lines=$(cat "$backup_file")
    else
        printf '(no history)\n'
        return 0
    fi

    if [ -z "$combined_lines" ]; then
        printf '(no history)\n'
        return 0
    fi

    # jq フィルターを構築（フィルタを先に適用してから末尾 N 件を取る）
    local jq_filter='.'

    # --action フィルター
    if [ -n "${HISTORY_FILTER_ACTION:-}" ]; then
        jq_filter="${jq_filter} | select(.action == \"${HISTORY_FILTER_ACTION}\")"
    fi

    # --since フィルター（ISO 8601 日付プレフィックス比較）
    if [ -n "${HISTORY_FILTER_SINCE:-}" ]; then
        jq_filter="${jq_filter} | select(.timestamp >= \"${HISTORY_FILTER_SINCE}\")"
    fi

    # --errors フィルター
    if [ -n "${HISTORY_FILTER_ERRORS:-}" ]; then
        jq_filter="${jq_filter} | select(.response_ok == false)"
    fi

    # フィルタ適用後に末尾 N 件を取得
    local lines
    lines=$(printf '%s\n' "$combined_lines" | jq -c "$jq_filter" 2>/dev/null | tail -n "$count")

    if [ -z "$lines" ]; then
        printf '(no history)\n'
        return 0
    fi

    if [ "$format" = "json" ]; then
        printf '%s\n' "$lines"
    else
        # human-readable 形式
        printf '%s\n' "$lines" | jq -r "
            ( .timestamp | split(\"T\") | .[0] + \" \" + (.[1] | .[0:5]) ) as \$dt |
            ( if .response_ok then \"OK\" else \"ERROR\" + (if .error then \": \" + .error else \"\" end) end ) as \$result |
            ( if .duration_ms != null then (.duration_ms / 1000 | . * 10 | round / 10 | tostring) + \"s\" else \"?s\" end ) as \$dur |
            ( .identifiers | to_entries | map(.key + \":\" + .value) | join(\" \") ) as \$ids |
            \$dt + \" — \" + .action + \" (\" + (.subcommand | ascii_upcase) + \")\" + (if \$ids != \"\" then \" \" + \$ids else \"\" end) + \" → \" + \$result + \", \" + \$dur
        " 2>/dev/null
    fi
}

# ========================================
# 5. _ccskill_history_clear
#    $@: --yes フラグが必須
# ========================================

_ccskill_history_clear() {
    local yes_flag=false
    for arg in "$@"; do
        if [ "$arg" = "--yes" ]; then
            yes_flag=true
        fi
    done

    if [ "$yes_flag" != true ]; then
        printf 'Error: --yes flag is required to clear history. Use: ccskill-gmail history clear --yes\n' >&2
        return 1
    fi

    local dir="${CCSKILL_HISTORY_DIR:-}"
    if [ -z "$dir" ]; then
        printf 'Error: CCSKILL_HISTORY_DIR is not set\n' >&2
        return 1
    fi

    rm -f "${dir}/audit.jsonl" "${dir}/audit.jsonl.1"
    printf 'History cleared.\n'
}
