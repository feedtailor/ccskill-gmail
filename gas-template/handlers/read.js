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
