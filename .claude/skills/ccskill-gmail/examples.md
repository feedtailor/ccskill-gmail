# Workflow Examples

## When to use ccskill-gmail vs the standard Gmail connector

ccskill-gmail is a **companion** to the standard Gmail connector available in Claude.ai and Codex. The two are not mutually exclusive — pick the right tool for each task.

| Task | Recommended |
|---|---|
| Quick "what's unread", "show me this thread", chat-driven reply drafting | Standard Gmail connector |
| Multi-account operation (default account + per-request `--account` switching + per-project binding) | **ccskill-gmail** |
| Downloading attachment file contents (the connector returns metadata only) | **ccskill-gmail** |
| Saving emails as HTML / PDF for archival | **ccskill-gmail** |
| Bulk operations across many threads | **ccskill-gmail** |
| Shell-script automation, cron, CI integration | **ccskill-gmail** |
| Local audit log of every AI-initiated operation | **ccskill-gmail** |

The examples that follow focus on workflows where ccskill-gmail is the right choice. For everyday search/read/draft, the standard connector is faster and more conversational.

## Prerequisites

The workflow examples below use the `ccskill-gmail api` command, which works from any directory.
The account, endpoint and authentication are resolved automatically (see "Account Selection" in [SKILL.md](SKILL.md)).

---

## 1. Check Unread Emails

```bash
# Get unread email list
ccskill-gmail api get action=search query="is:unread" maxResults=10

# View a specific thread in detail
ccskill-gmail api get action=get_thread threadId=THREAD_ID
```

---

## 2. Check Emails from Important Senders

```bash
# Unread emails from a specific sender
ccskill-gmail api get action=search query="is:unread from:boss@company.com"
```

---

## 3. Create a Reply Draft

```bash
# 1. Search for unread emails
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 2. Get thread details (THREAD_ID is obtained from step 1 results)
ccskill-gmail api get action=get_thread threadId=THREAD_ID

# 3. Create a reply draft (recipient and subject are auto-populated; defaults to reply-all)
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"Thank you for reaching out.\n\nUnderstood. I will take care of it.\n\nBest regards."}'

# To reply only to the sender (replyAll: false)
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"Understood.","replyAll":false}'

# To reply to the last message without skipping your own sent messages
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"One more thing.","skipSelf":false,"replyAll":false}'

# 4. Review and send the draft in Gmail
# https://mail.google.com/mail/u/0/#drafts
```

The default behavior (`skipSelf: true`, `replyAll: true`) correctly creates a reply-all draft addressed to the other party, even in threads where you sent the last message.

---

## 4. Search and Download Emails with Attachments

```bash
# Unread emails with attachments
ccskill-gmail api get action=search query="is:unread has:attachment"

# Check the attachment list (MESSAGE_ID is obtained from the above results)
ccskill-gmail api get action=list_attachments messageId=MESSAGE_ID

# Download an attachment (attachment at index=0)
ccskill-gmail api download MESSAGE_ID 0 .ccskill-gmail/tmp/attachment.pdf
```

---

## 5. Save Email as PDF (Print)

When the user wants to save an email as a PDF (a typical case being a receipt or invoice), check for an attached PDF first. The attached file is the publisher's authoritative document; re-rendering the body with `save-pdf` is a last resort. See [SKILL.md "PDF Saving Guidance"](SKILL.md#pdf-saving-guidance--choosing-between-download-and-save-pdf) for the full rule.

### Example: save a monthly receipt that came as an attached PDF

```bash
# 1. ALWAYS check attachments first
ccskill-gmail api get action=list_attachments messageId=MESSAGE_ID

# 2. If the response includes an application/pdf attachment, download it
ccskill-gmail api download MESSAGE_ID 0 ./2026-05_acme_receipt.pdf
```

### Example: save the body when no PDF attachment exists

```bash
# Fallback when list_attachments returns no application/pdf entry
ccskill-gmail api save-pdf MESSAGE_ID ./email.pdf

# Or save the raw HTML
ccskill-gmail api save-html MESSAGE_ID ./email.html
```

`save-pdf` auto-detects Chrome headless / wkhtmltopdf. If no tool is available, it saves the HTML and provides instructions for printing via a browser.

---

## 6. Search Emails by Date Range

```bash
# Emails from this month
ccskill-gmail api get action=search query="after:2024/01/01 before:2024/02/01"

# Past 7 days
ccskill-gmail api get action=search query="newer_than:7d"
```

---

## 7. Check Emails by Label

```bash
# Get label list
ccskill-gmail api get action=list_labels | jq '.data.labels[] | select(.unreadCount > 0)'

# Emails with a specific label
ccskill-gmail api get action=search query="label:Projects is:unread"
```

---

## 8. Create a Draft to Multiple Recipients

```bash
# Send a notification to all team members
ccskill-gmail api post '{"action":"create_draft","to":"member1@example.com,member2@example.com,member3@example.com","cc":"manager@example.com","subject":"Weekly Meeting Notice","body":"Hi team,\n\nThe weekly meeting is scheduled as follows:\n\nDate: Tuesday, Jan 30 at 3:00 PM\nLocation: Conference Room A\n\nPlease plan to attend."}'
```

For long JSON, use the Write tool + `@file` pattern:

```
# Step 1: Create a JSON file with the Write tool
Write(".ccskill-gmail/tmp/draft.json") with the following content:
{"action":"create_draft","to":"member1@example.com,member2@example.com","cc":"manager@example.com","subject":"Weekly Meeting Notice","body":"Hi team,\n\n...long body text..."}
```

```bash
# Step 2: Send via Bash
ccskill-gmail api post @.ccskill-gmail/tmp/draft.json
```

---

## 9. Read an Email and Mark as Read

```bash
# 1. Get unread emails (note the THREAD_ID)
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 2. View the content
ccskill-gmail api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. Mark as read
ccskill-gmail api post '{"action":"mark_read","threadId":"THREAD_ID"}'
```

---

## 10. Organize Emails with Labels

```bash
# 1. Search for unread important emails (note the THREAD_ID)
ccskill-gmail api get action=search query="is:unread is:important" maxResults=1

# 2. Add an "ActionRequired" label
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"ActionRequired"}'

# 3. After handling, change the label
ccskill-gmail api post '{"action":"remove_label","threadId":"THREAD_ID","label":"ActionRequired"}'
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'
```

---

## 11. Unread Email Handling Workflow (Complete)

```bash
# 1. Search for unread emails (note the THREAD_ID)
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 2. View the thread content
ccskill-gmail api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. Create a reply draft
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"Understood."}'

# 4. Mark as read
ccskill-gmail api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 5. Add a label
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'

# 6. Review and send the draft in Gmail
# https://mail.google.com/mail/u/0/#drafts
```

---

## 12. Monitor Unread Count

```bash
# Unread count in inbox
ccskill-gmail api get action=get_unread_count

# Unread count for a specific label
ccskill-gmail api get action=get_unread_count label=Important
```

---

## 13. Archive After Processing Email

```bash
# 1. Process unread emails (note the THREAD_ID)
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 2. Mark as read and add label
ccskill-gmail api post '{"action":"mark_read","threadId":"THREAD_ID"}'
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'

# 3. Archive to clean up the inbox
ccskill-gmail api post '{"action":"archive","threadId":"THREAD_ID"}'
```

---

## 14. Delete Unwanted Emails

```bash
# 1. Search for old promotional emails (note the THREAD_ID)
ccskill-gmail api get action=search query="category:promotions older_than:30d" maxResults=1

# 2. Move to trash (auto-deleted after 30 days)
ccskill-gmail api post '{"action":"move_to_trash","threadId":"THREAD_ID"}'
```

---

## 15. Complete Workflow (Check Unread -> Reply -> Organize -> Archive)

```bash
# 1. Check unread count
ccskill-gmail api get action=get_unread_count | jq '.data.unreadCount'

# 2. Get unread emails (note the THREAD_ID)
ccskill-gmail api get action=search query="is:unread" maxResults=1

# 3. View the content
ccskill-gmail api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 4. Create a reply draft
ccskill-gmail api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"Understood."}'

# 5. Mark as read
ccskill-gmail api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 6. Add a label
ccskill-gmail api post '{"action":"add_label","threadId":"THREAD_ID","label":"Handled"}'

# 7. Archive
ccskill-gmail api post '{"action":"archive","threadId":"THREAD_ID"}'

# 8. Re-check unread count
ccskill-gmail api get action=get_unread_count | jq '.data.unreadCount'

# Review and send drafts in Gmail: https://mail.google.com/mail/u/0/#drafts
```

---

## 16. Create a Draft with Attachments

Drafts with attachments produce large JSON, so use the Write tool + `@file` pattern.

```
# Step 1: Create a JSON file with the Write tool (with base64-encoded content)
Write(".ccskill-gmail/tmp/draft-with-attachment.json") with the following content:
{
  "action": "create_draft",
  "to": "recipient@example.com",
  "subject": "Report Attached",
  "body": "Hi, please find the report attached.",
  "attachments": [
    {
      "filename": "report.pdf",
      "contentType": "application/pdf",
      "content": "JVBERi0xLjQ..."
    }
  ]
}
```

```bash
# Step 2: Send via Bash
ccskill-gmail api post @.ccskill-gmail/tmp/draft-with-attachment.json
```

- `attachments` is an array that supports multiple files
- `content` is base64-encoded data
- Total size limit: 5MB (after base64 decoding)
- `contentType` defaults to `application/octet-stream` if omitted

---

## 17. Generate Shell Scripts for Gmail Automation

The `ccskill-gmail api` command works as a Gmail bridge API callable from shell scripts. Ask Claude Code to generate a script and it will produce a working automation — no manual API research needed.

### Use Case: Extract Spam Analysis Data

> "Search spam emails and extract sender domains and subjects into NDJSON"

Claude Code generates a script like:

```bash
#!/bin/bash
set -euo pipefail

# Search spam emails
result=$(ccskill-gmail api get action=search query="in:spam" maxResults=50)

# Extract thread IDs
thread_ids=$(echo "$result" | jq -r '.data.threads[].id')

# Fetch each thread and output NDJSON
for tid in $thread_ids; do
  thread=$(ccskill-gmail api get action=get_thread threadId="$tid")
  echo "$thread" | jq -c '.data.messages[0] | {
    from: .from,
    subject: .subject,
    date: .date,
    domain: (.from | capture("@(?<d>[^>]+)") | .d)
  }'
done
```

### Use Case: Bulk Download Attachments

> "Download all PDF attachments from emails matching 'invoice' in the last month"

```bash
#!/bin/bash
set -euo pipefail

mkdir -p ./invoices

# Search for invoice emails with attachments
result=$(ccskill-gmail api get action=search query="invoice has:attachment newer_than:30d" maxResults=50)

# Process each message
echo "$result" | jq -r '.data.threads[].messages[].id' | while read -r msg_id; do
  # List attachments
  attachments=$(ccskill-gmail api get action=list_attachments messageId="$msg_id")
  
  # Download PDF attachments
  echo "$attachments" | jq -r '.data.attachments[] | select(.mimeType == "application/pdf") | .index' | while read -r idx; do
    filename=$(echo "$attachments" | jq -r ".data.attachments[$idx].filename")
    ccskill-gmail api download "$msg_id" "$idx" "./invoices/${msg_id}_${filename}"
    echo "Downloaded: $filename"
  done
done
```

### Use Case: Daily Unread Summary Report

> "Create a script that outputs a Markdown summary of today's unread emails"

```bash
#!/bin/bash
set -euo pipefail

echo "# Unread Email Summary — $(date +%Y-%m-%d)"
echo ""

result=$(ccskill-gmail api get action=search query="is:unread newer_than:1d" maxResults=30)
count=$(echo "$result" | jq '.data.threads | length')

echo "**$count unread emails today**"
echo ""
echo "| From | Subject | Date |"
echo "|------|---------|------|"

echo "$result" | jq -r '.data.threads[] | "| \(.from) | \(.subject) | \(.date) |"'
```

### Key Points for Generated Scripts

- **Scripts run from any directory** once an account is registered. The account is resolved per call (project binding > default); pin it explicitly in scripts with `--account <email|label>` or the `CCSKILL_GMAIL_ACCOUNT` env var
- **Authentication is automatic** — `ccskill-gmail api` handles OAuth tokens
- **Standard shell features are allowed** — `$()`, pipes, loops, `jq`, `&&` are all fine in scripts (the restrictions in SKILL.md apply only to interactive Bash tool calls)
- **JSON responses** — all API responses are `{"ok": true, "data": ...}`, use `jq` for parsing

---

## 18. Extract Unreplied Emails as Task Candidates

Identify threads where the last message is from someone else (i.e., you haven't replied yet) and present them as task candidates.

> **Important**: Always include `id` when filtering search results with `jq`. Without the thread ID, you cannot call `get_thread` and must re-search by subject — which risks matching the wrong thread.

```bash
# 1. Get your own email address
ccskill-gmail api get action=get_profile | jq -r '.data.email'

# 2. Search recent emails (ALWAYS include id in jq output)
ccskill-gmail api get action=search query="is:unread" maxResults=20 \
  | jq '.data.threads[] | {id, subject, from, date}'

# 3. For each thread, check who sent the last message
ccskill-gmail api get action=get_thread threadId=THREAD_ID \
  | jq '{subject: .data.subject, lastFrom: .data.messages[-1].from, lastDate: .data.messages[-1].date}'

# 4. Determine unreplied status:
#    - If lastFrom does NOT contain your email → unreplied (task candidate)
#    - If lastFrom contains your email → already replied (skip)
#    - Exclude automated senders (noreply, notifications, etc.)
```

### Workflow Summary

1. `get_profile` → get your email address for comparison
2. `search` → get candidate threads (**always include `id`**)
3. `get_thread` for each → check the last message's `from` field
4. If `from` ≠ your email and not a noreply sender → unreplied task candidate

### Why Not Just Use Search?

The `search` response includes `from` (the thread's first sender) but does not indicate who sent the **last** message. To determine reply status, you must call `get_thread` and inspect `messages[-1].from`.

---

## 19. Smart Filtering — Surface Human Emails

When scanning the inbox for actionable emails, exclude automated senders to reduce noise:

```bash
# Filter out automated notifications and surface human-sent emails
ccskill-gmail api get action=search query="newer_than:1d in:inbox -category:promotions -category:updates -category:social -from:noreply -from:no-reply -from:donotreply -from:notification -from:alert" maxResults=20
```

### Customizing the Filter

```bash
# Customer emails only (if a label exists)
ccskill-gmail api get action=search query="newer_than:1d label:customers"

# Broader time range
ccskill-gmail api get action=search query="newer_than:7d in:inbox -from:noreply -from:no-reply"

# Combined with unreplied check (see §18)
# First filter with smart query, then check last sender per thread
```

### Presenting Results

After retrieving threads, fetch each thread's details and present a structured summary:

**Format:**

```
### 1. [Sender Name]（[Company]） — [Subject]
- **Latest**: [Who] → [Who] ([date])
- **Content**: [1-2 sentence summary]
- **Status**: [Current state — e.g., "awaiting your reply", "waiting for their response", "FYI only"]
- **Suggested action**: [What to do next — e.g., "reply with acknowledgment", "no action needed", "draft reply proposed below"]
```
