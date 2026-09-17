import { describe, it, expect } from 'vitest';
import { parseEmails } from './parseEmails';

// Admins paste a list copied from a roster or a mail client, so the separator
// is whatever they had: commas, spaces, new lines, or a mix. The parser keeps
// order, drops duplicates, and reports tokens that cannot be emails so the
// dialog can say "4 found, 1 skipped" before anything is sent.
describe('parseEmails', () => {
  it('splits on commas, spaces, and new lines in any mix', () => {
    const { emails } = parseEmails('a@x.com, b@x.com c@x.com\nd@x.com');
    expect(emails).toEqual(['a@x.com', 'b@x.com', 'c@x.com', 'd@x.com']);
  });

  it('trims, de-duplicates, and ignores empty tokens', () => {
    const { emails } = parseEmails('  a@x.com ,, a@x.com\n\n b@x.com  ');
    expect(emails).toEqual(['a@x.com', 'b@x.com']);
  });

  it('reports tokens without an @ as skipped instead of dropping them silently', () => {
    const { emails, skipped } = parseEmails('a@x.com not-an-email b@x.com');
    expect(emails).toEqual(['a@x.com', 'b@x.com']);
    expect(skipped).toEqual(['not-an-email']);
  });

  it('returns empty lists for blank input', () => {
    expect(parseEmails('')).toEqual({ emails: [], skipped: [] });
    expect(parseEmails('   \n ')).toEqual({ emails: [], skipped: [] });
  });
});
