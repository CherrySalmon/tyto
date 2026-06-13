import { test, expect } from './fixtures.mjs';
import { openCourseTab, openE2eCourse } from './helpers.mjs';

// Plan tasks 12a (manager assignment lifecycle: create -> publish -> unpublish)
// and 12b (students see only published assignments, with no management controls).

// Within an assignment card, the actions are [Edit, Publish|Unpublish, Delete];
// index 1 is the publish/unpublish toggle regardless of title attributes.
function statusToggle(card) {
  return card.locator('.assignment-actions .el-icon').nth(1);
}

async function createAssignment(page, title, { urlRequirement } = {}) {
  await page.locator('.assignment-item', { hasText: 'Create Assignment' }).click();
  const dlg = page.getByRole('dialog', { name: 'Create Assignment' });
  await expect(dlg).toBeVisible();
  await dlg.getByPlaceholder('Assignment title').fill(title);

  if (urlRequirement) {
    // The dialog seeds one (file, empty-description) requirement row. Switch it
    // to a URL requirement so a student can submit without a file upload.
    const row = dlg.locator('.requirement-row').first();
    await row.locator('.el-select').click();
    await page.locator('.el-select-dropdown__item', { hasText: 'URL' }).click();
    await row.getByPlaceholder(/Description/).fill(urlRequirement);
  }

  await dlg.getByRole('button', { name: 'Create' }).click();
  await expect(dlg).toBeHidden();
}

async function publishCard(page, card) {
  await statusToggle(card).click();
  await page.getByRole('button', { name: 'Publish' }).click();
  await expect(card.locator('.el-tag')).toHaveText('published');
}

test.describe('Assignments — manager lifecycle (task 12a)', () => {
  test('owner creates a draft, publishes it, then unpublishes it', async ({ page, loginAs }) => {
    await loginAs('owner');
    await openCourseTab(page, 'Assignments');

    const title = `PW Assignment ${Date.now()}`;
    await createAssignment(page, title);

    const card = page.locator('.assignment-item', { hasText: title });
    await expect(card.locator('.el-tag')).toHaveText('draft');

    // Publish (confirm dialog -> "Publish").
    await statusToggle(card).click();
    await page.getByRole('button', { name: 'Publish' }).click();
    await expect(card.locator('.el-tag')).toHaveText('published');

    // Unpublish (confirm dialog -> "Unpublish").
    await statusToggle(card).click();
    await page.getByRole('button', { name: 'Unpublish' }).click();
    await expect(card.locator('.el-tag')).toHaveText('draft');
  });
});

test.describe.serial('Assignments — student visibility (task 12b)', () => {
  const stamp = Date.now();
  const publishedTitle = `PW Published ${stamp}`;
  const draftTitle = `PW Draft ${stamp}`;

  test('owner creates one published and one draft assignment', async ({ page, loginAs }) => {
    await loginAs('owner');
    await openCourseTab(page, 'Assignments');

    await createAssignment(page, publishedTitle);
    await publishCard(page, page.locator('.assignment-item', { hasText: publishedTitle }));

    await createAssignment(page, draftTitle);
    await expect(page.locator('.assignment-item', { hasText: draftTitle }).locator('.el-tag')).toHaveText('draft');
  });

  test('student sees the published assignment but not the draft, and no controls', async ({ page, loginAs }) => {
    await loginAs('student');
    await openE2eCourse(page); // redirected to the assignments (read-only) view

    await expect(page.locator('.assignment-item', { hasText: publishedTitle })).toBeVisible();
    await expect(page.locator('.assignment-item', { hasText: draftTitle })).toHaveCount(0);
    // Read-only: no Create card and no status tags / action icons.
    await expect(page.locator('.assignment-item', { hasText: 'Create Assignment' })).toHaveCount(0);
    await expect(page.locator('.assignment-item .assignment-actions')).toHaveCount(0);
  });
});

test.describe.serial('Assignments — student submission (task 12b)', () => {
  const title = `PW Submittable ${Date.now()}`;

  test('owner creates and publishes an assignment with a URL requirement', async ({ page, loginAs }) => {
    await loginAs('owner');
    await openCourseTab(page, 'Assignments');

    await createAssignment(page, title, { urlRequirement: 'Project repository URL' });
    await publishCard(page, page.locator('.assignment-item', { hasText: title }));
  });

  test('student submits a URL to the published assignment', async ({ page, loginAs }) => {
    await loginAs('student');
    await openE2eCourse(page);

    await page.locator('.assignment-item', { hasText: title }).click();
    const dlg = page.getByRole('dialog', { name: title });
    await expect(dlg).toBeVisible();

    await dlg.getByPlaceholder('Enter URL').fill('https://github.com/example/project');
    await dlg.getByRole('button', { name: 'Submit', exact: true }).click();

    await expect(page.getByText('Submission saved')).toBeVisible();
    await expect(dlg.getByText('Your Submission')).toBeVisible();
  });
});
