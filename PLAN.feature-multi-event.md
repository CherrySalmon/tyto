# Multi-Event Bulk Creation

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-multi-event`

## Goal

Allow instructors/staff to create many attendance events at once for a course via a two-step flow: pick dates + shared details (calendar strip + quick-pick patterns), then refine each row in a spreadsheet-style review grid. Falls back to the existing single-event form when the "Create multiple" toggle is off.

## Reference Design

- `tmp/DESIGN-multi-events/create-events-modal.jsx` — reference React prototype from the [Claude online design tool](https://claude.ai/design) (launched late 2025). Describes modal sizing, step progression, validation copy, calendar component, quick-pick chips (`Every Mon`, `Mon + Wed`, …), name-pattern builder (`pad2 / nopad / date-short / none`), shared-defaults panel, and the spreadsheet grid with same-location conflict detection and fill-down helpers.
- Target Vue port: `frontend_app/pages/course/components/CreateAttendanceEventDialog.vue` (extended) + new companion components for the bulk steps.

## Strategy: Two Vertical Slices

Split into two vertical slices so each ships a coherent, testable change:

**Slice 1 — Route rename + array contract (refactor)**: Rename `GET/PUT/POST /api/course/:course_id/event` → `/events` (plural, per REST convention). POST now always requires `{ events: [...] }`; single-event create becomes a 1-element array. No behavior change — just the URL + payload contract. Route still delegates to existing `CreateEvent` / `UpdateEvent` / `ListEvents` services, iterating the array for POST.

**Slice 2 — Bulk creation feature**: Introduce `Service::Events::CreateEvents` (transactional bulk), swap the POST handler to call it instead of looping `CreateEvent`, and build the two-step frontend modal (dates + pattern → spreadsheet review).

Each slice is test-first: failing spec → implementation → frontend update → manual verify.

## Current State

- [x] Plan created
- [x] All scope questions (Q1–Q9) resolved with user
- [ ] Slice 1: route rename + schema cleanup shipped
  - [x] 1.1a event_route_spec updated to new URLs + array contract (red, as expected — 13 failures, endpoint doesn't exist yet)
  - [x] 1.1b current_event_route_spec updated to `/api/current_events`
  - [x] 1.1c Service specs audited — none reference route paths (as expected)
  - [x] 1.2 Route namespace renamed `event` → `events`; top-level mount `current_event` → `current_events`
  - [x] 1.3 POST /events validates `{ events: [...] }` array; loops CreateEvent; returns `{ success, events_info: [...] }` via Representer::EventsList. Rejects bare object, non-array, empty array with 400
  - [x] 1.4 Full spec suite green: 873 runs, 2057 assertions, 0 failures
  - [x] 1.5 Frontend callers updated: `SingleCourse.vue` (4 call sites — POST now wraps as `{ events: [form] }`), `AttendanceTrack.vue` + `AllCourse.vue` (`/current_event/` → `/current_events/`)
  - [x] 1.5b Manual dev verification passed — create/edit/delete/list + current_events all clean, no log errors
- [ ] Slice 2: bulk service + split-component modal shipped
- [ ] Manual verification of both flows
- [ ] Slice 3: retrospective → skill-file edits proposed

## Key Findings

> **Snapshot at time of research** (pre-refactor). Line numbers and API paths below reflect the *original* singular-`event` route. After Slice 1's `refactor: events route uses plural path and array payload` commit (022dbb1) the route namespace is `events`, POSTs wrap as `{ events: [...] }`, and the handler is substantially larger. The logical structure (service / policy / repo / entity / representer) is unchanged.

Research summary (from `Explore` agent — full notes kept in conversation):

**Existing single-event path** — what the bulk flow must mirror:

- **Route**: `POST /api/course/:course_id/event` in `backend_app/app/application/controllers/routes/course.rb:234-249`
- **Service**: `Tyto::Service::Events::CreateEvent` at `backend_app/app/application/services/events/create_event.rb` — `Dry::Operation` with steps: validate course id → verify course exists → authorize → validate input → persist → enrich with location
- **Policy**: `Tyto::Policy::Event#can_create?` — requires teaching staff (owner/instructor/staff) for the course
- **Repository**: `backend_app/app/infrastructure/database/repositories/events.rb` — exposes `create(entity)`. No existing bulk-insert helper
- **Entity**: `backend_app/app/domain/courses/entities/event.rb` — `id, course_id, location_id, name, start_at, end_at`
- **Representer**: `backend_app/app/presentation/representers/event.rb`
- **ORM + migration**: `backend_app/app/infrastructure/database/orm/event.rb` and `backend_app/db/migrations/007_event_create.rb`

**Events table schema** (migration 007):

```text
id PK, course_id FK cascade, location_id FK cascade,
name (not null), start_at, end_at, created_at, updated_at
unique (start_at, end_at)   ← DB-wide, cross-course/cross-location
```

**Frontend single-event UI**:

- Dialog: `frontend_app/pages/course/components/CreateAttendanceEventDialog.vue`
- Parent: `frontend_app/pages/course/SingleCourse.vue` — posts via `api.post('/course/:id/event', form)` then refreshes the event list
- Locations already fetched for the dropdown via `GET /api/course/:course_id/location`

**Testing convention**: Minitest spec-style. Reference: `backend_app/spec/application/services/events/create_event_spec.rb`.

**Gotchas to preserve / decide**:

1. **`unique (start_at, end_at)` is DB-global** (as of migration 007). A bulk create that accidentally reused an existing `start_at/end_at` pair would fail on insert. Resolved by **Q3** → dropped entirely in Slice 1 migration `009` (no replacement — multiple legitimate events can share times, e.g. parallel workshop sessions). Transactional bulk persistence still required for partial-failure safety (handled by Slice 2's `CreateEvents` service).
2. **Authorization is per-course, not per-event.** One `can_create?` check at the start of the bulk service is sufficient.
3. **Enrichment.** Single-event response enriches with location coords. Bulk service should fetch all needed locations once (via `repo.find_ids(ids)`) rather than N times.
4. **No contract classes.** Validation is inline in `CreateEvent` private methods — mirror that style rather than introducing dry-validation.
5. **Representer already exists** — reuse `Representer::Event` per row or `Representer::EventsList` for the collection response.

## Questions

> Questions must be numbered (Q1, Q2, ...) and crossed off when resolved. Note the decision made.

- [x] ~~Q1. **Endpoint shape.** Add new `POST /api/course/:course_id/events` (plural) that accepts `{ events: [...] }`, or extend the existing singular `POST /.../event` to accept either an object or an array?~~ **Decision**: Rename the resource from singular `event` to plural `events` (matching REST convention), and unify under a single endpoint `POST /api/course/:course_id/events` that always takes `{ events: [...] }`. Single-event create becomes a 1-row array. Also rename `GET /event` → `GET /events` and `PUT /event/:id` → `PUT /events/:id` for consistency. **Confirmed 2026-04-21**: the Vue frontend is the only consumer of the backend API — no third-party clients to break.
- [x] ~~Q2. **All-or-nothing semantics.** If one row fails validation or insert, should the entire batch be rejected (transaction rollback), or should valid rows still be created and the failed ones reported?~~ **Decision**: All-or-nothing with detailed error report. The bulk service validates every row up-front before persisting anything, and wraps persistence in a `DB.transaction` so any insert failure rolls back the whole batch. The failure response returns a per-row error map (row index → error message) so the frontend can highlight the specific offending rows in the review grid.
- [x] ~~Q3. **Unique `(start_at, end_at)` constraint.** The current DB constraint is cross-course and will cause collisions in bulk scenarios.~~ **Decision**: Drop the uniqueness constraint entirely — no replacement. Use cases like repeated workshop sessions legitimately need multiple events sharing the same `(start_at, end_at)` within a single course. Separately, tighten `start_at` and `end_at` to `NOT NULL` — null times don't make sense for attendance events. **Prerequisite**: audit the production database for any existing rows with null `start_at` or `end_at` before rolling out the `NOT NULL` migration; clean up or surface to the user for resolution before the migration runs. Folded into Slice 1.
- [x] ~~Q4. **Name-pattern generation — server or client?**~~ **Decision**: Client-side. The pattern (prefix + pad2/nopad/date-short/none + startNum) is presentation-layer formatting — the domain entity only cares about `Event.name` as a plain string, the pattern itself is never persisted, and the reference design's step-2 spreadsheet explicitly allows per-row overrides. Server accepts already-rendered names. **Caveat for future work**: if we later add server-rendered previews (email, PDF, calendar imports) or a "rename this whole series" feature, the pattern becomes domain data and we'd introduce `series_id` + pattern metadata. Out of scope for this branch.
- [x] ~~Q5. **Same-location conflict detection.** Reference shows a soft warning when two rows share date + location. Should this also be enforced server-side, or stay as a client-side soft warning only?~~ **Decision**: Client-side soft warning only, and the user can override it and continue submitting. Server does not reject same-location overlaps. Consistent with Q3 (dropped uniqueness entirely) — the app trusts the user's intent (parallel workshop sessions, etc.), and the warning is purely a UX guardrail against accidental duplication. The review-grid row still shows the amber warning indicator from the reference design, but the Create button stays enabled.
- [x] ~~Q6. **Max batch size.** Should we cap the number of events per request (e.g. 100) to keep transactions bounded and prevent runaway payloads?~~ **Decision**: Cap at **100 events per request**. Comfortably above real classroom use (a semester of MWF ≈ 45; a full academic year ≈ 60), well below Heroku's 30s H12 timeout, matches industry convention (Stripe/GitHub use 100). Enforced server-side in the bulk service's validation step as `400 bad_request` with message `"Batch too large: 100 events max, got N"`. Frontend preflights by disabling the Create button past 100 in the review grid. **Persistence approach**: loop single-row inserts inside one `DB.transaction` (not `multi_insert`). At N≤100 the perf difference is negligible, while cross-adapter compatibility (SQLite dev, PostgreSQL prod) and natural ID-return stay simple. Repository gains a `create_many(entities)` helper: `DB.transaction { entities.map { |e| create(e) } }`.
- [x] ~~Q7. **Component decomposition.** Keep everything in an extended `CreateAttendanceEventDialog.vue`, or split?~~ **Decision**: Split. File layout under `frontend_app/pages/course/components/`:

  - `CreateEventsDialog.vue` — outer wrapper. Owns the `view` state machine (`single` / `bulk-dates` / `bulk-review`), the "Create multiple at once" toggle, modal width per view (560 / 820 / 1160), and the final submit that always wraps payloads as `{ events: [...] }` (1 row for single, N rows for bulk). **No step-back navigation** (per Q8)
  - `events/SingleEventForm.vue` — `view = 'single'` — simple name / location / datetime-start / datetime-end form (mirrors current Tyto modal)
  - `events/BulkEventsStep1Dates.vue` — `view = 'bulk-dates'` — calendar strip + quick-pick chips + name-pattern panel + shared defaults (location, start time, end time). **Bulk-only; not used for single events**
  - `events/BulkEventsStep2Review.vue` — `view = 'bulk-review'` — spreadsheet review grid with per-row editing, fill-down, move up/down, remove, same-location soft warning (per Q5)
  - `events/EventCalendarStrip.vue` — reusable calendar-strip used inside Step 1
  - `events/QuickPickChips.vue` — reusable chip row used inside Step 1
  - `events/TimeInput.vue` — custom 24-hour HH:MM text input ported from the reference prototype. **Use this, not `el-time-picker`** — EP's time picker can render seconds on some browsers even with `format="HH:mm"`, which we want to avoid

  Each view component is a pure child: receives data via props, emits changes up. API calls only happen in the wrapper (`CreateEventsDialog.vue`). No wrappers around other Element Plus primitives (`el-select`, `el-date-picker`, `el-input`) — EP is already the abstraction layer. `ModifyAttendanceEventDialog.vue` stays untouched (edit flow is out of scope for this branch).

- [x] ~~Q8. **Step 2 → Step 1 back navigation — allow or one-way?**~~ **Decision**: One-way. No Back button on the review step. Rationale: step 2 already allows editing every field per row (name, date, location, start, end), plus fill-down for shared columns and add/remove rows — so going back to step 1 is almost never necessary. If the user really wants to redo the date picking or quick-pick pattern from scratch, Cancel restarts the flow. Simpler implementation, no edge cases around preserving row-level edits vs. regenerating from pattern.

- [x] ~~Q9. **Timezone support — this branch or later?**~~ **Decision**: Later. Timezone is a cross-cutting concern with no clean "lite version": schema change (TIMESTAMPTZ or UTC + tz string), prod-data migration with ambiguous source-of-truth for existing rows, every service/representer/picker needs tz context, business rules shift, and UX must disambiguate viewer-tz vs. event-tz. Folding it into this branch would triple the surface area. Current branch keeps the existing local-time-string behavior unchanged. **Action**: add an entry to `doc/future-work.md` with the problem statement, hard parts (existing-data ambiguity, multi-tz UX), and rough shape of the proper fix. Tracked as task 2.18 below.

## Scope

**Slice 1 — In scope**:

- Rename route namespace `r.on 'event'` → `r.on 'events'` in `backend_app/app/application/controllers/routes/course.rb`
- `POST /events` enforces `{ events: [{...}, ...] }` payload shape; rejects bare objects with a 400
- Route handler loops the array and calls existing `Service::Events::CreateEvent` per row (non-transactional for now — Slice 2 upgrades this). Response returns `{ success, events_info: [...] }` for uniformity with bulk
- `GET /events` unchanged in behavior, just renamed
- `PUT /events/:id` unchanged in behavior, just renamed
- Update route-level specs (`spec/routes/event_route_spec.rb`, `spec/routes/current_event_route_spec.rb`) to hit new URLs + new array payload
- Update all frontend API callers (`SingleCourse.vue`, any other files referencing `/event`) to use `/events` and wrap POSTs as 1-element arrays
- **DB schema corrections** (per Q3 + post-audit insight 1.6f): three migrations — 009 drops the `unique (start_at, end_at)` constraint; 010 tightens `start_at`/`end_at` to `NOT NULL`; 011 adds a CHECK constraint `start_at <= end_at` to replace the dropped uniqueness with a real integrity guarantee. Each preceded by a prod-data audit (null-time rows before 010; `start_at > end_at` rows before 011)

**Slice 1 — Out of scope**: transactional bulk, new service, any UI change. Slice 1 is a pure contract rename + schema cleanup.

**Slice 2 — In scope**:

- New backend bulk-create service + route accepting an array of event payloads
- Spec coverage for happy path, auth failure, validation failure on a row, unknown location_id, and transactional rollback behavior
- Frontend two-step modal flow matching the reference design: toggle → step 1 (calendar strip + quick-pick + name-pattern + shared defaults) → step 2 (spreadsheet grid with add/remove/move/fill-down + same-location conflict highlight)
- Existing single-event path continues to work via the same modal (toggle unchecked)

**Slice 2 — Out of scope** (deferrable):

- Editing multiple events in bulk (this branch is creation only)
- Recurrence rules stored server-side (RRULE etc.) — we just expand dates client-side
- Importing from CSV / copy-paste from a spreadsheet — the grid is hand-editable only
- Calendar-app integration (ICS export, Google Calendar sync)

**Slice 2 — Backend changes**:

- New service `Tyto::Service::Events::CreateEvents` (plural) at `backend_app/app/application/services/events/create_events.rb`, mirroring `CreateEvent` structure
- Swap route `POST /events` to delegate to new bulk service (instead of Slice 1's loop)
- Repository helper `EventsRepository#create_many(entities)` per Q6 — wraps a `DB.transaction` and returns the persisted entities with IDs
- *(No uniqueness-constraint migration: dropped entirely in Slice 1 per Q3.)*

**Slice 2 — Frontend changes**:

- Port the reference React modal to Vue 3 + Element Plus using existing components where possible (`el-dialog`, `el-date-picker`, `el-select`, `el-input`)
- Keep the existing single-event form as step "0" accessed via an unchecked "Create multiple at once" toggle
- Add a calendar-strip component for the month picker with existing-event dots, quick-pick chips, name-pattern preview, shared-defaults panel
- Add a spreadsheet-style review grid for step 2 with per-row name/date/location/start/end editing, fill-down buttons, move-up/move-down, remove, and same-location conflict warning
- On success close modal and refresh event list in `SingleCourse.vue`

## Tasks

> **Check tasks off as soon as each one (or each grouped set) is finished** — do not batch multiple completions before updating the plan.
>
> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

- [x] 0 Resolve open questions with user (all of Q1–Q9 recorded in the Questions section above)

### Slice 1 — Route rename + schema cleanup

- [x] 1.1a Update `spec/routes/event_route_spec.rb`: change POST paths to `/events` and wrap bodies as `{ events: [payload] }`; change GET paths to `/events`; change PUT/DELETE to `/events/:id`. Added three failing specs for malformed payloads: bare object (no events key), `events` not an array, and empty events array — all expected to return 400. Asserts POST response returns `events_info` (array) instead of `event_info` (singular). PUT response still uses singular `event_info` since it operates on one row. **Verified red**: 13 failures, all because `/events` routes don't exist yet
- [x] 1.1b Update `spec/routes/current_event_route_spec.rb` similarly (route prefix rename only) — `/api/current_event` → `/api/current_events` throughout
- [x] 1.1c Audit `spec/application/services/events/*_spec.rb` for route paths — none found (service specs test services, not routes)
- [x] 1.2 Renamed `r.on 'event'` → `r.on 'events'` in `course.rb`. Renamed top-level mount `r.on 'current_event'` → `r.on 'current_events'` in `app.rb`
- [x] 1.3 In `POST /events`, parse `request_body['events']`, reject with 400 if missing / not an array / empty. Loop over array, call `CreateEvent` per row, accumulate results. Return `{ success, events_info: [...] }` with `Representer::EventsList`. On per-row failure, break out and propagate the failure's http_status_code (consistent with current single-event error behavior)
- [x] 1.4 Full spec suite green: **873 runs, 2057 assertions, 0 failures, 1 skip**. Coverage 98.05%
- [x] 1.5 Frontend callers updated: `SingleCourse.vue` (createAttendanceEvent → wraps `{ events: [eventForm] }`; fetchAttendanceEvents/deleteAttendanceEvent/updateAttendanceEvent → `/events`), `AttendanceTrack.vue` + `AllCourse.vue` (`/current_event/` → `/current_events/`)
- [x] 1.5b Manual verification (dev), pre-schema-change — **passed 2026-04-21**. Walked through list / create x2 / edit / delete / current-events. Backend log confirms correct SQL: two INSERTs into `events` (both via `POST /api/course/1/events` with array payload), one UPDATE (name edit), one DELETE (row 3). Zero error/exception/warn lines in the log. Final DB state = original `frist post` row + edited `slice-1 test A (edited)`.
- [x] 1.6a Migration `009_drop_events_start_end_unique.rb`: drops the table-level `unique (start_at, end_at)` constraint. Adapter-aware: Postgres uses `drop_constraint :events_start_at_end_at_key`; SQLite rebuilds the table (the UNIQUE is part of the `CREATE TABLE` text, so there's no index to drop). Explicit `up`/`down` both implemented. Ran in dev + test — both at schema version 9, events data preserved (2 rows intact in dev), `.schema events` shows no UNIQUE, full suite still 873 runs / 2057 assertions / 0 failures
- [x] 1.6b **Prod DB audit — 2026-04-21.** No `rake console` task exists yet in this app, so we used `heroku run bash --app tyto` → `psql $DATABASE_URL`. Sanity check: connected to server 10.0.56.45 / db `d4a2kmtttg1l6m` with 582 accounts, 134 events, 16 courses, most-recent events matched known real names ("Week 09", "Week 08"). Audit query returned **0 rows** — no prod event has NULL start_at or end_at. Safe to proceed with migration 010. **Original instructions (now historical):** AI tooling must not be given direct access to the production database. The developer runs `heroku run rake console --app <app>` (once that task exists) OR `heroku pg:psql --app <app>` / `heroku run bash --app <app>` → `psql $DATABASE_URL` to query:

  ```ruby
  Tyto::DB[:events]
    .where(Sequel.|({ start_at: nil }, { end_at: nil }))
    .select(:id, :course_id, :name, :start_at, :end_at, :created_at)
    .all
  ```

  (Or use `heroku pg:psql --app <app>` for a raw `psql` shell if preferred — same intent, different surface.) AI tooling must not be given direct access to the production database.

  Expected outcomes:
  - **Zero rows** → report back "prod clean", proceed to 1.6c
  - **Some rows** → paste the result into this planning conversation; we decide per-row whether to backfill, delete, or defer the NOT NULL migration. No writes to prod until a plan is agreed
- [x] 1.6c Migration `010_events_times_not_null.rb` written with explicit `up`/`down` (`set_column_not_null` / `set_column_allow_null`). Applied in dev + test. 23 specs that had been creating bare `Tyto::Event.create(...)` calls without times surfaced as NOT NULL violations and were updated to supply real times: `courses_spec.rb` (6 sites via replace_all), `attendances_spec.rb` (2 `let` blocks), `events_spec.rb` (lines 224–225, 275–281 `#delete` case), `locations_spec.rb` (`returns true for location with events`), `list_events_spec.rb` (4 sites across 3 tests). Obsolete `persists event with minimal attributes (no times)` test was replaced with two new regression specs: nil times rejected (1.6c guard) and start > end rejected (1.6f-spec guard)
- [x] 1.6d Regression spec added in `backend_app/spec/infrastructure/database/repositories/events_spec.rb` (`#create` block): two events with identical `(start_at, end_at)` in the same course both persist with distinct IDs. Full suite now 874 runs / 2060 assertions / 0 failures. (Note: because 1.6a is already applied, the spec is green from the start; 1.6e's rehearsal will re-verify against a rolled-back schema.)
- [x] 1.6e **Data-integrity rehearsal — passed 2026-04-21.** Dev DB populated from existing 2 events up to 10 events (course 1, mix of locations 1/3/4, including a deliberate duplicate `(start_at, end_at)` pair across locations 3 + 4 — id 5 `Lab A` and id 6 `Lab A dup`, both `2026-05-04 14:00..16:00`). Baseline dump checksum `md5 b8a5fbdb4103e7e2f094ac8cd6d7afcb`. Intermediate snapshots stored under `tmp/rehearsal-1.6e/` (gitignored). Round-trips exercised separately for each migration via `bundle exec sequel -m backend_app/db/migrations -M <ver> sqlite://backend_app/db/store/development.db`:

  - **011 (CHECK start≤end)**: v11 rejected `start>end` insert (`CHECK constraint failed: start_before_end`). Rolled v11→v10; dump md5 matched baseline (`b8a5fbdb…`); violating row inserted successfully (CHECK removed); deleted it; re-migrated v10→v11; final md5 matched. ✅
  - **010 (NOT NULL)**: v11 rejected `start_at: NULL` insert (`NOT NULL constraint failed: events.start_at`). Rolled v11→v9 (skipping past 011's CHECK removal too, since 010-down is a no-op for CHECK); dump md5 matched baseline; NULL insert succeeded; deleted; re-migrated v9→v11; final md5 matched. ✅
  - **009 (drop UNIQUE)**: baseline already proves 009-up works (duplicate pair persists). For the down-then-up round-trip, id 6 (`Lab A dup`) deleted first to make the UNIQUE-restoring down migration applicable (else the `INSERT INTO events_new` would fail). Rolled v11→v8 (9 rows); duplicate-pair insert rejected (`UNIQUE constraint failed: events.start_at, events.end_at`); re-migrated v8→v11; id=11 `Lab A dup` re-inserted; final row count = 10, 1 duplicate pair. ✅

  At no point did the 9 through-the-round-trip rows lose or corrupt any field. Final dev DB: 10 events, schema v11, duplicate-pair restored.

  **1.6f-rehearsal coverage**: the 011 round-trip above is exactly the start-before-end violation-then-recovery flow — ticked below.

  **Test env**: `test.db` schema_info was empty after prior spec runs (tables built via test helpers, no migrator state). Ran `RACK_ENV=test bundle exec rake db:drop && RACK_ENV=test bundle exec rake db:migrate` → clean v11 schema. Full suite follow-up: **875 runs, 2058 assertions, 0 failures, 1 skip** — no regression.

  **Original procedure (historical):**

  **Setup**: from a clean `rake db:reset`, populate the `events` table with a representative mix by either (a) using the UI to create ~10 events across 2–3 courses and 2 locations, including at least one pair sharing `(start_at, end_at)` *would-be-collisions* that are currently blocked by the existing unique constraint — so create them across different courses/locations to get them in — or (b) writing a throwaway `rake` task / console snippet that inserts the same shape. Take a snapshot: total row count, a `SELECT id, course_id, location_id, name, start_at, end_at` dump of every event, checksum of that dump (`md5`).

  **Exercise migration 009 (drop unique)**:
  1. Run `bundle exec rake db:migrate`
  2. Re-dump events; diff against the pre-snapshot — must be identical (row count + every field)
  3. Insert a new event with `(start_at, end_at)` matching an existing row in the same course — must now succeed (this is the positive case 1.6d guards in a spec, re-verified here with real data)
  4. Rollback via the Sequel CLI (no `rake db:rollback` task exists — confirmed by inspecting `Rakefile`; only `db:migrate` is defined). Concrete command for dev:

     ```sh
     bundle exec sequel -m backend_app/db/migrations -M 008 sqlite://backend_app/db/store/development.db
     ```

     Replace `008` with the target pre-009 version and swap the URL for test (`sqlite://backend_app/db/store/test.db`). Re-dump: the extra row from step 3 will be present, but original rows intact. Re-migrate up with `bundle exec rake db:migrate`. **Optional chore**: add a small `db:rollback` rake task that wraps `Sequel::Migrator.run(db, migration_path, target: ENV['VERSION'].to_i)` — leave out of Slice 1 unless rollback rehearsal becomes painful

  **Exercise migration 010 (NOT NULL)**:
  1. Run `bundle exec rake db:migrate`
  2. Re-dump events; diff against the post-009 snapshot (minus the deliberately-added step-3 row, or including it) — no row lost, no field corrupted
  3. Attempt to insert an event with `start_at: nil` — must fail with a NOT NULL constraint error (positive confirmation the migration took)
  4. Rollback 010; re-migrate up. Verify data intact at every step

  **Repeat in test env** (`RACK_ENV=test bundle exec rake db:migrate`) to confirm the migrations apply cleanly against the test DB as well. **Caveat**: both dev and test use SQLite here (`backend_app/db/store/{development,test}.db`). Prod uses PostgreSQL — any adapter-specific surprises (e.g. CHECK syntax quirks, NOT NULL on populated columns needing `USING`) only surface at staging rehearsal (1.8b) or the prod release phase (1.8d). This step is **data-integrity rehearsal on the dev adapter**, not a cross-adapter smoke test.

  Record the snapshots + checksums in this plan or a sibling scratch file so the comparison is reproducible if anything needs re-doing. Only tick 1.6e off once all three migrations (009 drop-unique, 010 NOT-NULL, 011 CHECK start≤end — see 1.6f) round-trip cleanly with zero data damage.

- [ ] 1.6f **CHECK constraint: `start_at <= end_at`.** Dropping the old `(start_at, end_at)` uniqueness (1.6a) leaves *no* schema-level guarantees on the time columns. "End before start" is a nonsense state we shouldn't trust the service layer alone to prevent — migrations, seeds, and future bulk writes can bypass `CreateEvent` validation. Add a DB-level CHECK. Inclusive (`<=`) so zero-duration placeholder events remain legal.

  Three sub-tasks mirroring the 1.6b/c/d pattern:
  - [x] **1.6f-audit — 2026-04-21.** Same psql session as 1.6b (server 10.0.56.45 / db `d4a2kmtttg1l6m`, verified real data first). `SELECT ... WHERE start_at > end_at` returned **0 rows** — no prod event has an end time before its start. Safe to proceed with migration 011. Original procedural note retained: AI must not access prod directly; the developer runs either `heroku run rake console --app <app>` (once the task exists) or `heroku run bash --app <app>` → `psql $DATABASE_URL` / `heroku pg:psql --app <app>`
  - [x] **1.6f-migration** — `011_events_start_before_end.rb` with explicit `up`/`down` (`add_constraint(:start_before_end) { start_at <= end_at }` / `drop_constraint(:start_before_end)`). Applied in dev + test
  - [x] **1.6f-spec** — regression spec added in `events_spec.rb` `#create` block asserting that `start_at > end_at` raises `Sequel::ConstraintViolation` (the cross-adapter parent — covers SQLite and Postgres). Suite green: 875 runs / 2058 assertions / 0 failures
  - [x] **1.6f-rehearsal — passed 2026-04-21.** Covered in-place by the 1.6e rehearsal's 011 round-trip: v11 rejected `start>end` insert (`CHECK constraint failed: start_before_end`); rolled v11→v10 (check removed), violating insert succeeded, deleted, re-migrated v10→v11; data md5 identical to baseline at every step.

  **Replaces** the now-deleted Slice 2 task 2.5 (which would have re-added a multi-column unique constraint — obsoleted by the Q3 decision to drop uniqueness entirely).

### Slice 1 — Tooling prep (pre-deploy)

- [x] 1.7 `rake console` task shipped. `bundle exec rake console` → pry with full Tyto app loaded (`app`, `Tyto::Api.db`, `Tyto::Event`, etc. all resolve). `.pryrc` auto-renders Sequel model arrays as tables via `table_print`. `RACK_ENV=production` path verified — environment reports production, `Rack::Test` not mixed in (via `unless app.environment == :production` guard). Full suite still 875/2058/0 failures. **Files added**: `console.rb` (root), `.pryrc` (root). **Edits**: `Gemfile` (+ `table_print ~>1.0`), `Rakefile` (+ `:print_env`, `console:` tasks). **Reference cribbed from**: `/Users/soumyaray/Sync/Dropbox/ossdev/classes/SEC-class/projects/tyto2026-api/` (adapted: `console.rb` at root instead of `spec/test_load_all.rb`, wider `tp.set` list for our ORM). On Heroku, `heroku run rake console --app tyto` becomes the first-class inspection path.

### Slice 1 — Production rollout safety

- [x] 1.8a **Heroku release phase added — 2026-04-21.** `Procfile` now has `release: bundle exec rake db:migrate` prepended above the existing `web:` line. Verified path: `db:migrate` task in `Rakefile` loads `Tyto::Api` which reads `ENV['DATABASE_URL']` (set by Heroku in release phase) and runs `Sequel::Migrator.run` against the Postgres URL — no code changes needed to the rake task itself. Full failure-atomicity: if any migration raises, the release phase exits non-zero and Heroku does not promote the new slug. Closes the gap where devs had to remember `heroku run rake db:migrate` after every push.
- [x] 1.8b **Skipped — no staging app, overhead not worth the marginal confidence.** The release-phase directive is a well-documented Heroku feature, not custom logic; failure mode is fail-closed by contract (bad migration → deploy not promoted). Local rehearsal (1.6e) already validated each migration against real data; the adapter-surprise risk (SQLite dev → Postgres prod) is the only remaining unknown, covered by the 1.6b / 1.6f-audit prerequisites and the 1.8c backup. First prod deploy (1.8d) is effectively the staging test.
- [x] 1.8c **Pre-deploy backup captured — 2026-04-21.** Ran `heroku pg:backups:capture --app tyto` → snapshot `b004` (logical backup of `postgresql-aerodynamic-99158`). Heroku warned that continuous protection is already enabled, so this is belt-and-suspenders alongside WAL-based point-in-time recovery. Rollback path if 1.8d surprises us: `heroku pg:backups:restore b004 DATABASE_URL --app tyto --confirm tyto`.
- [x] 1.8d **Slice 1 deployed to prod — 2026-04-21, 23:34:54 +0800.** `git push heroku feature-multi-event:main` → Heroku built with Node 24.15 + Ruby 3.4.4 + bundler 2.7.2 (noisy but non-blocking Node/Puma/Ruby upgrade warnings) → release phase ran `bundle exec rake db:migrate` → slug promoted as **v79** (`Deploy d6a8bcea`, eligible for rollback). No migration errors in the push stream; release phase reported "Waiting for release.... done." The `heroku releases:output v79` endpoint returned "not started yet" repeatedly, which appears to be a Heroku display quirk for already-completed release commands — not a failure indicator. Actual state confirmed by 1.8e.
- [x] 1.8e **Post-deploy smoke check passed — 2026-04-21.** Ran via `heroku run --app tyto bash -c 'psql $DATABASE_URL -c "..."'` (direct SQL over the dyno; avoids boot-up cost of `rake console` for a one-shot read). Single aggregated query returned:

  | check | expected | actual |
  | --- | --- | --- |
  | schema_version | 11 | **11** |
  | null_start | 0 | **0** |
  | null_end | 0 | **0** |
  | end_before_start | 0 | **0** |
  | total_events | 134 (pre-deploy, per 1.6b) | **134** |

  All three migrations (009 drop-unique, 010 NOT NULL, 011 CHECK start≤end) are in force in prod with zero data loss or corruption. **UI walkthrough** (hit `/api/course/:id/events`, create + delete a test event) remains to be done by the user; the SQL-level check above is sufficient to prove the schema landed cleanly but not that the application layer is serving traffic correctly. Tack that on opportunistically next time you're logged in.

### Slice 1 → Slice 2 hand-off

- [ ] 1.9 **Merge Slice 1 PR, keep working on the same branch for Slice 2.** After 1.8e passes clean:
  1. **Verify merge strategy first.** GitHub → Settings → General → Pull Requests — confirm "Allow merge commits" is enabled (or just check what the green button on PR #59 offers). Reason: Slice 2 will continue on this same `feature-multi-event` branch, which only works if the merge preserves the Slice 1 commit SHAs as ancestors of `main`. Squash or rebase merges rewrite SHAs → branch diverges → next PR would appear to re-include all of Slice 1. If only squash is available, either toggle merge-commit on, or accept the ceremony of a fresh branch (`git reset --hard origin/main` on this branch, or create `feature-multi-event-2`).
  2. Update PR #59 description so its scope matches what's actually shipping (route rename + schema cleanup + release phase + console + the rehearsal evidence). Do NOT rename the PR — "multi-event" still describes the branch's overall destination.
  3. Merge PR #59 via **merge-commit** (preserves sub-commit history for future archaeology). Do NOT tick the "Delete branch after merge" checkbox — we're keeping the branch alive for Slice 2.
  4. Locally: `git fetch origin && git rebase origin/main` (no-op since merge-commit kept SHAs as ancestors, but confirms cleanliness). Branch now has 0 commits ahead of `origin/main`.
  5. Continue Slice 2 work on this same branch. First new commit on top (e.g. 2.1a failing spec) naturally becomes Slice 2's PR material. When there's enough reviewable work, open a fresh PR against `main`.
  6. First post-merge commit: tick **1.9** off in this plan so the hand-off itself is recorded. `PLAN.feature-multi-event.md` continues to travel with the branch — Slice 2 and Slice 3 sections remain open as the single source of truth.

### Slice 2 — Bulk creation feature

#### Backend (tests first)

- [ ] 2.1a Failing spec: `CreateEvents#call` returns `Success` with array of enriched events for a valid 3-row payload
- [ ] 2.1b Failing spec: rejects with `Failure(forbidden)` when requestor is a student (not teaching staff)
- [ ] 2.1c Failing spec: rejects with `Failure(bad_request)` when any row has missing name / invalid times / unknown `location_id`; no rows persisted (transaction rollback)
- [ ] 2.1d Failing spec: rejects with `Failure(not_found)` when course does not exist
- [ ] 2.1e Failing spec: batches larger than 100 rows are rejected with `Failure(bad_request)` and message `Batch too large: 100 events max, got N` (per Q6). Happy-path upper bound: exactly 100 rows succeeds
- [ ] 2.2 Implement `Tyto::Service::Events::CreateEvents` (validate course → authorize once → validate all rows → enforce ≤100 cap → persist transactionally → enrich with locations → return collection)
- [ ] 2.3 Add `EventsRepository#create_many(entities)` per Q6 — `DB.transaction { entities.map { |e| create(e) } }`. Kept separate from `create(entity)` to preserve single-method return types and make the transaction boundary explicit at the callsite (see audit 2026-04-21 for rationale against collapsing)
- [ ] 2.4 Swap `POST /events` route to delegate to `CreateEvents` (replacing Slice 1's loop). Keep the `{ success, message: 'Events created', events_info: [...] }` response shape for frontend compatibility
- [ ] 2.5 *(removed)* — was "migration to change unique constraint"; obsoleted by Q3 (drop entirely) and replaced by Slice 1 migrations 009 + 011 (drop-unique + CHECK start≤end via 1.6a / 1.6f)
- [ ] 2.6 Run full spec suite and fix any regressions

#### Frontend

- [ ] 2.7 Create `CreateEventsDialog.vue` wrapper: `view` state machine (`single` / `bulk-dates` / `bulk-review`), "Create multiple at once" toggle, modal width per view, final submit wrapping `{ events: [...] }`. **No back navigation from review** (per Q8). Replaces `CreateAttendanceEventDialog.vue` (which can be renamed/moved, or the new file can supersede it — update the parent `SingleCourse.vue` import either way)
- [ ] 2.8 `events/TimeInput.vue`: port the reference's custom 24-hour HH:MM numeric text input. **Not `el-time-picker`** (seconds rendering on some browsers)
- [ ] 2.9 `events/SingleEventForm.vue`: port current single-event fields (name, location, datetime-start, datetime-end) as a pure child component emitting changes up
- [ ] 2.10 `events/EventCalendarStrip.vue`: month tiles, date toggle, existing-event dots (sourced from a `existingEventDates` prop supplied by parent), add/remove month
- [ ] 2.11 `events/QuickPickChips.vue`: `Every Mon`, `Mon + Wed`, etc. — emits a pattern payload that the parent applies
- [ ] 2.12 `events/BulkEventsStep1Dates.vue`: composes the calendar strip + quick-pick chips + name-pattern panel (with live preview: `pad2 / nopad / date-short / none`) + shared-defaults panel (location, start time, end time). Disable "Review N events" button until all required fields filled. Fetch existing course events to pass as `existingEventDates` to the calendar strip
- [ ] 2.13 `events/BulkEventsStep2Review.vue`: spreadsheet grid with per-row editing, fill-down, move up/down, remove, same-location **soft warning** (warning does not block submit, per Q5). Client-side preflight: disable Create button when row count > 100 (per Q6)
- [ ] 2.14 Wire wrapper submit → `POST /course/:id/events` with `{ events: [...] }`; on success show `ElMessage` success toast, close modal, call existing `fetchAttendanceEvents` in `SingleCourse.vue`
- [ ] 2.15a Loading state: while POST is in flight, disable the Create button with a "Creating events…" spinner, prevent closing the modal via Escape/backdrop
- [ ] 2.15b Error handling: on failure, surface the per-row error map from the server (per Q2) by highlighting the offending rows in the review grid with their error messages; keep the modal open so the user can fix and retry. Non-per-row errors (e.g. auth, network) surface via `ElMessage` error toast

#### Verification

- [ ] 2.16 Manual verification in browser at `http://localhost:9292`:
  - Single flow still works (toggle off)
  - Bulk: pick 4 dates via calendar + 1 quick-pick, enter shared defaults, review & tweak one row, submit
  - Events list refreshes and shows all created rows
  - Validation errors surface cleanly for a deliberately bad row (all-or-nothing per Q2: zero rows committed, per-row error map returned)
  - Authorization: a student account sees no "Create" button (existing behavior unchanged)
- [ ] 2.17 Update `doc/future-work.md` if any of Q3/Q5/Q6 decisions defer follow-up work
- [ ] 2.18 Add timezone-support entry to `doc/future-work.md` (per Q9): problem statement, hard parts (existing-data source-of-truth ambiguity, multi-tz UX for instructors-vs-students in different zones, attendance-window business rules), and rough shape of proper fix (TIMESTAMPTZ or UTC+tz string; course-level default tz; picker disambiguation)

### Slice 3 — Retrospective: feed lessons back into `/ray-branch-plan` skill

> After Slices 1 and 2 ship, reflect on what this plan did differently from a "default" branch plan and capture durable lessons for the skill at `~/.claude/skills/ray-branch-plan/SKILL.md`.

- [ ] 3.1 Re-read this plan file and note what worked / what didn't (e.g. accuracy of slice scoping, usefulness of the Questions list, whether the two-slice split paid off)
- [ ] 3.2 Draft a short "Lessons" section below (in this file) with concrete, transferable guidance
- [ ] 3.3 Open `~/.claude/skills/ray-branch-plan/SKILL.md`, identify the right home for each lesson (template, "Planning and execution guidelines", or a new section), and propose edits. Show the diff to the user before committing to the skill file
- [ ] 3.4 Apply approved edits to the skill; commit in the `~/.claude/` repo (separate from this feature branch)

### Final pre-merge check

- [ ] 4.1 Run `bundle exec rake audit` (wraps `bundle-audit check --update`) and resolve any reported CVEs before merging the branch to `main`. This is the last thing to do — deliberately deferred to the end so the gem lockfile is stable and we're not chasing vulnerabilities in dependencies we might still add/remove during Slice 2. The `bundler-audit` gem + `rake audit` task were wired up in Slice 1 (Gemfile + Rakefile) and are ready to run

**Seed observations** (to expand during Slice 3):

- **Consider an initial refactoring slice before feature work.** When a new feature will break or awkwardly extend an existing structure (e.g. renaming routes, widening a payload contract, loosening a DB constraint), plan a dedicated refactoring slice *first* — behavior-preserving, test-covered — so the feature slice only adds new behavior on top of a clean foundation. This keeps each PR reviewable and limits the blast radius of any single change.
- **Numbered slices with prefixed task IDs (1.1a, 2.3, …) scale better than a flat list** once a branch plan exceeds ~10 tasks or crosses slice boundaries.
- **Capture scope questions explicitly and resolve them before coding.** The Q1–Q9 list surfaced endpoint-shape, DB-constraint, and timezone decisions up-front that would have caused rework if discovered mid-implementation.
- **Link to any external reference designs with file paths and a summary of what to port** — the reference React prototype at `tmp/DESIGN-multi-events/create-events-modal.jsx` was far more actionable once named + summarized in the plan than it would have been as a raw file.
- **Audit the deploy / migration mechanism before planning any schema change.** We discovered mid-planning that this app had no Heroku release phase — migrations were manual and a dev could deploy code that referenced a schema that hadn't been applied yet. Plans touching the DB should start by verifying `Procfile` (or equivalent) runs migrations automatically, and add that wiring if it's missing.

## Completed

(none yet)

---

Last updated: 2026-04-21
