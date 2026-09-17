import { describe, it, expect, vi, beforeEach } from 'vitest';
import Cookies from 'js-cookie';
import session from './session';
import api from './tytoApi';

vi.mock('./tytoApi', () => ({ default: { get: vi.fn() } }));

const loginPayload = { id: 7, name: 'Lin Chen', avatar: 'https://x/lin.png', roles: ['member'], credential: 'tok-1' };

function clearCookies() {
  ['account_id', 'account_roles', 'account_credential', 'account_img', 'account_name'].forEach((c) => Cookies.remove(c));
}

// The header, nav, and route guard read the session from cookies written at
// login. Roles can change while someone is logged in, so the app refreshes
// those cookies from the server and keeps only the credential from login.
describe('session', () => {
  beforeEach(() => {
    clearCookies();
    api.get.mockReset();
  });

  it('applyAccount writes the login payload into the session cookies', () => {
    session.applyAccount(loginPayload);

    const account = session.getAccount();
    expect(account.id).toBe('7');
    expect(account.roles).toEqual(['member']);
    expect(account.credential).toBe('tok-1');
    expect(account.name).toBe('Lin Chen');
    expect(account.img).toBe('https://x/lin.png');
  });

  it('refresh pulls the current roles, name, and avatar from the server and keeps the credential', async () => {
    session.applyAccount(loginPayload);
    api.get.mockResolvedValue({ status: 200, data: { data: { id: 7, name: 'Lin C.', avatar: null, roles: ['creator', 'member'] } } });

    const account = await session.refresh();

    expect(api.get).toHaveBeenCalledWith('/auth/session');
    expect(account.roles).toEqual(['creator', 'member']);
    expect(account.name).toBe('Lin C.');
    expect(session.getAccount().roles).toEqual(['creator', 'member']);
    expect(session.getAccount().credential).toBe('tok-1');
  });

  it('refresh leaves the session alone when the request fails', async () => {
    session.applyAccount(loginPayload);
    api.get.mockRejectedValue(new Error('network'));

    const account = await session.refresh();

    expect(account.roles).toEqual(['member']);
    expect(session.getAccount().credential).toBe('tok-1');
  });

  it('refresh does nothing when nobody is logged in', async () => {
    const account = await session.refresh();

    expect(account).toBe(false);
    expect(api.get).not.toHaveBeenCalled();
  });
});
