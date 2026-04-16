/**
 * Gmail Skill - Marker Handlers
 *
 * Message-level marker operations: star, important.
 */

/**
 * Star a message
 * @param {string} messageId - Message ID to star
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleStar("19bf7f25b96ab637")
 */
function handleStar(messageId) {
  requireParam(messageId, 'messageId');

  const message = GmailApp.getMessageById(messageId);
  if (!message) {
    return errorResponse('Message not found: ' + messageId,
      { code: 'NOT_FOUND', hint: 'Verify the messageId is correct', retryable: false });
  }

  message.star();

  return successResponse({
    messageId: messageId,
    action: 'star',
    message: 'Message starred'
  });
}

/**
 * Unstar a message
 * @param {string} messageId - Message ID to unstar
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleUnstar("19bf7f25b96ab637")
 */
function handleUnstar(messageId) {
  requireParam(messageId, 'messageId');

  const message = GmailApp.getMessageById(messageId);
  if (!message) {
    return errorResponse('Message not found: ' + messageId,
      { code: 'NOT_FOUND', hint: 'Verify the messageId is correct', retryable: false });
  }

  message.unstar();

  return successResponse({
    messageId: messageId,
    action: 'unstar',
    message: 'Message unstarred'
  });
}

/**
 * Mark a thread as important
 *
 * Important is a thread-level flag in Gmail (feeds Priority Inbox).
 * GmailApp does not expose a message-level markImportant() — use threadId.
 *
 * @param {string} threadId - Thread ID to mark as important
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleMarkImportant("19bf7f25b96ab637")
 */
function handleMarkImportant(threadId) {
  requireParam(threadId, 'threadId');

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'Verify the threadId is correct', retryable: false });
  }

  thread.markImportant();

  return successResponse({
    threadId: threadId,
    action: 'mark_important',
    message: 'Thread marked as important'
  });
}

/**
 * Unmark a thread as important
 * @param {string} threadId - Thread ID to unmark as important
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleUnmarkImportant("19bf7f25b96ab637")
 */
function handleUnmarkImportant(threadId) {
  requireParam(threadId, 'threadId');

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'Verify the threadId is correct', retryable: false });
  }

  thread.markUnimportant();

  return successResponse({
    threadId: threadId,
    action: 'unmark_important',
    message: 'Thread unmarked as important'
  });
}
