# Inbox Triage Workflow

When the user asks to check, review, or triage their inbox (e.g., "check my emails", "what needs my attention?", "triage my inbox"), follow this structured workflow.

## Step 1: Fetch and Filter

```bash
# Fetch unread emails in primary inbox, filtering out automated senders
.ccskill-gmail/api get action=search query="is:unread category:primary" maxResults=20
```

If results are too many, narrow with date range (`after:YYYY/MM/DD`) or sender filters. See [search.md](search.md) Search Strategy for progressive refinement.

## Step 2: Classify Each Thread

Read each thread and classify into one of these categories:

| Category | Meaning | Typical action |
|----------|---------|----------------|
| **reply-now** | Requires your reply within 24h | Create reply draft |
| **waiting** | You already replied; waiting for their response | No action (optionally add label) |
| **draft-needed** | Needs a thoughtful reply, but not urgent | Create reply draft |
| **fyi** | Informational, no reply needed | Mark as read |
| **archive** | No action needed, can be archived | Archive |

### Classification signals

- **reply-now**: Direct question to user, deadline mentioned, escalation tone, from important sender
- **waiting**: Last message in thread is from user, or thread has "I'll get back to you" pattern
- **draft-needed**: Complex request requiring research, multi-part question, first contact from new sender
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

## Integration with Email Review Guidelines

This workflow extends the Email Review Guidelines in SKILL.md. The core rules still apply:
- Filter out automated senders (noreply, notifications, promotions)
- Present structured summaries with content, status, and suggested action
- See examples.md §19 for automated sender query patterns
