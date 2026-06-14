import { test, expect } from './fixtures.mjs';
import { uniqueEmail } from './helpers.mjs';

// Plan task 9 — Manage People (owner/instructor). One sequential flow against a
// throwaway enrollee so it never mutates the seeded enrollments other specs
// rely on: enroll by email -> assign/extend role -> delete.

test('owner can enroll, re-role, and remove a course member', async ({ loginAs, peoplePage }, testInfo) => {
  await loginAs('owner');
  await peoplePage.open();

  const email = uniqueEmail('e2e-enrollee', testInfo.workerIndex);

  // --- Enroll (2-step wizard) -------------------------------------------------
  await peoplePage.enroll(email);
  // New enrollees default to the student role.
  await expect(peoplePage.row(email)).toContainText('student');

  // --- Re-role: add staff -----------------------------------------------------
  await peoplePage.addRole(email, 'staff');
  await expect(peoplePage.row(email)).toContainText('staff');

  // --- Delete -----------------------------------------------------------------
  await peoplePage.remove(email);
  await expect(peoplePage.row(email)).toHaveCount(0);
});
