import { test as base, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import { CREDENTIALS_PATH } from './global-setup.mjs';
import { CoursesPage } from './pages/courses-page.mjs';
import { SingleCoursePage } from './pages/single-course-page.mjs';
import { PeoplePage } from './pages/people-page.mjs';
import { AttendanceEventsPage } from './pages/attendance-events-page.mjs';
import { AssignmentsPage } from './pages/assignments-page.mjs';
import { LocationsPage } from './pages/locations-page.mjs';
import { ManageAccountPage } from './pages/manage-account-page.mjs';
import { LoginPage } from './pages/login-page.mjs';
import { AppShell } from './pages/app-shell.mjs';

// Cookie-injection login for E2E. global-setup.mjs has already minted a real
// credential per seeded `@e2e.test` account into e2e/.auth/credentials.json;
// here we read that file and set the 5 session cookies the app expects
// (frontend_app/lib/session.js), so the SPA boots already authenticated.
//
// Usage:
//   import { test, expect } from './fixtures.mjs';
//   test('...', async ({ page, loginAs }) => {
//     await loginAs('owner');          // owner | instructor | staff | student | creator | admin
//     await page.goto('/');
//   });

let cache;

function credentialFor(role) {
  cache ??= JSON.parse(readFileSync(CREDENTIALS_PATH, 'utf8'));
  const entry = cache[role];
  if (!entry) {
    throw new Error(
      `No E2E credential for role "${role}". Available: ${Object.keys(cache).join(', ')}`,
    );
  }
  return entry;
}

export const ROLES = ['admin', 'creator', 'owner', 'instructor', 'staff', 'student'];

export const test = base.extend({
  // loginAs(role) sets the session cookies on the browser context. Call it
  // before page.goto() so the SPA reads the session on first load. Returns the
  // account record ({ id, name, email, roles, ... }) for assertions.
  loginAs: async ({ context, baseURL }, use) => {
    const { hostname } = new URL(baseURL);
    const setSession = async (role) => {
      const account = credentialFor(role);
      const common = { domain: hostname, path: '/', sameSite: 'Lax' };
      await context.addCookies([
        { name: 'account_id', value: String(account.id), ...common },
        { name: 'account_roles', value: account.roles.join(','), ...common },
        { name: 'account_credential', value: account.credential, ...common },
        { name: 'account_img', value: account.avatar ?? '', ...common },
        { name: 'account_name', value: account.name ?? '', ...common },
      ]);
      return account;
    };
    await use(setSession);
  },

  // Page objects, injected per test. Specs receive these instead of
  // constructing them or touching selectors directly.
  coursesPage: async ({ page }, use) => use(new CoursesPage(page)),
  singleCoursePage: async ({ page }, use) => use(new SingleCoursePage(page)),
  peoplePage: async ({ page }, use) => use(new PeoplePage(page)),
  attendanceEventsPage: async ({ page }, use) => use(new AttendanceEventsPage(page)),
  assignmentsPage: async ({ page }, use) => use(new AssignmentsPage(page)),
  locationsPage: async ({ page }, use) => use(new LocationsPage(page)),
  manageAccountPage: async ({ page }, use) => use(new ManageAccountPage(page)),
  // LoginPage is anemic (URL-only) and needs no page handle.
  loginPage: async ({}, use) => use(new LoginPage()),
  appShell: async ({ page }, use) => use(new AppShell(page)),
});

export { expect };
