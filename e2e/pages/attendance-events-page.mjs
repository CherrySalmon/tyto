import { expect } from '@playwright/test';
import { Select } from '../components/select.mjs';
import { openCourseTab } from '../helpers.mjs';

// The Attendance Events management tab (manager-only). Download/create controls
// plus the create-event dialog and per-event delete.
export class AttendanceEventsPage {
  constructor(page) {
    this.page = page;
    this.downloadButton = page.getByRole('button', { name: 'Download Record' });
    this.createCard = page.locator('.event-item', { hasText: 'Create Event' });
  }

  async open() {
    await openCourseTab(this.page, 'Attendance Events');
    return this;
  }

  card(name) {
    return this.page.locator('.event-item', { hasText: name });
  }

  async createEvent(name, { location, start, end }) {
    await this.createCard.click();
    const dlg = this.page.getByRole('dialog', { name: 'Create Attendance Event' });
    await expect(dlg).toBeVisible();

    await dlg.getByPlaceholder('e.g. Week 08 Lecture').fill(name);
    await Select.inForm(dlg, 'Location').choose(location);

    // Datetime pickers accept typed "YYYY-MM-DD HH:mm:ss"; Enter commits.
    const startInput = dlg.getByPlaceholder('Select start time');
    await startInput.fill(start);
    await startInput.press('Enter');
    const endInput = dlg.getByPlaceholder('Select end time');
    await endInput.fill(end);
    await endInput.press('Enter');

    await dlg.getByRole('button', { name: 'Create event' }).click();
    await expect(dlg).toBeHidden();
  }

  async deleteEvent(name) {
    // The trash icon is the last el-icon in the event card.
    await this.card(name).locator('.el-icon').last().click();
  }
}
