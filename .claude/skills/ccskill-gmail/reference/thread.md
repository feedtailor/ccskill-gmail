# archive / move_to_inbox / move_to_trash - Thread Operations

Archive threads, restore them to the inbox, and move threads to trash.

---

## archive - Archive

Archives a thread from the inbox. The email itself is not deleted and can be found in "All Mail".

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to archive |

### Example

```bash
ccskill-gmail api post '{"action":"archive","threadId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "archive",
    "message": "Thread archived"
  }
}
```

### Notes

- Archiving only removes the thread from the inbox (the email itself remains)
- Can be found in "All Mail"
- Labels are preserved

---

## move_to_inbox - Move Back to Inbox

Restores an archived thread back to the inbox. The inverse operation of `archive`.

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to move back to inbox |

### Example

```bash
ccskill-gmail api post '{"action":"move_to_inbox","threadId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "move_to_inbox",
    "message": "Thread moved to inbox"
  }
}
```

### Notes

- Adds the `INBOX` label back to the thread
- Use to undo an `archive` operation, or to lift a thread out of archive when a reply arrives

---

## move_to_trash - Move to Trash

> **Note**: This action is disabled by default (included in `permissions.deny`). To enable it, remove `'move_to_trash'` from the `permissions.deny` array. For the account-shared setup, edit `~/.ccskill-gmail/gas/<clasp_user>/config.js` and run `ccskill-gmail account update`; for a dedicated per-project install, edit `.ccskill-gmail/config.js` and run `ccskill-gmail apply-config`.

Moves a thread to trash. It will be automatically deleted after 30 days.

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID to move to trash |

### Example

```bash
ccskill-gmail api post '{"action":"move_to_trash","threadId":"19bf7f25b96ab637"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "action": "move_to_trash",
    "message": "Thread moved to trash"
  }
}
```

### Notes

- Emails in trash are automatically deleted after 30 days
- Can be restored from trash
- A permanent delete API is not provided for safety reasons

---

## Workflow Example

### Complete Email Processing Workflow

```bash
# 1. Pick any one thread as a demo target (smoke test — NOT a triage query)
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 2. View the content (THREAD_ID is obtained from step 1 results)
ccskill-gmail api get action=get_thread threadId=THREAD_ID | jq '.data.subject'

# 3. Create a reply draft
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"Understood."}'

# 4. Mark as read and add label
ccskill-gmail api post '{"action":"mark_read","threadId":"THREAD_ID"}'
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'

# 5. Archive to clean up the inbox
ccskill-gmail api post '{"action":"archive","threadId":"THREAD_ID"}'
```
