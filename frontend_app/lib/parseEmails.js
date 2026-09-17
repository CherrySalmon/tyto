// Turn a pasted list into emails. Admins paste from rosters and mail clients,
// so the separators are whatever they had: commas, spaces, new lines, or a mix.
// Keeps first-seen order, drops duplicates and blanks, and reports tokens that
// cannot be emails (no @) as `skipped` so the UI can say so before sending.
export function parseEmails(text) {
  const tokens = String(text ?? '')
    .split(/[\s,;]+/)
    .map((token) => token.trim())
    .filter(Boolean);

  const seen = new Set();
  const emails = [];
  const skipped = [];
  for (const token of tokens) {
    if (seen.has(token)) continue;
    seen.add(token);
    (token.includes('@') ? emails : skipped).push(token);
  }
  return { emails, skipped };
}
