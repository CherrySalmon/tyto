import { test, expect } from './fixtures.mjs';

// Plan tasks 6b (course list per role) and 7 (creator creates a course).
// AllCourse.vue renders each enrolled course as a card with an <h3> name and
// gates "Start a New Course" behind the `creator` system role.

function e2eCourseCard(page) {
  return page.getByRole('heading', { level: 3, name: 'E2E Course' });
}

test.describe('Course list (task 6b)', () => {
  for (const role of ['owner', 'instructor', 'staff', 'student']) {
    test(`${role} sees the E2E Course they are enrolled in`, async ({ page, loginAs }) => {
      await loginAs(role);
      await page.goto('/');
      await expect(e2eCourseCard(page)).toBeVisible();
    });
  }

  test('creator (not enrolled in E2E Course) does not see it', async ({ page, loginAs }) => {
    await loginAs('creator');
    await page.goto('/');
    // Wait for the list to load: the welcome header is rendered from the session
    // immediately, and the course fetch resolves after.
    await expect(page.getByRole('heading', { name: /Welcome Back/ })).toBeVisible();
    await expect(e2eCourseCard(page)).toHaveCount(0);
  });
});

test.describe('Create course (task 7)', () => {
  test('creator can create a course and it appears in the list', async ({ page, loginAs }) => {
    await loginAs('creator');
    await page.goto('/');

    const courseName = `PW Course ${Date.now()}`;

    await page.getByRole('button', { name: 'Start a New Course' }).click();

    const dialog = page.getByRole('dialog', { name: 'Create Course' });
    await expect(dialog).toBeVisible();
    await dialog.locator('.el-form-item', { hasText: 'Name' }).getByRole('textbox').fill(courseName);
    await dialog.getByRole('button', { name: 'Confirm' }).click();

    await expect(dialog).toBeHidden();
    await expect(page.getByRole('heading', { level: 3, name: courseName })).toBeVisible();
  });

  test('non-creator (student) does not see the create-course button', async ({ page, loginAs }) => {
    await loginAs('student');
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Start a New Course' })).toHaveCount(0);
  });
});
