import { expect } from '@playwright/test';
import { Select } from './select.mjs';

// The "Edit Account" dialog. Two *separate* screens render their own
// near-identical copy of it (app-level duplication, not a shared component):
//  - ManagePeopleCard.vue   — edits a course enrollment's roles (enroll_identity)
//  - ManageAccount.vue      — edits an account's system roles
// Both produce the same accessible shape — title="Edit Account", a multi-select
// "Roles" field, and a Confirm footer button — so one object drives both. Open
// it from the target row's Edit button first.
export class RolesDialog {
  constructor(page) {
    this.page = page;
    this.dialog = page.getByRole('dialog', { name: 'Edit Account' });
  }

  async expectOpen() {
    await expect(this.dialog).toBeVisible();
    return this;
  }

  // Add a role to the multi-select. EP keeps the overlay open after a pick, so
  // Select.add() dismisses it so the Confirm button below is clickable.
  async addRole(role) {
    await Select.inForm(this.dialog, 'Roles').add(role);
    return this;
  }

  // Click Confirm. Does not wait for the dialog to disappear; callers assert
  // the resulting row state directly, and that assertion auto-retries past the
  // dialog close. GET /api/account now returns roles, so ManageAccount's rows
  // are durable after a reload (manage-account.spec.mjs reloads before asserting).
  async confirm() {
    await this.dialog.getByRole('button', { name: 'Confirm' }).click();
  }
}

// Drive the "Edit Account" dialog from a table row found by email: click that
// row's Edit, add a role, Confirm. Shared by PeoplePage and ManageAccountPage,
// whose tables and dialogs are identical at this level. Callers assert the
// resulting row state themselves.
export async function editRolesByEmail(page, email, role) {
  // Plain string => case-insensitive substring match on the row's accessible
  // name, with '.'/'+' literal (a RegExp would treat them as metacharacters).
  await page.getByRole('row', { name: email }).getByRole('button', { name: 'Edit' }).click();
  const dialog = await new RolesDialog(page).expectOpen();
  await dialog.addRole(role);
  await dialog.confirm();
}
