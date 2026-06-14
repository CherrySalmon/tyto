import { expect } from '@playwright/test';

// The home page (AllCourse.vue): the enrolled-course list, the creator-only
// "Start a New Course" flow, and the active-event cards a student checks in
// from. Course names render as <h3> headings; both course cards and event
// cards use the .course-item class.
export class CoursesPage {
  // The URL of a single course once a card is opened (/course/:id/...). Static
  // because helpers.openE2eCourse needs it without an instance; it is the one
  // route literal shared beyond a spec, so it lives here once.
  static courseUrl = /\/course\/\d+\//;

  constructor(page) {
    this.page = page;
    // The named course-list route. The router serves the list at both / (which
    // goto() uses) and /course; this is the protected route auth's logged-out
    // redirect probe hits.
    this.path = '/course';
    this.welcomeHeading = page.getByRole('heading', { name: /Welcome Back/ });
    this.newCourseButton = page.getByRole('button', { name: 'Start a New Course' });
  }

  async goto() {
    await this.page.goto('/');
    return this;
  }

  courseCard(name) {
    return this.page.getByRole('heading', { level: 3, name });
  }

  async openCourse(name) {
    await this.courseCard(name).click();
    await this.page.waitForURL(CoursesPage.courseUrl);
  }

  async startNewCourse(name) {
    await this.newCourseButton.click();
    const dialog = this.page.getByRole('dialog', { name: 'Create Course' });
    await expect(dialog).toBeVisible();
    await dialog.locator('.el-form-item', { hasText: 'Name' }).getByRole('textbox').fill(name);
    await dialog.getByRole('button', { name: 'Confirm' }).click();
    await expect(dialog).toBeHidden();
  }

  // Active-event card on the home page (events render as .course-item too).
  eventCard(name) {
    return this.page.locator('.course-item', { hasText: name });
  }

  async markAttendance(eventName) {
    await this.eventCard(eventName).getByRole('button', { name: 'Mark Attendance' }).click();
  }
}
