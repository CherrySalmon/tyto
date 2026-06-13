import { test, expect, ROLES } from './fixtures.mjs';

// Plan tasks 6a — auth / session via cookie injection. These also smoke-test
// the whole harness: seed -> mint -> cookie injection -> SPA boots authed.

test.describe('Authentication / session', () => {
  test('unauthenticated visit redirects to /login', async ({ page }) => {
    await page.goto('/course');
    await expect(page).toHaveURL(/\/login/);
  });

  for (const role of ROLES) {
    test(`cookie-injection login as ${role} lands authenticated (not /login)`, async ({ page, loginAs }) => {
      const account = await loginAs(role);
      await page.goto('/');

      // App.vue redirects to /login when session.getAccount() is falsy; staying
      // off /login proves the injected session was accepted.
      await expect(page).not.toHaveURL(/\/login/);

      // The SPA recognizes the account: the credential cookie round-tripped.
      const credential = await page.evaluate(() =>
        document.cookie.split('; ').find((c) => c.startsWith('account_credential='))?.slice('account_credential='.length),
      );
      expect(credential).toBe(account.credential);
    });
  }

  test('logout clears the session and forces re-login', async ({ page, loginAs }) => {
    await loginAs('owner');
    await page.goto('/');
    await expect(page).not.toHaveURL(/\/login/);

    // The avatar popover holds the Logout control (renders because E2E accounts
    // have an avatar). Hover to reveal it, then click.
    await page.locator('.avatar-btn').first().hover();
    await page.getByText('Logout', { exact: true }).click();

    await expect(page).toHaveURL(/\/login/);
    const hasCredential = await page.evaluate(() => document.cookie.includes('account_credential='));
    expect(hasCredential).toBe(false);
  });
});
