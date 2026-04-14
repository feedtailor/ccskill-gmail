# Commitment Extraction Workflow

When the user asks to extract commitments, tasks, or action items from email threads (e.g., "what did we promise?", "extract action items", "what's pending in this thread?"), follow this workflow.

## Step 1: Fetch Full Thread

```bash
.ccskill-gmail/api get action=get_thread threadId=THREAD_ID
```

If multiple threads are involved, fetch them in parallel Bash calls.

## Step 2: Extract Commitments

Analyze each message in the thread and extract structured commitments:

| Field | Description | Example |
|-------|-------------|---------|
| **From** | Who made the commitment or request | Tanaka |
| **To** | Who is expected to act | You (user) |
| **Commitment** | What was promised or requested | Send the estimate by Friday |
| **Deadline** | Explicit or implied deadline | 2026-04-18 (Friday) |
| **Status** | Current state based on thread context | Pending |

### Status values

| Status | Meaning |
|--------|---------|
| **Pending** | Commitment made, no evidence of completion |
| **In progress** | Follow-up messages indicate work is underway |
| **Completed** | Completion confirmed in a later message |
| **Overdue** | Deadline has passed with no completion evidence |
| **Unknown** | Cannot determine from available messages |

### What counts as a commitment

- Explicit promises: "I'll send it by Friday", "We'll prepare the document"
- Requests accepted: "Could you review this?" followed by "Sure, I'll take a look"
- Action items from meetings: "As discussed, I'll handle X"
- Implicit obligations: Direct questions awaiting answers

### What does NOT count

- Pleasantries: "Let's catch up sometime"
- Vague intentions without specificity: "We should think about this"
- Information sharing: "FYI, the server was updated"

## Step 3: Present Results

### Output format

> **Thread**: Re: Q2 Budget Review
> **Participants**: Tanaka, Sato, You
> **Period**: 2026-04-01 ~ 2026-04-10

| # | From | To | Commitment | Deadline | Status |
|---|------|----|-----------|----------|--------|
| 1 | Tanaka | You | Send revised estimate | 4/15 | Pending |
| 2 | You | Sato | Review spec document | None stated | In progress |
| 3 | Sato | Tanaka | Share Q1 actuals | 4/10 | Completed (4/9) |

### Highlight overdue and pending items

After the table, call out items that need attention:

> **Action needed:**
> - #1: Estimate for Tanaka is due 4/15 (3 days from now). Shall I create a reply draft?

## Multi-Thread Analysis

When asked to analyze commitments across multiple threads (e.g., "what do I owe to ACME Corp?"):

1. Search for relevant threads: `.ccskill-gmail/api get action=search query="from:acme.com OR to:acme.com" maxResults=10`
2. Fetch each thread in parallel
3. Extract commitments from all threads
4. Consolidate and deduplicate (same commitment may be referenced across threads)
5. Present a unified table sorted by deadline
