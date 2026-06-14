import { editRolesByEmail } from '../components/roles-dialog.mjs';
import { openCourseTab } from '../helpers.mjs';

// ManagePeopleCard.vue — the People management tab. Enroll by email (2-step
// wizard, auto-creates the account as `member`), edit enrollment roles via the
// shared "Edit Account" dialog, and delete an enrollment.
export class PeoplePage {
  constructor(page) {
    this.page = page;
    this.emailInput = page.getByPlaceholder('Enter email addresses (space-separated)');
  }

  async open() {
    await openCourseTab(this.page, 'People');
    return this;
  }

  row(email) {
    // Plain string => Playwright matches the accessible name case-insensitively
    // as a substring, with '.'/'+' treated literally (a RegExp would not).
    return this.page.getByRole('row', { name: email });
  }

  async enroll(email) {
    await this.emailInput.fill(email);
    await this.page.getByRole('button', { name: 'Next step' }).click();
    await this.page.getByRole('button', { name: 'Enroll in Course' }).click();
  }

  async addRole(email, role) {
    await editRolesByEmail(this.page, email, role);
  }

  async remove(email) {
    await this.row(email).getByRole('button', { name: 'Delete' }).click();
  }
}
