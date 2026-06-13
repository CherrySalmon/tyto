import { test, expect } from './fixtures.mjs';

// Plan task 13 — admin account management. Admin opens /manage-account and
// changes a target user's system roles via the Edit dialog (PUT /account/:id).

test('admin can change a user system role', async ({ page, loginAs }) => {
  await loginAs('admin');
  await page.goto('/manage-account');

  await expect(page.getByText('Accounts Management')).toBeVisible();

  // Target a course-role account whose system roles other specs don't read from
  // the DB (they read the cookie), so this change is isolated.
  const row = page.getByRole('row', { name: /e2e-staff@e2e\.test/ });
  await expect(row).toBeVisible();

  await row.getByRole('button', { name: 'Edit' }).click();
  const dlg = page.getByRole('dialog', { name: 'Edit Account' });
  await expect(dlg).toBeVisible();

  // Add the Creator system role.
  await dlg.locator('.el-form-item', { hasText: 'Roles' }).locator('.el-select').click();
  await page.locator('.el-select-dropdown__item', { hasText: 'Creator' }).click();
  await page.keyboard.press('Escape');
  await dlg.getByRole('button', { name: 'Confirm' }).click();

  await expect(page.getByRole('row', { name: /e2e-staff@e2e\.test/ })).toContainText('creator');
});

test('non-admin sees no Account Management menu item', async ({ page, loginAs }) => {
  await loginAs('owner');
  await page.goto('/');
  // The admin side menu / popover entry is gated on the admin role.
  await expect(page.getByText('Account Management')).toHaveCount(0);
});
