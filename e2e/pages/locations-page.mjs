import { openCourseTab } from '../helpers.mjs';

// LocationCard.vue — the Locations management tab. Creating a location happens
// inside a Google Maps popup (out of scope for headless E2E); here we cover the
// list, the help note, renaming in place, and delete.
export class LocationsPage {
  constructor(page) {
    this.page = page;
    this.helpNote = page.getByText('Click a spot or a place on the map to create a new location.');
    this.renameInput = page.locator('.location-item .location-rename-input input');
  }

  async open() {
    await openCourseTab(this.page, 'Locations');
    return this;
  }

  card(name) {
    return this.page.locator('.location-item', { hasText: name });
  }

  async startRename(name) {
    await this.page.getByRole('button', { name: `Rename ${name}`, exact: true }).click();
    return this.renameInput;
  }

  // Renames in place and commits with Enter.
  async rename(name, newName) {
    const input = await this.startRename(name);
    await input.fill(newName);
    await input.press('Enter');
  }

  async delete(name) {
    // The trash (Delete) is the last button in the location row.
    await this.card(name).getByRole('button').last().click();
  }
}
