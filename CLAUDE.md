# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

ccskill-gmail は Claude Code 用の Gmail スキル。GAS (Google Apps Script) Web App を通じて Gmail を操作する。

**設計原則**:
- 読み取り中心（検索・閲覧に特化）
- 下書き作成まで（送信は人間が確認してから行う）
- 永久削除 API は提供しない

## アーキテクチャ

```
Claude Code (Skill)
  ↓ .ccskill-gmail/api get|post|download|save-html|save-pdf
  ↓ (Bearer OAuth token 自動付与)
GAS Web App (standalone, MYSELF access)
  ↓
Gmail (GmailApp)
```

ccskill-spreadsheet と同じアーキテクチャパターンを採用。

## ディレクトリ構成

```
ccskill-gmail/
├── ccskill-gmail              # メインコマンド（ディスパッチャ）
├── commands/                   # サブコマンド
│   ├── install.sh
│   ├── uninstall.sh
│   ├── update.sh
│   ├── update-all.sh
│   ├── apply-config.sh
│   ├── register.sh
│   └── status.sh
├── lib/                        # 共通ライブラリ
│   ├── auth.sh                # OAuth 認証（gas_token）
│   ├── api                    # API スタンドアロンスクリプト（get/post/download/save-html/save-pdf）
│   ├── push-gas.sh            # GAS push/deploy
│   ├── registry.sh            # レジストリ管理
│   └── permissions.sh         # パーミッション設定
├── gas-template/               # GAS ソースコード
│   ├── appsscript.json
│   ├── config.js.template
│   ├── main.js
│   ├── handlers/
│   └── utils/
└── .claude/skills/ccskill-gmail/  # スキル定義のマスターソース
    ├── SKILL.md                   # install/update 時にインストール先の
    ├── troubleshooting.md         # .claude/skills/ccskill-gmail/ へコピーされる
    ├── examples.md
    └── reference/
```

## セキュリティ設計判断

不採用にした対策とその理由は `docs/security-decisions.md` を参照。

## API 設計

### GET（読み取り）
- `search` - メール検索（Gmail 検索構文使用）
- `get_thread` / `get_message` - スレッド/メッセージ取得
- `list_labels` / `get_unread_count`

### POST（書き込み）
- `create_draft` / `create_reply_draft` - 下書き作成
- `update_draft` / `delete_draft`
- `add_label` / `remove_label` / `mark_read` / `mark_unread`
- `archive` / `move_to_trash`

## GAS スコープ

```json
{
  "oauthScopes": [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/gmail.modify"
  ]
}
```

※ `script.external_request` は不要のため削除済み

## 開発コマンド

```bash
# インストール
ccskill-gmail install [NAME] [DIR]

# 更新
ccskill-gmail update [--force] [--yes] [DIR]

# 一括更新
ccskill-gmail update-all

# ステータス確認
ccskill-gmail status
```

## テスト手順

GAS コードを変更したら、必ずデプロイして実機テストすること。

```bash
# 1. テスト用プロジェクト（ftgmail）にデプロイ
cd ~/projects/ftgmail
~/projects/ccskill-gmail/ccskill-gmail update --force --yes .

# 2. テスト用プロジェクトに cd してからテスト実行
cd ~/projects/ftgmail
.ccskill-gmail/api get action=...
.ccskill-gmail/api post '{"action":...}'
```

**注意事項**:
- テストは必ず対象プロジェクトに `cd` してから行う（`.ccskill-gmail/api` がカレントディレクトリ依存）
- デプロイは `ccskill-gmail update` を使う（`push_gas` を直接呼ばない）
- Bash ツールでは `$()` を避けてパイプで繋ぐ（`$()` は sandbox の確認プロンプトを発生させる）
- curl の exit code 56 やレスポンスが HTML の場合、まず OAuth トークン期限切れを疑う（`auth.sh` の `gas_token` が自動リフレッシュする仕組みがある。sandbox でリフレッシュがブロックされる場合は sandbox 無効化が必要）

## コミットメッセージ規約

1行目は `type: 概要 (#issue番号)` 形式とする。`ccskill-gmail update` 時の履歴表示でパースされるため、1行目は簡潔に。

- type: `feat` / `fix` / `docs` / `refactor` / `chore`

## コード規約

- シェルスクリプト: `cp` ではなく `/bin/cp` を使用（macOS alias 対策）
- 環境変数: `CCSKILL_GMAIL_DIR` はディスパッチャが設定
- lib/ の関数は副作用を最小限に（jq なしでも graceful degradation）
