# Command reference

[← Back to README](../README.md) ・ [日本語版](commands.ja.md)

`ccskill-gmail <command> [args...]`. Run `ccskill-gmail help` for the built-in summary.

## Setup

| Command | Description |
|---|---|
| `./ccskill-gmail setup` | One-time install: installs clasp locally, registers ccskill-gmail in your PATH, then registers the user skill (`skill install`) and, if no account is registered yet, your Gmail account (`account add`) |
| `ccskill-gmail uninstall --all [--yes\|--dry-run]` | Remove ccskill-gmail from this machine: user skill, all account registrations, and the CLI symlink (GAS projects and clasp tokens are left for you to remove) |

## Accounts

| Command | Description |
|---|---|
| `ccskill-gmail account add [--label NAME]` | Register a Gmail account (provisions its shared GAS, opens a browser for authorization). `--label` is optional; if omitted, you're asked for a label after signing in (from the second account onward) |
| `ccskill-gmail account list` | List registered accounts (`*` marks the default) |
| `ccskill-gmail account default <email\|label>` | Change the default account |
| `ccskill-gmail account update [<email\|label>]` | Redeploy the shared GAS for all (or one) registered accounts |
| `ccskill-gmail account remove <email\|label>` | Remove an account from the registry |

## Skill registration

| Command | Description |
|---|---|
| `ccskill-gmail skill install [--copy]` | Register the user skill (`~/.claude/skills/`). Default is a symlink; `--copy` makes a real copy |
| `ccskill-gmail skill uninstall` | Remove the user skill registration |

## Directory binding

| Command | Description |
|---|---|
| `ccskill-gmail bind <email\|label> [DIR]` | Pin a directory to an account (writes `binding.json`) |
| `ccskill-gmail unbind [--purge-legacy] [DIR]` | Remove the pin (and optionally legacy per-project install files) |

## Using the API

| Command | Description |
|---|---|
| `ccskill-gmail api whoami` | Show which account a call resolves to, and why |
| `ccskill-gmail api get action=... [params]` | Call a read action (search, get_thread, get_profile, …) |
| `ccskill-gmail api post '{"action":...}'` | Call a write action (create_draft, add_label, …) |
| `ccskill-gmail api download\|save-html\|save-pdf ...` | Attachment download / mail-body export |

See [SKILL.md](../.claude/skills/ccskill-gmail/SKILL.md) for the full API specification.

## Status and diagnostics

| Command | Description |
|---|---|
| `ccskill-gmail info [--json] [DIR]` | Show details for a directory (account, permissions, unread) |
| `ccskill-gmail status [--refresh]` | List all installations and their status |
| `ccskill-gmail doctor` | Diagnose environment and setup issues |
| `ccskill-gmail history [--all]` | Show the API operation audit log |

## Migration and maintenance

| Command | Description |
|---|---|
| `ccskill-gmail migrate [--dry-run]` | Consolidate pre-central per-project installs onto the account registry |
| `ccskill-gmail update-all` | Update the shared GAS of every account, plus any legacy per-project installs |
| `ccskill-gmail register <PATH>...` | Register an existing installation |
| `ccskill-gmail release [DIR]` | Create a distributable zip file |

## Per-project (legacy / advanced)

These apply to dedicated per-project installs and are not needed for the standard account-shared setup.

| Command | Description |
|---|---|
| `ccskill-gmail install [--account NAME] [--dedicated] [DIR]` | Pin a project to an account (`--dedicated` creates a per-project GAS) |
| `ccskill-gmail uninstall [DIR]` | Remove a per-project install's local files |
| `ccskill-gmail update [DIR]` | Update one project |
| `ccskill-gmail apply-config [DIR]` | Push `config.js` changes to a dedicated GAS |
