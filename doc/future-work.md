# Future Work

Planned improvements and features to be addressed in future tasks.

## Database Migrations

- [ ] **Add timestamps to accounts table** - The `accounts` table is missing `created_at` and `updated_at` columns. Create a migration to add these columns, then update the Account ORM with `plugin :timestamps`. The Account entity and representer are already prepared to handle timestamps once available. **Requires production migration.**

## Infrastructure & DevOps

- [x] **Automated migrations on deploy** — shipped 2026-04-21 (Slice 1 of `feature-multi-event`). `Procfile` declares `release: bundle exec rake db:migrate`; every Heroku deploy runs migrations in the release phase and fails atomically if any migration raises.
- [ ] **CI/CD pipeline** - Set up continuous integration for automated testing on PRs
- [ ] **Heroku Review Apps** - Configure `app.json` to enable auto-provisioned review environments for PRs

## Application Layer

- [ ] **Input validation contracts** - Replace raw hash parameters (`attendance_data`, `location_data`, etc.) with dry-validation contracts. This would move validation out of services, provide consistent error formatting, and allow services to trust their input. See `CLAUDE.md` architecture notes on contracts.
- [ ] **Per-row error map in bulk-event responses** — `Service::Events::CreateEvents` currently short-circuits at the first failing row with a single `Failure(bad_request(message))`. The frontend review grid (`BulkEventsStep2Review.vue`) already accepts a `rowErrors` map keyed by row id so it can highlight multiple offending rows at once. Finishing the loop means collecting all row failures (not short-circuiting), returning a structured `{ errors_by_row: { 0: 'Name is required', 3: 'End must be after start' } }` shape from the route, and keeping the transaction rollback semantics intact. Low-medium effort: refactor `validate_rows` to collect failures, extend `ApiResult` to carry structured details, map indices to row ids in the handler. Decision taken during Slice 2 frontend port (2026-04-22): frontend is ready, backend gap deferred to avoid widening Slice 2 scope.
- [ ] **Promote `EnrolledCourse` to a domain value object** — the concept "Course as experienced by this viewer" currently has no name. It's split implicitly across `Domain::Courses::Entities::Course` (viewer-blind), `Response::CourseDetails` (application-layer DTO bundling course + enrollment + policies + `has_assignments`), and `Representer::CourseWithEnrollment` (JSON shape). Right now actor-aware questions about a viewed course are correctly placed on the relevant policy class (e.g., `Policy::Assignment#viewable_statuses`), but the *bundle* — Course + Enrollment + cross-context flags like `has_assignments` — has no domain home and lives as the `Response::CourseDetails` DTO. **Suggested fix**: introduce `Domain::Courses::Values::EnrolledCourse` (Dry::Struct) bundling `Course` + `Enrollment` + precomputed cross-context flags (`has_assignments`, future `has_events_today`, …); rewire `GetCourse` and `ListUserCourses` to build it; have the representer render it. `Domain::Attendance::Entities::EventAttendanceReport` is the existing precedent for a composite domain bundle. **Hard parts**: (a) cross-context purity — flags like `has_assignments` mix the Courses and Assignments contexts, so they must be **precomputed at the application layer** (where `Repository::Assignments` is reachable) and passed in; the domain object itself never reaches across contexts; (b) deciding whether to retire `Response::CourseDetails` entirely or keep it as a thin pass-through; (c) `Policy::Course` and `Policy::Assignment` stay separate (actor-context is broader than course-context) but the application service should compose them via `EnrolledCourse` rather than threading them piecemeal through DTOs. **Status as of Slice 3 (2026-05-06)**: visibility rule lifted to `Policy::Assignment#viewable_statuses`; the `EnrolledCourse` value object is the next step but deserves its own focused PR.

## Timezone Support

- [ ] **Timezone-aware event scheduling** (deferred from Slice 2 per Q9 in `PLAN.feature-multi-event-2.md`, 2026-04-22). Current state: `events.start_at` / `end_at` are stored as naive timestamps and rendered as whatever local time the server and client happen to agree on. This works only because instructors and students share the same timezone today. **Problem**: as soon as a course has participants or an instructor in a different zone — online courses, students travelling during exams, guest instructors — attendance windows and event times ambiguate. **Hard parts**: (a) existing-data ambiguity — we don't know what tz the legacy rows were *entered in*, so any migration has to pick a default (likely the course owner's browser tz at migration time) and accept that some rows will be off by hours until re-saved; (b) multi-viewer UX — a 9am event in the instructor's tz should render as 9am for the instructor and as the equivalent local time for a student abroad, without the student being confused that it "moved"; (c) attendance-window business rules — the geo-fence + time-window check must use the event's tz, not the requestor's, or students can't check in when physically present. **Rough shape of a proper fix**: (1) store `start_at` / `end_at` as `TIMESTAMPTZ` (Postgres) / UTC + tz string pair; (2) add `courses.timezone` as the course-level default; (3) event creation inherits the course tz by default but allows per-event override; (4) all pickers (single-event form, bulk review grid) disambiguate "9:00 in course tz" vs. "9:00 in my browser tz" with an explicit toggle or label; (5) attendance recording uses the event's tz for window checks. Out of scope for `feature-multi-event` because timezone has no clean "lite version" — schema, data migration, every service, every representer, every picker, and the UX all shift together.

## Security (Priority)

- [ ] **Input whitelisting on PUT routes** - Prevent mass assignment vulnerabilities. PUT routes currently accept arbitrary JSON fields that get written to DB (e.g., users could potentially update their own roles). Implement Sequel's `set_allowed_columns` or manual input filtering in services. *Note: Input validation contracts (above) would also address this.*
- [ ] **Review Policy::Role** - Exists but unused. Either wire it into AccountService for role assignment authorization, or remove if not needed.
- [ ] **Security tests** - Add tests verifying that sensitive fields (roles, etc.) cannot be modified via API without proper authorization.
- [ ] **CVE sweep of Ruby gem lockfile** — `bundle exec rake audit` (wired in Slice 1 of `feature-multi-event`) currently reports 17 pre-existing advisories as of 2026-04-21: 1 on `puma` (medium, CVE-2024-45614 header clobbering — Heroku also flags this on every deploy, recommends Puma 7.0.3+), 11 on `rack 3.0.9.1` (mix of medium and high — log injection, escape-sequence injection, path traversal), and 6 on `rexml 3.2.6` (medium/high — DoS via crafted XML). Each gem needs a minor-version bump plus regression testing; deferred from Slice 1 to avoid scope creep during a refactor-only deploy. Follow-up task: open a dedicated `security/cve-sweep` branch, bump puma → 7.x, rack → 3.1.x (or 2.2.x line depending on public API compat), rexml → 3.3+, run full spec suite + manual route smoke, deploy to prod.

## Testing

- [ ] **Test suite** - Implement backend tests using Minitest/Rack::Test
- [ ] **Frontend tests** - Add Vue component and integration tests

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
