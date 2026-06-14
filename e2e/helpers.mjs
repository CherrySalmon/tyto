import { expect } from '@playwright/test';
import { CoursesPage } from './pages/courses-page.mjs';
import { SEED } from './seed-data.mjs';

// Pure navigation helpers shared by the page objects (e2e/pages/). Selector
// quarantine lives in the page/component objects; these are URL/role-locator
// navigation only.

// Open the seeded "E2E Course" by clicking its card on the home page, so the
// course id is never hardcoded. Lands on /course/:id/attendance (or, for
// non-managers, wherever redirectIfNotManager sends them).
export async function openE2eCourse(page) {
  const courses = new CoursesPage(page);
  await courses.goto();
  await courses.openCourse(SEED.course.name);
}

// Open a management tab (Attendance Events | Locations | People | Assignments)
// from within the course. Manager-only tabs require a teaching role.
export async function openCourseTab(page, tabName) {
  await openE2eCourse(page);
  const tab = page.getByRole('link', { name: tabName });
  await expect(tab).toBeVisible();
  await tab.click();
}

// A unique @e2e.test email so enrollment specs never collide across runs or
// parallel workers (worker index keeps concurrent workers distinct).
export function uniqueEmail(prefix, workerIndex = 0) {
  return `${prefix}-${workerIndex}-${Date.now()}@e2e.test`;
}
