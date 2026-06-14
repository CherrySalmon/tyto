import { test, expect } from './fixtures.mjs';

// Plan tasks 12a (manager assignment lifecycle: create -> publish -> unpublish)
// and 12b (students see only published assignments, with no management controls).

test.describe('Assignments — manager lifecycle (task 12a)', () => {
  test('owner creates a draft, publishes it, then unpublishes it', async ({ loginAs, assignmentsPage }) => {
    await loginAs('owner');
    await assignmentsPage.open();

    const title = `PW Assignment ${Date.now()}`;
    await assignmentsPage.create(title);
    await expect(assignmentsPage.status(title)).toHaveText('draft');

    await assignmentsPage.publish(title);   // confirm dialog -> "Publish", asserts published
    await assignmentsPage.unpublish(title); // confirm dialog -> "Unpublish", asserts draft
  });
});

test.describe.serial('Assignments — student visibility (task 12b)', () => {
  const stamp = Date.now();
  const publishedTitle = `PW Published ${stamp}`;
  const draftTitle = `PW Draft ${stamp}`;

  test('owner creates one published and one draft assignment', async ({ loginAs, assignmentsPage }) => {
    await loginAs('owner');
    await assignmentsPage.open();

    await assignmentsPage.create(publishedTitle);
    await assignmentsPage.publish(publishedTitle);

    await assignmentsPage.create(draftTitle);
    await expect(assignmentsPage.status(draftTitle)).toHaveText('draft');
  });

  test('student sees the published assignment but not the draft, and no controls', async ({ loginAs, assignmentsPage }) => {
    await loginAs('student');
    await assignmentsPage.openAsStudent(); // redirected to the read-only assignments view

    await expect(assignmentsPage.card(publishedTitle)).toBeVisible();
    await expect(assignmentsPage.card(draftTitle)).toHaveCount(0);
    // Read-only: no Create card and no status tags / action icons.
    await expect(assignmentsPage.createCard).toHaveCount(0);
    await expect(assignmentsPage.actionGroups).toHaveCount(0);
  });
});

test.describe.serial('Assignments — student submission (task 12b)', () => {
  const title = `PW Submittable ${Date.now()}`;

  test('owner creates and publishes an assignment with a URL requirement', async ({ loginAs, assignmentsPage }) => {
    await loginAs('owner');
    await assignmentsPage.open();

    await assignmentsPage.create(title, { urlRequirement: 'Project repository URL' });
    await assignmentsPage.publish(title);
  });

  test('student submits a URL to the published assignment', async ({ loginAs, assignmentsPage }) => {
    await loginAs('student');
    await assignmentsPage.openAsStudent();

    const dlg = await assignmentsPage.submitUrl(title, 'https://github.com/example/project');

    await expect(dlg.page().getByText('Submission saved')).toBeVisible();
    await expect(dlg.getByText('Your Submission')).toBeVisible();
  });
});
