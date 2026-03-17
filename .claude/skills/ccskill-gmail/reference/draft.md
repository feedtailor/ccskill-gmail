# list_drafts - 下書き一覧取得

下書きの一覧を軽量な形式で取得します。

## リクエスト

**メソッド**: GET

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| maxResults | | 最大取得件数（デフォルト 20, 上限 100） |

---

## 実行例

```bash
# 下書き一覧（デフォルト 20 件）
.ccskill-gmail/api get action=list_drafts

# 件数指定
.ccskill-gmail/api get action=list_drafts maxResults=50
```

---

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "total": 5,
    "count": 5,
    "drafts": [
      {
        "draftId": "r-935971606264660525",
        "subject": "お見積りの件",
        "to": "recipient@example.com",
        "snippet": "お世話になっております。添付の通りお見積りをお送りします。よろしくお願いいたし...",
        "lastDate": "2024-01-15T10:30:00.000Z"
      }
    ]
  }
}
```

- `total`: 全下書き件数
- `count`: 今回返した件数（maxResults で制限された場合は total と異なる）
- `snippet`: 本文の先頭 100 文字（プレーンテキスト）

---

# create_draft - 新規メールの下書き作成

新しいメールの下書きを作成します。既存スレッドへの返信は `create_reply_draft` を使用してください。

## 設計思想

**送信機能は意図的に含めていません。**

- 誤送信防止: AI が直接送信すると取り消し不可
- 確認フロー: 人間が Gmail UI で内容確認 → 送信
- 責任の明確化: 送信は人間の意思決定

下書きは Gmail の「下書き」フォルダに保存され、ブラウザや Gmail アプリで確認・編集・送信できます。

---

## リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| to | ✓ | 宛先メールアドレス（カンマ区切りで複数可） |
| subject | ✓ | 件名 |
| body | ✓ | 本文（プレーンテキスト。htmlBody 指定時はフォールバック用） |
| cc | | CC（カンマ区切りで複数可） |
| bcc | | BCC（カンマ区切りで複数可） |
| htmlBody | | HTML 本文（指定時は body がプレーンテキストフォールバックになる） |
| attachments | | 添付ファイル配列（詳細は下記参照） |

### attachments の形式

```json
[
  {
    "filename": "report.pdf",
    "contentType": "application/pdf",
    "content": "<base64エンコードされたファイル内容>"
  }
]
```

- `filename` (必須): ファイル名
- `content` (必須): base64 エンコードされたファイルデータ
- `contentType` (任意): MIME タイプ（省略時は `application/octet-stream`）
- 合計サイズ上限: 5MB（base64 デコード後のサイズ）

---

## 実行例

### 基本的な下書き

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"recipient@example.com","subject":"お見積りの件","body":"お世話になっております。\n\n添付の通りお見積りをお送りします。\n\nよろしくお願いいたします。"}'
```

### CC/BCC 付き

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"client@example.com","cc":"manager@example.com","bcc":"archive@example.com","subject":"プロジェクト進捗報告","body":"お疲れ様です。\n\n進捗をご報告します。"}'
```

### 複数宛先

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"user1@example.com,user2@example.com","subject":"チームミーティングのお知らせ","body":"明日10時からミーティングを行います。"}'
```

### HTML メール

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"recipient@example.com","subject":"月次レポート","body":"月次レポートを送ります。","htmlBody":"<h1>月次レポート</h1><p>詳細は以下の通りです。</p>"}'
```

### 添付ファイル付き

Write ツールで JSON ファイルを作成してから送信:

```bash
.ccskill-gmail/api post @/tmp/draft-with-attachment.json
```

---

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "draftId": "r-935971606264660525",
    "to": "recipient@example.com",
    "subject": "お見積りの件",
    "message": "下書きを作成しました。Gmail で確認・送信してください。",
    "gmailUrl": "https://mail.google.com/mail/u/0/#drafts"
  }
}
```

---

## 下書きの確認・送信

1. Gmail を開く: https://mail.google.com/mail/u/0/#drafts
2. 下書き一覧から該当メールを選択
3. 内容を確認・編集
4. 「送信」ボタンをクリック

---

---

# create_reply_draft - 返信下書き作成

既存のスレッドに対する返信の下書きを作成します。

## リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| threadId | ✓ | 返信先スレッドの ID |
| body | ✓ | 返信本文（プレーンテキスト。htmlBody 指定時はフォールバック用） |
| cc | | CC（カンマ区切りで複数可） |
| bcc | | BCC（カンマ区切りで複数可） |
| htmlBody | | HTML 本文（指定時は body がプレーンテキストフォールバックになる） |
| attachments | | 添付ファイル配列（形式は create_draft と同じ） |
| skipSelf | | 自分の送信メッセージをスキップして相手のメッセージに返信する（デフォルト `true`） |
| replyAll | | 全員に返信する — 元メッセージの to/cc を自動保持（デフォルト `true`） |

---

## 実行例

### 基本的な返信下書き

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ご連絡ありがとうございます。\n\n承知いたしました。"}'
```

### CC 付き返信

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"確認しました。","cc":"manager@example.com"}'
```

### HTML 返信

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ありがとうございます。","htmlBody":"<p>ありがとうございます。<br>承知いたしました。</p>"}'
```

---

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "draftId": "r-123456789",
    "threadId": "19bf7f25b96ab637",
    "to": "original-sender@example.com",
    "subject": "Re: 元の件名",
    "skipSelf": true,
    "replyAll": true,
    "message": "返信下書きを作成しました。Gmail で確認・送信してください。",
    "gmailUrl": "https://mail.google.com/mail/u/0/#drafts"
  }
}
```

---

## 動作詳細

- **skipSelf（デフォルト true）**: スレッド内メッセージを新しい順に遡り、自分以外が送信したメッセージを返信対象にする。全メッセージが自分の場合は最後のメッセージにフォールバック
- **replyAll（デフォルト true）**: 元メッセージの to/cc を自動保持した「全員に返信」で下書きを作成
- 件名は自動的に「Re: 元の件名」形式に設定
- 宛先は実際の下書き宛先（`draft.getMessage().getTo()`）を返す

---

# update_draft - 下書き更新

既存の下書きを更新します。

## リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| draftId | ✓ | 更新する下書きの ID |
| to | | 新しい宛先（**新規下書きのみ有効。返信下書きでは無視される**） |
| subject | | 新しい件名（省略時は現在の値を維持） |
| body | | 新しい本文（省略時は現在の値を維持） |
| cc | | 新しい CC |
| bcc | | 新しい BCC |
| htmlBody | | 新しい HTML 本文（省略時は既存の HTML を維持） |

## 実行例

```bash
.ccskill-gmail/api post '{"action":"update_draft","draftId":"r-123456789","subject":"【更新】お見積りの件"}'
```

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "draftId": "r-987654321",
    "oldDraftId": "r-123456789",
    "threadId": "19bf7f25b96ab637",
    "isReply": true,
    "action": "update_draft",
    "message": "下書きを更新しました",
    "gmailUrl": "https://mail.google.com/mail/u/0/#drafts"
  }
}
```

- `threadId`: 下書きが属するスレッドの ID
- `isReply`: 返信下書きとして再作成された場合 `true`

## 注意事項

- GmailApp は下書きの直接編集をサポートしていないため、内部的には「削除→再作成」で実装
- そのため **draftId が変更されます**（レスポンスで新しい ID を確認してください）
- 返信下書きの場合、スレッドとの紐付けを維持して再作成します（`isReply: true` で判別可能）
- **返信下書きの to（宛先）は変更できません**（GmailApp API の制約）。cc / bcc / body / subject は変更可能です。宛先を変更したい場合は、Gmail UI の下書き確認時に手動で変更してください
- **update_draft では添付ファイル（attachments）の更新は未対応です。** 添付を変更する場合は delete_draft → create_draft で再作成してください

---

# delete_draft - 下書き削除

下書きを削除します。

## リクエスト

**メソッド**: POST

**パラメータ**:

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| draftId | ✓ | 削除する下書きの ID |

## 実行例

```bash
.ccskill-gmail/api post '{"action":"delete_draft","draftId":"r-123456789"}'
```

## レスポンス例

```json
{
  "ok": true,
  "data": {
    "draftId": "r-123456789",
    "action": "delete_draft",
    "message": "下書きを削除しました"
  }
}
```

## エラー例

存在しない draftId を指定した場合：

```json
{
  "ok": false,
  "error": "Draft not found: r-invalid"
}
```
