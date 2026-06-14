import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan task 14 — Locations (manager). The list + delete are plain DOM, but
// CREATE/UPDATE happen by clicking a Google Maps widget to pick coordinates
// (see LocationCard.vue), which needs a live Maps API key and can't run in
// headless E2E — so those are out of scope here (noted in the plan). We cover
// the manager-visible list, the create affordance, and a real delete.

test('owner sees the locations list and create affordance', async ({ loginAs, locationsPage }) => {
  await loginAs('owner');
  await locationsPage.open();

  await expect(locationsPage.card(SEED.mainHall.name)).toBeVisible();
  await expect(locationsPage.createButton).toBeVisible();
  await expect(locationsPage.nameInput).toBeVisible();
});

test('owner can delete a location', async ({ loginAs, locationsPage }) => {
  await loginAs('owner');
  await locationsPage.open();

  // Delete the event-free spare location (deleting E2E Main Hall would cascade
  // the seeded attendance event). Assumes fresh DB — gone on re-run.
  await expect(locationsPage.card(SEED.spareRoom.name)).toBeVisible();
  await locationsPage.delete(SEED.spareRoom.name);
  await expect(locationsPage.card(SEED.spareRoom.name)).toHaveCount(0);
});
