# search - メール検索

Gmail の検索構文を使用してメールを検索します。

## リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| query | ✓ | Gmail 検索クエリ |
| maxResults | | 最大取得件数 (デフォルト: 20, 最大: 500) |

## 実行例

```bash
# 未読メール
ccskill-get "$GMAIL_ENDPOINT" action=search query="is:unread"

# 特定の送信者から（最新10件）
ccskill-get "$GMAIL_ENDPOINT" action=search query="from:boss@company.com" maxResults=10

# 日本語を含むクエリ（ccskill-get が自動エンコード）
ccskill-get "$GMAIL_ENDPOINT" action=search query="subject:請求書"
```

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "query": "is:unread",
    "resultCount": 3,
    "threads": [
      {
        "id": "19bf7f25b96ab637",
        "subject": "ミーティングの件",
        "from": "sender@example.com",
        "date": "2024-01-15T10:30:00.000Z",
        "messageCount": 3,
        "isUnread": true,
        "isImportant": true,
        "isInInbox": true,
        "labels": ["INBOX", "重要"]
      }
    ]
  }
}
```

## Gmail 検索演算子

| 演算子 | 説明 | 例 |
|--------|------|-----|
| is:unread | 未読メール | `is:unread` |
| is:starred | スター付き | `is:starred` |
| from: | 送信者 | `from:example@gmail.com` |
| to: | 宛先 | `to:me@gmail.com` |
| subject: | 件名 | `subject:請求書` |
| has:attachment | 添付ファイル付き | `has:attachment` |
| after: | 日付以降 | `after:2024/01/01` |
| before: | 日付以前 | `before:2024/02/01` |
| label: | ラベル | `label:重要` |
| in:inbox | 受信トレイ | `in:inbox` |
| in:sent | 送信済み | `in:sent` |

複数の条件はスペースで区切って AND 検索：
```
is:unread from:boss@company.com has:attachment
```
