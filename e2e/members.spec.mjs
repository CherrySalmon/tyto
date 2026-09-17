import { test, expect, credentialFor } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// feat-new-members Slice 2 — what an admin-added account can do. A `member`-only
// account (seeded unenrolled, like one fresh from the Add accounts dialog) can
// log in but sees no courses, no create-course control, and no admin menu.
// A `creator` account does see the create-course control.

test('member-only account logs in and sees no courses, no create button, no admin menu', async ({
  loginAs, coursesPage, appShell,
}) => {
  await loginAs('member');
  await coursesPage.goto();

  await expect(coursesPage.welcomeHeading).toBeVisible();
  await expect(coursesPage.courseCard(SEED.course.name)).toHaveCount(0);
  await expect(coursesPage.newCourseButton).toHaveCount(0);
  await expect(appShell.accountManagementMenu()).toHaveCount(0);
});

test('creator account sees the create-course button', async ({ loginAs, coursesPage }) => {
  await loginAs('creator');
  await coursesPage.goto();

  await expect(coursesPage.newCourseButton).toBeVisible();
});

// Roles are read from the DB on every request and the app refreshes its
// session on each navigation, so a role change shows up without re-login.
// Assumes a fresh seed: this promotes the staff account to creator.
test('a role change by an admin shows in the header and unlocks controls on the next navigation', async ({
  loginAs, page, coursesPage, request, baseURL,
}) => {
  const staff = await loginAs('staff');
  await coursesPage.goto();
  await expect(page.getByText(`${staff.name} - member`)).toBeVisible();
  await expect(coursesPage.newCourseButton).toHaveCount(0);

  const admin = credentialFor('admin');
  const response = await request.put(`${baseURL}/api/account/${staff.id}`, {
    headers: { Authorization: `Bearer ${admin.credential}`, 'Content-Type': 'application/json' },
    data: { roles: ['creator', 'member'] },
  });
  expect(response.ok()).toBeTruthy();

  await coursesPage.goto();
  await expect(page.getByText(`${staff.name} - creator, member`)).toBeVisible();
  await expect(coursesPage.newCourseButton).toBeVisible();
});
