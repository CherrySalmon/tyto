import { test, expect } from './fixtures.mjs';
import { openE2eCourse, chooseOption } from './helpers.mjs';

// Plan tasks 8a (manager management view + "view as role" switcher) and
// 8b (student is forced to the read-only branch via redirectIfNotManager).
//
// Course-list cards link everyone to /course/:id/attendance. Managers
// (owner/instructor/staff — can_update) get the tabbed management branch with a
// role switcher; students (can_update=false) are redirected to the Assignments
// view. We reach the course by clicking its card so the id is never hardcoded.

test.describe('SingleCourse management view (task 8a)', () => {
  test('manager sees the management tabs and role switcher', async ({ page, loginAs }) => {
    await loginAs('owner');
    await openE2eCourse(page);

    for (const tab of ['Attendance Events', 'Locations', 'People', 'Assignments']) {
      await expect(page.getByRole('link', { name: tab })).toBeVisible();
    }
    await expect(page.locator('.selecor-role-container .el-select')).toBeVisible();
  });

  test('multi-role manager can switch the viewed role', async ({ page, loginAs }) => {
    await loginAs('multi');
    await openE2eCourse(page);

    // Open the "View" role select and pick the student role.
    await chooseOption(page, 'student', page.locator('.selecor-role-container .el-select'));

    // changeRole pops a confirm dialog, then a success toast on OK.
    await page.getByRole('button', { name: 'OK' }).click();
    await expect(page.getByText('Change to student view').first()).toBeVisible();
  });
});

test.describe('SingleCourse read-only branch (task 8b)', () => {
  test('student is redirected from /attendance to the Assignments view', async ({ page, loginAs }) => {
    await loginAs('student');
    await openE2eCourse(page);

    // redirectIfNotManager() replaces the management route with AssignmentsCard.
    await expect(page).toHaveURL(/\/course\/\d+\/assignments/);
  });

  test('student does not see management tabs', async ({ page, loginAs }) => {
    await loginAs('student');
    await openE2eCourse(page);

    await expect(page.getByRole('link', { name: 'People' })).toHaveCount(0);
    await expect(page.getByRole('link', { name: 'Locations' })).toHaveCount(0);
    await expect(page.getByRole('link', { name: 'Attendance Events' })).toHaveCount(0);
  });
});
