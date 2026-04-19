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
- [x] All scope questions (Q1–Q7) resolved with user
- [ ] Slice 1: route rename + schema cleanup shipped
- [ ] Slice 2: bulk service + split-component modal shipped
- [ ] Manual verification of both flows
- [ ] Slice 3: retrospective → skill-file edits proposed

## Key Findings

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

1. **`unique (start_at, end_at)` is DB-global.** A bulk create that accidentally reuses an existing `start_at/end_at` pair (even from a different course) will fail on insert. Need transactional behavior so partial failures don't leave half the batch committed. Worth flagging as `Q3`.
2. **Authorization is per-course, not per-event.** One `can_create?` check at the start of the bulk service is sufficient.
3. **Enrichment.** Single-event response enriches with location coords. Bulk service should fetch all needed locations once (via `repo.find_ids(ids)`) rather than N times.
4. **No contract classes.** Validation is inline in `CreateEvent` private methods — mirror that style rather than introducing dry-validation.
5. **Representer already exists** — reuse `Representer::Event` per row or `Representer::EventsList` for the collection response.

## Questions

> Questions must be numbered (Q1, Q2, ...) and crossed off when resolved. Note the decision made.

- [x] ~~Q1. **Endpoint shape.** Add new `POST /api/course/:course_id/events` (plural) that accepts `{ events: [...] }`, or extend the existing singular `POST /.../event` to accept either an object or an array?~~ **Decision**: Rename the resource from singular `event` to plural `events` (matching REST convention), and unify under a single endpoint `POST /api/course/:course_id/events` that always takes `{ events: [...] }`. Single-event create becomes a 1-row array. Also rename `GET /event` → `GET /events` and `PUT /event/:id` → `PUT /events/:id` for consistency. Pending confirmation that there are no external API consumers beyond the Vue frontend.
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

- [x] ~~Q9. **Timezone support — this branch or later?**~~ **Decision**: Later. Timezone is a cross-cutting concern with no clean "lite version": schema change (TIMESTAMPTZ or UTC + tz string), prod-data migration with ambiguous source-of-truth for existing rows, every service/representer/picker needs tz context, business rules shift, and UX must disambiguate viewer-tz vs. event-tz. Folding it into this branch would triple the surface area. Current branch keeps the existing local-time-string behavior unchanged. **Action**: add an entry to `doc/future-work.md` with the problem statement, hard parts (existing-data ambiguity, multi-tz UX), and rough shape of the proper fix. Tracked as task 2.17 below.

## Scope

**Slice 1 — In scope**:

- Rename route namespace `r.on 'event'` → `r.on 'events'` in `backend_app/app/application/controllers/routes/course.rb`
- `POST /events` enforces `{ events: [{...}, ...] }` payload shape; rejects bare objects with a 400
- Route handler loops the array and calls existing `Service::Events::CreateEvent` per row (non-transactional for now — Slice 2 upgrades this). Response returns `{ success, events_info: [...] }` for uniformity with bulk
- `GET /events` unchanged in behavior, just renamed
- `PUT /events/:id` unchanged in behavior, just renamed
- Update route-level specs (`spec/routes/event_route_spec.rb`, `spec/routes/current_event_route_spec.rb`) to hit new URLs + new array payload
- Update all frontend API callers (`SingleCourse.vue`, any other files referencing `/event`) to use `/events` and wrap POSTs as 1-element arrays
- **DB schema corrections** (per Q3): migration to drop `unique (start_at, end_at)` constraint; separate migration to tighten `start_at` and `end_at` to `NOT NULL`. Audit prod DB for null-time rows before the NOT NULL migration

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
- Possible migration to adjust the `unique` constraint (pending Q3)
- Optional repository helper `EventsRepository#create_many(entities)` that wraps a DB transaction and returns the persisted entities with IDs

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

- [ ] 0 Resolve Q2–Q7 with user (record decisions in Questions section)

### Slice 1 — Route rename + array contract

- [ ] 1.1a Update `spec/routes/event_route_spec.rb`: change POST paths to `/events` and wrap bodies as `{ events: [payload] }`; change GET paths to `/events`. Also add a new failing spec: POST `/events` with a bare object (no array) returns 400
- [ ] 1.1b Update `spec/routes/current_event_route_spec.rb` similarly (route prefix rename only)
- [ ] 1.1c Update `spec/application/services/events/*_spec.rb` if any reference the route path — service specs shouldn't, but check
- [ ] 1.2 Rename `r.on 'event'` → `r.on 'events'` in `backend_app/app/application/controllers/routes/course.rb`. Rename any CurrentEvent route prefix similarly
- [ ] 1.3 In `POST /events`, parse `request_body['events']`, reject with 400 if missing / not an array / empty. Loop over array, call `CreateEvent` per row, accumulate results. Return `{ success, events_info: [...] }` with `Representer::EventsList`
- [ ] 1.4 Run backend spec suite until green
- [ ] 1.5 Update frontend callers: grep `frontend_app/` for `/event` (path and filename string) and update to `/events`; wrap POST bodies as `{ events: [form] }`. Key files: `frontend_app/pages/course/SingleCourse.vue`, `CreateAttendanceEventDialog.vue` (wiring), `ModifyAttendanceEventDialog.vue`, any API-client layer
- [ ] 1.6a Migration `009_drop_events_start_end_unique.rb`: drop `unique (start_at, end_at)` index from `events` table. Explicit `up`/`down` blocks so revert is a well-defined statement. Run `bundle exec rake db:migrate` in dev + `RACK_ENV=test bundle exec rake db:migrate` in test
- [ ] 1.6b **Prod DB audit — HUMAN ONLY, NOT AI.** This step must be performed by a developer via `heroku run rails dbconsole` (or equivalent Sequel / psql shell on the Heroku dyno). AI tooling must not be given direct access to the production database. The dev runs:

  ```sql
  SELECT id, course_id, name, start_at, end_at, created_at
  FROM events
  WHERE start_at IS NULL OR end_at IS NULL;
  ```

  Expected outcomes:
  - **Zero rows** → report back "prod clean", proceed to 1.6c
  - **Some rows** → paste the result into this planning conversation; we decide per-row whether to backfill, delete, or defer the NOT NULL migration. No writes to prod until a plan is agreed
- [ ] 1.6c Migration `010_events_times_not_null.rb`: add `NOT NULL` to `events.start_at` and `events.end_at` via explicit `up`/`down` blocks (`set_column_not_null` / `set_column_allow_null`). Only run after 1.6b is clean (or the user has resolved violations). Exercise in dev + test
- [ ] 1.6d Add a failing spec (then green) for the repository / ORM: creating two events with identical `(start_at, end_at)` in the same course now succeeds (regression guard against re-adding the dropped constraint)

### Slice 1 — Production rollout safety

- [ ] 1.7a **Add Heroku release phase to `Procfile`**: prepend `release: bundle exec rake db:migrate` above the existing `web:` line. This makes every deploy atomic — if migrations fail, the new release does not promote and the previous release stays live. Closes the gap where devs must remember to run `heroku run rake db:migrate` after every push
- [ ] 1.7b Verify release-phase behavior on a staging app (or a throwaway Heroku app if no staging exists). Push a deliberately broken migration, confirm deploy is rejected, revert
- [ ] 1.7c **Before deploying the NOT NULL migration to prod**: human dev captures a backup — `heroku pg:backups:capture --app <app>` — and notes the backup ID in the deploy log. Free insurance even with point-in-time recovery
- [ ] 1.7d Deploy Slice 1 to prod: push the branch → release phase runs migrations 009 + 010 in order → new slug promoted only if both succeed. If 010 fails (unexpected NULL rows), 009 has still applied cleanly and the deploy halts — no half-state in application code
- [ ] 1.7e Post-deploy smoke check: hit `/api/course/:id/events` in prod with a known course, confirm event list loads. Create and delete a test event via the UI

- [ ] 1.8 Manual verification (dev): existing single-event create / edit / list / delete all still work end-to-end in browser at `http://localhost:9292`

### Slice 2 — Bulk creation feature

#### Backend (tests first)

- [ ] 2.1a Failing spec: `CreateEvents#call` returns `Success` with array of enriched events for a valid 3-row payload
- [ ] 2.1b Failing spec: rejects with `Failure(forbidden)` when requestor is a student (not teaching staff)
- [ ] 2.1c Failing spec: rejects with `Failure(bad_request)` when any row has missing name / invalid times / unknown `location_id`; no rows persisted (transaction rollback)
- [ ] 2.1d Failing spec: rejects with `Failure(not_found)` when course does not exist
- [ ] 2.1e Failing spec (pending Q6): rejects oversized batches
- [ ] 2.2 Implement `Tyto::Service::Events::CreateEvents` (validate course → authorize once → validate all rows → persist transactionally → enrich with locations → return collection)
- [ ] 2.3 Add `EventsRepository#create_many` if it makes the service cleaner; otherwise wrap `DB.transaction` in the service
- [ ] 2.4 Swap `POST /events` route to delegate to `CreateEvents` (replacing Slice 1's dumb loop). Keep the same response shape for frontend compatibility
- [ ] 2.5 (Pending Q3) Migration to change unique constraint to `(course_id, location_id, start_at, end_at)`
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

- [ ] 2.15 Manual verification in browser at `http://localhost:9292`:
  - Single flow still works (toggle off)
  - Bulk: pick 4 dates via calendar + 1 quick-pick, enter shared defaults, review & tweak one row, submit
  - Events list refreshes and shows all created rows
  - Validation errors surface cleanly for a deliberately bad row
  - Authorization: a student account sees no "Create" button (existing behavior unchanged)
- [ ] 2.16 Update `doc/future-work.md` if any of Q3/Q5/Q6 decisions defer follow-up work
- [ ] 2.17 Add timezone-support entry to `doc/future-work.md` (per Q9): problem statement, hard parts (existing-data source-of-truth ambiguity, multi-tz UX for instructors-vs-students in different zones, attendance-window business rules), and rough shape of proper fix (TIMESTAMPTZ or UTC+tz string; course-level default tz; picker disambiguation)

### Slice 3 — Retrospective: feed lessons back into `/ray-branch-plan` skill

> After Slices 1 and 2 ship, reflect on what this plan did differently from a "default" branch plan and capture durable lessons for the skill at `~/.claude/skills/ray-branch-plan/SKILL.md`.

- [ ] 3.1 Re-read this plan file and note what worked / what didn't (e.g. accuracy of slice scoping, usefulness of the Questions list, whether the two-slice split paid off)
- [ ] 3.2 Draft a short "Lessons" section below (in this file) with concrete, transferable guidance
- [ ] 3.3 Open `~/.claude/skills/ray-branch-plan/SKILL.md`, identify the right home for each lesson (template, "Planning and execution guidelines", or a new section), and propose edits. Show the diff to the user before committing to the skill file
- [ ] 3.4 Apply approved edits to the skill; commit in the `~/.claude/` repo (separate from this feature branch)

**Seed observations** (to expand during Slice 3):

- **Consider an initial refactoring slice before feature work.** When a new feature will break or awkwardly extend an existing structure (e.g. renaming routes, widening a payload contract, loosening a DB constraint), plan a dedicated refactoring slice *first* — behavior-preserving, test-covered — so the feature slice only adds new behavior on top of a clean foundation. This keeps each PR reviewable and limits the blast radius of any single change.
- **Numbered slices with prefixed task IDs (1.1a, 2.3, …) scale better than a flat list** once a branch plan exceeds ~10 tasks or crosses slice boundaries.
- **Capture scope questions explicitly and resolve them before coding.** The Q1–Q7 list surfaced endpoint-shape and DB-constraint decisions up-front that would have caused rework if discovered mid-implementation.
- **Link to any external reference designs with file paths and a summary of what to port** — the reference React prototype at `tmp/DESIGN-multi-events/create-events-modal.jsx` was far more actionable once named + summarized in the plan than it would have been as a raw file.
- **Audit the deploy / migration mechanism before planning any schema change.** We discovered mid-planning that this app had no Heroku release phase — migrations were manual and a dev could deploy code that referenced a schema that hadn't been applied yet. Plans touching the DB should start by verifying `Procfile` (or equivalent) runs migrations automatically, and add that wiring if it's missing.

## Completed

(none yet)

---

Last updated: 2026-04-19
