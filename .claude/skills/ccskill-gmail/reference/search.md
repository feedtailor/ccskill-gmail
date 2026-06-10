# search - Email Search

Searches emails using Gmail search syntax.

## Use-case query map

Pick the query by **what you want**, not by the first operator that comes to mind. `is:unread` is often the wrong default — see the NG column.

| What you want | Recommended query | Do NOT use |
|---------------|-------------------|------------|
| New mail since last check | `is:unread in:inbox newer_than:1d` | — |
| Unread count only | `get_unread_count` action (see [read.md](read.md)) | — |
| **Emails that need a reply** | `in:inbox -from:me newer_than:7d -category:promotions -category:social -category:updates -category:forums` | ❌ `is:unread` |
| Automated bill/receipt triage | `from:<sender> subject:invoice` | — |
| Find a specific thread | `from:<sender> subject:<keyword>` | — |
| All mail from a sender | `from:<sender>` | — |

> **Why `is:unread` fails for "need a reply"**: A Gmail message becomes "read" the moment the user opens it in any client (web, mobile, preview pane) — that does not mean they have replied. See [triage.md](triage.md) for the full "emails that need a reply" workflow.

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
ccskill-gmail api get action=search query="is:unread"

# From a specific sender (latest 10)
ccskill-gmail api get action=search query="from:boss@company.com" maxResults=10

# Query containing non-ASCII characters (get subcommand auto-encodes)
ccskill-gmail api get action=search query="subject:invoice"
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
        "subject": "Meeting Tomorrow",
        "from": "sender@example.com",
        "date": "2024-01-15T10:30:00.000Z",
        "messageCount": 3,
        "isUnread": true,
        "isImportant": true,
        "isInInbox": true,
        "labels": ["INBOX", "Important"]
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
| subject: | Subject | `subject:invoice` |
| has:attachment | Has attachments | `has:attachment` |
| after: | After date | `after:2024/01/01` |
| before: | Before date | `before:2024/02/01` |
| label: | Label | `label:Important` |
| in:inbox | In inbox | `in:inbox` |
| in:sent | In sent | `in:sent` |

Multiple conditions are space-separated for AND search:
```
is:unread from:boss@company.com has:attachment
```

## Search Strategy

### Progressive Refinement

Always narrow down results progressively rather than fetching a large set at once:

1. **Estimate first** — Run the query with `maxResults=1` to check if results exist, then decide the appropriate `maxResults`
2. **Start narrow, widen if needed** — Begin with specific conditions (sender + date range), relax only if too few results
3. **Avoid broad queries with large maxResults** — A query like `is:unread` with `maxResults=100` may hit the GAS 6-minute execution timeout

### Recommended Filter Priority

Apply filters in this order for efficiency:

1. **Sender / domain** — `from:alice@example.com` or `from:example.com`
2. **Status** — `is:unread`, `is:starred`, `in:inbox`
3. **Date range** — `after:2026/04/01 before:2026/04/12`
4. **Attachments** — `has:attachment`
5. **Category / label** — `label:Important`, `category:primary`

### Patterns to Avoid

| Pattern | Risk | Better approach |
|---------|------|-----------------|
| `is:unread` with `maxResults=50+` | Timeout on large inboxes | Add sender or date filter |
| Many OR conditions at once | Unpredictable result count | Split into multiple searches |
| Searching all mail without date range | Slow, may timeout | Always add `after:` for broad queries |
