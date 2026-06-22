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
| Multi-account support | × | × | ◎ |
| Move to trash | × | × | ○ |
| Archive | × | × | ○ |
| Toggle read / unread | × | × | ○ |
| Add star | × | × | ○ |
| Attachment download (invoice PDFs, etc.) | × | × | ○ |
| Export mail body to PDF | × | × | ○ |
| Prompt-injection defenses (neutralizes hidden prompts in HTML mail) | × | × | ○ |
| Local audit log of every operation | × | × | ○ |
| Build custom Gmail scripts | × | × | ○ |

Sources: [Claude official docs — "Use Google Workspace Connectors"](https://support.claude.com/en/articles/10166901-use-google-workspace-connectors) / [Google — "Configure Workspace MCP servers"](https://developers.google.com/workspace/guides/configure-mcp-servers)

## Distinctive features

### Multi-account support

The standard Gmail connector only sees the single account linked to Claude. ccskill-gmail registers any number of Gmail accounts centrally from a single install — set a default and switch per request. In Claude Code you can simply say things like "check this on my personal account", or pin a directory so everything run there uses a specific account.

(Setup commands are in [Using multiple accounts](#using-multiple-accounts), after installation.)

### Attachment downloads

ccskill-gmail can download attachment file contents. You can have them saved with names derived from the email body, or hand them off as input for Claude Code's next step.

### Save mail body as PDF

You can save a mail body as a PDF file. Both HTML mail and plain-text mail are supported.

### Operation history

You can look back at the work ccskill-gmail has done.

This is implemented by writing every operation — mail search, content fetch, draft creation, attachment download, and so on — to a local audit log in JSONL.

Only the action name and Gmail thread ID are recorded; subjects, bodies, and recipients are not. When you ask Claude Code to display  history, the information is looked up using those thread IDs.

### Build your own Gmail scripts

The `ccskill-gmail api` command works as a Gmail operation script callable from anywhere. You can use it to have Claude Code build programs that integrate with Gmail. No GCP API key (and no OAuth setup) is required.

### Security

- **No send feature.** Claude Code prepares the draft; you send it yourself from Gmail (same design as the standard connector)
- **Move-to-trash is off by default.** Opt in via `config.js` if you really need it
- **Prompt-injection defenses.** Hidden instructions embedded in HTML mail (CSS hiding, zero-width characters, white-on-white text, and so on) are neutralized in the GAS layer before they ever reach the AI
- **Built on Google account authentication.** The skill is designed around being authenticated with a Google account.

## Specific examples

### Work across multiple accounts

> "Check both my work and personal accounts for external emails I haven't replied to this week, and list them by account with sender and subject"

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

> "Write a script to bulk-download PDF attachments from this month's invoice mails"

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

```bash
cd ~/projects/ccskill-gmail
./ccskill-gmail setup
```

`setup` handles the whole install — it installs clasp, registers ccskill-gmail in your PATH, registers the user skill (so every project can use Gmail, no per-project install), and registers your Gmail account. A browser opens partway through for Google authorization — click "Allow".

That's it. Verify with:

```bash
ccskill-gmail api whoami
```

### 3. Registering additional accounts (optional)

To add a second (or later) account, run `account add`. A Google sign-in page opens in the browser — sign in with the account you want to add (the email address is determined automatically, so there's nothing to type).

```bash
ccskill-gmail account add     # sign in in the browser → that account gets registered
```

When you register a second (or later) account, you're asked for a **label** (a nickname) for it. Give it something memorable like `work` or `personal` and you can address it by that name from then on (alphanumeric, hyphens, underscores; skip it to address the account by email).

```bash
ccskill-gmail account add                    # enter a label after signing in (e.g. work)
ccskill-gmail account list                   # * marks the default
ccskill-gmail account default work           # change the default
```

If you already know the label, you can pass it up front with `--label` (you won't be asked then).

```bash
ccskill-gmail account add --label work
```

To choose which account to use, just name it (by label or email) in your request to Claude Code. If you don't, the default account is used.

## Already using ccskill-gmail? (older per-project setup)

If you used to run `ccskill-gmail install` per project, pull the latest code and consolidate those installs onto the central account registry with `migrate` (your existing installs keep working, so this is optional):

```bash
cd ~/projects/ccskill-gmail
git pull
ccskill-gmail migrate            # consolidate onto the central accounts (--dry-run to preview)
```

`migrate` registers your accounts from the existing installs, so no separate sign-in is needed, and it deletes nothing.

## Update

ccskill-gmail receives feature additions and bug fixes from time to time.

### git clone

Pull the latest code, then redeploy your account's shared GAS:

```bash
cd ~/projects/ccskill-gmail
git pull
ccskill-gmail account update          # redeploy the shared GAS for every registered account
```

The user skill is a symlink to this repository, so it's already current after `git pull`.

### zip distribution

Extract the new zip over the ccskill-gmail directory, then redeploy your account's shared GAS (just `unzip -o` instead of `git pull`):

```bash
cd ~/projects
unzip -o ccskill-gmail-XXXXXX.zip     # extract over the existing directory
ccskill-gmail account update          # redeploy the shared GAS for every registered account
```

The user skill is a symlink to this directory, so re-extracting keeps it current — no reinstall needed.

## Uninstall

Remove ccskill-gmail from this machine in one shot (user skill, all accounts, and the CLI):

```bash
ccskill-gmail uninstall --all          # shows what will be removed, then removes it (--dry-run to preview)
```

GAS projects (on Google's side) and clasp tokens are **not** deleted automatically — remove the GAS projects from [script.google.com](https://script.google.com) if you want them gone.

## Further reading

| Document | Contents |
|---|---|
| [Command reference](docs/commands.md) | All commands and their options |
| [Technical details](docs/technical-details.md) | Architecture, clasp / Gmail permission scopes, skill definition docs |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and fixes (auth errors, changes not taking effect, etc.) |

## Support

No support is provided — questions will not be answered. This is offered free of charge, so please understand. If you need support for commercial use, please consider a contract via [this page](https://www.feedtailor.jp/product_advisory-claudecode/).

## License

MIT License
