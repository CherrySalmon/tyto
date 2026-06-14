import { expect } from '@playwright/test';
import { Select } from '../components/select.mjs';
import { openE2eCourse } from '../helpers.mjs';

// SingleCourse.vue: the per-course management shell. Managers (can_update) get
// the tabbed view + a "view as role" switcher; non-teaching roles are sent to
// the read-only assignments branch by redirectIfNotManager().
//
// NOTE: `.selecor-role-container` is a typo carried from the component
// (SingleCourse.vue). Quarantined here so a future component fix is one line.
export class SingleCoursePage {
  constructor(page) {
    this.page = page;
    // Where redirectIfNotManager() sends a non-teaching role: the read-only
    // assignments view of the course. Asserted from single-course + attendance
    // -events specs, so the cross-spec contract lives once on this page object.
    this.assignmentsUrl = /\/course\/\d+\/assignments/;
    this.roleSwitcher = page.locator('.selecor-role-container .el-select');
  }

  async open() {
    await openE2eCourse(this.page);
    return this;
  }

  tab(name) {
    return this.page.getByRole('link', { name });
  }

  async openTab(name) {
    const tab = this.tab(name);
    await expect(tab).toBeVisible();
    await tab.click();
  }

  // Pick a role in the "view as" switcher and confirm the dialog. changeRole
  // refetches data and shows a "Change to … view" toast.
  async switchRole(role) {
    await new Select(this.page, this.roleSwitcher).choose(role);
    await this.page.getByRole('button', { name: 'OK' }).click();
  }
}
