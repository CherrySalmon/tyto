import { test, expect } from './fixtures.mjs';
import { openCourseTab, uniqueEmail } from './helpers.mjs';

// Plan task 9 — Manage People (owner/instructor). One sequential flow against a
// throwaway enrollee so it never mutates the seeded enrollments other specs
// rely on: enroll by email -> assign/extend role -> delete.

test('owner can enroll, re-role, and remove a course member', async ({ page, loginAs }, testInfo) => {
  await loginAs('owner');
  await openCourseTab(page, 'People');

  const email = uniqueEmail('e2e-enrollee', testInfo.workerIndex);

  // --- Enroll (2-step wizard) -------------------------------------------------
  await page.getByPlaceholder('Enter email addresses (space-separated)').fill(email);
  await page.getByRole('button', { name: 'Next step' }).click();
  await page.getByRole('button', { name: 'Enroll in Course' }).click();

  const row = page.getByRole('row', { name: new RegExp(email) });
  await expect(row).toBeVisible();
  // New enrollees default to the student role.
  await expect(row).toContainText('student');

  // --- Re-role: add staff -----------------------------------------------------
  await row.getByRole('button', { name: 'Edit' }).click();
  const dialog = page.getByRole('dialog', { name: 'Edit Account' });
  await expect(dialog).toBeVisible();

  await dialog.locator('.el-form-item', { hasText: 'Roles' }).locator('.el-select').click();
  await page.locator('.el-select-dropdown__item', { hasText: 'staff' }).click();
  // Close the dropdown overlay before clicking Confirm.
  await page.keyboard.press('Escape');
  await dialog.getByRole('button', { name: 'Confirm' }).click();
  await expect(dialog).toBeHidden();

  await expect(page.getByRole('row', { name: new RegExp(email) })).toContainText('staff');

  // --- Delete -----------------------------------------------------------------
  await page.getByRole('row', { name: new RegExp(email) }).getByRole('button', { name: 'Delete' }).click();
  await expect(page.getByRole('row', { name: new RegExp(email) })).toHaveCount(0);
});
