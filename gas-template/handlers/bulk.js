/**
 * Gmail Skill - Bulk Operation Handlers
 *
 * Batch operations on multiple threads.
 * All bulk operations require threadIds array and support dryRun mode.
 */

/**
 * Validate bulk operation parameters
 * @param {Array} threadIds - Array of thread IDs
 * @param {boolean} dryRun - Whether this is a dry run
 * @returns {Object|null} Error response if validation fails, null if OK
 */
function validateBulkParams_(threadIds, dryRun) {
  if (!threadIds || !Array.isArray(threadIds) || threadIds.length === 0) {
    return errorResponse('threadIds must be a non-empty array',
      { code: 'INVALID_PARAM', hint: 'threadIds に threadId の配列を指定してください', retryable: false });
  }
  if (threadIds.length > 50) {
    return errorResponse('Too many threadIds: ' + threadIds.length + ' (max 50)',
      { code: 'SIZE_LIMIT', hint: '1回あたり最大 50 件です。分割して実行してください', retryable: false });
  }
  if (dryRun !== true && dryRun !== false) {
    return errorResponse('dryRun must be true or false',
      { code: 'INVALID_PARAM', hint: 'dryRun: true で対象確認、dryRun: false で実行', retryable: false });
  }
  return null;
}

/**
 * Resolve threads from IDs and return summary info
 * @param {Array} threadIds - Array of thread IDs
 * @returns {Object} { threads: [...], notFound: [...] }
 */
function resolveThreads_(threadIds) {
  var threads = [];
  var notFound = [];

  for (var i = 0; i < threadIds.length; i++) {
    var thread = GmailApp.getThreadById(threadIds[i]);
    if (thread) {
      var firstMessage = thread.getMessages()[0];
      threads.push({
        threadId: threadIds[i],
        subject: firstMessage.getSubject(),
        from: firstMessage.getFrom()
      });
    } else {
      notFound.push(threadIds[i]);
    }
  }

  return { threads: threads, notFound: notFound };
}

/**
 * Bulk mark threads as read
 * @param {Array} threadIds - Thread IDs
 * @param {boolean} dryRun - If true, only return targets without executing
 * @returns {ContentService.TextOutput} JSON response
 */
function handleBulkMarkRead(threadIds, dryRun) {
  var validation = validateBulkParams_(threadIds, dryRun);
  if (validation) return validation;

  var resolved = resolveThreads_(threadIds);

  if (dryRun) {
    return successResponse({
      action: 'bulk_mark_read',
      dryRun: true,
      targetCount: resolved.threads.length,
      targets: resolved.threads,
      notFound: resolved.notFound
    });
  }

  var succeeded = [];
  var failed = [];

  for (var i = 0; i < resolved.threads.length; i++) {
    try {
      GmailApp.getThreadById(resolved.threads[i].threadId).markRead();
      succeeded.push(resolved.threads[i].threadId);
    } catch (e) {
      failed.push({ threadId: resolved.threads[i].threadId, error: e.message });
    }
  }

  return successResponse({
    action: 'bulk_mark_read',
    dryRun: false,
    succeeded: succeeded.length,
    failed: failed.length,
    notFound: resolved.notFound,
    failedDetails: failed
  });
}

/**
 * Bulk mark threads as unread
 * @param {Array} threadIds - Thread IDs
 * @param {boolean} dryRun - If true, only return targets without executing
 * @returns {ContentService.TextOutput} JSON response
 */
function handleBulkMarkUnread(threadIds, dryRun) {
  var validation = validateBulkParams_(threadIds, dryRun);
  if (validation) return validation;

  var resolved = resolveThreads_(threadIds);

  if (dryRun) {
    return successResponse({
      action: 'bulk_mark_unread',
      dryRun: true,
      targetCount: resolved.threads.length,
      targets: resolved.threads,
      notFound: resolved.notFound
    });
  }

  var succeeded = [];
  var failed = [];

  for (var i = 0; i < resolved.threads.length; i++) {
    try {
      GmailApp.getThreadById(resolved.threads[i].threadId).markUnread();
      succeeded.push(resolved.threads[i].threadId);
    } catch (e) {
      failed.push({ threadId: resolved.threads[i].threadId, error: e.message });
    }
  }

  return successResponse({
    action: 'bulk_mark_unread',
    dryRun: false,
    succeeded: succeeded.length,
    failed: failed.length,
    notFound: resolved.notFound,
    failedDetails: failed
  });
}

/**
 * Bulk add label to threads
 * @param {Array} threadIds - Thread IDs
 * @param {string} labelName - Label name to add
 * @param {boolean} dryRun - If true, only return targets without executing
 * @returns {ContentService.TextOutput} JSON response
 */
function handleBulkAddLabel(threadIds, labelName, dryRun) {
  var validation = validateBulkParams_(threadIds, dryRun);
  if (validation) return validation;

  if (!labelName) {
    return errorResponse('label is required for bulk_add_label',
      { code: 'MISSING_PARAM', hint: 'label パラメータを指定してください', retryable: false });
  }

  var resolved = resolveThreads_(threadIds);

  if (dryRun) {
    return successResponse({
      action: 'bulk_add_label',
      dryRun: true,
      label: labelName,
      targetCount: resolved.threads.length,
      targets: resolved.threads,
      notFound: resolved.notFound
    });
  }

  // Get or create label
  var label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    label = GmailApp.createLabel(labelName);
  }

  var succeeded = [];
  var failed = [];

  for (var i = 0; i < resolved.threads.length; i++) {
    try {
      GmailApp.getThreadById(resolved.threads[i].threadId).addLabel(label);
      succeeded.push(resolved.threads[i].threadId);
    } catch (e) {
      failed.push({ threadId: resolved.threads[i].threadId, error: e.message });
    }
  }

  return successResponse({
    action: 'bulk_add_label',
    dryRun: false,
    label: labelName,
    succeeded: succeeded.length,
    failed: failed.length,
    notFound: resolved.notFound,
    failedDetails: failed
  });
}

/**
 * Bulk remove label from threads
 * @param {Array} threadIds - Thread IDs
 * @param {string} labelName - Label name to remove
 * @param {boolean} dryRun - If true, only return targets without executing
 * @returns {ContentService.TextOutput} JSON response
 */
function handleBulkRemoveLabel(threadIds, labelName, dryRun) {
  var validation = validateBulkParams_(threadIds, dryRun);
  if (validation) return validation;

  if (!labelName) {
    return errorResponse('label is required for bulk_remove_label',
      { code: 'MISSING_PARAM', hint: 'label パラメータを指定してください', retryable: false });
  }

  var label = GmailApp.getUserLabelByName(labelName);
  if (!label) {
    return errorResponse('Label not found: ' + labelName,
      { code: 'NOT_FOUND', hint: 'list_labels でラベル名を確認してください', retryable: false });
  }

  var resolved = resolveThreads_(threadIds);

  if (dryRun) {
    return successResponse({
      action: 'bulk_remove_label',
      dryRun: true,
      label: labelName,
      targetCount: resolved.threads.length,
      targets: resolved.threads,
      notFound: resolved.notFound
    });
  }

  var succeeded = [];
  var failed = [];

  for (var i = 0; i < resolved.threads.length; i++) {
    try {
      GmailApp.getThreadById(resolved.threads[i].threadId).removeLabel(label);
      succeeded.push(resolved.threads[i].threadId);
    } catch (e) {
      failed.push({ threadId: resolved.threads[i].threadId, error: e.message });
    }
  }

  return successResponse({
    action: 'bulk_remove_label',
    dryRun: false,
    label: labelName,
    succeeded: succeeded.length,
    failed: failed.length,
    notFound: resolved.notFound,
    failedDetails: failed
  });
}

/**
 * Bulk archive threads
 * @param {Array} threadIds - Thread IDs
 * @param {boolean} dryRun - If true, only return targets without executing
 * @returns {ContentService.TextOutput} JSON response
 */
function handleBulkArchive(threadIds, dryRun) {
  var validation = validateBulkParams_(threadIds, dryRun);
  if (validation) return validation;

  var resolved = resolveThreads_(threadIds);

  if (dryRun) {
    return successResponse({
      action: 'bulk_archive',
      dryRun: true,
      targetCount: resolved.threads.length,
      targets: resolved.threads,
      notFound: resolved.notFound
    });
  }

  var succeeded = [];
  var failed = [];

  for (var i = 0; i < resolved.threads.length; i++) {
    try {
      GmailApp.getThreadById(resolved.threads[i].threadId).moveToArchive();
      succeeded.push(resolved.threads[i].threadId);
    } catch (e) {
      failed.push({ threadId: resolved.threads[i].threadId, error: e.message });
    }
  }

  return successResponse({
    action: 'bulk_archive',
    dryRun: false,
    succeeded: succeeded.length,
    failed: failed.length,
    notFound: resolved.notFound,
    failedDetails: failed
  });
}
