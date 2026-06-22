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

## Management Command Audit

In addition to the per-account API audit log above, the execution of **management commands** (`account` / `bind` / `unbind` / `migrate` / `install` / `uninstall` / `update` / `update-all` / `apply-config` / `skill` / `setup`) is recorded to a single, account-independent file:

```
~/.ccskill-gmail/history/commands.jsonl
```

This exists for troubleshooting — to trace when, in which directory, and with which arguments a command such as `migrate` was run. Read-only commands (`status` / `info` / `whoami` / `doctor` / `account list` / `help` / `history`) are not recorded.

Each line is one JSON record:

| Field | Meaning |
|---|---|
| id | Record ID |
| timestamp | ISO8601 |
| project | Working directory (cwd) where the command ran |
| account | Account in effect (`CCSKILL_GMAIL_ACCOUNT`), or null |
| command | Top-level command (`migrate`, `account`, ...) |
| subcommand | Second level for `account` / `skill` (`add`, `default`, ...), else null |
| args | Remaining arguments (identifiers / flags). Sensitive flag values (`--token` etc.) are redacted to `***` |
| success | Whether the exit code was 0 |
| error | `"exit code N"` on failure, else null (command output is not captured, to avoid breaking interactive commands) |
| duration_ms | Elapsed time, or null |

Sample lines:

```json
{"id":"20260621T150012_a1b2c3","timestamp":"2026-06-21T15:00:12+0900","project":"/Users/oishi/projects/ccskill-gmail","account":null,"command":"migrate","subcommand":null,"args":[],"success":true,"error":null,"duration_ms":4120}
{"id":"20260621T150305_d4e5f6","timestamp":"2026-06-21T15:03:05+0900","project":"/Users/oishi/projects/x","account":null,"command":"account","subcommand":"add","args":["--label","work"],"success":true,"error":null,"duration_ms":8800}
{"id":"20260621T151030_6d7e8f","timestamp":"2026-06-21T15:10:30+0900","project":"/Users/oishi/projects/y","account":null,"command":"install","subcommand":null,"args":[],"success":false,"error":"exit code 1","duration_ms":210}
```

Email bodies, subjects, and recipients are never part of management command arguments, so they are not recorded here. Recording is skipped silently when the file cannot be written (sandbox, etc.), and is disabled entirely by `CCSKILL_GMAIL_HISTORY=off`.

## Privacy Note

- **Recorded information**: Action name, identifying IDs (threadId, etc.), success/failure, execution time
- **Not recorded**: Email body, recipients, subject, search query content (intentionally not recorded for security)
- **Checking details**: If the user asks "what email was that?", use the `threadId` / `messageId` from the history and look it up via `get_thread` / `get_message`
- **Storage location**: `.ccskill-gmail/audit.jsonl` (local only, recommended to exclude from git)
- **Disabling**: Set the `CCSKILL_GMAIL_HISTORY=off` environment variable to stop logging
