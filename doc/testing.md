# Testing Guide

TYTO has three test layers, each with its own runner and scope:

| Layer | Tool | Scope | Files | Command |
| --- | --- | --- | --- | --- |
| **Backend** | Minitest (spec style) | API routes, services, policies, domain entities | `backend_app/spec/**/*_spec.rb` | `bundle exec rake spec:backend` |
| **Frontend** | Vitest + `@vue/test-utils` (jsdom) | Vue components in isolation | `frontend_app/**/*.{test,spec}.js` | `bundle exec rake spec:frontend` |
| **End-to-end** | Playwright (Chromium) | Real browser driving the live SPA + Roda API | `e2e/**/*.spec.mjs` | `bundle exec rake spec:e2e` |

```shell
bundle exec rake spec        # Backend + frontend (the default task). Does NOT run e2e.
bundle exec rake spec:e2e    # End-to-end, opt-in and self-contained (see below).
```

E2E is intentionally **not** part of `rake spec`: it is slower, needs a built frontend
and a booted server, and resets its own database. Run it explicitly.

---

## Backend (Minitest)

Spec-style Minitest (`describe`/`it`) — **not** RSpec. Specs live alongside the app under
`backend_app/spec/` and exercise routes, services, policies, and domain logic.

```shell
RACK_ENV=test bundle exec rake db:setup   # First time / after schema or seed changes
bundle exec rake spec:backend
```

The suite reports **one intentional skip** (`courses_spec.rb` — testing a missing `owner`
role would require deleting seed data the rest of the suite depends on). Expected; not a
regression.

> **TDD protocol** for backend work: red → green → refactor, one test at a time. Write the
> failing test first, run it to confirm the failure, then implement. See `CLAUDE.md`.

---

## Frontend (Vitest)

Component-level tests in jsdom via `vitest` + `@vue/test-utils`. Config lives in
`vitest.config.mjs` (mirrors the webpack `@` → `frontend_app` alias). Element Plus is
auto-imported by webpack in the real app but not under Vitest, so specs stub `el-*`
components explicitly.

```shell
bundle exec rake spec:frontend   # === npm test === vitest run
npm run test:watch               # Watch mode while developing
```

No database or server is required.

---

## End-to-end (Playwright)

Browser-based tests that drive the **real** Vue SPA served by the Roda backend on `:9292`,
against a dedicated `RACK_ENV=test` database. They cover role-gated behavior end to end —
system roles (admin, creator, member) and per-course enrollment roles (owner, instructor,
staff, student).

### One command

```shell
bundle exec rake spec:e2e
```

This task is self-contained. It:

1. **Resets the test DB** as three separate processes — `db:drop`, then `db:migrate`, then
   `db:seed`. (A single-process `db:reset` is broken for SQLite; see *Gotchas* below.)
2. **Builds the frontend** into `dist/` via `npm run prod` (the backend serves these assets).
3. **Runs Playwright** (`npx playwright test`), which boots the backend itself (see the
   `webServer` block in `playwright.config.mjs`) and runs all specs in `e2e/`.

### First-time setup

```shell
npm install                              # Installs @playwright/test
npx playwright install --with-deps chromium   # One-time browser download
```

### Running a subset / debugging

```shell
npm run e2e                  # playwright test  (server must already be running, or it boots one)
npm run e2e:headed           # Watch it drive a visible browser
npm run e2e:ui               # Playwright's interactive UI mode
npx playwright test e2e/auth.spec.mjs        # A single file
npx playwright show-report                   # Open the HTML report after a run
```

> When running Playwright directly (not via `rake spec:e2e`), you are responsible for the
> prerequisites that the rake task normally handles: a seeded test DB and a built `dist/`.
> The simplest path is just `bundle exec rake spec:e2e`.

### How auth works (cookie injection, no Google)

Production login goes through Google OAuth, but the e2e suite bypasses it — Google is flaky
and unusable in CI. Instead:

- The seed creates deterministic accounts on the reserved `@e2e.test` domain
  (`e2e-owner@e2e.test`, `e2e-student@e2e.test`, …) and one `E2E Course` with the four
  enrollment roles, a geo-fenced `E2E Main Hall` location, and a live event.
  See `backend_app/db/seeds/account_seeds.rb`.
- Playwright **global setup** (`e2e/global-setup.mjs`) runs `rake generate:e2e_credentials`
  once, minting a real encrypted credential for each `@e2e.test` account, and caches them to
  `e2e/.auth/credentials.json` (gitignored).
- The `loginAs(role)` fixture (`e2e/fixtures.mjs`) reads that cache and sets the five session
  cookies on the browser context, so the SPA boots already authenticated as that role —
  with real, authorized API calls.

To mint a credential for a single account manually:

```shell
RACK_ENV=test bundle exec rake "generate:test_credential[e2e-owner@e2e.test]"
```

### Config & environment

- `playwright.config.mjs` — `testDir: ./e2e`, `testMatch: **/*.spec.mjs` (so it never
  collides with Vitest's `.spec.js`), Chromium only, traces on first retry, screenshots on
  failure.
- `E2E_BASE_URL` — override the target URL (default `http://localhost:9292`).

### CI

The `e2e-tests` job in `.github/workflows/ci.yml` installs Ruby + Node, writes a
`secrets.yml` (including `LOCAL_STORAGE_*`), installs the Chromium browser, and runs
`bundle exec rake spec:e2e` headless (`workers: 1`, `retries: 2`), uploading the
`playwright-report/` artifact.

### Gotchas

- **`db:reset` is broken for SQLite.** Dropping unlinks the DB file while the boot-time
  connection stays open and keeps writing to the stale inode, so the next `migrate` sees
  "table already exists". `spec:e2e` works around it by running `db:drop`, `db:migrate`, and
  `db:seed` as three separate processes (each opens a fresh connection on the fresh file).
  Don't collapse those three lines back into `db:reset`.
- **Some specs mutate shared state** (geo check-in records attendance, locations delete the
  spare room, people/assignments/courses create rows) and assume a fresh DB. `rake spec:e2e`
  resets every run, so this only bites if you re-run specs against a long-lived dev server.
- **`LOCAL_STORAGE_*` secrets** must be present in the `test` section of
  `backend_app/config/secrets.yml` (assignment submission needs them at boot). CI generates
  them; `secrets_example.yml` lists them for local setup.

### Scope & limitations

- Chromium only (WebKit/Firefox deferred).
- Location create/update is not covered — coordinate picking happens inside a Google Maps
  InfoWindow that needs a live API key (not headless-testable). List + delete are covered.
- The Google OAuth login UI is not exercised (bypassed by design via cookie injection).
