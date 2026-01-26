/**
 * Gmail Skill - Draft Handlers
 *
 * Draft creation and management operations.
 * Note: Sending is intentionally not supported - drafts should be reviewed and sent manually.
 */

/**
 * Create a new email draft
 * @param {string} to - Recipient email address(es), comma-separated for multiple
 * @param {string} subject - Email subject
 * @param {string} body - Email body (plain text)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting Tomorrow", "Hi, let's meet tomorrow at 10am.")
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting", "Body", "cc@example.com", "bcc@example.com")
 */
function handleCreateDraft(to, subject, body, cc, bcc) {
  requireParam(to, 'to');
  requireParam(subject, 'subject');
  requireParam(body, 'body');

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc
  });

  // Create the draft
  const draft = GmailApp.createDraft(to, subject, body, options);

  return successResponse({
    draftId: draft.getId(),
    to: to,
    subject: subject,
    message: '下書きを作成しました。Gmail で確認・送信してください。',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}
