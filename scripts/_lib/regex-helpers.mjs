/**
 * Regex utility helpers.
 */

/**
 * Collect all matches of a global regex against content.
 * Returns an array of match objects (RegExpExecArray).
 */
export function findAllMatches(pattern, content) {
  const results = [];
  // Reset lastIndex in case the regex was used before
  pattern.lastIndex = 0;
  let match;
  while ((match = pattern.exec(content)) !== null) {
    results.push(match);
    // Prevent infinite loop on zero-length matches
    if (match[0].length === 0) pattern.lastIndex++;
  }
  return results;
}
