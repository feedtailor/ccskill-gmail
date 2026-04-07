# mark_read / mark_unread - Read/Unread Operations

Changes the read/unread status of a thread or message.

---

## mark_read - Mark as Read

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | * | Thread ID (either threadId or messageId is required) |
| messageId | * | Message ID |

### Example

```bash
# Mark an entire thread as read
.ccskill-gmail/api post '{"action":"mark_read","threadId":"19bf7f25b96ab637"}'

# Mark a specific message as read
.ccskill-gmail/api post '{"action":"mark_read","messageId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "mark_read",
    "message": "Thread marked as read"
  }
}
```

---

## mark_unread - Mark as Unread

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | * | Thread ID (either threadId or messageId is required) |
| messageId | * | Message ID |

### Example

```bash
# Mark an entire thread as unread
.ccskill-gmail/api post '{"action":"mark_unread","threadId":"19bf7f25b96ab637"}'

# Mark a specific message as unread
.ccskill-gmail/api post '{"action":"mark_unread","messageId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "mark_unread",
    "message": "Thread marked as unread"
  }
}
```

---

## Usage Guide

| Target | Effect |
|--------|--------|
| threadId | Changes read/unread status for all messages in the thread |
| messageId | Changes read/unread status for the specified message only |

When both are specified, `threadId` takes priority.
