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

/**
 * Create a reply draft for an existing thread
 * @param {string} threadId - Thread ID to reply to
 * @param {string} body - Reply body (plain text)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateReplyDraft("19bf7f25b96ab637", "Thank you for your email.")
 */
function handleCreateReplyDraft(threadId, body, cc, bcc) {
  requireParam(threadId, 'threadId');
  requireParam(body, 'body');

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse(`Thread not found: ${threadId}`);
  }

  // Get the last message in the thread to reply to
  const messages = thread.getMessages();
  const lastMessage = messages[messages.length - 1];

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc
  });

  // Create reply draft
  const draft = lastMessage.createDraftReply(body, options);

  return successResponse({
    draftId: draft.getId(),
    threadId: threadId,
    to: lastMessage.getFrom(),
    subject: 'Re: ' + lastMessage.getSubject().replace(/^Re:\s*/i, ''),
    message: '返信下書きを作成しました。Gmail で確認・送信してください。',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}
