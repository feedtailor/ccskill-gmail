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
