import { test, expect } from './fixtures.mjs';

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

const FENCE = { latitude: 25.0330, longitude: 121.5654 }; // E2E Main Hall
const FAR_AWAY = { latitude: 24.0, longitude: 121.0 }; // ~100+ km away

test.use({ permissions: ['geolocation'], geolocation: FENCE });

test.describe.serial('Student attendance check-in (task 11)', () => {
  function liveSessionCard(page) {
    return page.locator('.course-item', { hasText: 'E2E Live Session' });
  }

  test('rejects check-in from outside the geo-fence', async ({ page, context, loginAs }) => {
    await context.setGeolocation(FAR_AWAY);
    await loginAs('student');
    await page.goto('/');

    await liveSessionCard(page).getByRole('button', { name: 'Mark Attendance' }).click();

    // recordAttendance surfaces the backend 403 detail in an alert.
    await expect(page.getByText(/outside the allowed geo-fence range/i)).toBeVisible();
  });

  test('accepts check-in from inside the geo-fence', async ({ page, context, loginAs }) => {
    await context.setGeolocation(FENCE);
    await loginAs('student');
    await page.goto('/');

    await liveSessionCard(page).getByRole('button', { name: 'Mark Attendance' }).click();

    await expect(page.getByText('Attendance recorded successfully')).toBeVisible();
    // Dismiss the success alert; the card flips to the recorded state.
    await page.getByRole('button', { name: 'OK' }).click();
    await expect(liveSessionCard(page).getByRole('button', { name: 'Attendance Recorded' })).toBeVisible();
  });
});
