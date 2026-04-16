# star / unstar / mark_important / unmark_important - Markers

Markers for starring messages and flagging thread importance.

- **Star / unstar** operate on **individual messages** (`messageId`). Gmail's "Starred" view aggregates per-message stars.
- **Mark / unmark important** operate on **entire threads** (`threadId`). Importance is a thread-level flag in Gmail that feeds the Priority Inbox classifier; GmailApp does not expose message-level importance.

AI triage can use these to surface actionable items to the human reader.

---

## star - Star a Message

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID to star |

### Example

```bash
.ccskill-gmail/api post '{"action":"star","messageId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "messageId": "19bf7f25b96ab637",
    "action": "star",
    "message": "Message starred"
  }
}
```

---

## unstar - Unstar a Message

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| messageId | ✓ | Message ID to unstar |

### Example

```bash
.ccskill-gmail/api post '{"action":"unstar","messageId":"19bf7f25b96ab637"}'
```

---

## mark_important - Mark Thread as Important

Marks an entire thread as important. This feeds into Gmail's Priority Inbox classifier.

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to mark as important |

### Example

```bash
.ccskill-gmail/api post '{"action":"mark_important","threadId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "mark_important",
    "message": "Thread marked as important"
  }
}
```

---

## unmark_important - Unmark Thread Importance

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to unmark as important |

### Example

```bash
.ccskill-gmail/api post '{"action":"unmark_important","threadId":"19bf7f25b96ab637"}'
```

---

## Usage Notes

- **Star** is per-message: pass `messageId`. Obtain it from `get_thread` → `data.messages[].id`.
- **Importance** is per-thread: pass `threadId`. GmailApp does not expose a message-level `markImportant()`; this matches Gmail's own model where importance applies to an entire conversation.
- A typical triage flow: AI classifies threads, stars the specific messages the human should look at, and marks the whole thread as important to train Priority Inbox.
