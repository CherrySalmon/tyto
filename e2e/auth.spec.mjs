import { test, expect, ROLES } from './fixtures.mjs';

// Plan tasks 6a — auth / session via cookie injection. These also smoke-test
// the whole harness: seed -> mint -> cookie injection -> SPA boots authed.

test.describe('Authentication / session', () => {
  test('unauthenticated visit redirects to /login', async ({ page, coursesPage, loginPage }) => {
    await page.goto(coursesPage.path);
    await expect(page).toHaveURL(loginPage.url);
  });

  for (const role of ROLES) {
    test(`cookie-injection login as ${role} lands authenticated (not /login)`, async ({ page, loginAs, coursesPage, loginPage }) => {
      const account = await loginAs(role);
      await coursesPage.goto();

      // App.vue redirects to /login when session.getAccount() is falsy; staying
      // off /login proves the injected session was accepted.
      await expect(page).not.toHaveURL(loginPage.url);

      // The SPA recognizes the account: the credential cookie round-tripped.
      const credential = await page.evaluate(() =>
        document.cookie.split('; ').find((c) => c.startsWith('account_credential='))?.slice('account_credential='.length),
      );
      expect(credential).toBe(account.credential);
    });
  }

  test('logout clears the session and forces re-login', async ({ page, loginAs, appShell, coursesPage, loginPage }) => {
    await loginAs('owner');
    await coursesPage.goto();
    await expect(page).not.toHaveURL(loginPage.url);

    await appShell.logout();

    await expect(page).toHaveURL(loginPage.url);
    const hasCredential = await page.evaluate(() => document.cookie.includes('account_credential='));
    expect(hasCredential).toBe(false);
  });
});
