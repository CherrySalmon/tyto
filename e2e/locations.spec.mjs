import { test, expect } from './fixtures.mjs';
import { openCourseTab } from './helpers.mjs';

// Plan task 14 — Locations (manager). The list + delete are plain DOM, but
// CREATE/UPDATE happen by clicking a Google Maps widget to pick coordinates
// (see LocationCard.vue), which needs a live Maps API key and can't run in
// headless E2E — so those are out of scope here (noted in the plan). We cover
// the manager-visible list, the create affordance, and a real delete.

test('owner sees the locations list and create affordance', async ({ page, loginAs }) => {
  await loginAs('owner');
  await openCourseTab(page, 'Locations');

  await expect(page.locator('.location-item', { hasText: 'E2E Main Hall' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Create New' })).toBeVisible();
  await expect(page.getByPlaceholder('Enter a name of the location')).toBeVisible();
});

test('owner can delete a location', async ({ page, loginAs }) => {
  await loginAs('owner');
  await openCourseTab(page, 'Locations');

  // Delete the event-free spare location (deleting E2E Main Hall would cascade
  // the seeded attendance event). Assumes fresh DB — gone on re-run.
  const spare = page.locator('.location-item', { hasText: 'E2E Spare Room' });
  await expect(spare).toBeVisible();
  await spare.getByRole('button').last().click(); // trash (Delete) is the last button in the row

  await expect(page.locator('.location-item', { hasText: 'E2E Spare Room' })).toHaveCount(0);
});
