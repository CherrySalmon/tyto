import { test, expect } from './fixtures.mjs';
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
