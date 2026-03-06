/**
 * Gmail Skill - Read Handlers
 *
 * Email reading operations: get thread, get message, list labels.
 */

/**
 * Get a thread by ID with all messages
 * @param {string} threadId - Gmail thread ID
 * @returns {ContentService.TextOutput} JSON response with thread and messages
 *
 * @example
 * handleGetThread("18d1a2b3c4d5e6f7")
 */
function handleGetThread(threadId) {
  requireParam(threadId, 'threadId');

  const thread = GmailApp.getThreadById(threadId);

  if (!thread) {
    return errorResponse(`Thread not found: ${threadId}`);
  }

  return successResponse(formatThreadWithMessages(thread));
}

/**
 * Get a single message by ID
 * @param {string} messageId - Gmail message ID
 * @returns {ContentService.TextOutput} JSON response with message details
 *
 * @example
 * handleGetMessage("18d1a2b3c4d5e6f7")
 */
function handleGetMessage(messageId) {
  requireParam(messageId, 'messageId');

  const message = GmailApp.getMessageById(messageId);

  if (!message) {
    return errorResponse(`Message not found: ${messageId}`);
  }

  return successResponse(formatMessage(message));
}

/**
 * List all user-created labels
 * @returns {ContentService.TextOutput} JSON response with label list
 *
 * @example
 * handleListLabels()
 */
function handleListLabels() {
  const labels = GmailApp.getUserLabels();

  return successResponse({
    count: labels.length,
    labels: labels.map(formatLabel)
  });
}

/**
 * List attachments for a message
 * @param {string} messageId - Gmail message ID
 * @returns {ContentService.TextOutput} JSON response with attachment list
 *
 * @example
 * handleListAttachments("18d1a2b3c4d5e6f7")
 */
function handleListAttachments(messageId) {
  requireParam(messageId, 'messageId');

  var message = GmailApp.getMessageById(messageId);

  if (!message) {
    return errorResponse('Message not found: ' + messageId);
  }

  var attachments = message.getAttachments();

  return successResponse({
    messageId: messageId,
    attachments: attachments.map(function(attachment, index) {
      return {
        index: index,
        filename: attachment.getName(),
        contentType: attachment.getContentType(),
        size: attachment.getSize()
      };
    })
  });
}

/**
 * Get a single attachment with base64-encoded content
 * @param {string} messageId - Gmail message ID
 * @param {number} attachmentIndex - Attachment index (0-based)
 * @returns {ContentService.TextOutput} JSON response with attachment data
 *
 * @example
 * handleGetAttachment("18d1a2b3c4d5e6f7", 0)
 */
function handleGetAttachment(messageId, attachmentIndex) {
  requireParam(messageId, 'messageId');
  if (attachmentIndex === undefined || attachmentIndex === null || attachmentIndex === '') {
    throw new Error('Missing required parameter: attachmentIndex');
  }

  var index = parseInt(attachmentIndex);
  if (isNaN(index) || index < 0) {
    return errorResponse('attachmentIndex must be a non-negative integer');
  }

  var message = GmailApp.getMessageById(messageId);

  if (!message) {
    return errorResponse('Message not found: ' + messageId);
  }

  var attachments = message.getAttachments();

  if (index >= attachments.length) {
    return errorResponse(
      'Attachment index out of range: ' + index +
      ' (message has ' + attachments.length + ' attachment(s))'
    );
  }

  var attachment = attachments[index];
  var size = attachment.getSize();

  // GAS レスポンスサイズ制限対策（5MB 超は拒否）
  if (size > 5 * 1024 * 1024) {
    return errorResponse(
      'Attachment too large: ' + attachment.getName() +
      ' (' + Math.round(size / 1024 / 1024 * 10) / 10 + 'MB). ' +
      'Maximum supported size is 5MB.'
    );
  }

  return successResponse({
    filename: attachment.getName(),
    contentType: attachment.getContentType(),
    size: size,
    content: Utilities.base64Encode(attachment.getBytes())
  });
}

/**
 * Get message body as HTML
 * @param {string} messageId - Gmail message ID
 * @param {string} includeHeaders - Whether to prepend email headers in HTML ("true"/"false", default "true")
 * @returns {ContentService.TextOutput} JSON response with HTML body
 *
 * @example
 * handleGetMessageHtml("18d1a2b3c4d5e6f7", "true")
 */
function handleGetMessageHtml(messageId, includeHeaders) {
  requireParam(messageId, 'messageId');

  var message = GmailApp.getMessageById(messageId);

  if (!message) {
    return errorResponse('Message not found: ' + messageId);
  }

  var html = message.getBody();
  var addHeaders = (includeHeaders !== 'false');

  if (addHeaders) {
    var headerHtml =
      '<div style="font-family: sans-serif; margin-bottom: 20px; padding: 10px; border-bottom: 1px solid #ccc;">' +
      '<p><strong>From:</strong> ' + escapeHtml_(message.getFrom()) + '</p>' +
      '<p><strong>To:</strong> ' + escapeHtml_(message.getTo()) + '</p>' +
      '<p><strong>Date:</strong> ' + message.getDate().toISOString() + '</p>' +
      '<p><strong>Subject:</strong> ' + escapeHtml_(message.getSubject()) + '</p>' +
      '</div>';
    html = headerHtml + html;
  }

  return successResponse({
    messageId: messageId,
    subject: message.getSubject(),
    from: message.getFrom(),
    to: message.getTo(),
    date: message.getDate().toISOString(),
    html: html
  });
}

/**
 * Escape HTML special characters
 * @param {string} str - Input string
 * @returns {string} Escaped string
 */
function escapeHtml_(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Get unread message count
 * @param {string} labelName - Label name (optional, defaults to INBOX)
 * @returns {ContentService.TextOutput} JSON response with unread count
 *
 * @example
 * handleGetUnreadCount() // INBOX の未読数
 *
 * @example
 * handleGetUnreadCount("重要") // 特定ラベルの未読数
 */
function handleGetUnreadCount(labelName) {
  let unreadCount;
  let targetLabel = labelName || 'INBOX';

  if (!labelName || labelName.toUpperCase() === 'INBOX') {
    // 受信トレイの未読数
    unreadCount = GmailApp.getInboxUnreadCount();
    targetLabel = 'INBOX';
  } else {
    // 特定ラベルの未読数
    const label = GmailApp.getUserLabelByName(labelName);
    if (!label) {
      return errorResponse(`Label not found: ${labelName}`);
    }
    unreadCount = label.getUnreadCount();
    targetLabel = labelName;
  }

  return successResponse({
    label: targetLabel,
    unreadCount: unreadCount,
    message: `未読メールが ${unreadCount} 件あります`
  });
}

/**
 * アカウントのプロフィール情報を取得
 * @returns {ContentService.TextOutput} JSON response with profile info
 *
 * @example
 * handleGetProfile()
 */
function handleGetProfile() {
  const email = Session.getActiveUser().getEmail();
  const inboxUnreadCount = GmailApp.getInboxUnreadCount();
  const starredUnreadCount = GmailApp.getStarredUnreadCount();

  return successResponse({
    email: email,
    inboxUnreadCount: inboxUnreadCount,
    starredUnreadCount: starredUnreadCount
  });
}
