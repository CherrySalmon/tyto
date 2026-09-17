import { describe, it, expect, vi, beforeEach } from 'vitest';
import { adminGuard } from './guards';
import session from '@/lib/session';

vi.mock('@/lib/session', () => ({ default: { getAccount: vi.fn() } }));

// Only admins may manage accounts (plan Q9). The nav hides the link for
// everyone else; this guard closes the direct-URL path too.
describe('adminGuard', () => {
  beforeEach(() => session.getAccount.mockReset());

  it('lets an admin through to an admin-only route', () => {
    session.getAccount.mockReturnValue({ id: '1', roles: ['admin', 'creator'] });
    expect(adminGuard({ meta: { requiresAdmin: true } })).toBe(true);
  });

  it('redirects a non-admin to the home page', () => {
    session.getAccount.mockReturnValue({ id: '2', roles: ['member'] });
    expect(adminGuard({ meta: { requiresAdmin: true } })).toBe('/');
  });

  it('redirects a logged-out visitor to the home page', () => {
    session.getAccount.mockReturnValue(false);
    expect(adminGuard({ meta: { requiresAdmin: true } })).toBe('/');
  });

  it('ignores routes without the requiresAdmin flag', () => {
    session.getAccount.mockReturnValue(false);
    expect(adminGuard({ meta: {} })).toBe(true);
    expect(adminGuard({})).toBe(true);
  });
});
