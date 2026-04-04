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
.ccskill-gmail/api post '{"action":"add_label","threadId":"19bf7f25b96ab637","label":"対応済"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "対応済",
    "action": "add_label",
    "message": "ラベル「対応済」を追加しました"
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
.ccskill-gmail/api post '{"action":"remove_label","threadId":"19bf7f25b96ab637","label":"対応済"}'
```

### Response Example

```json
{
  "ok": true,
  "data": {
    "threadId": "19bf7f25b96ab637",
    "label": "対応済",
    "action": "remove_label",
    "message": "ラベル「対応済」を削除しました"
  }
}
```

### Error Example

When attempting to remove a non-existent label:

```json
{
  "ok": false,
  "error": "Label not found: 存在しないラベル"
}
```

---

## Workflow Example

```bash
# 1. Search for unread emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. Add a "要確認" (needs review) label (THREAD_ID is obtained from step 1 results)
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"要確認"}'

# 3. After handling, remove "要確認" and add "対応済" (handled)
.ccskill-gmail/api post '{"action":"remove_label","threadId":"THREAD_ID","label":"要確認"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'
```

---

## Limitations

- **Thread-level operations only**: Per-message labeling is not supported due to GmailApp limitations
- **System labels**: System labels such as `INBOX`, `SENT`, `TRASH` cannot be operated on
