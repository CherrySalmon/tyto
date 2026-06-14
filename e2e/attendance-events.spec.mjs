import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan tasks 10a (manager create/delete attendance events) and 10b (students
// never reach the management view — covered structurally by 8b, re-asserted at
// the controls level here).

test.describe('Attendance events — manager (task 10a)', () => {
  test('owner sees management controls, creates an event, then deletes it', async ({ loginAs, attendanceEventsPage }) => {
    await loginAs('owner');
    await attendanceEventsPage.open();

    // Manager-only controls are present.
    await expect(attendanceEventsPage.downloadButton).toBeVisible();
    await expect(attendanceEventsPage.createCard).toBeVisible();

    const eventName = `PW Event ${Date.now()}`;
    await attendanceEventsPage.createEvent(eventName, {
      location: SEED.mainHall.name,
      start: '2026-07-01 09:00:00',
      end: '2026-07-01 11:00:00',
    });

    await expect(attendanceEventsPage.card(eventName)).toBeVisible();

    await attendanceEventsPage.deleteEvent(eventName);
    await expect(attendanceEventsPage.card(eventName)).toHaveCount(0);
  });
});

test.describe('Attendance events — student (task 10b)', () => {
  test('student cannot reach the attendance view or its controls', async ({ page, loginAs, singleCoursePage, attendanceEventsPage }) => {
    await loginAs('student');
    await singleCoursePage.open();

    // redirectIfNotManager sends students to the assignments view.
    await expect(page).toHaveURL(singleCoursePage.assignmentsUrl);
    await expect(attendanceEventsPage.downloadButton).toHaveCount(0);
    await expect(attendanceEventsPage.createCard).toHaveCount(0);
  });
});
