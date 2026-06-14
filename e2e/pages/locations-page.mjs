import { openCourseTab } from '../helpers.mjs';

// LocationCard.vue — the Locations management tab. Create/update happen inside
// a Google Maps widget (out of scope for headless E2E); here we cover the list,
// the create affordance, and delete.
export class LocationsPage {
  constructor(page) {
    this.page = page;
    this.createButton = page.getByRole('button', { name: 'Create New' });
    this.nameInput = page.getByPlaceholder('Enter a name of the location');
  }

  async open() {
    await openCourseTab(this.page, 'Locations');
    return this;
  }

  card(name) {
    return this.page.locator('.location-item', { hasText: name });
  }

  async delete(name) {
    // The trash (Delete) is the last button in the location row.
    await this.card(name).getByRole('button').last().click();
  }
}
