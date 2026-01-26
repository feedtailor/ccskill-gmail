/**
 * Gmail Skill - Validation Utilities
 *
 * Parameter validation helpers for Gmail operations.
 */

/**
 * Validate required parameter
 * @param {*} value - Parameter value
 * @param {string} name - Parameter name
 * @throws {Error} If parameter is missing
 */
function requireParam(value, name) {
  if (value === undefined || value === null || value === '') {
    throw new Error(`Missing required parameter: ${name}`);
  }
}

/**
 * Validate email address format
 * @param {string} email - Email address
 * @returns {boolean} True if valid email format
 */
function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  // Basic email pattern (not exhaustive, but catches common issues)
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailPattern.test(email);
}

/**
 * Validate multiple email addresses (comma-separated or array)
 * @param {string|Array} emails - Email addresses
 * @returns {boolean} True if all emails are valid
 */
function isValidEmailList(emails) {
  if (!emails) return false;

  let emailArray;
  if (typeof emails === 'string') {
    emailArray = emails.split(',').map(e => e.trim());
  } else if (Array.isArray(emails)) {
    emailArray = emails;
  } else {
    return false;
  }

  return emailArray.length > 0 && emailArray.every(isValidEmail);
}

/**
 * Validate Gmail thread ID format
 * Thread IDs are hexadecimal strings
 * @param {string} threadId - Thread ID
 * @returns {boolean} True if valid format
 */
function isValidThreadId(threadId) {
  if (!threadId || typeof threadId !== 'string') return false;
  // Gmail thread IDs are typically 16 character hex strings
  // But we'll be lenient and just check for hex characters
  return /^[a-f0-9]+$/i.test(threadId);
}

/**
 * Validate Gmail message ID format
 * Message IDs are hexadecimal strings
 * @param {string} messageId - Message ID
 * @returns {boolean} True if valid format
 */
function isValidMessageId(messageId) {
  if (!messageId || typeof messageId !== 'string') return false;
  // Gmail message IDs are typically 16 character hex strings
  return /^[a-f0-9]+$/i.test(messageId);
}

/**
 * Validate Gmail draft ID format
 * @param {string} draftId - Draft ID
 * @returns {boolean} True if valid format
 */
function isValidDraftId(draftId) {
  if (!draftId || typeof draftId !== 'string') return false;
  // Draft IDs follow similar format to message IDs
  return /^[a-z0-9_-]+$/i.test(draftId);
}

/**
 * Validate positive integer
 * @param {*} value - Value to check
 * @returns {boolean} True if positive integer
 */
function isPositiveInteger(value) {
  const num = parseInt(value, 10);
  return !isNaN(num) && num > 0 && num === Number(value);
}

/**
 * Validate maxResults parameter (1-500)
 * @param {*} value - Value to check
 * @returns {boolean} True if valid maxResults
 */
function isValidMaxResults(value) {
  const num = parseInt(value, 10);
  return !isNaN(num) && num >= 1 && num <= 500;
}
