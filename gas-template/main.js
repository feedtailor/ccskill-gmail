/**
 * Gmail Skill - Main Entry Point
 *
 * doGet/doPost handlers for Web App.
 * Phase 1: search, get_thread, get_message, list_labels, create_draft
 */

/**
 * Handle GET requests (read operations)
 * @param {Object} e - Event object with query parameters
 * @returns {ContentService.TextOutput} JSON response
 */
function doGet(e) {
  try {
    const action = e.parameter.action;

    // Health check (no action specified)
    if (!action) {
      return successResponse({
        status: 'ok',
        message: 'Gmail Skill is running',
        version: '1.0.0'
      });
    }

    // Permission check
    if (!isActionAllowed(action)) {
      return errorResponse(
        'Action "' + action + '" is denied by permissions config. ' +
        'To enable, remove "' + action + '" from permissions.deny in config.js ' +
        'and run: ccskill-gmail apply-config',
        { code: 'PERMISSION_DENIED', hint: 'config.js の permissions.deny を確認してください', retryable: false }
      );
    }

    // Route to appropriate handler
    switch (action) {
      case 'search':
        return handleSearch(
          e.parameter.query,
          parseInt(e.parameter.maxResults) || 20
        );

      case 'get_thread':
        return handleGetThread(e.parameter.threadId);

      case 'get_message':
        return handleGetMessage(e.parameter.messageId);

      case 'list_labels':
        return handleListLabels();

      case 'get_unread_count':
        return handleGetUnreadCount(e.parameter.label);

      case 'list_attachments':
        return handleListAttachments(e.parameter.messageId);

      case 'get_attachment':
        return handleGetAttachment(
          e.parameter.messageId,
          e.parameter.attachmentIndex
        );

      case 'get_message_html':
        return handleGetMessageHtml(
          e.parameter.messageId,
          e.parameter.includeHeaders
        );

      case 'list_drafts':
        return handleListDrafts(
          parseInt(e.parameter.maxResults) || 20
        );

      case 'get_profile':
        return handleGetProfile();

      default:
        return errorResponse('Unknown action: ' + action,
          { code: 'UNKNOWN_ACTION', hint: 'action パラメータを確認してください。利用可能: search, get_thread, get_message, list_labels, get_unread_count, list_attachments, get_attachment, get_message_html, list_drafts, get_profile', retryable: false });
    }
  } catch (error) {
    // requireParam の throw はパラメータ不足
    var errMsg = error.message || String(error);
    if (errMsg.indexOf('Missing required parameter') === 0) {
      return errorResponse(errMsg, { code: 'MISSING_PARAM', hint: '必須パラメータが不足しています', retryable: false });
    }
    return errorResponse(errMsg, { code: 'INTERNAL_ERROR', retryable: true });
  }
}

/**
 * Handle POST requests (write operations)
 * @param {Object} e - Event object with postData
 * @returns {ContentService.TextOutput} JSON response
 */
function doPost(e) {
  try {
    // Parse JSON body
    let body;
    try {
      body = JSON.parse(e.postData.contents);
    } catch (parseError) {
      return errorResponse('Invalid JSON in request body',
        { code: 'INVALID_JSON', hint: 'リクエストボディが正しい JSON か確認してください', retryable: false });
    }

    const action = body.action;

    if (!action) {
      return errorResponse('Missing required field: action',
        { code: 'MISSING_PARAM', hint: 'JSON に "action" フィールドを含めてください', retryable: false });
    }

    // Permission check
    if (!isActionAllowed(action)) {
      return errorResponse(
        'Action "' + action + '" is denied by permissions config. ' +
        'To enable, remove "' + action + '" from permissions.deny in config.js ' +
        'and run: ccskill-gmail apply-config',
        { code: 'PERMISSION_DENIED', hint: 'config.js の permissions.deny を確認してください', retryable: false }
      );
    }

    // Route to appropriate handler
    switch (action) {
      case 'create_draft':
        return handleCreateDraft(
          body.to,
          body.subject,
          body.body,
          body.cc,
          body.bcc,
          body.htmlBody,
          body.attachments
        );

      case 'create_reply_draft':
        return handleCreateReplyDraft(
          body.threadId,
          body.body,
          body.cc,
          body.bcc,
          body.htmlBody,
          body.attachments,
          body.skipSelf,
          body.replyAll
        );

      case 'mark_read':
        return handleMarkRead(body.threadId, body.messageId);

      case 'mark_unread':
        return handleMarkUnread(body.threadId, body.messageId);

      case 'add_label':
        return handleAddLabel(body.threadId, body.messageId, body.label);

      case 'remove_label':
        return handleRemoveLabel(body.threadId, body.messageId, body.label);

      case 'archive':
        return handleArchive(body.threadId);

      case 'move_to_trash':
        return handleMoveToTrash(body.threadId);

      case 'update_draft':
        return handleUpdateDraft(
          body.draftId,
          body.to,
          body.subject,
          body.body,
          body.cc,
          body.bcc,
          body.htmlBody
        );

      case 'delete_draft':
        return handleDeleteDraft(body.draftId);

      default:
        return errorResponse('Unknown action: ' + action,
          { code: 'UNKNOWN_ACTION', hint: 'action パラメータを確認してください。利用可能: create_draft, create_reply_draft, mark_read, mark_unread, add_label, remove_label, archive, move_to_trash, update_draft, delete_draft', retryable: false });
    }
  } catch (error) {
    var errMsg = error.message || String(error);
    if (errMsg.indexOf('Missing required parameter') === 0) {
      return errorResponse(errMsg, { code: 'MISSING_PARAM', hint: '必須パラメータが不足しています', retryable: false });
    }
    return errorResponse(errMsg, { code: 'INTERNAL_ERROR', retryable: true });
  }
}
