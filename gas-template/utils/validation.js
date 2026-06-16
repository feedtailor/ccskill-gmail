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
 * Split a recipient list on commas, ignoring commas inside double quotes.
 * Keeps name-addr display-names with commas intact (e.g. '"Smith, John" <a@b>').
 * @param {string} s - Recipient string (comma-separated)
 * @returns {Array<string>} Recipient elements (not trimmed). Empty-only input yields [].
 */
function splitRecipients_(s) {
  if (!s) return [];
  var result = [];
  var cur = '';
  var inQuote = false;
  for (var i = 0; i < s.length; i++) {
    var ch = s.charAt(i);
    if (ch === '"') {
      inQuote = !inQuote;
      cur += ch;
    } else if (ch === ',' && !inQuote) {
      result.push(cur);
      cur = '';
    } else {
      cur += ch;
    }
  }
  if (cur.trim() !== '') result.push(cur);
  return result;
}

/**
 * Extract the addr-spec (the bare address part) from one recipient element.
 * For name-addr ("Display" <addr>) returns the content inside the last <...>.
 * Otherwise strips any quoted segments and returns the remainder.
 * @param {string} elem - One recipient element
 * @returns {string} addr-spec (not trimmed by caller's contract; callers trim as needed)
 */
function extractAddrSpec_(elem) {
  if (!elem) return '';
  var m = elem.match(/<([^>]*)>/);
  if (m) return m[1];
  // No angle brackets: drop any quoted display-name segments, keep the rest.
  return elem.replace(/"[^"]*"/g, '').trim();
}

/**
 * Find the first recipient whose addr-spec contains a non-ASCII character.
 * Non-ASCII in display-names is allowed (GmailApp encodes it correctly); only
 * the address part is checked, because a non-ASCII addr-spec causes mojibake (#127).
 * @param {string} recipients - Recipient string (to / cc / bcc), comma-separated
 * @returns {string|null} The offending addr-spec, or null if all are ASCII
 */
function findNonAsciiAddrSpec_(recipients) {
  if (!recipients) return null;
  var elems = splitRecipients_(recipients);
  for (var i = 0; i < elems.length; i++) {
    var addr = extractAddrSpec_(elems[i]).trim();
    if (addr && /[^\x00-\x7F]/.test(addr)) {
      return addr;
    }
  }
  return null;
}
