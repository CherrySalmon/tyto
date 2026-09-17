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

// feat-new-members Slice 3 — search, sort, detail modal, delete confirm, guard.

test('admin can search the table down to one account', async ({ loginAs, manageAccountPage }) => {
  await loginAs('admin');
  await manageAccountPage.goto();
  const email = SEED.accounts.instructor.email;

  await manageAccountPage.search(email);

  await expect(manageAccountPage.rows()).toHaveCount(1);
  await expect(manageAccountPage.row(email)).toBeVisible();
});

test('sorting by Roles puts the admin first', async ({ loginAs, manageAccountPage }) => {
  await loginAs('admin');
  await manageAccountPage.goto();

  await manageAccountPage.sortBy('Roles');

  await expect(manageAccountPage.rows().first()).toContainText(/admin/i);
});

test('the account detail shows the seeded course under enrollments', async ({ loginAs, manageAccountPage }) => {
  await loginAs('admin');
  await manageAccountPage.goto();
  const email = SEED.accounts.instructor.email;

  await manageAccountPage.openDetail(email);

  await expect(manageAccountPage.detailDialog).toContainText(email);
  await expect(manageAccountPage.detailDialog).toContainText(SEED.course.name);
  await expect(manageAccountPage.detailDialog).toContainText('instructor');
  await manageAccountPage.closeDetail();
});

test('admin cannot delete their own account from the table', async ({ loginAs, manageAccountPage }) => {
  const admin = await loginAs('admin');
  await manageAccountPage.goto();

  await expect(manageAccountPage.deleteButton(admin.email)).toBeDisabled();
});

// Assumes a freshly-seeded DB: the deletable fixture is gone after this runs.
test('delete needs the typed email, names the enrollment count, and removes the row', async ({
  loginAs, manageAccountPage,
}) => {
  await loginAs('admin');
  await manageAccountPage.goto();
  const email = SEED.accounts.deletable.email;

  await manageAccountPage.openDelete(email);
  await expect(manageAccountPage.deleteDialog).toContainText(/1 course enrollment/);
  await expect(manageAccountPage.confirmDeleteButton()).toBeDisabled();

  await manageAccountPage.typeDeleteConfirmation('wrong@e2e.test');
  await expect(manageAccountPage.confirmDeleteButton()).toBeDisabled();

  await manageAccountPage.cancelDelete();
  await expect(manageAccountPage.row(email)).toBeVisible();

  await manageAccountPage.openDelete(email);
  await manageAccountPage.typeDeleteConfirmation(email);
  await expect(manageAccountPage.confirmDeleteButton()).toBeEnabled();
  await manageAccountPage.confirmDeleteButton().click();

  await expect(manageAccountPage.deleteDialog).toBeHidden();
  await expect(manageAccountPage.row(email)).toHaveCount(0);
  await manageAccountPage.goto();
  await expect(manageAccountPage.row(email)).toHaveCount(0);
});

test('a non-admin navigating to /manage-account is sent home', async ({ loginAs, page, manageAccountPage, coursesPage }) => {
  await loginAs('owner');

  await page.goto('/manage-account');

  await expect(page).toHaveURL(/\/$/);
  await expect(coursesPage.welcomeHeading).toBeVisible();
  await expect(manageAccountPage.title).toHaveCount(0);
});
