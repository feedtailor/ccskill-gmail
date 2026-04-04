# search - Email Search

Searches emails using Gmail search syntax.

## Request

**Method**: GET

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| query | ✓ | Gmail search query |
| maxResults | | Maximum number of results (default: 20, max: 500) |

## Examples

```bash
# Unread emails
.ccskill-gmail/api get action=search query="is:unread"

# From a specific sender (latest 10)
.ccskill-gmail/api get action=search query="from:boss@company.com" maxResults=10

# Query containing Japanese (get subcommand auto-encodes)
.ccskill-gmail/api get action=search query="subject:請求書"
```

## Response Example

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

## Gmail Search Operators

| Operator | Description | Example |
|----------|-------------|---------|
| is:unread | Unread emails | `is:unread` |
| is:starred | Starred emails | `is:starred` |
| from: | Sender | `from:example@gmail.com` |
| to: | Recipient | `to:me@gmail.com` |
| subject: | Subject | `subject:請求書` |
| has:attachment | Has attachments | `has:attachment` |
| after: | After date | `after:2024/01/01` |
| before: | Before date | `before:2024/02/01` |
| label: | Label | `label:重要` |
| in:inbox | In inbox | `in:inbox` |
| in:sent | In sent | `in:sent` |

Multiple conditions are space-separated for AND search:
```
is:unread from:boss@company.com has:attachment
```
