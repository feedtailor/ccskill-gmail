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
        `Action "${action}" is denied by permissions config. ` +
        `To enable, remove "${action}" from permissions.deny in config.js ` +
        `and run: ccskill-gmail apply-config`
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

      default:
        return errorResponse(`Unknown action: ${action}`);
    }
  } catch (error) {
    return errorResponse(error.message);
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
      return errorResponse('Invalid JSON in request body');
    }

    const action = body.action;

    if (!action) {
      return errorResponse('Missing required field: action');
    }

    // Permission check
    if (!isActionAllowed(action)) {
      return errorResponse(
        `Action "${action}" is denied by permissions config. ` +
        `To enable, remove "${action}" from permissions.deny in config.js ` +
        `and run: ccskill-gmail apply-config`
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
          body.bcc
        );

      case 'create_reply_draft':
        return handleCreateReplyDraft(
          body.threadId,
          body.body,
          body.cc,
          body.bcc
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
          body.bcc
        );

      case 'delete_draft':
        return handleDeleteDraft(body.draftId);

      default:
        return errorResponse(`Unknown action: ${action}`);
    }
  } catch (error) {
    return errorResponse(error.message);
  }
}
