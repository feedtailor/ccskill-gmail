# Workflow Examples

## Prerequisites

The workflow examples below use the `.ccskill-gmail/api` command.
The endpoint and authentication are automatically resolved internally by the script.

---

## 1. Check Unread Emails

```bash
# Get unread email list
.ccskill-gmail/api get action=search query="is:unread" maxResults=10

# View a specific thread in detail
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID
```

---

## 2. Check Emails from Important Senders

```bash
# Unread emails from a specific sender
.ccskill-gmail/api get action=search query="is:unread from:boss@company.com"
```

---

## 3. Create a Reply Draft

```bash
# 1. Search for unread emails
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. Get thread details (THREAD_ID is obtained from step 1 results)
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID

# 3. Create a reply draft (recipient and subject are auto-populated; defaults to reply-all)
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"ご連絡ありがとうございます。\n\n承知いたしました。対応いたします。\n\nよろしくお願いいたします。"}'

# To reply only to the sender (replyAll: false)
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。","replyAll":false}'

# To reply to the last message without skipping your own sent messages
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"追記です。","skipSelf":false,"replyAll":false}'

# 4. Review and send the draft in Gmail
# https://mail.google.com/mail/u/0/#drafts
```

The default behavior (`skipSelf: true`, `replyAll: true`) correctly creates a reply-all draft addressed to the other party, even in threads where you sent the last message.

---

## 4. Search and Download Emails with Attachments

```bash
# Unread emails with attachments
.ccskill-gmail/api get action=search query="is:unread has:attachment"

# Check the attachment list (MESSAGE_ID is obtained from the above results)
.ccskill-gmail/api get action=list_attachments messageId=MESSAGE_ID

# Download an attachment (attachment at index=0)
.ccskill-gmail/api download MESSAGE_ID 0 /tmp/attachment.pdf
```

---

## 5. Save Email as PDF (Print)

```bash
# Save an email as PDF (fetches HTML and converts to PDF in one step)
.ccskill-gmail/api save-pdf MESSAGE_ID ./receipt.pdf

# To save as HTML instead
.ccskill-gmail/api save-html MESSAGE_ID ./email.html
```

`save-pdf` auto-detects Chrome headless / wkhtmltopdf. If no tool is available, it saves the HTML and provides instructions for printing via a browser.

---

## 6. Search Emails by Date Range

```bash
# Emails from this month
.ccskill-gmail/api get action=search query="after:2024/01/01 before:2024/02/01"

# Past 7 days
.ccskill-gmail/api get action=search query="newer_than:7d"
```

---

## 7. Check Emails by Label

```bash
# Get label list
.ccskill-gmail/api get action=list_labels | jq '.data.labels[] | select(.unreadCount > 0)'

# Emails with a specific label
.ccskill-gmail/api get action=search query="label:Projects is:unread"
```

---

## 8. Create a Draft to Multiple Recipients

```bash
# Send a notification to all team members
.ccskill-gmail/api post '{"action":"create_draft","to":"member1@example.com,member2@example.com,member3@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n週次ミーティングを以下の日程で行います。\n\n日時: 1月30日（火）15:00〜\n場所: 会議室A\n\nご参加よろしくお願いいたします。"}'
```

For long JSON, use the Write tool + `@file` pattern:

```
# Step 1: Create a JSON file with the Write tool
Write("/tmp/draft.json") with the following content:
{"action":"create_draft","to":"member1@example.com,member2@example.com","cc":"manager@example.com","subject":"週次ミーティングのお知らせ","body":"お疲れ様です。\n\n...long body text..."}
```

```bash
# Step 2: Send via Bash
.ccskill-gmail/api post @/tmp/draft.json
```

---

## 9. Read an Email and Mark as Read

```bash
# 1. Get unread emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. View the content
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. Mark as read
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'
```

---

## 10. Organize Emails with Labels

```bash
# 1. Search for unread important emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread is:important" maxResults=1

# 2. Add a "要対応" (action required) label
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"要対応"}'

# 3. After handling, change the label
.ccskill-gmail/api post '{"action":"remove_label","threadId":"THREAD_ID","label":"要対応"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'
```

---

## 11. Unread Email Handling Workflow (Complete)

```bash
# 1. Search for unread emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. View the thread content
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 3. Create a reply draft
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 4. Mark as read
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 5. Add a label
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 6. Review and send the draft in Gmail
# https://mail.google.com/mail/u/0/#drafts
```

---

## 12. Monitor Unread Count

```bash
# Unread count in inbox
.ccskill-gmail/api get action=get_unread_count

# Unread count for a specific label
.ccskill-gmail/api get action=get_unread_count label=重要
```

---

## 13. Archive After Processing Email

```bash
# 1. Process unread emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 2. Mark as read and add label
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 3. Archive to clean up the inbox
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'
```

---

## 14. Delete Unwanted Emails

```bash
# 1. Search for old promotional emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="category:promotions older_than:30d" maxResults=1

# 2. Move to trash (auto-deleted after 30 days)
.ccskill-gmail/api post '{"action":"move_to_trash","threadId":"THREAD_ID"}'
```

---

## 15. Complete Workflow (Check Unread -> Reply -> Organize -> Archive)

```bash
# 1. Check unread count
.ccskill-gmail/api get action=get_unread_count | jq '.data.unreadCount'

# 2. Get unread emails (note the THREAD_ID)
.ccskill-gmail/api get action=search query="is:unread" maxResults=1

# 3. View the content
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID | jq '.data.subject, .data.messages[-1].body'

# 4. Create a reply draft
.ccskill-gmail/api post '{"action":"create_reply_draft","threadId":"THREAD_ID","body":"承知いたしました。"}'

# 5. Mark as read
.ccskill-gmail/api post '{"action":"mark_read","threadId":"THREAD_ID"}'

# 6. Add a label
.ccskill-gmail/api post '{"action":"add_label","threadId":"THREAD_ID","label":"対応済"}'

# 7. Archive
.ccskill-gmail/api post '{"action":"archive","threadId":"THREAD_ID"}'

# 8. Re-check unread count
.ccskill-gmail/api get action=get_unread_count | jq '.data.unreadCount'

# Review and send drafts in Gmail: https://mail.google.com/mail/u/0/#drafts
```

---

## 16. Create a Draft with Attachments

Drafts with attachments produce large JSON, so use the Write tool + `@file` pattern.

```
# Step 1: Create a JSON file with the Write tool (with base64-encoded content)
Write("/tmp/draft-with-attachment.json") with the following content:
{
  "action": "create_draft",
  "to": "recipient@example.com",
  "subject": "報告書送付",
  "body": "お世話になっております。報告書を添付いたします。",
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
.ccskill-gmail/api post @/tmp/draft-with-attachment.json
```

- `attachments` is an array that supports multiple files
- `content` is base64-encoded data
- Total size limit: 5MB (after base64 decoding)
- `contentType` defaults to `application/octet-stream` if omitted
