import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan task 13 — admin account management. Admin opens /manage-account and
// changes a target user's system roles via the Edit dialog (PUT /account/:id).

test('admin can change a user system role', async ({ loginAs, manageAccountPage }) => {
  await loginAs('admin');
  await manageAccountPage.goto();

  // Target a course-role account whose system roles other specs don't read from
  // the DB (they read the cookie), so this change is isolated.
  const email = SEED.accounts.staff.email;
  await expect(manageAccountPage.row(email)).toBeVisible();

  await manageAccountPage.addRole(email, 'Creator');

  await expect(manageAccountPage.row(email)).toContainText('creator');
});

test('non-admin sees no Account Management menu item', async ({ loginAs, coursesPage, appShell }) => {
  await loginAs('owner');
  await coursesPage.goto();
  // The admin side menu / popover entry is gated on the admin role.
  await expect(appShell.accountManagementMenu()).toHaveCount(0);
});
