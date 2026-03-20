/**
 * Gmail Skill - Status Handlers
 *
 * Read/Unread status operations.
 */

/**
 * Mark a thread or message as read
 * @param {string} threadId - Thread ID (optional if messageId provided)
 * @param {string} messageId - Message ID (optional if threadId provided)
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleMarkRead("19bf7f25b96ab637", null) // Mark thread as read
 *
 * @example
 * handleMarkRead(null, "19bf7f25b96ab637") // Mark message as read
 */
function handleMarkRead(threadId, messageId) {
  if (!threadId && !messageId) {
    return errorResponse('Either threadId or messageId is required',
      { code: 'MISSING_PARAM', hint: 'threadId または messageId を指定してください', retryable: false });
  }

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) {
      return errorResponse('Thread not found: ' + threadId,
        { code: 'NOT_FOUND', hint: 'threadId が正しいか確認してください', retryable: false });
    }
    thread.markRead();
    return successResponse({
      threadId: threadId,
      action: 'mark_read',
      message: 'スレッドを既読にしました'
    });
  } else {
    const message = GmailApp.getMessageById(messageId);
    if (!message) {
      return errorResponse('Message not found: ' + messageId,
        { code: 'NOT_FOUND', hint: 'messageId が正しいか確認してください', retryable: false });
    }
    message.markRead();
    return successResponse({
      messageId: messageId,
      action: 'mark_read',
      message: 'メッセージを既読にしました'
    });
  }
}

/**
 * Mark a thread or message as unread
 * @param {string} threadId - Thread ID (optional if messageId provided)
 * @param {string} messageId - Message ID (optional if threadId provided)
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleMarkUnread("19bf7f25b96ab637", null) // Mark thread as unread
 *
 * @example
 * handleMarkUnread(null, "19bf7f25b96ab637") // Mark message as unread
 */
function handleMarkUnread(threadId, messageId) {
  if (!threadId && !messageId) {
    return errorResponse('Either threadId or messageId is required',
      { code: 'MISSING_PARAM', hint: 'threadId または messageId を指定してください', retryable: false });
  }

  if (threadId) {
    const thread = GmailApp.getThreadById(threadId);
    if (!thread) {
      return errorResponse('Thread not found: ' + threadId,
        { code: 'NOT_FOUND', hint: 'threadId が正しいか確認してください', retryable: false });
    }
    thread.markUnread();
    return successResponse({
      threadId: threadId,
      action: 'mark_unread',
      message: 'スレッドを未読にしました'
    });
  } else {
    const message = GmailApp.getMessageById(messageId);
    if (!message) {
      return errorResponse('Message not found: ' + messageId,
        { code: 'NOT_FOUND', hint: 'messageId が正しいか確認してください', retryable: false });
    }
    message.markUnread();
    return successResponse({
      messageId: messageId,
      action: 'mark_unread',
      message: 'メッセージを未読にしました'
    });
  }
}
