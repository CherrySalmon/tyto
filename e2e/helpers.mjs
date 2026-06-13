import { expect } from '@playwright/test';

// Shared navigation helpers for E2E specs.

// Open the seeded "E2E Course" by clicking its card on the home page, so the
// course id is never hardcoded. Lands on /course/:id/attendance (or, for
// non-managers, wherever redirectIfNotManager sends them).
export async function openE2eCourse(page) {
  await page.goto('/');
  await page.getByRole('heading', { level: 3, name: 'E2E Course' }).click();
  await page.waitForURL(/\/course\/\d+\//);
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

// Pick an option from an already-opened Element Plus dropdown (el-select).
// Options render in a body-level overlay, so this is scoped to the page, not
// the trigger. `scope` clicks the trigger first (defaults to the page).
export async function chooseOption(page, optionText, trigger) {
  if (trigger) await trigger.click();
  await page.locator('.el-select-dropdown__item', { hasText: optionText }).click();
}
