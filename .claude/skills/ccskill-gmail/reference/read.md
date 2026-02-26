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

### 実行例

```bash
ccskill-get "$GMAIL_ENDPOINT" action=get_thread threadId=19bf7f25b96ab637
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

### 実行例

```bash
ccskill-get "$GMAIL_ENDPOINT" action=get_message messageId=19bf7f25b96ab637
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

### 実行例

```bash
ccskill-get "$GMAIL_ENDPOINT" action=list_labels
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

### 実行例

```bash
# 受信トレイの未読数
ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count

# 特定ラベルの未読数
ccskill-get "$GMAIL_ENDPOINT" action=get_unread_count label="重要"
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

---

## list_attachments - 添付ファイル一覧

メッセージの添付ファイル一覧を取得します。`get_attachment` の前にサイズ確認に使用します。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| messageId | ✓ | メッセージ ID |

### 実行例

```bash
ccskill-get "$GMAIL_ENDPOINT" action=list_attachments messageId=19bf7f25b96ab637
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "messageId": "19bf7f25b96ab637",
    "attachments": [
      {
        "index": 0,
        "filename": "report.pdf",
        "contentType": "application/pdf",
        "size": 123456
      },
      {
        "index": 1,
        "filename": "data.xlsx",
        "contentType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "size": 45678
      }
    ]
  }
}
```

添付ファイルがない場合は空配列が返されます。

---

## get_attachment - 添付ファイル取得

添付ファイルの内容を base64 エンコードで取得します。5MB 超のファイルはエラーになります。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| messageId | ✓ | メッセージ ID |
| attachmentIndex | ✓ | 添付ファイルのインデックス（0始まり） |

### 実行例

```bash
# 添付ファイルを取得してローカルに保存（推奨: ccskill-download ヘルパー）
ccskill-download "$GMAIL_ENDPOINT" 19bf7f25b96ab637 0 /tmp/report.pdf

# 直接 API を使う場合
ccskill-get "$GMAIL_ENDPOINT" action=get_attachment messageId=19bf7f25b96ab637 attachmentIndex=0 | jq -r '.data.content' | base64 -d > /tmp/report.pdf
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "filename": "report.pdf",
    "contentType": "application/pdf",
    "size": 123456,
    "content": "JVBERi0xLjQKMS..."
  }
}
```

### エラー例

インデックスが範囲外の場合：

```json
{
  "ok": false,
  "error": "Attachment index out of range: 2 (message has 1 attachment(s))"
}
```

サイズ超過の場合：

```json
{
  "ok": false,
  "error": "Attachment too large: bigfile.zip (7.3MB). Maximum supported size is 5MB."
}
```

---

## get_message_html - メール本文 HTML 取得

メール本文を完全な HTML として取得します。PDF 化やブラウザ表示に使用します。

### リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| messageId | ✓ | メッセージ ID |
| includeHeaders | | ヘッダー情報を HTML に含めるか（デフォルト: true） |

### 実行例

```bash
# HTML を保存（推奨: ccskill-save-html ヘルパー）
ccskill-save-html "$GMAIL_ENDPOINT" 19bf7f25b96ab637 /tmp/email.html

# ヘッダーなしで保存
ccskill-save-html "$GMAIL_ENDPOINT" 19bf7f25b96ab637 /tmp/email.html false

# 直接 API を使う場合
ccskill-get "$GMAIL_ENDPOINT" action=get_message_html messageId=19bf7f25b96ab637 | jq -r '.data.html' > /tmp/email.html
```

### レスポンス例

```json
{
  "ok": true,
  "data": {
    "messageId": "19bf7f25b96ab637",
    "subject": "ミーティングの件",
    "from": "sender@example.com",
    "to": "me@gmail.com",
    "date": "2024-01-15T10:30:00.000Z",
    "html": "<div style=\"font-family: sans-serif; ...\">...</div><html>...</html>"
  }
}
```

### PDF 化の手順

HTML を取得後、ローカルツールで PDF に変換します。

```bash
# wkhtmltopdf の場合
wkhtmltopdf /tmp/email.html /tmp/email.pdf

# Chrome headless の場合
google-chrome --headless --print-to-pdf=/tmp/email.pdf /tmp/email.html
```

PDF 変換ツールがない場合は、ユーザーに以下を案内してください：

```
PDF 変換ツールが見つかりませんでした。
HTML ファイルを保存しました: /tmp/email.html

PDF として保存するには:
1. ブラウザで上記ファイルを開く
2. Cmd+P（印刷）> 「PDF として保存」を選択
```
