# add_label / remove_label - Label Operations

Add or remove labels from threads.

---

## add_label - Add a Label

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID |
| label | ✓ | Label name |

### Example

```bash
.ccskill-gmail/api post '{"action":"add_label","threadId":"19bf7f25b96ab637","label":"Handled"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "Handled",
    "action": "add_label",
    "message": "Label \"Handled\" added"
  }
}
```

### Notes

- If a non-existent label is specified, it will be **automatically created**
- Nested labels can be specified in `parent/child` format

---

## remove_label - Remove a Label

### Request

**Method**: POST

**Parameters**:

| Parameter | Required | Description |
|-----------|----------|-------------|
| threadId | ✓ | Thread ID |
| label | ✓ | Label name |

### Example

```bash
.ccskill-gmail/api post '{"action":"remove_label","threadId":"19bf7f25b96ab637","label":"Handled"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "Handled",
    "action": "remove_label",
    "message": "Label \"Handled\" removed"
  }
}
```

### Error Example

When attempting to remove a non-existent label:

```json
{
  "ok": false,
  "error": "Label not found: NonExistentLabel"
}
```

---

## Workflow Example

```bash
# 1. Pick any one thread as a demo target (smoke test — NOT a triage query)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. Add a "NeedsReview" (needs review) label (THREAD_ID is obtained from step 1 results)
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"NeedsReview"}'

# 3. After handling, remove "NeedsReview" and add "Handled" (handled)
.ccskill-gmail/api post '{"action":"remove_label","threadId":"THREAD_ID","label":"NeedsReview"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'
```

---

## Limitations

- **Thread-level operations only**: Per-message labeling is not supported due to GmailApp limitations
- **System labels**: System labels such as `INBOX`, `SENT`, `TRASH` cannot be operated on
