# list_drafts - List Drafts

Retrieves a list of drafts in a lightweight format.

## Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| maxResults | | Maximum number of results (default 20, max 100) |

---

## Example

```bash
# List drafts (default 20 items)
.ccskill-gmail/api get action=list_drafts

# Specify count
.ccskill-gmail/api get action=list_drafts maxResults=50
```

---

## Response Example

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

- `total`: Total number of drafts
- `count`: Number of drafts returned in this response (differs from total when limited by maxResults)
- `snippet`: First 100 characters of the body (plain text)

---

# create_draft - Create a New Email Draft

Creates a new email draft. For replies to existing threads, use `create_reply_draft`.

## Design Philosophy

**Send functionality is intentionally excluded.**

- Prevent accidental sends: Once AI sends directly, it cannot be undone
- Review flow: Human reviews content in Gmail UI -> sends
- Clear responsibility: Sending is a human decision

Drafts are saved in Gmail's "Drafts" folder and can be reviewed, edited, and sent via browser or the Gmail app.

---

## Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| to | ✓ | Recipient email address (comma-separated for multiple) |
| subject | ✓ | Subject |
| body | ✓ | Body (plain text; used as fallback when htmlBody is specified) |
| cc | | CC (comma-separated for multiple) |
| bcc | | BCC (comma-separated for multiple) |
| htmlBody | | HTML body (when specified, body becomes the plain text fallback) |
| attachments | | Attachment array (see details below) |

### attachments Format

```json
[
  {
    "filename": "report.pdf",
    "contentType": "application/pdf",
    "content": "<base64-encoded file content>"
  }
]
```

- `filename` (required): File name
- `content` (required): Base64-encoded file data
- `contentType` (optional): MIME type (defaults to `application/octet-stream` if omitted)
- Total size limit: 5MB (size after base64 decoding)

---

## Examples

### Basic Draft

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"recipient@example.com","subject":"お見積りの件","body":"お世話になっております。\n\n添付の通りお見積りをお送りします。\n\nよろしくお願いいたします。"}'
```

### With CC/BCC

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"client@example.com","cc":"manager@example.com","bcc":"archive@example.com","subject":"プロジェクト進捗報告","body":"お疲れ様です。\n\n進捗をご報告します。"}'
```

### Multiple Recipients

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"user1@example.com,user2@example.com","subject":"チームミーティングのお知らせ","body":"明日10時からミーティングを行います。"}'
```

### HTML Email

```bash
.ccskill-gmail/api post '{"action":"create_draft","to":"recipient@example.com","subject":"月次レポート","body":"月次レポートを送ります。","htmlBody":"<h1>月次レポート</h1><p>詳細は以下の通りです。</p>"}'
```

### With Attachments

Create a JSON file with the Write tool, then send:

```bash
.ccskill-gmail/api post @/tmp/draft-with-attachment.json
```

---

## Response Example

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

## Reviewing and Sending Drafts

1. Open Gmail: https://mail.google.com/mail/u/0/#drafts
2. Select the draft from the drafts list
3. Review and edit the content
4. Click "Send"

---

---

# create_reply_draft - Create a Reply Draft

Creates a reply draft to an existing thread.

## Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to reply to |
| body | ✓ | Reply body (plain text; used as fallback when htmlBody is specified) |
| cc | | CC (comma-separated for multiple) |
| bcc | | BCC (comma-separated for multiple) |
| htmlBody | | HTML body (when specified, body becomes the plain text fallback) |
| attachments | | Attachment array (same format as create_draft) |
| skipSelf | | Skip your own sent messages and reply to the other party's message (default `true`) |
| replyAll | | Reply to all -- auto-preserves original message's to/cc (default `true`) |

---

## Examples

### Basic Reply Draft

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ご連絡ありがとうございます。\n\n承知いたしました。"}'
```

### Reply with CC

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"確認しました。","cc":"manager@example.com"}'
```

### HTML Reply

```bash
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"19bf7f25b96ab637","body":"ありがとうございます。","htmlBody":"<p>ありがとうございます。<br>承知いたしました。</p>"}'
```

---

## Response Example

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

## Behavior Details

- **skipSelf (default true)**: Traverses messages in the thread from newest to oldest and selects the first message not sent by you as the reply target. Falls back to the last message if all messages are from you
- **replyAll (default true)**: Creates a "reply all" draft that auto-preserves the original message's to/cc
- The subject is automatically set to "Re: original subject" format
- The recipient returned is the actual draft recipient (`draft.getMessage().getTo()`)

---

# update_draft - Update a Draft

Updates an existing draft.

## Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| draftId | ✓ | Draft ID to update |
| to | | New recipient (**only effective for new drafts; ignored for reply drafts**) |
| subject | | New subject (retains current value if omitted) |
| body | | New body (retains current value if omitted) |
| cc | | New CC |
| bcc | | New BCC |
| htmlBody | | New HTML body (retains existing HTML if omitted) |

## Example

```bash
.ccskill-gmail/api post '{"action":"update_draft","draftId":"r-123456789","subject":"【更新】お見積りの件"}'
```

## Response Example

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

- `threadId`: Thread ID the draft belongs to
- `isReply`: `true` if recreated as a reply draft

## Notes

- GmailApp does not support direct editing of drafts, so internally this is implemented as "delete -> recreate"
- Therefore, **the draftId will change** (check the new ID in the response)
- For reply drafts, the thread association is preserved during recreation (identifiable by `isReply: true`)
- **The to (recipient) of a reply draft cannot be changed** (GmailApp API limitation). cc / bcc / body / subject can be changed. To change the recipient, manually modify it when reviewing the draft in the Gmail UI
- **update_draft does not support updating attachments.** To change attachments, use delete_draft -> create_draft to recreate the draft

---

# delete_draft - Delete a Draft

Deletes a draft.

## Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| draftId | ✓ | Draft ID to delete |

## Example

```bash
.ccskill-gmail/api post '{"action":"delete_draft","draftId":"r-123456789"}'
```

## Response Example

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

## Error Example

When a non-existent draftId is specified:

```json
{
  "ok": false,
  "error": "Draft not found: r-invalid"
}
```
