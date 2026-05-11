# Shell Script Generation

This skill can generate **standalone shell scripts** that automate Gmail operations. The `.ccskill-gmail/api` command works as a Gmail bridge API callable from any shell script — not just from Claude Code's interactive session.

When the user asks "create a script that does X with my emails", generate a shell script that calls `.ccskill-gmail/api` directly. Since the skill teaches you the full API, you can produce correct scripts without trial and error.

> **⚠️ Important — relaxed rules inside generated scripts**
>
> The API Command Construction Rules in `SKILL.md` (no `$()`, no `&&`, no pipes other than `| jq`) apply only to **interactive Bash tool calls** within Claude Code. **Generated shell scripts are free to use standard shell features** (`$()`, pipes, loops, `jq`, `cat <<EOF`, etc.). Do not propagate the interactive constraints into the scripts you write.

## Key points for script generation

- Authentication is handled automatically by `.ccskill-gmail/api` — scripts do not need to manage tokens
- Scripts must be run from the project directory where ccskill-gmail is installed (`.ccskill-gmail/api` resolves paths relative to the current directory)
- GET responses and POST responses both return JSON (`{"ok": true, "data": ...}`) — use `jq` for parsing in scripts
- Include `set -euo pipefail` and basic error handling in generated scripts

## Script pattern: GET

```bash
result=$(.ccskill-gmail/api get action=search query="is:unread" maxResults=10)
echo "$result" | jq -r '.data.threads[] | .id'
```

## Script pattern: POST (inline JSON)

```bash
.ccskill-gmail/api post '{"action":"mark_read","threadId":"'"$thread_id"'"}'
```

## Script pattern: POST with JSON file

```bash
cat > .ccskill-gmail/tmp/payload.json <<EOF
{"action":"create_draft","to":"$recipient","subject":"$subject","body":"$body"}
EOF
.ccskill-gmail/api post @.ccskill-gmail/tmp/payload.json
```
