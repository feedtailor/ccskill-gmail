# Operation History

All Gmail Skill operations are automatically logged locally to an audit log.

## Viewing History

```bash
# View recent operations (default: latest 20 entries, human-readable format)
ccskill-gmail history

# Show errors only
ccskill-gmail history list --errors

# Output in JSON format (for Claude or jq processing)
ccskill-gmail history list --json

# Latest 50 entries
ccskill-gmail history list 50

# Filter by specific action
ccskill-gmail history list --action create_draft

# Since a specific date
ccskill-gmail history list --since 2026-03-17

# Clear logs (--yes required)
ccskill-gmail history clear --yes
```

When the user asks "what did the AI do?" / "what did the skill do recently?", use this command to look it up.

## Privacy Note

- **Recorded information**: Action name, identifying IDs (threadId, etc.), success/failure, execution time
- **Not recorded**: Email body, recipients, subject, search query content (intentionally not recorded for security)
- **Checking details**: If the user asks "what email was that?", use the `threadId` / `messageId` from the history and look it up via `get_thread` / `get_message`
- **Storage location**: `.ccskill-gmail/audit.jsonl` (local only, recommended to exclude from git)
- **Disabling**: Set the `CCSKILL_GMAIL_HISTORY=off` environment variable to stop logging
