import { expect } from '@playwright/test';
import { editRolesByEmail } from '../components/roles-dialog.mjs';

// ManageAccount.vue (admin) — change a user's system roles via the shared
// "Edit Account" dialog (PUT /account/:id).
export class ManageAccountPage {
  constructor(page) {
    this.page = page;
    this.title = page.getByText('Accounts Management');
  }

  async goto() {
    await this.page.goto('/manage-account');
    await expect(this.title).toBeVisible();
    return this;
  }

  row(email) {
    // Plain string => Playwright matches the accessible name case-insensitively
    // as a substring, with '.'/'+' treated literally (a RegExp would not).
    return this.page.getByRole('row', { name: email });
  }

  async addRole(email, role) {
    await editRolesByEmail(this.page, email, role);
  }
}
