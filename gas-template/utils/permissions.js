/**
 * Gmail Skill - Permission Utilities
 *
 * Check if an action is allowed by CONFIG.permissions.
 * Follows Claude Code allow/deny pattern:
 * - deny takes priority over allow
 * - If allow is specified, only listed actions are permitted (whitelist)
 * - If neither is specified, all actions are allowed (backward compat)
 */

/**
 * Check if an action is allowed by CONFIG.permissions
 * @param {string} action - Action name to check
 * @returns {boolean} Whether the action is allowed
 */
function isActionAllowed(action) {
  if (!CONFIG.permissions) return true;

  const deny = CONFIG.permissions.deny;
  const allow = CONFIG.permissions.allow;

  // deny takes priority
  if (deny && deny.indexOf(action) !== -1) return false;

  // allow specified = whitelist mode
  if (allow && allow.length > 0) {
    return allow.indexOf(action) !== -1;
  }

  return true;
}
