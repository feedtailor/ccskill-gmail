# ccskill-gmail 設計アイデア

Claude Code 用 Gmail スキルの設計案。ccskill-spreadsheet と同じアーキテクチャで実装。

---

## コンセプト

- **読み取り中心**: メール検索・閲覧に特化
- **下書き作成まで**: 送信は人間が確認してから行う（安全設計）
- **GAS Web App**: curl 経由で JSON API を呼び出し

---

## アーキテクチャ

```
┌─────────────────┐      curl        ┌─────────────────┐
│   Claude Code   │ ◄──────────────► │   GAS Web App   │
│   (Skill使用)   │   JSON API       │  (standalone)   │
└─────────────────┘                  └────────┬────────┘
                                              │
                                              ▼
                                     ┌─────────────────┐
                                     │      Gmail      │
                                     │   (GmailApp)    │
                                     └─────────────────┘
```

---

## API 一覧

### 読み取り系（GET）

| API | 説明 | パラメータ |
|-----|------|-----------|
| `search` | メール検索 | `query`, `maxResults` |
| `get_thread` | スレッド取得 | `threadId` |
| `get_message` | メッセージ詳細 | `messageId` |
| `list_labels` | ラベル一覧 | - |
| `get_unread_count` | 未読数取得 | `label` (optional) |

### 書き込み系（POST）

| API | 説明 | パラメータ |
|-----|------|-----------|
| `create_draft` | 下書き作成 | `to`, `subject`, `body`, `cc`, `bcc` |
| `create_reply_draft` | 返信下書き作成 | `threadId`, `body` |
| `update_draft` | 下書き更新 | `draftId`, `to`, `subject`, `body` |
| `delete_draft` | 下書き削除 | `draftId` |

### 操作系（POST）

| API | 説明 | パラメータ |
|-----|------|-----------|
| `add_label` | ラベル付与 | `messageId`, `label` |
| `remove_label` | ラベル削除 | `messageId`, `label` |
| `mark_read` | 既読にする | `messageId` or `threadId` |
| `mark_unread` | 未読にする | `messageId` or `threadId` |
| `archive` | アーカイブ | `threadId` |
| `move_to_trash` | ゴミ箱へ | `threadId` |

---

## 検索クエリ例

Gmail の検索構文をそのまま使用：

```bash
# 未読メール
?action=search&query=is:unread

# 特定の送信者から
?action=search&query=from:example@gmail.com

# 件名に含む
?action=search&query=subject:請求書

# 日付指定
?action=search&query=after:2024/01/01 before:2024/02/01

# 添付ファイル付き
?action=search&query=has:attachment

# 複合条件
?action=search&query=is:unread from:boss@company.com
```

---

## レスポンス形式

### search

```json
{
  "ok": true,
  "data": {
    "threads": [
      {
        "id": "thread_abc123",
        "snippet": "お世話になっております。請求書を...",
        "subject": "【請求書】1月分",
        "from": "billing@example.com",
        "date": "2024-01-15T10:30:00.000Z",
        "messageCount": 3,
        "isUnread": true,
        "labels": ["INBOX", "重要"]
      }
    ],
    "resultCount": 25
  }
}
```

### get_message

```json
{
  "ok": true,
  "data": {
    "id": "msg_xyz789",
    "threadId": "thread_abc123",
    "from": "sender@example.com",
    "to": ["me@gmail.com"],
    "cc": [],
    "subject": "Re: ミーティングの件",
    "body": "メール本文...",
    "date": "2024-01-15T10:30:00.000Z",
    "attachments": [
      {
        "name": "document.pdf",
        "size": 102400,
        "mimeType": "application/pdf"
      }
    ]
  }
}
```

### create_draft

```json
{
  "ok": true,
  "data": {
    "draftId": "draft_123",
    "message": "下書きを作成しました。Gmailで確認・送信してください。",
    "gmailUrl": "https://mail.google.com/mail/u/0/#drafts"
  }
}
```

---

## ディレクトリ構成

```
ccskill-gmail/
├── CLAUDE.md                 # 開発ガイドライン
├── README.md                 # ユーザー向けドキュメント
├── install.sh                # インストールスクリプト
├── update.sh                 # 更新スクリプト
├── uninstall.sh              # アンインストールスクリプト
│
├── gas-template/
│   ├── appsscript.json       # GAS マニフェスト（Gmail スコープ）
│   ├── config.js.template    # 設定テンプレート
│   ├── main.js               # エントリポイント
│   ├── handlers/
│   │   ├── search.js         # 検索系
│   │   ├── read.js           # 読み取り系
│   │   ├── draft.js          # 下書き系
│   │   └── label.js          # ラベル操作系
│   └── utils/
│       ├── response.js       # レスポンス生成
│       └── gmail.js          # Gmail 操作ユーティリティ
│
└── .claude/
    └── skills/
        └── ccskill-gmail/
            ├── SKILL.md              # Skill 定義
            ├── troubleshooting.md    # トラブルシューティング
            └── examples.md           # ワークフロー例
```

---

## appsscript.json（スコープ設定）

```json
{
  "timeZone": "Asia/Tokyo",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.compose",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/script.external_request"
  ]
}
```

---

## ユースケース例

### 1. 未読メールの確認

```bash
# 未読メール一覧
curl -sL "$GMAIL_ENDPOINT?action=search&query=is:unread&maxResults=10"

# 特定のメールを読む
curl -sL "$GMAIL_ENDPOINT?action=get_message&messageId=msg_xyz"
```

### 2. 下書き作成

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{
    "action": "create_draft",
    "to": "client@example.com",
    "subject": "お見積りの件",
    "body": "お世話になっております。\n\n添付の通りお見積りをお送りします。\n\nよろしくお願いいたします。"
  }' "$GMAIL_ENDPOINT"
```

### 3. 返信下書き作成

```bash
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{
    "action": "create_reply_draft",
    "threadId": "thread_abc123",
    "body": "ご連絡ありがとうございます。\n\n承知いたしました。"
  }' "$GMAIL_ENDPOINT"
```

### 4. メール整理

```bash
# 既読にする
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"mark_read","threadId":"thread_abc"}' "$GMAIL_ENDPOINT"

# ラベル付与
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"add_label","messageId":"msg_xyz","label":"対応済"}' "$GMAIL_ENDPOINT"

# アーカイブ
curl -sL --max-time 60 \
  -H "Content-Type: application/json" \
  --data '{"action":"archive","threadId":"thread_abc"}' "$GMAIL_ENDPOINT"
```

---

## 安全設計のポイント

### 送信機能を含めない理由

1. **誤送信防止**: AI が直接送信すると取り消し不可
2. **確認フロー**: 人間が Gmail UI で内容確認→送信
3. **責任の明確化**: 送信は人間の意思決定

### 下書きで十分な理由

- 下書きに入れば Gmail アプリ/Web で確認可能
- 編集・修正が容易
- 送信タイミングを人間がコントロール

### その他の安全策

- `move_to_trash` は即時削除ではない（復元可能）
- 永久削除 API は提供しない
- 大量操作時は確認プロンプト推奨

---

## 実装優先度

### Phase 1（MVP）

- [ ] `search` - メール検索
- [ ] `get_thread` - スレッド取得
- [ ] `get_message` - メッセージ詳細
- [ ] `list_labels` - ラベル一覧
- [ ] `create_draft` - 下書き作成

### Phase 2

- [ ] `create_reply_draft` - 返信下書き
- [ ] `mark_read` / `mark_unread` - 既読/未読
- [ ] `add_label` / `remove_label` - ラベル操作

### Phase 3

- [ ] `archive` - アーカイブ
- [ ] `move_to_trash` - ゴミ箱移動
- [ ] `get_unread_count` - 未読数
- [ ] `update_draft` / `delete_draft` - 下書き編集

---

## 課題・検討事項

### 技術的課題

1. **本文の取得**: HTML / プレーンテキストの扱い
2. **添付ファイル**: ダウンロード機能は必要か？
3. **文字エンコード**: 日本語メールの扱い

### 運用上の課題

1. **レート制限**: Gmail API の制限（1日あたり）
2. **スコープ**: 最小限の権限で動作させる
3. **複数アカウント**: 対応するか？（Phase 2以降？）

---

## 参考リンク

- [GmailApp - Google Apps Script](https://developers.google.com/apps-script/reference/gmail/gmail-app)
- [Gmail API Scopes](https://developers.google.com/gmail/api/auth/scopes)
- [Gmail Search Operators](https://support.google.com/mail/answer/7190)

---

## メモ

- ccskill-spreadsheet のコードを流用できる部分が多い
- install.sh / update.sh はほぼそのまま使えそう
- main.js のルーティング構造も同じパターンで
