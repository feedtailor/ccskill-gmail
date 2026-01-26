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
Claude Code (Skill) ◄── curl/JSON API ──► GAS Web App (standalone) ──► Gmail (GmailApp)
```

ccskill-spreadsheet と同じアーキテクチャパターンを採用。

## ディレクトリ構成

```
ccskill-gmail/
├── install.sh / update.sh / uninstall.sh   # シェルスクリプト
├── gas-template/
│   ├── appsscript.json      # GAS マニフェスト
│   ├── config.js.template   # 設定テンプレート
│   ├── main.js              # エントリポイント（ルーティング）
│   ├── handlers/            # API ハンドラ（search, read, draft, label）
│   └── utils/               # ユーティリティ（response, gmail）
└── .claude/skills/ccskill-gmail/
    ├── SKILL.md             # Skill 定義
    ├── troubleshooting.md
    └── examples.md
```

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
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/script.external_request"
  ]
}
```

## 実装優先度

1. **Phase 1 (MVP)**: search, get_thread, get_message, list_labels, create_draft
2. **Phase 2**: create_reply_draft, mark_read/unread, add/remove_label
3. **Phase 3**: archive, move_to_trash, get_unread_count, update/delete_draft
