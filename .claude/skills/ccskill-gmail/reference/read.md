# 読み取り API

メールの詳細取得とラベル一覧を取得します。

---

## get_thread - スレッド取得

スレッド ID を指定して、スレッド内の全メッセージを取得します。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | スレッド ID |

### リクエスト例

```bash
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_thread&threadId=19bf7f25b96ab637"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "id": "19bf7f25b96ab637",
    "subject": "ミーティングの件",
    "messageCount": 2,
    "isUnread": true,
    "labels": ["INBOX"],
    "messages": [
      {
        "id": "19bf7f25b96ab637",
        "threadId": "19bf7f25b96ab637",
        "from": "sender@example.com",
        "to": "me@gmail.com",
        "cc": "",
        "subject": "ミーティングの件",
        "body": "お世話になっております。\n\n明日のミーティングについて...",
        "htmlBody": "<html>...</html>",
        "date": "2024-01-15T10:30:00.000Z",
        "isUnread": true,
        "attachments": []
      }
    ]
  }
}
```

---

## get_message - メッセージ詳細

メッセージ ID を指定して、単一メッセージの詳細を取得します。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| messageId | ✓ | メッセージ ID |

### リクエスト例

```bash
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_message&messageId=19bf7f25b96ab637"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "id": "19bf7f25b96ab637",
    "threadId": "19bf7f25b96ab637",
    "from": "sender@example.com",
    "to": "me@gmail.com",
    "cc": "cc@example.com",
    "bcc": "",
    "replyTo": "sender@example.com",
    "subject": "ミーティングの件",
    "body": "お世話になっております。\n\n明日のミーティングについて...",
    "htmlBody": "<html>...</html>",
    "date": "2024-01-15T10:30:00.000Z",
    "isUnread": true,
    "isStarred": false,
    "isDraft": false,
    "attachments": [
      {
        "name": "document.pdf",
        "contentType": "application/pdf",
        "size": 102400
      }
    ]
  }
}
```

---

## list_labels - ラベル一覧

ユーザーが作成したラベルの一覧を取得します。

### リクエスト

**メソッド**: GET

**パラメータ**: なし

### リクエスト例

```bash
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=list_labels"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "count": 5,
    "labels": [
      {"name": "Projects", "unreadCount": 3},
      {"name": "Projects/重要", "unreadCount": 1},
      {"name": "Purchasing", "unreadCount": 0},
      {"name": "取材", "unreadCount": 2},
      {"name": "執筆", "unreadCount": 0}
    ]
  }
}
```

**備考**: システムラベル（INBOX, SENT, DRAFT など）は含まれません。ユーザーが作成したラベルのみ返されます。

---

## get_unread_count - 未読メール数取得

受信トレイまたは特定ラベルの未読メール数を取得します。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| label | | ラベル名（省略時は INBOX） |

### リクエスト例

```bash
# 受信トレイの未読数
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count"

# 特定ラベルの未読数
curl -sL --max-time 60 "$GMAIL_ENDPOINT?action=get_unread_count&label=重要"
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "label": "INBOX",
    "unreadCount": 15,
    "message": "未読メールが 15 件あります"
  }
}
```

### エラー例

存在しないラベルを指定した場合：

```json
{
  "ok": false,
  "error": "Label not found: 存在しないラベル"
}
```
