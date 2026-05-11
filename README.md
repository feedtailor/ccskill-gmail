# ccskill-gmail

**Make Gmail work a whole lot easier.**

ccskill-gmail is a skill that complements Claude Code's built-in Gmail connector (MCP). It adds what the standard connector can't do — attachment downloads, mail-body PDF export, prompt-injection defenses — plus local audit logging of every Claude Code action and support for multiple Gmail accounts.

For everyday search, reading, and reply drafting alone, the standard Gmail connector may feel more natural to use — but ccskill-gmail covers those cases too.

[日本語版 README はこちら](README.ja.md)

## Feature comparison

| Capability / task | Gmail Connector | Workspace MCP (preview) | ccskill-gmail |
|---|:---:|:---:|:---:|
| Search and read mail | ○ | ○ | ○ |
| Draft creation | ○ | ○ | ○ |
| Label add / remove | × | ○ | ○ |
| Move to trash | × | × | ○ |
| Archive | × | × | ○ |
| Toggle read / unread | × | × | ○ |
| Add star | × | × | ○ |
| Attachment download (invoice PDFs, etc.) | × | × | ○ |
| Export mail body to PDF | × | × | ○ |
| Prompt-injection defenses (neutralizes hidden prompts in HTML mail) | × | × | ○ |
| Local audit log of every operation | × | × | ○ |
| Multi-account support | × | × | ○ |
| Build custom Gmail scripts | × | × | ○ |

Sources: [Claude official docs — "Use Google Workspace Connectors"](https://support.claude.com/en/articles/10166901-use-google-workspace-connectors) / [Google — "Configure Workspace MCP servers"](https://developers.google.com/workspace/guides/configure-mcp-servers). Workspace MCP is in preview at the time of writing — the surface may change.

## Distinctive features

### Attachment downloads

ccskill-gmail can download attachment file contents. You can have them saved with names derived from the email body, or hand them off as input for Claude Code's next step.

### Save mail body as PDF

You can save a mail body as a PDF file. Both HTML mail and plain-text mail are supported.

### Multi-account support

The standard Gmail connector only sees the single account linked to Claude. ccskill-gmail connects to any Gmail account on a per-project-directory basis.

```bash
cd /path/to/work-project    # operates on work@company.com
cd /path/to/personal-blog   # operates on you@gmail.com
cd /path/to/client-x        # operates on sales@client-x.example
```

A single project directory can be bound to one Gmail account.

### Operation history

You can look back at the work ccskill-gmail has done.

This is implemented by writing every operation — mail search, content fetch, draft creation, attachment download, and so on — to a local audit log in JSONL.

Only the action name and Gmail thread ID are recorded; subjects, bodies, and recipients are not. When you ask Claude Code to display  history, the information is looked up using those thread IDs.

### Build your own Gmail scripts

The bundled `.ccskill-gmail/api` works as a Gmail operation script. You can use it to have Claude Code build programs that integrate with Gmail. No GCP API key (and no OAuth setup) is required.

### Security

- **No send feature.** Claude Code prepares the draft; you send it yourself from Gmail (same design as the standard connector)
- **Move-to-trash is off by default.** Opt in via `config.js` if you really need it
- **Prompt-injection defenses.** Hidden instructions embedded in HTML mail (CSS hiding, zero-width characters, white-on-white text, and so on) are neutralized in the GAS layer before they ever reach the AI
- **Built on Google account authentication.** The skill is designed around being authenticated with a Google account.

## Specific examples

### Organize attached receipts

> "Find all receipt emails from ACME Corp in the last 6 months and save the attached PDFs as `20260401_VendorName_TotalWithTax_receipt.pdf`"

### Make sense of past mail threads

> "Trace the entire email history with John at ACME Corp and create a handover document including background, open tasks, and work in progress. Export the list as Excel"

> "Search all incident response emails for the XYZ system from the past year and create a table of occurrence date, root cause, and resolution"

### Context-aware reply drafts

> "Find all external emails from the past month I haven't replied to. List them with sender, subject, and days since received. Draft follow-up replies for the important ones"

### Look back at recent work

> "Show me what I asked the skill last week, in order"

### Archive what you don't need

> "List all mailing lists and automated notifications by sender, frequency, and last received date. Archive any that have sat unread for more than 3 months"

### Build your own scripts

> "Write a script that searches likely-spam mails and extracts sender domains"

> "Write a script to bulk-download PDF attachments from this month's invoice mails"

> "Generate a daily unread-mail summary as Markdown"

## Requirements

- Google account (personal or Google Workspace)
- Node.js / npm
- jq
- Google Apps Script API enabled — first-time GAS users must turn on [the Google Apps Script API setting](https://script.google.com/home/usersettings)

## Installation

### 1. Get the skill

**git clone:**

```bash
cd ~/projects
git clone https://github.com/feedtailor/ccskill-gmail.git
```

**zip distribution:**

```bash
cd ~/projects
unzip ccskill-gmail-XXXXXX.zip
```

### 2. Run the setup script

Installs clasp, registers PATH, and handles Google login.

```bash
cd ~/projects/ccskill-gmail
./ccskill-gmail setup
```

### 3. Install into your project

Run the install command from the directory of the project you want to use the skill in.

```bash
cd /path/to/your-project
ccskill-gmail install
```

GAS project creation and deployment happen automatically. A browser will open partway through for Google authorization — click "Allow".

### 4. Verify

After installation, run `ccskill-gmail info`. You should see something like the output below — confirm that the project directory is wired up to the Gmail account you intended.

```bash
  Account:       ccskill-gmail@example.com
  Directory:     /path/to/your-project
  Version:       999ce0e
  Installed:     2026-05-06 01:23:45

  Permissions:
    Denied:      move_to_trash

  Inbox:         xxxx unread
  Starred:       xx unread
```

## Update

ccskill-gmail receives feature additions and bug fixes from time to time.

### git clone

In the directory where you cloned ccskill-gmail, run `git pull` and then the update-all command. It detects every project where ccskill-gmail is installed and updates all of them.

```bash
cd ~/projects/ccskill-gmail
git pull
ccskill-gmail update-all
```

You can also update one project at a time.

```bash
cd /path/to/your-project/
ccskill-gmail update
```

### zip distribution

Download the new zip, extract it over the project directory, then apply with `ccskill-gmail update`.

## Uninstall

```bash
ccskill-gmail uninstall
```

This removes local files (`.ccskill-gmail/`, skill definitions, permission settings). The Google Apps Script project is **not** automatically deleted — remove it manually from [script.google.com](https://script.google.com) if you want it gone.

## Other commands

```bash
ccskill-gmail help                # Show all commands
ccskill-gmail info [--json]       # Show details for the current project (account, permissions, unread)
ccskill-gmail status [--refresh]  # List all installations and their status
ccskill-gmail doctor              # Diagnose environment and setup issues
ccskill-gmail history             # Show the API operation audit log
ccskill-gmail apply-config        # Push config.js changes to GAS
ccskill-gmail register <PATH>     # Register an existing installation
ccskill-gmail release             # Create a distributable zip file
```

## Using multiple accounts

To switch between Google accounts, use the `--user` option. `--user` accepts only alphanumeric characters, hyphens, and underscores (e.g. `work`, `personal2`, `info-ft`).

```bash
cd /path/to/work-project
ccskill-gmail install --user work
```

A separate Google login may be required mid-flow. The Google account becomes bound to the project directory.

## Technical details

### Architecture

ccskill-gmail does not use the GCP Gmail API. Instead, it deploys a bridge API as a GAS (Google Apps Script) project accessible only to the authenticated user, and Claude Code calls that bridge.

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

Each Google account is bound to a project directory, so the Gmail account being operated on changes per project.

### Permissions

During setup, Google will ask you to grant permissions.

**clasp permissions (during setup)**

| Permission | What it's for |
|---|---|
| View and manage Google Drive files | Create and update GAS project files |
| View and manage Apps Script projects | Create the GAS project and push code |
| View and manage deployments | Deploy the Web App |

These are the standard permissions clasp (Google's official CLI for GAS) requests. ccskill-gmail relies on clasp, so they are required.

**Gmail permissions (on first use)**

| Permission (OAuth scope) | What it's for |
|---|---|
| `gmail.readonly` | Search and read mail, list labels, download attachments |
| `gmail.compose` | Create and edit drafts |
| `gmail.modify` | Toggle read/unread, add/remove labels, archive, move to trash |

Only the minimum scopes required are requested. The `gmail.send` scope is **not** requested.

### Skill definition documents

For API specifications and troubleshooting, see the skill definition documents:

- [SKILL.md](.claude/skills/ccskill-gmail/SKILL.md) — API specification and rules
- [examples.md](.claude/skills/ccskill-gmail/examples.md) — Workflow examples
- [troubleshooting.md](.claude/skills/ccskill-gmail/troubleshooting.md) — Common issues and solutions

## Troubleshooting

### Installation fails midway

Re-run `ccskill-gmail install`. You'll be asked "Overwrite?" — answer `y` to start over. A failed install can leave a stranded GAS project on Google's side; remove it manually from [script.google.com](https://script.google.com) before retrying.

### Redirect loop or "Unable to open file" when the browser opens

This happens when you're already signed in to multiple Google accounts in the browser, or a session from a different account is still cached. Try the following:

1. Copy the **Authorization URL** shown in your terminal (starts with `https://script.google.com/macros/s/...`)
2. Open a **new private/incognito window** (close any existing private windows first)
3. Go to [accounts.google.com](https://accounts.google.com) and sign in with the Google account you want to bind
4. In the same window, paste the Authorization URL from step 1 into the address bar
5. Click "Allow"

**Important:**
- Do **not** copy the URL from the browser's error page — always use the URL **shown in your terminal**
- Sign in at accounts.google.com **before** opening the Authorization URL. Opening the URL first will trigger the same redirect loop

### Multi-account OAuth errors

If you encounter authentication errors while using `--user`, run `ccskill-gmail doctor` from the project directory. The doctor command checks the full chain — clasp login, OAuth tokens, endpoint connectivity — and tells you exactly what's broken with fix suggestions.

### Something doesn't work after update

Run `ccskill-gmail doctor` to diagnose. If the issue persists, try `ccskill-gmail update --force` to redeploy the GAS project from scratch.

## Support

No support is provided — questions will not be answered. This is offered free of charge, so please understand. If you need support for commercial use, please consider a contract via [this page](https://www.feedtailor.jp/product_advisory-claudecode/).

## License

MIT License
