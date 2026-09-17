# Future Work

Planned improvements and features to be addressed in future tasks.

## Database Migrations

- [x] **Add timestamps to accounts table** - Done on `feat-new-members` (migration 016): existing rows are backfilled from the oldest enrolled course's creation time, else the migration time. Take a Heroku backup before the first release that carries it.

## Infrastructure & DevOps

- [x] **Automated migrations on deploy** — shipped 2026-04-21 (Slice 1 of `feature-multi-event`). `Procfile` declares `release: bundle exec rake db:migrate`; every Heroku deploy runs migrations in the release phase and fails atomically if any migration raises.
- [x] **CI/CD pipeline** - Done. CI: `.github/workflows/ci.yml` runs backend (Ubuntu + macOS), frontend, and Playwright E2E jobs on every PR and on pushes to `main`. CD: Heroku's GitHub integration builds a new release from `main`, and the `Procfile` release phase migrates. Stale item struck 2026-09-17; it predated both.
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs
- [ ] **Remove devcontainer** — no longer used by the maintainer (2026-06-04); can be deleted soon unless other contributors rely on it. Before removing: confirm no contributor uses it, then delete `.devcontainer/` and strip devcontainer references from `CLAUDE.md` (DevContainer section) and `README.md` if present. Note `.nvmrc` (node 24) is now the source of truth for Node version (CI reads it via `node-version-file`; prod pinned to `24.x` via `engines` in package.json); the devcontainer's pinned Node/Ruby versions are redundant.

## Application Layer

- [ ] **Account removal that keeps attendance history** (raised 2026-09-17 on `feat-new-members`). Deleting an account cascades its enrollments and attendance rows, so self-deletion was disabled and deletion made admin-only. That protects history but leaves two gaps: people cannot leave on their own, and an admin delete still erases the records. The usual practice is one of: (a) **soft delete** — a `deleted_at` column; the row stays, lists and login hide it, counts and reports still see it; (b) **anonymize** — keep the account id, blank name/email/avatar to a placeholder such as `deleted-<id>`, drop the roles; attendance and enrollment rows keep their foreign key so per-event counts stay right, and the person's identity is gone (this is the common answer to "right to erasure" requests); (c) **archive-then-purge** — soft delete now, hard delete after a retention period. Either (a) or (b) would let self-service "remove my account" return safely. Needs a migration, repository and policy changes, and a decision on what the People tab and attendance reports show for a removed person.
- [ ] **Accounts page pagination** — the admin Accounts table is client-side (search, sort, and filter run in the browser over the full list from `GET /api/account`). Fine while accounts number in the hundreds; add server-side paging and search once that changes (deferred from `feat-new-members`, 2026-09-17).
- [ ] **Self-registration on first Google login** — login still requires a pre-existing account (`VerifyGoogleToken` answers 404 otherwise). Admins now add accounts in bulk, so this is a policy choice rather than a gap; if wanted, the login service would call `Repository::Accounts#find_or_create_many_by_email` for the one email and issue the credential (deferred from `feat-new-members`, 2026-09-17).
- [ ] **Email facility** — invitations and notifications (deferred from `feat-new-members` Q5). No mail infrastructure exists; admin-added accounts learn their login link out of band.
- [ ] **Input validation contracts** - Replace raw hash parameters (`attendance_data`, `location_data`, etc.) with dry-validation contracts. This would move validation out of services, provide consistent error formatting, and allow services to trust their input. See `CLAUDE.md` architecture notes on contracts.
- [ ] **Per-row error map in bulk-event responses** — `Service::Events::CreateEvents` currently short-circuits at the first failing row with a single `Failure(bad_request(message))`. The frontend review grid (`BulkEventsStep2Review.vue`) already accepts a `rowErrors` map keyed by row id so it can highlight multiple offending rows at once. Finishing the loop means collecting all row failures (not short-circuiting), returning a structured `{ errors_by_row: { 0: 'Name is required', 3: 'End must be after start' } }` shape from the route, and keeping the transaction rollback semantics intact. Low-medium effort: refactor `validate_rows` to collect failures, extend `ApiResult` to carry structured details, map indices to row ids in the handler. Decision taken during Slice 2 frontend port (2026-04-22): frontend is ready, backend gap deferred to avoid widening Slice 2 scope.
- [ ] **Promote `EnrolledCourse` to a domain value object** — the concept "Course as experienced by this viewer" currently has no name. It's split implicitly across `Domain::Courses::Entities::Course` (viewer-blind), `Response::CourseDetails` (application-layer DTO bundling course + enrollment + policies + `has_assignments`), and `Representer::CourseWithEnrollment` (JSON shape). Right now actor-aware questions about a viewed course are correctly placed on the relevant policy class (e.g., `Policy::Assignment#viewable_statuses`), but the *bundle* — Course + Enrollment + cross-context flags like `has_assignments` — has no domain home and lives as the `Response::CourseDetails` DTO. **Suggested fix**: introduce `Domain::Courses::Values::EnrolledCourse` (Dry::Struct) bundling `Course` + `Enrollment` + precomputed cross-context flags (`has_assignments`, future `has_events_today`, …); rewire `GetCourse` and `ListUserCourses` to build it; have the representer render it. `Domain::Attendance::Entities::EventAttendanceReport` is the existing precedent for a composite domain bundle. **Hard parts**: (a) cross-context purity — flags like `has_assignments` mix the Courses and Assignments contexts, so they must be **precomputed at the application layer** (where `Repository::Assignments` is reachable) and passed in; the domain object itself never reaches across contexts; (b) deciding whether to retire `Response::CourseDetails` entirely or keep it as a thin pass-through; (c) `Policy::Course` and `Policy::Assignment` stay separate (actor-context is broader than course-context) but the application service should compose them via `EnrolledCourse` rather than threading them piecemeal through DTOs. **Status as of Slice 3 (2026-05-06)**: visibility rule lifted to `Policy::Assignment#viewable_statuses`; the `EnrolledCourse` value object is the next step but deserves its own focused PR.

## Timezone Support

- [ ] **Timezone-aware event scheduling** (deferred from Slice 2 per Q9 in `.claude/plans/016-PLAN-feature-multi-event/b-PLAN.md`, 2026-04-22). Current state: `events.start_at` / `end_at` are stored as naive timestamps and rendered as whatever local time the server and client happen to agree on. This works only because instructors and students share the same timezone today. **Problem**: as soon as a course has participants or an instructor in a different zone — online courses, students travelling during exams, guest instructors — attendance windows and event times ambiguate. **Hard parts**: (a) existing-data ambiguity — we don't know what tz the legacy rows were *entered in*, so any migration has to pick a default (likely the course owner's browser tz at migration time) and accept that some rows will be off by hours until re-saved; (b) multi-viewer UX — a 9am event in the instructor's tz should render as 9am for the instructor and as the equivalent local time for a student abroad, without the student being confused that it "moved"; (c) attendance-window business rules — the geo-fence + time-window check must use the event's tz, not the requestor's, or students can't check in when physically present. **Rough shape of a proper fix**: (1) store `start_at` / `end_at` as `TIMESTAMPTZ` (Postgres) / UTC + tz string pair; (2) add `courses.timezone` as the course-level default; (3) event creation inherits the course tz by default but allows per-event override; (4) all pickers (single-event form, bulk review grid) disambiguate "9:00 in course tz" vs. "9:00 in my browser tz" with an explicit toggle or label; (5) attendance recording uses the event's tz for window checks. Out of scope for `feature-multi-event` because timezone has no clean "lite version" — schema, data migration, every service, every representer, every picker, and the UX all shift together.

## Locations Map

Deferred from `fix-new-locations` (2026-09-17), which moved location creation into the map popup, added markers, and added in-place renaming.

- [ ] **Move an existing location** — there is no way to change a location's coordinates; managers delete it and create it again. A possible design: draggable markers with a "Move *name* here?" confirm popup that sends a coordinates-only `PUT` (the update service already keeps the stored name when `name` is absent). Rejected for now to keep the UI simple.
- [ ] **Place search box** — let managers find a building by name (Places Autocomplete) instead of panning the map. Adds more Places API usage, so check the billing impact first.
- [ ] **Advanced markers** — `LocationCard.vue` and `AttendanceMap.vue` use the deprecated `google.maps.Marker`. `AdvancedMarkerElement` needs a Map ID configured in the Cloud Console for the project that owns `VUE_APP_GOOGLE_MAP_KEY`.
- [ ] **Show save errors** — `SingleCourse.vue` only logs failed location create/update requests to the console; the user sees nothing when the API rejects a name.

## Security (Priority)

- [ ] **🚨 TOP PRIORITY — npm dependency vulnerability sweep (ASAP)** — `npm audit` reports **26 vulnerabilities (1 critical, 9 high, 16 moderate)** as of 2026-06-04. Crucially, several affect **direct production dependencies that ship in the frontend bundle**, not just dev tooling: `axios` (HIGH — 4 advisories incl. credential theft / full MitM via prototype-pollution gadgets in config merge, GHSA-3g43-6gmg-66jw, GHSA-35jp-ww65-95wh), `js-cookie` (HIGH, direct — this is the library that stores the auth JWT), and `lodash`/`lodash-es` (HIGH, transitive via element-plus — `_.template` code injection). Dev-only: `vitest` (CRITICAL), `esbuild`, `node-forge`/`serialize-javascript`/`path-to-regexp` (webpack-dev-server chain — moderate/high but not shipped to prod). **Remediation path**: (1) `npm audit fix` resolves most non-breaking (axios, js-cookie, lodash, follow-redirects); (2) `npm audit fix --force` or manual major bumps for esbuild/vitest; (3) verify with `bundle exec rake spec:frontend`, `npm run prod` build, and a manual login + attendance smoke (axios and js-cookie sit on the auth path). Prioritize the prod-bundle deps (axios, js-cookie, lodash) even if the dev-only ones need a separate pass.
- [ ] **Input whitelisting on PUT routes** - Prevent mass assignment vulnerabilities. PUT routes currently accept arbitrary JSON fields that get written to DB (e.g., users could potentially update their own roles). Implement Sequel's `set_allowed_columns` or manual input filtering in services. *Note: Input validation contracts (above) would also address this.*
- [x] **Review Policy::Role** - Removed. Its intent (only admins assign system roles) now lives in `Policy::Account#can_change_system_roles?`.
- [ ] **Security tests** - Add tests verifying that sensitive fields (roles, etc.) cannot be modified via API without proper authorization.
- [ ] **CVE sweep of Ruby gem lockfile** — `bundle exec rake audit` (wired in Slice 1 of `feature-multi-event`) currently reports 17 pre-existing advisories as of 2026-04-21: 1 on `puma` (medium, CVE-2024-45614 header clobbering — Heroku also flags this on every deploy, recommends Puma 7.0.3+), 11 on `rack 3.0.9.1` (mix of medium and high — log injection, escape-sequence injection, path traversal), and 6 on `rexml 3.2.6` (medium/high — DoS via crafted XML). Each gem needs a minor-version bump plus regression testing; deferred from Slice 1 to avoid scope creep during a refactor-only deploy. Follow-up task: open a dedicated `security/cve-sweep` branch, bump puma → 7.x, rack → 3.1.x (or 2.2.x line depending on public API compat), rexml → 3.3+, run full spec suite + manual route smoke, deploy to prod.

## Testing

- [ ] **E2E must not reuse a foreign server** — `playwright.config.mjs` has `reuseExistingServer` on locally and targets 9292, the same port `rake run:api` uses. With several worktrees checked out, a dev server from another branch on 9292 gets reused silently, and the specs fail with timeouts against the wrong code and database (seen 2026-09-17). Fix: give E2E its own port (e.g. 9393) in both the `webServer.command` and the default `E2E_BASE_URL`, and have `global-setup.mjs` assert the server's `RACK_ENV` is test (a `/api/_env` probe or a response header) before minting credentials.
- [x] **Test suite** - Done long since: the backend suite is Minitest + Rack::Test (about 1,450 examples as of 2026-09-17). Stale item struck.
- [ ] **Frontend tests** - Expand Vue component and integration test coverage. *Infrastructure landed on `fix-add-course-button` (2026-06-04): Vitest + @vue/test-utils + jsdom, `vitest.config.js`, `npm test` / `rake spec:frontend`, first regression spec at `frontend_app/pages/course/components/AttendanceEventCard.spec.js`. Remaining: cover SingleCourse's `redirectIfNotManager()` (needs vue-router + api mocks), then grow coverage with new features.*

## Domain Layer (Prepared for Future Use)

The following domain functionality has been implemented but is not yet used by the application. These are available for future features:

### Geolocation Accuracy Check for Attendance Anti-Spoofing

Backend geo-fence proximity validation (Haversine, 55m radius) and time-window enforcement are now implemented. However, the system trusts whatever coordinates the client sends. The browser Geolocation API provides a `coords.accuracy` value (radius in meters) that can help detect naive spoofing attempts (e.g., Chrome DevTools Sensors panel often reports accuracy of `0`).

**Suggested implementation:**

- Frontend: send `coords.accuracy` alongside latitude/longitude when recording attendance
- Backend: reject submissions where accuracy is `0` or exceeds a threshold (e.g., > 100m)
- Real GPS typically reports 5-20m accuracy; unrealistic values suggest spoofing or poor signal
- Low effort: one additional field in the request, one check in the service

**Limitations:** sophisticated spoofers can set realistic accuracy values. This blocks naive spoofing only. For stronger anti-spoofing, consider rotating check-in codes (physical presence proof) or motion sensor verification.

### Scheduling Conflict Detection

**Available domain objects:**

- `Value::TimeRange#overlaps?(other)` - Check if two time ranges overlap
- `Value::TimeRange#contains?(time)` - Check if a time falls within the range

**Use cases:**

- Prevent scheduling overlapping events in the same location
- Detect course schedule conflicts for students
