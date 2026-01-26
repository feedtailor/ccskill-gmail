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
 * @returns {ContentService.TextOutput} JSON response
 */
function errorResponse(message) {
  const response = {
    ok: false,
    error: message
  };
  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}
