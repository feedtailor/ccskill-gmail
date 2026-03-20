/**
 * Gmail Skill - Thread Handlers
 *
 * Thread operations: archive, move to trash.
 */

/**
 * Archive a thread (remove from inbox)
 * @param {string} threadId - Thread ID to archive
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleArchive("19bf7f25b96ab637")
 */
function handleArchive(threadId) {
  requireParam(threadId, 'threadId');

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'threadId が正しいか確認してください', retryable: false });
  }

  thread.moveToArchive();

  return successResponse({
    threadId: threadId,
    action: 'archive',
    message: 'スレッドをアーカイブしました'
  });
}

/**
 * Move a thread to trash
 * @param {string} threadId - Thread ID to move to trash
 * @returns {ContentService.TextOutput} JSON response
 *
 * @example
 * handleMoveToTrash("19bf7f25b96ab637")
 */
function handleMoveToTrash(threadId) {
  requireParam(threadId, 'threadId');

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'threadId が正しいか確認してください', retryable: false });
  }

  thread.moveToTrash();

  return successResponse({
    threadId: threadId,
    action: 'move_to_trash',
    message: 'スレッドをゴミ箱に移動しました'
  });
}
