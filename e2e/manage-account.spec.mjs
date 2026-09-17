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

  // Reload so the row reflects what the API returns, not the in-place mutation
  // the Edit dialog made on the row object. GET /api/account must carry roles.
  await manageAccountPage.goto();
  await expect(manageAccountPage.row(email)).toContainText(/creator/i);
});

// feat-new-members Slice 2 — bulk add. Assumes a freshly-seeded DB (rake
// spec:e2e): on a re-run these emails already exist and land in the
// "already existed" bucket instead of "added".
test('admin bulk-adds accounts, then sets a role on one of them', async ({ loginAs, manageAccountPage }) => {
  await loginAs('admin');
  await manageAccountPage.goto();
  const one = 'e2e-added-one@e2e.test';
  const two = 'e2e-added-two@e2e.test';

  await manageAccountPage.addAccounts([one, two]);

  await expect(manageAccountPage.resultRow(one)).toContainText(/added/i);
  await expect(manageAccountPage.resultRow(one)).toContainText(/member/i);
  await expect(manageAccountPage.resultRow(two)).toContainText(/added/i);

  await manageAccountPage.setRoleInResults(one, 'Creator');
  await manageAccountPage.finishAddAccounts();

  // The table refetches from the API on Done; reload to be sure the rows are durable.
  await manageAccountPage.goto();
  await expect(manageAccountPage.row(one)).toContainText(/creator/i);
  await expect(manageAccountPage.row(two)).toContainText(/member/i);
  await expect(manageAccountPage.row(two)).not.toContainText(/creator/i);
});

test('non-admin sees no Account Management menu item', async ({ loginAs, coursesPage, appShell }) => {
  await loginAs('owner');
  await coursesPage.goto();
  // The admin side menu / popover entry is gated on the admin role.
  await expect(appShell.accountManagementMenu()).toHaveCount(0);
});
