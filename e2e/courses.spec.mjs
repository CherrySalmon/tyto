import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan tasks 6b (course list per role) and 7 (creator creates a course).
// AllCourse.vue renders each enrolled course as a card with an <h3> name and
// gates "Start a New Course" behind the `creator` system role.

test.describe('Course list (task 6b)', () => {
  for (const role of ['owner', 'instructor', 'staff', 'student']) {
    test(`${role} sees the E2E Course they are enrolled in`, async ({ loginAs, coursesPage }) => {
      await loginAs(role);
      await coursesPage.goto();
      await expect(coursesPage.courseCard(SEED.course.name)).toBeVisible();
    });
  }

  test('creator (not enrolled in E2E Course) does not see it', async ({ loginAs, coursesPage }) => {
    await loginAs('creator');
    await coursesPage.goto();
    // Wait for the list to load: the welcome header renders from the session
    // immediately, and the course fetch resolves after.
    await expect(coursesPage.welcomeHeading).toBeVisible();
    await expect(coursesPage.courseCard(SEED.course.name)).toHaveCount(0);
  });
});

test.describe('Create course (task 7)', () => {
  test('creator can create a course and it appears in the list', async ({ loginAs, coursesPage }) => {
    await loginAs('creator');
    await coursesPage.goto();

    const courseName = `PW Course ${Date.now()}`;
    await coursesPage.startNewCourse(courseName);

    await expect(coursesPage.courseCard(courseName)).toBeVisible();
  });

  test('non-creator (student) does not see the create-course button', async ({ loginAs, coursesPage }) => {
    await loginAs('student');
    await coursesPage.goto();
    await expect(coursesPage.newCourseButton).toHaveCount(0);
  });
});
