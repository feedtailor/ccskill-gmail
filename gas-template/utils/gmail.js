/**
 * Gmail Skill - Gmail Utilities
 *
 * Helper functions for Gmail operations and data formatting.
 */

/**
 * Format a Gmail thread for API response
 * @param {GmailThread} thread - Gmail thread object
 * @returns {Object} Formatted thread data
 */
function formatThread(thread) {
  const messages = thread.getMessages();
  const firstMessage = messages[0];
  const lastMessage = messages[messages.length - 1];

  return {
    id: thread.getId(),
    subject: stripInvisibleChars(firstMessage.getSubject()),
    from: firstMessage.getFrom(),
    date: lastMessage.getDate().toISOString(),
    messageCount: messages.length,
    isUnread: thread.isUnread(),
    isImportant: thread.isImportant(),
    isInPriorityInbox: thread.isInPriorityInbox(),
    isInInbox: thread.isInInbox(),
    labels: thread.getLabels().map(function(label) {
      return label.getName();
    })
  };
}

/**
 * Format a Gmail thread with full message details
 * @param {GmailThread} thread - Gmail thread object
 * @returns {Object} Formatted thread with messages
 */
function formatThreadWithMessages(thread) {
  const messages = thread.getMessages();

  return {
    id: thread.getId(),
    subject: stripInvisibleChars(messages[0].getSubject()),
    messageCount: messages.length,
    isUnread: thread.isUnread(),
    isImportant: thread.isImportant(),
    isInPriorityInbox: thread.isInPriorityInbox(),
    isInInbox: thread.isInInbox(),
    labels: thread.getLabels().map(function(label) {
      return label.getName();
    }),
    messages: messages.map(formatMessage)
  };
}

/**
 * Strip invisible characters (indirect prompt injection mitigation)
 * Removes zero-width spaces, joiners, direction control chars, etc.
 * @param {string} str - Input string
 * @returns {string} Sanitized string
 */
function stripInvisibleChars(str) {
  if (!str) return '';
  return str.replace(/[\u200B-\u200F\u2028-\u202F\u2060-\u206F\uFEFF]/g, '');
}

/**
 * Format a Gmail message for API response
 * @param {GmailMessage} message - Gmail message object
 * @returns {Object} Formatted message data
 */
function formatMessage(message) {
  return {
    id: message.getId(),
    threadId: message.getThread().getId(),
    from: message.getFrom(),
    to: message.getTo(),
    cc: message.getCc(),
    bcc: message.getBcc(),
    replyTo: message.getReplyTo(),
    subject: stripInvisibleChars(message.getSubject()),
    body: '--- EMAIL CONTENT START ---\n' +
          stripInvisibleChars(message.getPlainBody()) +
          '\n--- EMAIL CONTENT END ---',
    // htmlBody is intentionally excluded — use get_message_html for HTML access
    date: message.getDate().toISOString(),
    isUnread: message.isUnread(),
    isStarred: message.isStarred(),
    isDraft: message.isDraft(),
    attachments: formatAttachments(message)
  };
}

/**
 * Format message attachments
 * @param {GmailMessage} message - Gmail message object
 * @returns {Array} Formatted attachment list
 */
function formatAttachments(message) {
  const attachments = message.getAttachments();
  return attachments.map(function(attachment) {
    return {
      name: attachment.getName(),
      contentType: attachment.getContentType(),
      size: attachment.getSize()
    };
  });
}

/**
 * Format a Gmail label for API response
 * @param {GmailLabel} label - Gmail label object
 * @returns {Object} Formatted label data
 */
function formatLabel(label) {
  return {
    name: label.getName(),
    unreadCount: label.getUnreadCount()
  };
}

/**
 * Format a Gmail draft for API response
 * @param {GmailDraft} draft - Gmail draft object
 * @returns {Object} Formatted draft data
 */
function formatDraft(draft) {
  const message = draft.getMessage();
  return {
    id: draft.getId(),
    message: formatMessage(message)
  };
}

/**
 * Parse email addresses from various formats
 * Handles: "Name <email@example.com>", "email@example.com", comma-separated
 * @param {string} input - Email input string
 * @returns {Array} Array of email addresses
 */
function parseEmailAddresses(input) {
  if (!input) return [];

  // Extract <email> addresses (handles quoted names containing commas)
  var results = [];
  var bracketPattern = /<([^>]+)>/g;
  var match;
  var remaining = input;
  while ((match = bracketPattern.exec(input)) !== null) {
    results.push(match[1]);
  }

  if (results.length > 0) {
    // Also pick up any bare addresses not wrapped in <>
    // Remove all "...< >..." segments, then split remainder by comma
    remaining = input.replace(/"[^"]*"?\s*<[^>]+>/g, '').replace(/<[^>]+>/g, '');
    remaining.split(',').forEach(function(part) {
      part = part.trim();
      if (part.length > 0 && part.indexOf('@') !== -1) {
        results.push(part);
      }
    });
    return results;
  }

  // Fallback: plain comma-separated addresses (no angle brackets)
  return input.split(',').map(function(part) {
    return part.trim();
  }).filter(function(email) {
    return email.length > 0;
  });
}

/**
 * Build email options object for GmailApp.createDraft
 * @param {Object} params - Parameters (cc, bcc, htmlBody, etc.)
 * @returns {Object} Options object for GmailApp methods
 */
function buildEmailOptions(params) {
  const options = {};

  if (params.cc) {
    options.cc = params.cc;
  }
  if (params.bcc) {
    options.bcc = params.bcc;
  }
  if (params.htmlBody) {
    options.htmlBody = params.htmlBody;
  }
  if (params.name) {
    options.name = params.name;
  }
  if (params.replyTo) {
    options.replyTo = params.replyTo;
  }
  if (params.attachments && params.attachments.length > 0) {
    options.attachments = params.attachments;
  }

  return options;
}
