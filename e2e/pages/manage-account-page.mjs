import { expect } from '@playwright/test';
import { editRolesByEmail } from '../components/roles-dialog.mjs';
import { Select } from '../components/select.mjs';

// ManageAccount.vue (admin) — change a user's system roles via the shared
// "Edit Account" dialog (PUT /account/:id), and bulk-add accounts through the
// two-step "Add accounts" dialog (POST /account/bulk, then PUT per row).
export class ManageAccountPage {
  constructor(page) {
    this.page = page;
    this.title = page.getByText('Accounts Management');
    this.addAccountsButton = page.getByRole('button', { name: 'Add accounts' });
    this.addDialog = page.getByRole('dialog', { name: 'Add accounts' });
    this.searchBox = page.getByPlaceholder('Search name, email, or role');
    this.detailDialog = page.getByRole('dialog', { name: 'Account' });
    this.deleteDialog = page.getByRole('dialog', { name: 'Delete account' });
  }

  // All data rows of the accounts table (header row excluded).
  rows() {
    return this.page.locator('.el-table__body-wrapper').getByRole('row');
  }

  async search(query) {
    await this.searchBox.fill(query);
  }

  // Click a column header to sort by it (first click = ascending).
  async sortBy(columnLabel) {
    await this.page.locator('.el-table__header').getByRole('columnheader', { name: columnLabel }).click();
  }

  // Open the account detail modal by clicking the name link in a row.
  async openDetail(email) {
    await this.row(email).locator('.el-link').click();
    await expect(this.detailDialog).toBeVisible();
  }

  async closeDetail() {
    // The footer button, not el-dialog's own "×" (also named Close).
    await this.detailDialog.locator('.el-dialog__footer').getByRole('button', { name: 'Close' }).click();
    await expect(this.detailDialog).toBeHidden();
  }

  deleteButton(email) {
    return this.row(email).getByRole('button', { name: 'Delete' });
  }

  async openDelete(email) {
    await this.deleteButton(email).click();
    await expect(this.deleteDialog).toBeVisible();
  }

  async typeDeleteConfirmation(text) {
    await this.deleteDialog.getByRole('textbox').fill(text);
  }

  confirmDeleteButton() {
    return this.deleteDialog.getByRole('button', { name: 'Delete account' });
  }

  async cancelDelete() {
    await this.deleteDialog.getByRole('button', { name: 'Cancel' }).click();
    await expect(this.deleteDialog).toBeHidden();
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

  // Step 1 of the Add accounts dialog: paste the emails and submit. Resolves
  // once the results step (step 2) is showing.
  async addAccounts(emails) {
    await this.addAccountsButton.click();
    await expect(this.addDialog).toBeVisible();
    await this.addDialog.getByRole('textbox').fill(emails.join('\n'));
    await this.addDialog.getByRole('button', { name: /^Add \d+ accounts?$/ }).click();
    await expect(this.addDialog.getByRole('button', { name: 'Done' })).toBeVisible();
  }

  // A row of the results step, found by its email.
  resultRow(email) {
    return this.addDialog.getByRole('row', { name: email });
  }

  // Add a system role on a results row (its el-select multi-select).
  async setRoleInResults(email, role) {
    await new Select(this.page, this.resultRow(email).locator('.el-select')).add(role);
  }

  async finishAddAccounts() {
    await this.addDialog.getByRole('button', { name: 'Done' }).click();
    await expect(this.addDialog).toBeHidden();
  }
}
