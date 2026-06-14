import { expect } from '@playwright/test';
import { Select } from '../components/select.mjs';
import { openCourseTab, openE2eCourse } from '../helpers.mjs';

// The Assignments view. Managers reach it via the management tab and get the
// full lifecycle (create / publish / unpublish / delete); students are routed
// here read-only by redirectIfNotManager and can submit to published ones.
export class AssignmentsPage {
  constructor(page) {
    this.page = page;
    this.createCard = page.locator('.assignment-item', { hasText: 'Create Assignment' });
    // Every assignment card's action group (Edit/Publish/Delete); absent in the
    // student read-only view.
    this.actionGroups = page.locator('.assignment-item .assignment-actions');
  }

  // Manager entry: the Assignments management tab.
  async open() {
    await openCourseTab(this.page, 'Assignments');
    return this;
  }

  // Student entry: redirectIfNotManager lands them on the read-only view.
  async openAsStudent() {
    await openE2eCourse(this.page);
    return this;
  }

  card(title) {
    return this.page.locator('.assignment-item', { hasText: title });
  }

  status(title) {
    return this.card(title).locator('.el-tag');
  }

  // Within an assignment card the actions are [Edit, Publish|Unpublish, Delete];
  // index 1 is the publish/unpublish toggle regardless of title attributes.
  #statusToggle(title) {
    return this.card(title).locator('.assignment-actions .el-icon').nth(1);
  }

  async create(title, { urlRequirement } = {}) {
    await this.createCard.click();
    const dlg = this.page.getByRole('dialog', { name: 'Create Assignment' });
    await expect(dlg).toBeVisible();
    await dlg.getByPlaceholder('Assignment title').fill(title);

    if (urlRequirement) {
      // The dialog seeds one (file, empty-description) requirement row. Switch
      // it to a URL requirement so a student can submit without a file upload.
      const row = dlg.locator('.requirement-row').first();
      await new Select(this.page, row.locator('.el-select')).choose('URL');
      await row.getByPlaceholder(/Description/).fill(urlRequirement);
    }

    await dlg.getByRole('button', { name: 'Create' }).click();
    await expect(dlg).toBeHidden();
  }

  async publish(title) {
    await this.#statusToggle(title).click();
    await this.page.getByRole('button', { name: 'Publish' }).click();
    await expect(this.status(title)).toHaveText('published');
  }

  async unpublish(title) {
    await this.#statusToggle(title).click();
    await this.page.getByRole('button', { name: 'Unpublish' }).click();
    await expect(this.status(title)).toHaveText('draft');
  }

  // Open a published assignment and submit a URL; returns the dialog Locator so
  // callers can assert on its post-submit state.
  async submitUrl(title, url) {
    await this.card(title).click();
    const dlg = this.page.getByRole('dialog', { name: title });
    await expect(dlg).toBeVisible();
    await dlg.getByPlaceholder('Enter URL').fill(url);
    await dlg.getByRole('button', { name: 'Submit', exact: true }).click();
    return dlg;
  }
}
