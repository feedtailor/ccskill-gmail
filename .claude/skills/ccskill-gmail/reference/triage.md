# Inbox Triage Workflow

## When to use this document

Read this document **before constructing any search query** if the user's request matches any of these phrases:

- 日本語: 「要返信」「未返信」「返信漏れ」「返信すべきメール」「メールチェックして」「**重要なメール**」「**優先度の高いメール**」「**ピックアップ**」「**目を通すべきメール**」「**重要なやりとり**」「**最近の重要**」
- English: "reply needed", "emails I should reply to", "pending replies", "check my emails", "triage my inbox", "scan inbox", "what needs my attention?", "**important emails**", "**high-priority emails**", "**pick out the important ones**", "**what's important**", "**highlights**"

**Do NOT improvise a search query based on `is:unread` or `is:important`.**

- `is:unread` ≠ unreplied. A message becomes "read" the moment the user opens it in any client; that says nothing about whether they replied.
- `is:important` ≠ what the user means by "important". The Gmail "Important" marker is auto-assigned and noisy (often hundreds of messages per month, including system notifications). When the user asks for "important emails", they expect **your human-style judgment** based on sender, content, and context — not the Gmail marker.

See [Recommended search query](#recommended-search-query) below. Importance/priority is judged by the classification rules in this document, not by Gmail markers.

### Always use `lastSentMessage` (NOT `messages[-1]`) to determine the last sender

`get_thread` returns drafts inline with sent messages. A freshly created reply draft will appear at the end of `messages[]` and can be misclassified as "sent reply" if you read `messages[-1]` directly.

The response includes two helper fields specifically for triage:

| Field | Type | Purpose |
|-------|------|---------|
| `lastSentMessage` | object \| null | The most recent **non-draft** message (full message object). Use this to determine "who spoke last". |
| `hasDraft` | bool | True if the thread contains at least one draft. Useful to detect "I already drafted a reply but haven't sent it yet". |

Always use these fields. Treat `messages[-1]` as untrusted for the "last sender" judgment.

---

When the user asks to check, review, or triage their inbox, follow this structured workflow.

## Step 1: Fetch and Filter

```bash
# Fetch unread emails in primary inbox, filtering out automated senders
.ccskill-gmail/api get action=search query="is:unread category:primary" maxResults=20
```

If results are too many, narrow with date range (`after:YYYY/MM/DD`) or sender filters. See [search.md](search.md) Search Strategy for progressive refinement.

## Step 2: Classify Each Thread

For each candidate thread, fetch the full conversation:

```bash
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID
```

### Reading the response for triage

Read these top-level fields from `data` (do NOT scan `messages[-1]` for the last sender):

- `data.lastSentMessage.from` — who sent the last **non-draft** message
- `data.lastSentMessage.date` — when that message was sent
- `data.lastSentMessage.body` — the content of that message (for context)
- `data.hasDraft` — `true` if there is already a draft in the thread

Decision shortcut:

| Observation | Likely category |
|-------------|-----------------|
| `lastSentMessage.from` is the user | **waiting** |
| `lastSentMessage.from` is someone else | **reply-now** or **draft-needed** |
| `hasDraft: true` | A draft already exists — inspect it before creating another. Do NOT create a duplicate draft on top |
| `lastSentMessage` is `null` | All messages in the thread are drafts — unusual, treat as **draft-needed** and verify with the user |

### Classify into one of these categories

| Category | Meaning | Typical action |
|----------|---------|----------------|
| **reply-now** | Requires your reply within 24h | Create reply draft |
| **waiting** | You already replied; waiting for their response | No action (optionally add label) |
| **draft-needed** | Needs a thoughtful reply, but not urgent | Create reply draft |
| **fyi** | Informational, no reply needed | Mark as read |
| **archive** | No action needed, can be archived | Archive |

### Classification signals

- **reply-now**: Direct question to user, deadline mentioned, escalation tone, from important sender, AND `lastSentMessage.from` is not the user
- **waiting**: `lastSentMessage.from` is the user (i.e., the user sent the most recent **non-draft** message), or thread has "I'll get back to you" pattern. **Do NOT use `messages[-1]` for this judgment** — use `lastSentMessage`, which is computed server-side excluding drafts
- **draft-needed**: Complex request requiring research, multi-part question, first contact from new sender, AND `lastSentMessage.from` is not the user
- **fyi**: CC'd, newsletter from a person, team announcements, status updates
- **archive**: Automated notifications that passed primary filter, resolved threads

## Step 3: Report Summary

Present results in this structure:

### Summary line
> Unread 15: reply-now 3, draft-needed 2, waiting 1, fyi 7, archive 2

### Reply-now details (always show)

For each reply-now item:
- **Subject / From / Date**
- **Content**: Brief summary of the latest message
- **Why urgent**: The signal that triggered reply-now classification
- **Suggested action**: Specific next step

### Other categories (brief)

List subject + from for draft-needed, fyi, archive. Waiting items note who you're waiting on.

## Step 4: Offer Next Actions

After the report, ask the user what they'd like to do:

- "Shall I create reply drafts for the reply-now items?"
- "Want me to archive the archive items and mark fyi as read?"
- "Should I add labels to track the waiting items?"

Do not take action without the user's confirmation.

## Recommended search query

For "emails that need a reply", use:

```bash
.ccskill-gmail/api get action=search query="in:inbox -from:me newer_than:7d -category:promotions -category:social -category:updates -category:forums" maxResults=30
```

Then for each thread call `get_thread` and read `data.lastSentMessage.from` (NOT `messages[-1].from`). If `lastSentMessage.from` is not the user, the thread is a reply-now / draft-needed candidate.

### Why not `is:unread`?

**Unread ≠ unreplied.** A Gmail message becomes "read" the moment the user opens it in any Gmail client (web, mobile app, preview pane) — that does not mean they have replied. In Japanese business workflows especially, users routinely scan an email to understand it, then leave it in the inbox to reply later.

When looking for emails that need a reply, **never include `is:unread`** in the query. Use `in:inbox -from:me` to find threads where the user is not the last actor, then verify per-thread with `lastSentMessage`.

Date range: `newer_than:7d` to `newer_than:14d` is a reasonable default. Shorter windows (e.g., `newer_than:1d`) will miss stalled replies.

### Output format

1. **Filter out automated senders** — Exclude noreply, notifications, promotions, updates, and social category emails to surface only human-sent messages. See examples.md §19 for query patterns.
2. **Present each email as a structured summary** — For each relevant thread, report:
   - **Subject / From / Date**
   - **Content**: Brief summary of the latest message
   - **Status**: Current state (e.g., "awaiting your reply", "waiting for their response", "FYI only")
   - **Suggested action**: What to do next (e.g., "reply with acknowledgment", "no action needed", "draft reply proposed below")
