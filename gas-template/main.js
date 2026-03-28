/**
 * Gmail Skill - Main Entry Point
 *
 * doGet/doPost handlers for Web App.
 * Phase 1: search, get_thread, get_message, list_labels, create_draft
 */

/** GET ルーティングテーブル: アクション名 → ハンドラ関数 */
var GET_ROUTES = {
  search:           function(e) { return handleSearch(e.parameter.query, parseInt(e.parameter.maxResults) || 20); },
  get_thread:       function(e) { return handleGetThread(e.parameter.threadId); },
  get_message:      function(e) { return handleGetMessage(e.parameter.messageId); },
  list_labels:      function(e) { return handleListLabels(); },
  get_unread_count: function(e) { return handleGetUnreadCount(e.parameter.label); },
  list_attachments: function(e) { return handleListAttachments(e.parameter.messageId); },
  get_attachment:   function(e) { return handleGetAttachment(e.parameter.messageId, e.parameter.attachmentIndex); },
  get_message_html: function(e) { return handleGetMessageHtml(e.parameter.messageId, e.parameter.includeHeaders); },
  list_drafts:      function(e) { return handleListDrafts(parseInt(e.parameter.maxResults) || 20); },
  get_profile:      function(e) { return handleGetProfile(); }
};

/** POST ルーティングテーブル: アクション名 → ハンドラ関数 */
var POST_ROUTES = {
  create_draft:       function(b) { return handleCreateDraft(b.to, b.subject, b.body, b.cc, b.bcc, b.htmlBody, b.attachments); },
  create_reply_draft: function(b) { return handleCreateReplyDraft(b.threadId, b.body, b.cc, b.bcc, b.htmlBody, b.attachments, b.skipSelf, b.replyAll); },
  mark_read:          function(b) { return handleMarkRead(b.threadId, b.messageId); },
  mark_unread:        function(b) { return handleMarkUnread(b.threadId, b.messageId); },
  add_label:          function(b) { return handleAddLabel(b.threadId, b.messageId, b.label); },
  remove_label:       function(b) { return handleRemoveLabel(b.threadId, b.messageId, b.label); },
  archive:            function(b) { return handleArchive(b.threadId); },
  move_to_trash:      function(b) { return handleMoveToTrash(b.threadId); },
  update_draft:       function(b) { return handleUpdateDraft(b.draftId, b.to, b.subject, b.body, b.cc, b.bcc, b.htmlBody); },
  delete_draft:       function(b) { return handleDeleteDraft(b.draftId); },
  bulk_mark_read:     function(b) { return handleBulkMarkRead(b.threadIds, b.dryRun); },
  bulk_mark_unread:   function(b) { return handleBulkMarkUnread(b.threadIds, b.dryRun); },
  bulk_add_label:     function(b) { return handleBulkAddLabel(b.threadIds, b.label, b.dryRun); },
  bulk_remove_label:  function(b) { return handleBulkRemoveLabel(b.threadIds, b.label, b.dryRun); },
  bulk_archive:       function(b) { return handleBulkArchive(b.threadIds, b.dryRun); }
};

var GET_ACTIONS = Object.keys(GET_ROUTES);
var POST_ACTIONS = Object.keys(POST_ROUTES);

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
    var handler = GET_ROUTES[action];
    if (handler) {
      return handler(e);
    }
    if (POST_ROUTES[action]) {
      return errorResponse(action + ' は POST メソッドで呼び出してください',
        { code: 'WRONG_METHOD', hint: '使い方: .ccskill-gmail/api post \'{"action":"' + action + '",...}\'', retryable: false });
    }
    return errorResponse('Unknown action: ' + action,
      { code: 'UNKNOWN_ACTION', hint: 'action パラメータを確認してください。GET で利用可能: ' + GET_ACTIONS.join(', ') + ' / POST で利用可能: ' + POST_ACTIONS.join(', '), retryable: false });
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
    var postHandler = POST_ROUTES[action];
    if (postHandler) {
      return postHandler(body);
    }
    if (GET_ROUTES[action]) {
      return errorResponse(action + ' は GET メソッドで呼び出してください',
        { code: 'WRONG_METHOD', hint: '使い方: .ccskill-gmail/api get action=' + action, retryable: false });
    }
    return errorResponse('Unknown action: ' + action,
      { code: 'UNKNOWN_ACTION', hint: 'action パラメータを確認してください。GET で利用可能: ' + GET_ACTIONS.join(', ') + ' / POST で利用可能: ' + POST_ACTIONS.join(', '), retryable: false });
  } catch (error) {
    var errMsg = error.message || String(error);
    if (errMsg.indexOf('Missing required parameter') === 0) {
      return errorResponse(errMsg, { code: 'MISSING_PARAM', hint: '必須パラメータが不足しています', retryable: false });
    }
    return errorResponse(errMsg, { code: 'INTERNAL_ERROR', retryable: true });
  }
}
