/**
 * Gmail Skill - Draft Handlers
 *
 * Draft creation and management operations.
 * Note: Sending is intentionally not supported - drafts should be reviewed and sent manually.
 */

/**
 * 添付ファイル配列を base64 から Blob に変換
 * @param {Array} attachments - [{filename, contentType, content(base64)}]
 * @returns {Array<Blob>} GmailApp 用の Blob 配列
 * @throws {Error} 合計サイズが 5MB を超える場合
 */
function parseAttachments(attachments) {
  if (!attachments || !Array.isArray(attachments) || attachments.length === 0) {
    return [];
  }

  var MAX_ATTACHMENTS = 25;
  if (attachments.length > MAX_ATTACHMENTS) {
    throw new Error('添付ファイルは最大 ' + MAX_ATTACHMENTS + ' 個までです');
  }

  var totalSize = 0;
  var MAX_SIZE = 5 * 1024 * 1024; // 5MB

  return attachments.map(function(att, index) {
    if (!att.filename) {
      throw new Error('attachments[' + index + ']: filename is required');
    }
    if (!att.content) {
      throw new Error('attachments[' + index + ']: content (base64) is required');
    }

    // base64 文字列長から事前にサイズを推定してチェック
    var estimatedSize = Math.ceil(att.content.length * 3 / 4);
    totalSize += estimatedSize;
    if (totalSize > MAX_SIZE) {
      throw new Error('添付ファイルの合計サイズが 5MB を超えています（上限: 5MB）');
    }

    var contentType = att.contentType || 'application/octet-stream';
    var decoded = Utilities.base64Decode(att.content);

    return Utilities.newBlob(decoded, contentType, att.filename);
  });
}

/**
 * Create a new email draft
 * @param {string} to - Recipient email address(es), comma-separated for multiple
 * @param {string} subject - Email subject
 * @param {string} body - Email body (plain text, フォールバック用)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @param {string} htmlBody - HTML 本文 (optional, 指定時は body がプレーンテキストフォールバックになる)
 * @param {Array} attachments - 添付ファイル配列 (optional, [{filename, contentType, content(base64)}])
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting Tomorrow", "Hi, let's meet tomorrow at 10am.")
 *
 * @example
 * handleCreateDraft("recipient@example.com", "Meeting", "Body", "cc@example.com", "bcc@example.com")
 */
function handleCreateDraft(to, subject, body, cc, bcc, htmlBody, attachments) {
  requireParam(to, 'to');
  requireParam(subject, 'subject');
  requireParam(body, 'body');

  // htmlBody 未指定時は body から自動生成（改行消失防止）
  if (!htmlBody && body) {
    htmlBody = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');
  }

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc,
    htmlBody: htmlBody,
    attachments: parseAttachments(attachments)
  });

  // Create the draft
  const draft = GmailApp.createDraft(to, subject, body, options);

  return successResponse({
    draftId: draft.getId(),
    to: to,
    subject: subject,
    message: '下書きを作成しました。Gmail で確認・送信してください。',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * Create a reply draft for an existing thread
 * @param {string} threadId - Thread ID to reply to
 * @param {string} body - Reply body (plain text, フォールバック用)
 * @param {string} cc - CC recipients (optional)
 * @param {string} bcc - BCC recipients (optional)
 * @param {string} htmlBody - HTML 本文 (optional, 指定時は body がプレーンテキストフォールバックになる)
 * @param {Array} attachments - 添付ファイル配列 (optional, [{filename, contentType, content(base64)}])
 * @param {boolean} skipSelf - 自分の送信メッセージをスキップして相手のメッセージに返信する (デフォルト true)
 * @param {boolean} replyAll - 全員に返信する (デフォルト true)
 * @returns {ContentService.TextOutput} JSON response with draft info
 *
 * @example
 * handleCreateReplyDraft("19bf7f25b96ab637", "Thank you for your email.")
 */
function handleCreateReplyDraft(threadId, body, cc, bcc, htmlBody, attachments, skipSelf, replyAll) {
  requireParam(threadId, 'threadId');
  requireParam(body, 'body');

  // デフォルト値: 両方 true
  if (skipSelf === undefined || skipSelf === null) skipSelf = true;
  if (replyAll === undefined || replyAll === null) replyAll = true;

  const thread = GmailApp.getThreadById(threadId);
  if (!thread) {
    return errorResponse('Thread not found: ' + threadId,
      { code: 'NOT_FOUND', hint: 'threadId が正しいか確認してください', retryable: false });
  }

  const messages = thread.getMessages();

  // skipSelf: 自分以外が送信した直近のメッセージを探す
  let targetMessage = messages[messages.length - 1]; // フォールバック
  if (skipSelf) {
    const myEmail = Session.getActiveUser().getEmail().toLowerCase();
    for (let i = messages.length - 1; i >= 0; i--) {
      const from = messages[i].getFrom().toLowerCase();
      if (!from.includes(myEmail)) {
        targetMessage = messages[i];
        break;
      }
    }
  }

  // htmlBody 未指定時は body から自動生成（改行消失防止）
  if (!htmlBody && body) {
    htmlBody = body
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/\n/g, '<br>');
  }

  // Build options object
  const options = buildEmailOptions({
    cc: cc,
    bcc: bcc,
    htmlBody: htmlBody,
    attachments: parseAttachments(attachments)
  });

  // replyAll に応じて使い分け
  const draft = replyAll
    ? targetMessage.createDraftReplyAll(body, options)
    : targetMessage.createDraftReply(body, options);

  // 実際の下書き宛先を返す
  const draftMessage = draft.getMessage();

  return successResponse({
    draftId: draft.getId(),
    threadId: threadId,
    to: draftMessage.getTo(),
    subject: 'Re: ' + targetMessage.getSubject().replace(/^Re:\s*/i, ''),
    skipSelf: skipSelf,
    replyAll: replyAll,
    message: '返信下書きを作成しました。Gmail で確認・送信してください。',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * Update an existing draft
 * Note: GmailApp doesn't support direct draft update, so we delete and recreate.
 * @param {string} draftId - Draft ID to update
 * @param {string} to - New recipient (optional)
 * @param {string} subject - New subject (optional)
 * @param {string} body - New body (optional)
 * @param {string} cc - New CC recipients (optional)
 * @param {string} bcc - New BCC recipients (optional)
 * @param {string} htmlBody - HTML 本文 (optional, 省略時は既存の HTML を維持)
 * @returns {ContentService.TextOutput} JSON response with new draft info
 */
function handleUpdateDraft(draftId, to, subject, body, cc, bcc, htmlBody) {
  requireParam(draftId, 'draftId');

  const drafts = GmailApp.getDrafts();
  const draft = drafts.find(function(d) { return d.getId() === draftId; });
  if (!draft) {
    return errorResponse('Draft not found: ' + draftId,
      { code: 'NOT_FOUND', hint: 'list_drafts で draftId を確認してください', retryable: false });
  }

  const message = draft.getMessage();
  const currentTo = to || message.getTo();
  const currentSubject = subject || message.getSubject();
  const currentBody = body || message.getPlainBody();
  // htmlBody は明示的に渡された場合のみ使用（既存の HTML を引き継ぐ場合は getBody）
  const currentHtmlBody = htmlBody !== undefined ? htmlBody : message.getBody();

  // スレッドに紐付いているか判定
  const thread = message.getThread();
  const threadMessages = thread.getMessages();
  const isReplyDraft = threadMessages.length > 1
    || (threadMessages.length === 1 && !threadMessages[0].isDraft());

  const options = buildEmailOptions({ cc: cc, bcc: bcc, htmlBody: currentHtmlBody });

  draft.deleteDraft();

  let newDraft;
  if (isReplyDraft) {
    // 返信下書き → 自分以外が送信した直近の非下書きメッセージに対して再作成
    const nonDraftMessages = threadMessages.filter(function(m) {
      return !m.isDraft();
    });
    let replyTarget = nonDraftMessages[nonDraftMessages.length - 1];

    // skipSelf: 自分以外の送信メッセージを優先
    const myEmail = Session.getActiveUser().getEmail().toLowerCase();
    for (let i = nonDraftMessages.length - 1; i >= 0; i--) {
      const from = nonDraftMessages[i].getFrom().toLowerCase();
      if (!from.includes(myEmail)) {
        replyTarget = nonDraftMessages[i];
        break;
      }
    }

    if (to) options.to = to;
    newDraft = replyTarget.createDraftReplyAll(currentBody, options);
  } else {
    // 新規下書き → 従来通り
    newDraft = GmailApp.createDraft(currentTo, currentSubject, currentBody, options);
  }

  return successResponse({
    draftId: newDraft.getId(),
    oldDraftId: draftId,
    threadId: thread.getId(),
    isReply: isReplyDraft,
    action: 'update_draft',
    message: '下書きを更新しました',
    gmailUrl: 'https://mail.google.com/mail/u/0/#drafts'
  });
}

/**
 * 下書き一覧を取得
 * @param {number} maxResults - 最大取得件数（デフォルト 20, 上限 100）
 * @returns {ContentService.TextOutput} JSON response with draft list
 *
 * @example
 * handleListDrafts(20)
 */
function handleListDrafts(maxResults) {
  let limit = maxResults || 20;
  if (limit > 100) {
    limit = 100;
  }

  const drafts = GmailApp.getDrafts();
  const total = drafts.length;

  // maxResults で切り詰め
  const sliced = drafts.slice(0, limit);

  const results = sliced.map(function(draft) {
    const message = draft.getMessage();
    const plainBody = message.getPlainBody() || '';
    let snippet = plainBody.substring(0, 100);
    if (plainBody.length > 100) {
      snippet += '...';
    }

    return {
      draftId: draft.getId(),
      subject: message.getSubject(),
      to: message.getTo(),
      snippet: snippet,
      lastDate: message.getDate().toISOString()
    };
  });

  return successResponse({
    total: total,
    count: results.length,
    drafts: results
  });
}

/**
 * Delete a draft
 * @param {string} draftId - Draft ID to delete
 * @returns {ContentService.TextOutput} JSON response
 */
function handleDeleteDraft(draftId) {
  requireParam(draftId, 'draftId');

  const drafts = GmailApp.getDrafts();
  const draft = drafts.find(function(d) { return d.getId() === draftId; });

  if (!draft) {
    return errorResponse('Draft not found: ' + draftId,
      { code: 'NOT_FOUND', hint: 'list_drafts で draftId を確認してください', retryable: false });
  }

  draft.deleteDraft();

  return successResponse({
    draftId: draftId,
    action: 'delete_draft',
    message: '下書きを削除しました'
  });
}
