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
