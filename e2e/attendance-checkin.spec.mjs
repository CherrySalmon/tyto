import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan task 11 — student geo-fenced attendance check-in.
//
// The home page (AllCourse) lists active events with a "Mark Attendance"
// button; recordAttendance() reads navigator.geolocation and POSTs lat/long.
// The backend enforces a 55m geo-fence (Haversine) and the event time window.
// We mock the browser position with Playwright's geolocation context option.
//
// Serial + rejection-first: the rejection attempt records nothing, so the
// "Mark Attendance" button is still present for the success attempt; the
// success attempt records last. Assumes a freshly-seeded DB (rake spec:e2e),
// since a recorded attendance hides the button on re-run.

// The geo-fence is the seeded Main Hall's own coordinates (the event is held
// there), sourced from the seed so the fence and the location never drift.
const FENCE = { latitude: SEED.mainHall.latitude, longitude: SEED.mainHall.longitude };
const FAR_AWAY = { latitude: 24.0, longitude: 121.0 }; // ~100+ km away
const LIVE_SESSION = SEED.event.name;

test.use({ permissions: ['geolocation'], geolocation: FENCE });

test.describe.serial('Student attendance check-in (task 11)', () => {
  test('rejects check-in from outside the geo-fence', async ({ page, context, loginAs, coursesPage }) => {
    await context.setGeolocation(FAR_AWAY);
    await loginAs('student');
    await coursesPage.goto();

    await coursesPage.markAttendance(LIVE_SESSION);

    // recordAttendance surfaces the backend 403 detail in an alert.
    await expect(page.getByText(/outside the allowed geo-fence range/i)).toBeVisible();
  });

  test('accepts check-in from inside the geo-fence', async ({ page, context, loginAs, coursesPage }) => {
    await context.setGeolocation(FENCE);
    await loginAs('student');
    await coursesPage.goto();

    await coursesPage.markAttendance(LIVE_SESSION);

    await expect(page.getByText('Attendance recorded successfully')).toBeVisible();
    // Dismiss the success alert; the card flips to the recorded state.
    await page.getByRole('button', { name: 'OK' }).click();
    await expect(coursesPage.eventCard(LIVE_SESSION).getByRole('button', { name: 'Attendance Recorded' })).toBeVisible();
  });
});
