# Read API

Retrieves email details and label lists.

---

## get_thread - Get Thread

Retrieves all messages in a thread by specifying the thread ID.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID |

### Example

```bash
.ccskill-gmail/api get action=get_thread threadId=19bf7f25b96ab637
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "id": "19bf7f25b96ab637",
    "subject": "Meeting Tomorrow",
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
        "subject": "Meeting Tomorrow",
        "body": "Hi,\n\nRegarding tomorrow's meeting...",
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

## get_message - Get Message Details

Retrieves details of a single message by specifying the message ID.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID |

### Example

```bash
.ccskill-gmail/api get action=get_message messageId=19bf7f25b96ab637
```

### Response Example

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
    "subject": "Meeting Tomorrow",
    "body": "Hi,\n\nRegarding tomorrow's meeting...",
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

## list_labels - List Labels

Retrieves a list of user-created labels.

### Request

**Method**: GET

**Parameters**: None

### Example

```bash
.ccskill-gmail/api get action=list_labels
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "count": 5,
    "labels": [
      {"name": "Projects", "unreadCount": 3},
      {"name": "Projects/Important", "unreadCount": 1},
      {"name": "Purchasing", "unreadCount": 0},
      {"name": "Interviews", "unreadCount": 2},
      {"name": "Writing", "unreadCount": 0}
    ]
  }
}
```

**Note**: System labels (INBOX, SENT, DRAFT, etc.) are not included. Only user-created labels are returned.

---

## get_unread_count - Get Unread Count

Retrieves the unread email count for the inbox or a specific label.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| label | | Label name (defaults to INBOX if omitted) |

### Example

```bash
# Inbox unread count
.ccskill-gmail/api get action=get_unread_count

# Unread count for a specific label
.ccskill-gmail/api get action=get_unread_count label="Important"
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "label": "INBOX",
    "unreadCount": 15,
    "message": "15 unread email(s)"
  }
}
```

### Error Example

When a non-existent label is specified:

```json
{
  "ok": false,
  "error": "Label not found: NonExistentLabel"
}
```

---

## list_attachments - List Attachments

Retrieves the list of attachments for a message. Use this to check sizes before calling `get_attachment`.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID |

### Example

```bash
.ccskill-gmail/api get action=list_attachments messageId=19bf7f25b96ab637
```

### Response Example

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

An empty array is returned if there are no attachments.

---

## get_attachment - Get Attachment

Retrieves the content of an attachment as base64-encoded data. Returns an error for files over 5MB.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID |
| attachmentIndex | ✓ | Attachment index (0-based) |

### Example

```bash
# Get an attachment and save locally (recommended: download subcommand)
.ccskill-gmail/api download 19bf7f25b96ab637 0 /tmp/report.pdf
```

### Response Example

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

### Error Examples

When the index is out of range:

```json
{
  "ok": false,
  "error": "Attachment index out of range: 2 (message has 1 attachment(s))"
}
```

When the file exceeds the size limit:

```json
{
  "ok": false,
  "error": "Attachment too large: bigfile.zip (7.3MB). Maximum supported size is 5MB."
}
```

---

## get_message_html - Get Message HTML

Retrieves the email body as complete HTML. Used for PDF conversion or browser display.

### Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID |
| includeHeaders | | Whether to include header information in the HTML (default: true) |

### Example

```bash
# Save as HTML (recommended: save-html subcommand)
.ccskill-gmail/api save-html 19bf7f25b96ab637 /tmp/email.html

# Save without headers
.ccskill-gmail/api save-html 19bf7f25b96ab637 /tmp/email.html false
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "messageId": "19bf7f25b96ab637",
    "subject": "Meeting Tomorrow",
    "from": "sender@example.com",
    "to": "me@gmail.com",
    "date": "2024-01-15T10:30:00.000Z",
    "html": "<div style=\"font-family: sans-serif; ...\">...</div><html>...</html>"
  }
}
```

### PDF Conversion Procedure

The `save-pdf` subcommand performs HTML retrieval and PDF conversion in a single step.

```bash
# Recommended: One-step processing with save-pdf
.ccskill-gmail/api save-pdf 19bf7f25b96ab637 ./email.pdf
```

It auto-detects Chrome headless / wkhtmltopdf internally. If no tool is available, it saves the HTML and returns a guidance message.

---

## get_profile - Get Profile Information

Retrieves the account email address and unread count summary.

### Request

**Method**: GET

**Parameters**: None

### Example

```bash
.ccskill-gmail/api get action=get_profile
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "email": "user@gmail.com",
    "inboxUnreadCount": 15,
    "starredUnreadCount": 3
  }
}
```

- `email`: Account email address
- `inboxUnreadCount`: Inbox unread email count
- `starredUnreadCount`: Starred unread email count
