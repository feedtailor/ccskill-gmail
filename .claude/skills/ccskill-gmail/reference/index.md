# Gmail Skill API Reference

## Prerequisites

`.ccskill-gmail/api` is a standalone script. The endpoint and authentication are automatically resolved internally by the script.

## Read Operations (GET)

| API | File | Example |
|-----|------|---------|
| search | [search.md](search.md) | `.ccskill-gmail/api get action=search query="is:unread"` |
| get_thread | [read.md](read.md) | `.ccskill-gmail/api get action=get_thread threadId=ID` |
| get_message | [read.md](read.md) | `.ccskill-gmail/api get action=get_message messageId=ID` |
| list_labels | [read.md](read.md) | `.ccskill-gmail/api get action=list_labels` |
| get_unread_count | [read.md](read.md) | `.ccskill-gmail/api get action=get_unread_count` |

## Write Operations (POST)

| API | File | Description |
|-----|------|-------------|
| create_draft | [draft.md](draft.md) | Create a new email draft |
| create_reply_draft | [draft.md](draft.md) | Create a reply draft to an existing thread |
| update_draft | [draft.md](draft.md) | Update a draft |
| delete_draft | [draft.md](draft.md) | Delete a draft |
| mark_read | [status.md](status.md) | Mark as read |
| mark_unread | [status.md](status.md) | Mark as unread |
| add_label | [label.md](label.md) | Add a label |
| remove_label | [label.md](label.md) | Remove a label |
| archive | [thread.md](thread.md) | Archive |
| move_to_trash | [thread.md](thread.md) | Move to trash |
| bulk_mark_read | (see README) | Bulk mark threads as read |
| bulk_mark_unread | (see README) | Bulk mark threads as unread |
| bulk_add_label | (see README) | Bulk add label to threads |
| bulk_remove_label | (see README) | Bulk remove label from threads |
| bulk_archive | (see README) | Bulk archive threads |

## Workflows

| Workflow | File | Description |
|----------|------|-------------|
| Inbox Triage | [triage.md](triage.md) | Structured inbox review and classification |
| Commitment Extraction | [commitment.md](commitment.md) | Extract action items and promises from threads |
