/**
 * Gmail Skill - Draft Handlers
 *
 * Draft creation and management operations.
 * Note: Sending is intentionally not supported - drafts should be reviewed and sent manually.
 */

/**
 * Convert attachment array from base64 to Blob
 * @param {Array} attachments - [{filename, contentType, content(base64)}]
 * @returns {Array<Blob>} Blob array for GmailApp
 * @throws {Error} When total size exceeds 5MB
 */
function parseAttachments(attachments) {
  if (!attachments || !Array.isArray(attachments) || attachments.length === 0) {
    return [];
  }

  var MAX_ATTACHMENTS = 25;
  if (attachments.length > MAX_ATTACHMENTS) {
    throw new Error('Too many attachments: maximum is ' + MAX_ATTACHMENTS);
  }

  var totalSize = 0;
  var MAX_SIZE = 5 * 1024 * 1024; // 5MB

  return attachments.map(function(att, index) {
    if (!att.filename) {
      throw new Error('attachments[' + index + ']: filename is required');
    }
    if (!att.content) {
      throw new Error('attachments[' + index + ']: content (base64) is required');
    }

    // Estimate size from base64 string length
    var estimatedSize = Math.ceil(att.content.length * 3 / 4);
    totalSize += estimatedSize;
    if (totalSize > MAX_SIZE) {
      throw new Error('Total attachment size exceeds 5MB limit');
    }

    var contentType = att.contentType || 'application/octet-stream';
    var decoded = Utilities.base64Decode(att.content);

    return Utilities.newBlob(decoded, contentType, att.filename);
  });
}

/**
 * Create a new email draft
 * @param {string} to - Recipient email address(es), comma-separated for multiple
 * @param {string} subject - Email subject
 * @param {string} body - Email body (plain text, used as fallback)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @param {string} htmlBody - HTML body (optional, when specified body becomes plain text fallback)
 * @param {Array} attachments - Attachment array (optional, [{filename, contentType, content(base64)}])
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting Tomorrow", "Hi, let's meet tomorrow at 10am.")
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting", "Body", "cc@example.com", "bcc@example.com")
 */
function handleCreateDraft(to, subject, body, cc, bcc, htmlBody, attachments) {
  requireParam(to, 'to');
  requireParam(subject, 'subject');
  requireParam(body, 'body');

  // Auto-generate htmlBody from body when not specified (preserves line breaks)
  if (!htmlBody && body) {
    htmlBody = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');
  }

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc,
    htmlBody: htmlBody,
    attachments: parseAttachments(attachments)
  });

  // Create the draft
  const draft = GmailApp.createDraft(to, subject, body, options);

  return successResponse({
    draftId: draft.getId(),
    to: to,
    subject: subject,
    message: 'Draft created. Review and send it in Gmail.',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * Create a reply draft for an existing thread
 * @param {string} threadId - Thread ID to reply to
 * @param {string} body - Reply body (plain text, used as fallback)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @param {string} htmlBody - HTML body (optional, when specified body becomes plain text fallback)
 * @param {Array} attachments - Attachment array (optional, [{filename, contentType, content(base64)}])
 * @param {boolean} skipSelf - Skip own sent messages and reply to the other party's message (default true)
 * @param {boolean} replyAll - Reply to all recipients (default true)
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateReplyDraft("19bf7f25b96ab637", "Thank you for your email.")
 */
function handleCreateReplyDraft(threadId, body, cc, bcc, htmlBody, attachments, skipSelf, replyAll) {
  requireParam(threadId, 'threadId');
  requireParam(body, 'body');

  // Default: both true
  if (skipSelf === undefined || skipSelf === null) skipSelf = true;
  if (replyAll === undefined || replyAll === null) replyAll = true;

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'Verify the threadId is correct', retryable: false });
  }

  const messages = thread.getMessages();

  // skipSelf: find the most recent message not sent by self
  let targetMessage = messages[messages.length - 1]; // fallback
  if (skipSelf) {
    const myEmail = Session.getActiveUser().getEmail().toLowerCase();
    for (let i = messages.length - 1; i >= 0; i--) {
      const from = messages[i].getFrom().toLowerCase();
      if (!from.includes(myEmail)) {
        targetMessage = messages[i];
        break;
      }
    }
  }

  // Auto-generate htmlBody from body when not specified (preserves line breaks)
  if (!htmlBody && body) {
    htmlBody = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');
  }

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc,
    htmlBody: htmlBody,
    attachments: parseAttachments(attachments)
  });

  // Use replyAll or reply based on the flag
  const draft = replyAll
    ? targetMessage.createDraftReplyAll(body, options)
    : targetMessage.createDraftReply(body, options);

  // Return the actual draft recipient
  const draftMessage = draft.getMessage();

  return successResponse({
    draftId: draft.getId(),
    threadId: threadId,
    to: draftMessage.getTo(),
    subject: 'Re: ' + targetMessage.getSubject().replace(/^Re:\s*/i, ''),
    skipSelf: skipSelf,
    replyAll: replyAll,
    message: 'Reply draft created. Review and send it in Gmail.',
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
 * @param {string} htmlBody - HTML body (optional, retains existing HTML if omitted)
 * @returns {ContentService.TextOutput} JSON response with new draft info
 */
function handleUpdateDraft(draftId, to, subject, body, cc, bcc, htmlBody) {
  requireParam(draftId, 'draftId');

  const drafts = GmailApp.getDrafts();
  const draft = drafts.find(function(d) { return d.getId() === draftId; });
  if (!draft) {
    return errorResponse('Draft not found: ' + draftId,
      { code: 'NOT_FOUND', hint: 'Use list_drafts to verify the draftId', retryable: false });
  }

  const message = draft.getMessage();
  const currentTo = to || message.getTo();
  const currentSubject = subject || message.getSubject();
  const currentBody = body || message.getPlainBody();
  // Use htmlBody only when explicitly provided (falls back to getBody for existing HTML)
  const currentHtmlBody = htmlBody !== undefined ? htmlBody : message.getBody();

  // Determine if the draft is associated with a thread
  const thread = message.getThread();
  const threadMessages = thread.getMessages();
  const isReplyDraft = threadMessages.length > 1
    || (threadMessages.length === 1 && !threadMessages[0].isDraft());

  const options = buildEmailOptions({ cc: cc, bcc: bcc, htmlBody: currentHtmlBody });

  draft.deleteDraft();

  let newDraft;
  if (isReplyDraft) {
    // Reply draft: recreate against the most recent non-draft message from others
    const nonDraftMessages = threadMessages.filter(function(m) {
      return !m.isDraft();
    });
    let replyTarget = nonDraftMessages[nonDraftMessages.length - 1];

    // skipSelf: prefer messages from others
    const myEmail = Session.getActiveUser().getEmail().toLowerCase();
    for (let i = nonDraftMessages.length - 1; i >= 0; i--) {
      const from = nonDraftMessages[i].getFrom().toLowerCase();
      if (!from.includes(myEmail)) {
        replyTarget = nonDraftMessages[i];
        break;
      }
    }

    if (to) options.to = to;
    newDraft = replyTarget.createDraftReplyAll(currentBody, options);
  } else {
    // New draft: create as usual
    newDraft = GmailApp.createDraft(currentTo, currentSubject, currentBody, options);
  }

  return successResponse({
    draftId: newDraft.getId(),
    oldDraftId: draftId,
    threadId: thread.getId(),
    isReply: isReplyDraft,
    action: 'update_draft',
    message: 'Draft updated',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * List drafts
 * @param {number} maxResults - Maximum number of results (default 20, max 100)
 * @returns {ContentService.TextOutput} JSON response with draft list
 *
 * @example
 * handleListDrafts(20)
 */
function handleListDrafts(maxResults) {
  let limit = maxResults || 20;
  if (limit > 100) {
    limit = 100;
  }

  const drafts = GmailApp.getDrafts();
  const total = drafts.length;

  // Truncate by maxResults
  const sliced = drafts.slice(0, limit);

  const results = sliced.map(function(draft) {
    const message = draft.getMessage();
    const plainBody = message.getPlainBody() || '';
    let snippet = plainBody.substring(0, 100);
    if (plainBody.length > 100) {
      snippet += '...';
    }

    return {
      draftId: draft.getId(),
      subject: message.getSubject(),
      to: message.getTo(),
      snippet: snippet,
      lastDate: message.getDate().toISOString()
    };
  });

  return successResponse({
    total: total,
    count: results.length,
    drafts: results
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
    return errorResponse('Draft not found: ' + draftId,
      { code: 'NOT_FOUND', hint: 'Use list_drafts to verify the draftId', retryable: false });
  }

  draft.deleteDraft();

  return successResponse({
    draftId: draftId,
    action: 'delete_draft',
    message: 'Draft deleted'
  });
}
