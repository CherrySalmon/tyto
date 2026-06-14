// Global app chrome present on every authenticated page: the avatar menu
// (logout) and the admin-only nav entries.
export class AppShell {
  constructor(page) {
    this.page = page;
  }

  // Logout lives in the avatar popover (renders because E2E accounts have an
  // avatar). Hover to reveal it, then click.
  async logout() {
    await this.page.locator('.avatar-btn').first().hover();
    await this.page.getByText('Logout', { exact: true }).click();
  }

  // The admin-only "Account Management" nav entry.
  accountManagementMenu() {
    return this.page.getByText('Account Management');
  }
}
