import { defineConfig, devices } from '@playwright/test';

// Browser-based E2E for the Tyto app. Drives the real Vue SPA served by the
// Roda backend (API + built assets from dist/) on :9292, against a dedicated
// RACK_ENV=test database. See .claude/plans/PLAN.test-ui.md.
//
// Auth is by cookie injection, not Google OAuth: global-setup.mjs mints a real
// credential per seeded `@e2e.test` account and writes e2e/.auth/credentials.json;
// the loginAs() fixture (e2e/fixtures.mjs) sets the 5 session cookies.
//
// Prerequisites (handled by `rake spec:e2e`): seed the test DB and build the
// frontend (`npm run prod`). The webServer block below boots the backend.

const BASE_URL = process.env.E2E_BASE_URL || 'http://localhost:9292';

export default defineConfig({
  testDir: './e2e',
  testMatch: '**/*.spec.mjs',
  globalSetup: './e2e/global-setup.mjs',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',

  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  // Boot the backend (API + dist/ assets) against the test DB. The DB must
  // already be seeded and dist/ already built — `rake spec:e2e` does both
  // before invoking Playwright. Locally we reuse an already-running server.
  webServer: {
    command: 'RACK_ENV=test bundle exec puma config.ru -t 1:5 -p 9292',
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
