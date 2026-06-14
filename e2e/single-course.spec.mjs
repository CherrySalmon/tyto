import { test, expect } from './fixtures.mjs';

// Plan tasks 8a (manager management view + "view as role" switcher) and
// 8b (student is forced to the read-only branch via redirectIfNotManager).
//
// Course-list cards link everyone to /course/:id/attendance. Managers
// (owner/instructor/staff — can_update) get the tabbed management branch with a
// role switcher; students (can_update=false) are redirected to the Assignments
// view.

test.describe('SingleCourse management view (task 8a)', () => {
  test('manager sees the management tabs and role switcher', async ({ loginAs, singleCoursePage }) => {
    await loginAs('owner');
    await singleCoursePage.open();

    for (const tab of ['Attendance Events', 'Locations', 'People', 'Assignments']) {
      await expect(singleCoursePage.tab(tab)).toBeVisible();
    }
    await expect(singleCoursePage.roleSwitcher).toBeVisible();
  });

  test('multi-role manager can switch the viewed role', async ({ page, loginAs, singleCoursePage }) => {
    await loginAs('multi');
    await singleCoursePage.open();

    await singleCoursePage.switchRole('student');
    await expect(page.getByText('Change to student view').first()).toBeVisible();
  });
});

test.describe('SingleCourse read-only branch (task 8b)', () => {
  test('student is redirected from /attendance to the Assignments view', async ({ page, loginAs, singleCoursePage }) => {
    await loginAs('student');
    await singleCoursePage.open();

    // redirectIfNotManager() replaces the management route with AssignmentsCard.
    await expect(page).toHaveURL(singleCoursePage.assignmentsUrl);
  });

  test('student does not see management tabs', async ({ loginAs, singleCoursePage }) => {
    await loginAs('student');
    await singleCoursePage.open();

    await expect(singleCoursePage.tab('People')).toHaveCount(0);
    await expect(singleCoursePage.tab('Locations')).toHaveCount(0);
    await expect(singleCoursePage.tab('Attendance Events')).toHaveCount(0);
  });
});
