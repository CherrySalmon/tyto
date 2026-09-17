import { test, expect } from './fixtures.mjs';
import { SEED } from './seed-data.mjs';

// Plan task 14 — Locations (manager). The list, rename, and delete are plain
// DOM, but CREATE happens in a Google Maps popup (see LocationCard.vue), which
// needs a live Maps API key and can't run in headless E2E — Vitest covers it
// with a Maps stub instead. We cover the manager-visible list, the help note
// that replaced the old create form, renaming in place, and a real delete.
//
// Serial: the rename and delete specs both touch the spare location.
test.describe.configure({ mode: 'serial' });

test('owner sees the locations list and the click-the-map note', async ({ loginAs, locationsPage, page }) => {
  await loginAs('owner');
  await locationsPage.open();

  await expect(locationsPage.card(SEED.mainHall.name)).toBeVisible();
  await expect(locationsPage.helpNote).toBeVisible();
  await expect(page.getByRole('button', { name: 'Create New' })).toHaveCount(0);
  await expect(page.getByPlaceholder('Enter a name of the location')).toHaveCount(0);
});

test('owner can rename a location in place', async ({ loginAs, locationsPage }) => {
  await loginAs('owner');
  await locationsPage.open();

  const renamed = `${SEED.spareRoom.name} Renamed`;
  await locationsPage.rename(SEED.spareRoom.name, renamed);
  await expect(locationsPage.card(renamed)).toBeVisible();

  // Restore the seeded name so the delete spec below finds it.
  await locationsPage.rename(renamed, SEED.spareRoom.name);
  await expect(locationsPage.card(renamed)).toHaveCount(0);
  await expect(locationsPage.card(SEED.spareRoom.name)).toBeVisible();
});

test('a blank rename reverts to the original name', async ({ loginAs, locationsPage }) => {
  await loginAs('owner');
  await locationsPage.open();

  await locationsPage.rename(SEED.mainHall.name, '   ');
  await expect(locationsPage.renameInput).toHaveCount(0);
  await expect(locationsPage.card(SEED.mainHall.name)).toBeVisible();
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
