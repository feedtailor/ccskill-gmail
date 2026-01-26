/**
 * Gmail Skill - Label Handlers
 *
 * Label operations: add, remove.
 */

/**
 * Add a label to a thread
 * @param {string} threadId - Thread ID
 * @param {string} messageId - Message ID (not supported, use threadId)
 * @param {string} labelName - Label name to add
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleAddLabel("19bf7f25b96ab637", null, "対応済")
 */
function handleAddLabel(threadId, messageId, labelName) {
  requireParam(labelName, 'label');

  if (!threadId && !messageId) {
    return errorResponse('Either threadId or messageId is required');
  }

  // GmailApp only supports thread-level label operations
  if (messageId && !threadId) {
    return errorResponse('Adding label to individual message is not supported. Use threadId instead.');
  }

  // Get or create label
  let label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    label = GmailApp.createLabel(labelName);
  }

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse(`Thread not found: ${threadId}`);
  }

  thread.addLabel(label);

  return successResponse({
    threadId: threadId,
    label: labelName,
    action: 'add_label',
    message: `ラベル「${labelName}」を追加しました`
  });
}

/**
 * Remove a label from a thread
 * @param {string} threadId - Thread ID
 * @param {string} messageId - Message ID (not supported, use threadId)
 * @param {string} labelName - Label name to remove
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleRemoveLabel("19bf7f25b96ab637", null, "対応済")
 */
function handleRemoveLabel(threadId, messageId, labelName) {
  requireParam(labelName, 'label');

  if (!threadId && !messageId) {
    return errorResponse('Either threadId or messageId is required');
  }

  // GmailApp only supports thread-level label operations
  if (messageId && !threadId) {
    return errorResponse('Removing label from individual message is not supported. Use threadId instead.');
  }

  const label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    return errorResponse(`Label not found: ${labelName}`);
  }

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse(`Thread not found: ${threadId}`);
  }

  thread.removeLabel(label);

  return successResponse({
    threadId: threadId,
    label: labelName,
    action: 'remove_label',
    message: `ラベル「${labelName}」を削除しました`
  });
}
