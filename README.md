# ccskill-gmail

A **companion skill** for Claude/Codex Gmail workflows.

Use the **standard Gmail connector** for everyday search, reading, and drafting — it is faster and more conversational. Reach for **ccskill-gmail** when you need project-bound multi-account operation, attachment file downloads, email-to-PDF export, or local shell automation.

[日本語版 README はこちら](README.ja.md)

## When to use ccskill-gmail

ccskill-gmail is designed to **complement** — not replace — the standard Gmail connector available in Claude.ai and Codex.

| Use case | Recommended tool |
|---|---|
| Everyday search, reading, and drafting | Standard Gmail connector |
| Reply drafting in a chat session | Standard Gmail connector |
| Organization-managed official integration | Standard Gmail connector |
| Project-bound multi-account operation (different account per `cd`) | **ccskill-gmail** |
| Downloading attachment file contents | **ccskill-gmail** |
| Saving emails as HTML / PDF | **ccskill-gmail** |
| Shell-script automation via local bridge API | **ccskill-gmail** |
| Local audit log of AI operations | **ccskill-gmail** |

The most distinctive value is **project-bound multi-account operation**: by binding a Gmail account to each project directory, you eliminate the structural risk of an AI accidentally reading or drafting from the wrong account while working across personal / work / customer mailboxes.

## Features

### Project-bound multi-account operation

Bind a different Gmail / Google Workspace account to each project directory. The active account follows `cd` — no UI toggling, no confirmation prompts, no risk of the AI operating on the wrong mailbox.

```bash
cd /path/to/work-project    # operates on work@company.com
cd /path/to/personal-blog   # operates on you@gmail.com
cd /path/to/client-x        # operates on you@client-x.example
```

This is the most important safety property when juggling personal, work, and customer mailboxes from a single Claude Code environment.

### Attachment download and email export

- **Download attachment file contents** — the standard connector exposes metadata only
- **Export emails as HTML or PDF** — useful for audit trails, handover packages, and offline archives
- Bulk download / export across search results

### Local shell automation

`.ccskill-gmail/api` doubles as a Gmail bridge API callable from shell scripts. Suitable for cron jobs, CI pipelines, or any unattended workflow that needs Gmail without launching a chat session.

### Local audit log

All AI-initiated operations are recorded locally in JSONL (action names and IDs only — no subjects or bodies). Inspect with `ccskill-gmail history`.

### Security defaults

- **No send capability** — draft creation only. Users review and send manually from Gmail (the same approach as the official Claude.ai Gmail connector)
- **Delete is opt-in** — disabled by default in `config.js`
- **Prompt injection protection** — hidden instructions embedded in HTML emails (CSS hiding, zero-width characters, white-on-white text, etc.) are neutralized in the GAS layer before reaching the AI

## Examples

The examples below highlight where ccskill-gmail is the right choice. For everyday search / read / draft, prefer the standard Gmail connector.

### Attachment & PDF workflows

> "Find all receipt emails from ACME Corp in the last 6 months and save the attached PDFs as `20260401_VendorName_TotalWithTax_receipt.pdf`"

> "Save this email thread as PDF for the audit trail"

### Multi-account workflows

> "List unread mails for the account bound to this project only"

> "I'm in the personal-blog directory now — show today's new arrivals from this account"

### Cross-cutting knowledge work

> "Trace the entire email history with John at ACME Corp and create a handover document including background, open tasks, and work in progress. Export the list as Excel"

> "Search all incident response emails for the XYZ system from the past year and create a table of occurrence date, root cause, and resolution"

> "Find all external emails from the past month that I haven't replied to. List them with sender, subject, and days since received. Draft follow-up replies for the important ones"

### Recurring task automation — works great with `/loop`

> "Review all external emails received this week, categorize them as needs-reply / FYI / resolved, and compile a weekly report"

> "List all mailing lists and automated notifications by sender, frequency, and last received date. Archive any I haven't read in over 3 months"

### Shell script generation

The `.ccskill-gmail/api` command doubles as a Gmail bridge API callable from shell scripts. Just describe what you want automated, and Claude Code generates a working script — no manual API research needed.

> "Create a script that searches spam emails and extracts sender domains into NDJSON"

> "Write a script to download all PDF attachments from invoice emails this month"

> "Generate a daily unread email summary report in Markdown"

## Architecture

Instead of using the GCP Gmail API, this skill deploys a bridge API as a GAS (Google Apps Script) project accessible only to the authenticated user. Claude Code calls this as a private Gmail API.

```mermaid
flowchart LR
    You["🧑 User\n(natural language)"]
    CC["🤖 Claude Code\n(uses this skill)"]
    GAS["📡 GAS Web App\n(in your Google account)"]
    Gmail["📧 Gmail"]

    You -->|talk to| CC
    CC -->|API call| GAS
    GAS -->|GmailApp| Gmail
    Gmail -->|results| GAS
    GAS -->|JSON| CC
    CC -->|feedback| You

    style CC fill:#d97706,stroke:#f59e0b,color:#fff
    style GAS fill:#1a73e8,stroke:#4285f4,color:#fff
    style Gmail fill:#c5221f,stroke:#ea4335,color:#fff
```

This local-first architecture is what enables the project-bound multi-account model: each project directory binds to its own GAS deployment under a chosen Google account, and the active deployment is selected by `cd`.

## Requirements

- Google account
- Node.js / npm
- jq (command-line JSON processor)
- Bash (macOS, Linux, WSL)
- Apps Script API enabled — visit https://script.google.com/home/usersettings and turn on "Google Apps Script API" (required for first-time GAS users)

## Installation

### 1. Get the skill

```bash
cd ~/projects
git clone https://github.com/feedtailor/ccskill-gmail.git
```

### 2. Setup

Installs clasp locally, registers PATH, and handles Google login in one command.

```bash
cd ~/projects/ccskill-gmail
./ccskill-gmail setup
```

### 3. Install to your project

```bash
cd /path/to/your-project
ccskill-gmail install
```

The installer will automatically create a GAS project, deploy it, and handle Google authorization. When a browser window opens, click "Allow".

**SSH / headless environments:** The installer always displays the Authorization URL in the terminal, so you can copy it and open it in any browser — even on a different machine.

After installation, run `ccskill-gmail info` to confirm which Google account is bound to the current project.

## Update

```bash
cd ~/projects/ccskill-gmail
git pull

# Apply to projects
ccskill-gmail update        # single project
ccskill-gmail update-all    # all projects
```

## Uninstall

```bash
ccskill-gmail uninstall
```

This removes local files (`.ccskill-gmail/`, skill definitions, permission settings). The Google Apps Script project is not automatically deleted — to fully remove it, delete it manually from [script.google.com](https://script.google.com).

## Other Commands

```bash
ccskill-gmail info [--json]       # Show details for current project (account, permissions, unread)
ccskill-gmail status [--refresh]  # Show all installations and their health
ccskill-gmail doctor              # Diagnose environment and setup issues
ccskill-gmail history             # Show API operation audit log
ccskill-gmail apply-config        # Push config.js changes to GAS
ccskill-gmail register <PATH>     # Register an existing installation
ccskill-gmail release             # Create a distributable zip file
ccskill-gmail help                # Show all available commands
```

- `info` shows the account email, version, permissions, and unread counts for the current project — use it to confirm which account you are about to operate on
- `status --refresh` fetches account emails for all installations via the API and caches them

## Troubleshooting

### Installation fails midway

Re-run `ccskill-gmail install`. You'll be asked "Overwrite?" — answer `y` to overwrite the previous partial installation. A failed install may also leave an orphaned GAS project on Google's side — delete it manually from [script.google.com](https://script.google.com) before retrying.

### Redirect loop or "Unable to open file" during Google authorization

This happens when your browser is logged into multiple Google accounts, or when a private window has a cached session from a different account. Follow these steps:

1. Copy the **Authorization URL** shown in your terminal (starts with `https://script.google.com/macros/s/...`)
2. Open a **new private/incognito window** (close any existing private windows to clear cached sessions)
3. Go to [accounts.google.com](https://accounts.google.com) and **explicitly sign in** with the Google account you want to use for this project
4. In the **same window**, paste the Authorization URL into the address bar
5. Click "Allow" to authorize the script

**Important:**
- Do NOT copy the URL from the browser's error page — it contains corrupted redirect data. Always use the clean URL from your terminal
- Make sure to sign in at accounts.google.com **before** opening the Authorization URL — opening the URL first may trigger the same redirect loop

### Multi-account OAuth issues

If you use `--user` and encounter authentication errors, run `ccskill-gmail doctor` in the project directory. The doctor command checks the full chain — clasp login, OAuth tokens, endpoint connectivity — and tells you exactly what's broken with fix suggestions.

### Something doesn't work after update

Run `ccskill-gmail doctor` to diagnose. If the issue persists, try `ccskill-gmail update --force` to re-deploy the GAS project from scratch.

## Technical Details

### Permissions Explained

During setup, Google will ask you to grant permissions at two stages:

**Stage 1: Permissions for managing GAS projects (during `setup`)**

| Permission | Why it's needed |
|---|---|
| View and manage Google Drive files | Create and update the GAS project files |
| View and manage Apps Script projects | Create the GAS project and push code |
| View and manage deployments | Deploy the Web App |

These are standard clasp (GAS CLI tool) permissions. They do **not** grant access to your email.

**Stage 2: Permissions for Gmail access (during first use)**

| Permission (OAuth scope) | Why it's needed |
|---|---|
| `gmail.readonly` | Search and read emails, list labels, download attachments |
| `gmail.compose` | Create and edit drafts |
| `gmail.modify` | Mark read/unread, add/remove labels, archive, move to trash |

These are the minimum scopes required for the skill's features. No `gmail.send` scope is requested.

### Multi-account Setup

Without `--user`, the default account is used. No additional setup is needed for single-account usage.

To use different Google accounts for different projects, use the `--user` option. The installer will prompt for Google login automatically.

```bash
cd /path/to/work-project
ccskill-gmail install --user work
# The installer will prompt for Google login if needed
# This directory now uses the work account's Gmail
```

Note: `--user` accepts only alphanumeric characters, hyphens, and underscores (e.g. `work`, `personal`, `info-ft`).

### Skill Definition Documents

For API specifications and troubleshooting, see the skill definition documents:

- [SKILL.md](.claude/skills/ccskill-gmail/SKILL.md) — API specification and rules
- [examples.md](.claude/skills/ccskill-gmail/examples.md) — Workflow examples
- [troubleshooting.md](.claude/skills/ccskill-gmail/troubleshooting.md) — Common issues and solutions

## Limitations

- No send capability (draft creation only; send manually from Gmail UI)
- Attachments: up to 5 MB
- Drafts are always HTML format, even when replying to plain text emails (GmailApp limitation — plain text line breaks are lost without HTML conversion)

## License

MIT License — see [LICENSE](LICENSE) for details.
