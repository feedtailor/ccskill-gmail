/**
 * Gmail Skill - Response Utilities
 *
 * JSON response helpers for consistent API responses.
 */

/**
 * Create a success response
 * @param {Object} data - Response data
 * @returns {ContentService.TextOutput} JSON response
 */
function successResponse(data) {
  const response = {
    ok: true,
    data: data
  };
  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Create an error response
 * @param {string} message - Error message
 * @param {Object} opts - Optional structured error fields
 * @param {string} opts.code - Error code (e.g., "NOT_FOUND", "MISSING_PARAM")
 * @param {string} opts.hint - Recovery hint for the agent
 * @param {boolean} opts.retryable - Whether the operation can be retried
 * @returns {ContentService.TextOutput} JSON response
 */
function errorResponse(message, opts) {
  var response = {
    ok: false,
    error: message
  };
  if (opts) {
    if (opts.code) response.error_code = opts.code;
    if (opts.hint) response.hint = opts.hint;
    if (opts.retryable !== undefined) response.retryable = opts.retryable;
  }
  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}
