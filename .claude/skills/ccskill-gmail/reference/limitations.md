# Limitations

- **Permission control**: The `permissions` setting in `config.js` allows controlling specific actions with allow/deny (following Claude Code's allow/deny pattern). `move_to_trash` is disabled by default. To enable it, remove it from `permissions.deny`. The config location and re-deploy command depend on your setup: for the account-shared setup edit `~/.ccskill-gmail/gas/<clasp_user>/config.js` and run `ccskill-gmail account update`; for a dedicated per-project install edit `.ccskill-gmail/config.js` and run `ccskill-gmail apply-config`.
- **No send functionality**: Only draft creation is supported (sending is done manually via the Gmail UI).
- **Authentication**: Requires `clasp login` to be completed and the Web App to be published as "Only myself".
- **Token management**: The `gas_token` function handles automatic refresh. If the `clasp login` session expires, re-login is required.
- **OAuth authorization**: Browser-based OAuth authorization is required on first install (one-time only).
- **Endpoint restriction**: Only `https://script.google.com/*` is allowed (security measure).
- **Rate limiting**: GAS execution time limits apply (6 minutes per execution).
- **Attachments**: Supports downloading (`list_attachments` / `get_attachment`) and attaching to drafts (`attachments` parameter in `create_draft` / `create_reply_draft`).
- **Attachment size limit**: `get_attachment` rejects files over 5MB. Draft attachments are also limited to 5MB total. Use the Gmail UI for larger files.
- **Reply draft recipient cannot be changed**: `update_draft` cannot change the `to` (recipient) of a reply draft (GmailApp API limitation). `cc` / `bcc` / `body` / `subject` can be changed. If the recipient needs to be changed, instruct the user to "manually change the recipient when reviewing the draft in Gmail".
- **Recipient address must be ASCII**: The address part (addr-spec) of `to` / `cc` / `bcc` must be ASCII only; a non-ASCII addr-spec (e.g. `【要入力】@example.co.jp`) is rejected with `code: INVALID_ADDRESS` because GmailApp would otherwise produce mojibake. A non-ASCII **display name** is fine via the RFC 5322 name-addr form `"\"表示名\" <address@example.com>"` (the address itself stays ASCII). See `reference/draft.md` for details.
