import { test, expect } from './fixtures.mjs';
import { openCourseTab, openE2eCourse } from './helpers.mjs';

// Plan tasks 10a (manager create/delete attendance events) and 10b (students
// never reach the management view — covered structurally by 8b, re-asserted at
// the controls level here).

test.describe('Attendance events — manager (task 10a)', () => {
  test('owner sees management controls, creates an event, then deletes it', async ({ page, loginAs }) => {
    await loginAs('owner');
    await openCourseTab(page, 'Attendance Events');

    // Manager-only controls are present.
    await expect(page.getByRole('button', { name: 'Download Record' })).toBeVisible();
    const createCard = page.locator('.event-item', { hasText: 'Create Event' });
    await expect(createCard).toBeVisible();

    const eventName = `PW Event ${Date.now()}`;

    await createCard.click();
    const dlg = page.getByRole('dialog', { name: 'Create Attendance Event' });
    await expect(dlg).toBeVisible();

    await dlg.getByPlaceholder('e.g. Week 08 Lecture').fill(eventName);

    // Location select -> E2E Main Hall
    await dlg.locator('.el-form-item', { hasText: 'Location' }).locator('.el-select').click();
    await page.locator('.el-select-dropdown__item', { hasText: 'E2E Main Hall' }).click();

    // Datetime pickers accept typed input in "YYYY-MM-DD HH:mm:ss"; Enter commits.
    const startInput = dlg.getByPlaceholder('Select start time');
    await startInput.fill('2026-07-01 09:00:00');
    await startInput.press('Enter');
    const endInput = dlg.getByPlaceholder('Select end time');
    await endInput.fill('2026-07-01 11:00:00');
    await endInput.press('Enter');

    await dlg.getByRole('button', { name: 'Create event' }).click();
    await expect(dlg).toBeHidden();

    const card = page.locator('.event-item', { hasText: eventName });
    await expect(card).toBeVisible();

    // Delete it (the trash icon is the last el-icon in the card).
    await card.locator('.el-icon').last().click();
    await expect(page.locator('.event-item', { hasText: eventName })).toHaveCount(0);
  });
});

test.describe('Attendance events — student (task 10b)', () => {
  test('student cannot reach the attendance view or its controls', async ({ page, loginAs }) => {
    await loginAs('student');
    await openE2eCourse(page);

    // redirectIfNotManager sends students to the assignments view.
    await expect(page).toHaveURL(/\/course\/\d+\/assignments/);
    await expect(page.getByRole('button', { name: 'Download Record' })).toHaveCount(0);
    await expect(page.locator('.event-item', { hasText: 'Create Event' })).toHaveCount(0);
  });
});
