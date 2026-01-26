/**
 * Gmail Skill - Search Handler
 *
 * Email search operations using Gmail search syntax.
 */

/**
 * Search emails using Gmail search query
 * @param {string} query - Gmail search query (e.g., "is:unread", "from:example@gmail.com")
 * @param {number} maxResults - Maximum number of threads to return (default: 20, max: 500)
 * @returns {ContentService.TextOutput} JSON response with matching threads
 *
 * @example
 * // Search for unread emails
 * handleSearch("is:unread", 10)
 *
 * // Search from specific sender
 * handleSearch("from:boss@company.com", 20)
 *
 * // Combined search
 * handleSearch("is:unread has:attachment after:2024/01/01", 50)
 */
function handleSearch(query, maxResults) {
  requireParam(query, 'query');

  // Validate and cap maxResults
  let limit = maxResults || 20;
  if (limit < 1) limit = 1;
  if (limit > 500) limit = 500;

  const threads = GmailApp.search(query, 0, limit);

  return successResponse({
    query: query,
    resultCount: threads.length,
    threads: threads.map(formatThread)
  });
}
