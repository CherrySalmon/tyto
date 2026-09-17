import { describe, it, expect, vi, beforeEach } from 'vitest';
import { adminGuard } from './guards';
import session from '@/lib/session';

vi.mock('@/lib/session', () => ({ default: { getAccount: vi.fn(), refresh: vi.fn() } }));

// Only admins may manage accounts (plan Q9). The nav hides the link for
// everyone else; this guard closes the direct-URL path. It asks the server
// for the current roles first, so a demotion or promotion made while the
// person was logged in is honoured on this very navigation.
describe('adminGuard', () => {
  beforeEach(() => {
    session.getAccount.mockReset();
    session.refresh.mockReset();
  });

  it('lets an admin through to an admin-only route', async () => {
    session.refresh.mockResolvedValue({ id: '1', roles: ['admin', 'creator'] });
    expect(await adminGuard({ meta: { requiresAdmin: true } })).toBe(true);
  });

  it('redirects a non-admin to the home page', async () => {
    session.refresh.mockResolvedValue({ id: '2', roles: ['member'] });
    expect(await adminGuard({ meta: { requiresAdmin: true } })).toBe('/');
  });

  it('redirects a logged-out visitor to the home page', async () => {
    session.refresh.mockResolvedValue(false);
    expect(await adminGuard({ meta: { requiresAdmin: true } })).toBe('/');
  });

  it('decides on the refreshed roles, not the cookie from login', async () => {
    session.getAccount.mockReturnValue({ id: '3', roles: ['admin'] });
    session.refresh.mockResolvedValue({ id: '3', roles: ['member'] });

    expect(await adminGuard({ meta: { requiresAdmin: true } })).toBe('/');
    expect(session.refresh).toHaveBeenCalledTimes(1);
  });

  it('ignores routes without the requiresAdmin flag and does not hit the server', async () => {
    expect(await adminGuard({ meta: {} })).toBe(true);
    expect(await adminGuard({})).toBe(true);
    expect(session.refresh).not.toHaveBeenCalled();
  });
});
