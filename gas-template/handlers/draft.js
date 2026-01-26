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

/**
 * Update an existing draft
 * Note: GmailApp doesn't support direct draft update, so we delete and recreate.
 * @param {string} draftId - Draft ID to update
 * @param {string} to - New recipient (optional)
 * @param {string} subject - New subject (optional)
 * @param {string} body - New body (optional)
 * @param {string} cc - New CC recipients (optional)
 * @param {string} bcc - New BCC recipients (optional)
 * @returns {ContentService.TextOutput} JSON response with new draft info
 */
function handleUpdateDraft(draftId, to, subject, body, cc, bcc) {
  requireParam(draftId, 'draftId');

  // Get existing draft
  const drafts = GmailApp.getDrafts();
  const draft = drafts.find(function(d) { return d.getId() === draftId; });

  if (!draft) {
    return errorResponse(`Draft not found: ${draftId}`);
  }

  // Get current message content
  const message = draft.getMessage();
  const currentTo = to || message.getTo();
  const currentSubject = subject || message.getSubject();
  const currentBody = body || message.getPlainBody();

  // Build options
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc
  });

  // Delete old draft and create new one
  draft.deleteDraft();
  const newDraft = GmailApp.createDraft(currentTo, currentSubject, currentBody, options);

  return successResponse({
    draftId: newDraft.getId(),
    oldDraftId: draftId,
    action: 'update_draft',
    message: '下書きを更新しました',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * Delete a draft
 * @param {string} draftId - Draft ID to delete
 * @returns {ContentService.TextOutput} JSON response
 */
function handleDeleteDraft(draftId) {
  requireParam(draftId, 'draftId');

  const drafts = GmailApp.getDrafts();
  const draft = drafts.find(function(d) { return d.getId() === draftId; });

  if (!draft) {
    return errorResponse(`Draft not found: ${draftId}`);
  }

  draft.deleteDraft();

  return successResponse({
    draftId: draftId,
    action: 'delete_draft',
    message: '下書きを削除しました'
  });
}
