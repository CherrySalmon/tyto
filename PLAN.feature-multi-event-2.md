# Multi-Event Bulk Creation — Slice 2 + Slice 3 (active)

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.
>
> **Slice 1 shipped** (route rename + schema cleanup, merged as PR #59). Slice 1's history, audit evidence, and deploy notes live in `PLAN.feature-multi-event-1.md` — consult it only when re-investigating a migration, rollback, or deploy step. This file is otherwise self-contained.

## Branch

`feature-multi-event`

## Goal

Allow instructors/staff to create many attendance events at once for a course via a two-step flow: pick dates + shared details (calendar strip + quick-pick patterns), then refine each row in a spreadsheet-style review grid. Falls back to the existing single-event form when the "Create multiple" toggle is off.

## What Slice 1 already shipped (context for Slice 2)

- `GET/PUT/POST /api/course/:course_id/events` (plural). `POST` requires `{ events: [...] }` and returns `{ success, events_info: [...] }`. Currently the handler loops `Service::Events::CreateEvent` per row (non-transactional); Slice 2 replaces this with a transactional bulk service
- `GET /api/current_events` (was `/current_event`)
- Events table schema:
  - `unique (start_at, end_at)` dropped (migration 009)
  - `start_at` / `end_at` are `NOT NULL` (migration 010)
  - CHECK constraint `start_at <= end_at` (migration 011)
- Prod tooling: `rake console` task; Heroku `release: bundle exec rake db:migrate` in `Procfile`
- Frontend `SingleCourse.vue`, `AttendanceTrack.vue`, `AllCourse.vue` already call the plural URLs and wrap 1-row arrays

## Reference Design

**Source** (removed post-port, 2026-04-22): The Claude Design React prototype (`doc/design/multi-events/prototype/`) was deleted once Slice 2 frontend landed — the port is complete and the 1.2 MB source tree doesn't need to live in main. Deletion was amended into the frontend commit so the prototype never enters main's tree on merge. The component index table below is preserved as a port log — line references point to the now-removed `create-events-modal.jsx` and are useful only if the prototype is temporarily restored (see Recovery below).

**Screenshots** (retained): `doc/design/multi-events/01-current-single-modal.png`, `02-new-single-modal-with-toggle.png`, `03-timeinput-detail.png`. Kept alongside for future planners — useful visual reference for the single-event flow variant.

**Recovery**: if the prototype is ever needed again (re-port, design review), restore with `git show <pre-deletion-commit>:doc/design/multi-events/prototype/create-events-modal.jsx > /tmp/proto.jsx` against commit 5372c2d or the parent of the current frontend commit.

**Component index for `create-events-modal.jsx`** (port log — line references point to the now-removed file):

| Line | React function | Ported to |
| --- | --- | --- |
| 20 | `Calendar` | `EventCalendarStrip.vue` |
| 76 | `QuickPick` | `QuickPickChips.vue` |
| 185 | `TimeInput` | `TimeInput.vue` |
| 257 | `SpreadsheetGrid` | `BulkEventsStep2Review.vue` |
| 351 | `addDays` | inlined in `BulkEventsStep2Review.vue` |
| 357 | `detectConflicts` | inlined in `BulkEventsStep2Review.vue` |
| 376 | `buildName` | exported from `BulkEventsStep1Dates.vue` |
| 397 | `CreateEventsModal` | `CreateEventsDialog.vue` |
| 789 | `SingleOrDatesHeader` | inlined in `CreateEventsDialog.vue` header slot |
| 798 | `StepHeader` | inlined in `CreateEventsDialog.vue` header slot |

**Target Vue port (shipped)**: `frontend_app/pages/course/components/CreateEventsDialog.vue` (supersedes the old `CreateAttendanceEventDialog.vue`) + companion components under `frontend_app/pages/course/components/events/`.

## Current State

- [x] Slice 1 shipped (see `PLAN.feature-multi-event-1.md`)
- [x] All scope questions (Q1–Q9) resolved with user
- [x] Slice 2: bulk service + split-component modal shipped — *backend 2.1–2.6 + frontend 2.7–2.18 shipped 2026-04-22; user manual verification complete with feedback addressed*
- [ ] Slice 2 refactoring pass (DDD domain extraction, behavior-preserving)
- [x] Manual verification of both flows — *2026-04-22*
- [ ] Slice 3: retrospective → skill-file edits proposed
- [x] Cleanup: delete `doc/design/multi-events/prototype/` — *2026-04-22: amended into the frontend commit so the 1.2 MB prototype tree never enters main. Screenshots retained.*

## Key Findings

> **Snapshot at time of research** (pre-refactor). Line numbers and API paths below reflect the *original* singular-`event` route from before Slice 1. After Slice 1 the route namespace is `events`, POSTs wrap as `{ events: [...] }`, and the handler is larger. The logical structure (service / policy / repo / entity / representer) is unchanged.

Research summary:

**Existing single-event path** — what the bulk flow must mirror:

- **Route**: originally `POST /api/course/:course_id/event`; now plural `/events` in `backend_app/app/application/controllers/routes/course.rb`
- **Service**: `Tyto::Service::Events::CreateEvent` at `backend_app/app/application/services/events/create_event.rb` — `Dry::Operation` with steps: validate course id → verify course exists → authorize → validate input → persist → enrich with location
- **Policy**: `Tyto::Policy::Event#can_create?` — requires teaching staff (owner/instructor/staff) for the course
- **Repository**: `backend_app/app/infrastructure/database/repositories/events.rb` — exposes `create(entity)`. No existing bulk-insert helper
- **Entity**: `backend_app/app/domain/courses/entities/event.rb` — `id, course_id, location_id, name, start_at, end_at`
- **Representer**: `backend_app/app/presentation/representers/event.rb`
- **ORM + migration**: `backend_app/app/infrastructure/database/orm/event.rb` and `backend_app/db/migrations/007_event_create.rb`

**Events table schema** (post-Slice-1):

```text
id PK, course_id FK cascade, location_id FK cascade,
name (not null), start_at (not null), end_at (not null),
created_at, updated_at
CHECK (start_at <= end_at)   ← migration 011
```

**Frontend single-event UI** (current state):

- Dialog: `frontend_app/pages/course/components/CreateAttendanceEventDialog.vue`
- Parent: `frontend_app/pages/course/SingleCourse.vue` — posts via `api.post('/course/:id/events', { events: [form] })` then refreshes the event list
- Locations already fetched for the dropdown via `GET /api/course/:course_id/location`

**Testing convention**: Minitest spec-style. Reference: `backend_app/spec/application/services/events/create_event_spec.rb`.

**Gotchas to preserve / decide**:

1. **Authorization is per-course, not per-event.** One `can_create?` check at the start of the bulk service is sufficient.
2. **Enrichment.** Single-event response enriches with location coords. Bulk service should fetch all needed locations once (via `repo.find_ids(ids)`) rather than N times.
3. **No contract classes.** Validation is inline in `CreateEvent` private methods — mirror that style rather than introducing dry-validation.
4. **Representer already exists** — reuse `Representer::Event` per row or `Representer::EventsList` for the collection response.
5. **Transactional bulk persistence is required** for partial-failure safety (Q2: all-or-nothing). Slice 1's route handler loops `CreateEvent` non-transactionally; Slice 2's `CreateEvents` service replaces that with a single `DB.transaction` wrapping all inserts.

## Questions

> All resolved before coding Slice 2. Numbered for cross-reference.

- [x] ~~Q1. **Endpoint shape.** Add new `POST /api/course/:course_id/events` (plural) that accepts `{ events: [...] }`, or extend the existing singular `POST /.../event` to accept either an object or an array?~~ **Decision**: Rename the resource from singular `event` to plural `events` (matching REST convention), and unify under a single endpoint `POST /api/course/:course_id/events` that always takes `{ events: [...] }`. Single-event create becomes a 1-row array. Also rename `GET /event` → `GET /events` and `PUT /event/:id` → `PUT /events/:id` for consistency. **Confirmed 2026-04-21**: the Vue frontend is the only consumer of the backend API — no third-party clients to break. *(Shipped in Slice 1.)*
- [x] ~~Q2. **All-or-nothing semantics.** If one row fails validation or insert, should the entire batch be rejected (transaction rollback), or should valid rows still be created and the failed ones reported?~~ **Decision**: All-or-nothing with detailed error report. The bulk service validates every row up-front before persisting anything, and wraps persistence in a `DB.transaction` so any insert failure rolls back the whole batch. The failure response returns a per-row error map (row index → error message) so the frontend can highlight the specific offending rows in the review grid.
- [x] ~~Q3. **Unique `(start_at, end_at)` constraint.** The current DB constraint is cross-course and will cause collisions in bulk scenarios.~~ **Decision**: Drop the uniqueness constraint entirely — no replacement. Use cases like repeated workshop sessions legitimately need multiple events sharing the same `(start_at, end_at)` within a single course. Separately, tighten `start_at` and `end_at` to `NOT NULL` — null times don't make sense for attendance events. **Prerequisite**: audit the production database for any existing rows with null `start_at` or `end_at` before rolling out the `NOT NULL` migration; clean up or surface to the user for resolution before the migration runs. *(Shipped in Slice 1 as migrations 009 / 010 / 011.)*
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

**In scope**:

- New backend bulk-create service + route accepting an array of event payloads
- Spec coverage for happy path, auth failure, validation failure on a row, unknown location_id, and transactional rollback behavior
- Frontend two-step modal flow matching the reference design: toggle → step 1 (calendar strip + quick-pick + name-pattern + shared defaults) → step 2 (spreadsheet grid with add/remove/move/fill-down + same-location conflict highlight)
- Existing single-event path continues to work via the same modal (toggle unchecked)

**Out of scope** (deferrable):

- Editing multiple events in bulk (this branch is creation only)
- Recurrence rules stored server-side (RRULE etc.) — we just expand dates client-side
- Importing from CSV / copy-paste from a spreadsheet — the grid is hand-editable only
- Calendar-app integration (ICS export, Google Calendar sync)

**Backend changes**:

- New service `Tyto::Service::Events::CreateEvents` (plural) at `backend_app/app/application/services/events/create_events.rb`, mirroring `CreateEvent` structure
- Swap route `POST /events` to delegate to new bulk service (instead of Slice 1's loop)
- Repository helper `EventsRepository#create_many(entities)` per Q6 — wraps a `DB.transaction` and returns the persisted entities with IDs
- *(No uniqueness-constraint migration: dropped entirely in Slice 1 per Q3.)*

**Frontend changes**:

- Port the reference React modal to Vue 3 + Element Plus using existing components where possible (`el-dialog`, `el-date-picker`, `el-select`, `el-input`)
- Keep the existing single-event form as step "0" accessed via an unchecked "Create multiple at once" toggle
- Add a calendar-strip component for the month picker with existing-event dots, quick-pick chips, name-pattern preview, shared-defaults panel
- Add a spreadsheet-style review grid for step 2 with per-row name/date/location/start/end editing, fill-down buttons, move-up/move-down, remove, and same-location conflict warning
- On success close modal and refresh event list in `SingleCourse.vue`

## Tasks

> **Check tasks off as soon as each one (or each grouped set) is finished** — do not batch multiple completions before updating the plan.
>
> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Slice 2 — Bulk creation feature

#### Backend (tests first)

- [x] 2.1a Failing spec: `CreateEvents#call` returns `Success` with array of enriched events for a valid 3-row payload — *shipped 2026-04-22*
- [x] 2.1b Failing spec: rejects with `Failure(forbidden)` when requestor is a student (not teaching staff) — *shipped 2026-04-22*
- [x] 2.1c Failing spec: rejects with `Failure(bad_request)` when any row has missing name / invalid times / unknown `location_id`; no rows persisted (transaction rollback) — *shipped 2026-04-22: three separate assertions (missing name, end<start, bad FK); all verify 0 rows persisted*
- [x] 2.1d Failing spec: rejects with `Failure(not_found)` when course does not exist — *shipped 2026-04-22*
- [x] 2.1e Failing spec: batches larger than 100 rows are rejected with `Failure(bad_request)` and message `Batch too large: 100 events max, got N` (per Q6). Happy-path upper bound: exactly 100 rows succeeds — *shipped 2026-04-22*
- [x] 2.2 Implement `Tyto::Service::Events::CreateEvents` (validate course → authorize once → validate all rows → enforce ≤100 cap → persist transactionally → enrich with locations → return collection) — *shipped 2026-04-22: `backend_app/app/application/services/events/create_events.rb`*
- [x] 2.3 Add `EventsRepository#create_many(entities)` per Q6 — `DB.transaction { entities.map { |e| create(e) } }`. Kept separate from `create(entity)` to preserve single-method return types and make the transaction boundary explicit at the callsite (see audit 2026-04-21 for rationale against collapsing) — *shipped 2026-04-22*
- [x] 2.4 Swap `POST /events` route to delegate to `CreateEvents` (replacing Slice 1's loop). Keep the `{ success, message: 'Events created', events_info: [...] }` response shape for frontend compatibility — *shipped 2026-04-22: added two route-level regression specs (3-row happy path + bulk rollback on bad row) — the rollback spec was red against the old loop, green against `CreateEvents`*
- [x] 2.5 *(removed as task)* — was "migration to change unique constraint"; obsoleted by Q3 (drop entirely) and replaced by Slice 1 migrations 009 + 011 (drop-unique + CHECK start≤end via 1.6a / 1.6f). Left in the list (as done) for numbering stability.
- [x] 2.6 Run full spec suite and fix any regressions — *2026-04-22: 885 runs, 0 failures, 1 skip; line coverage 97.82%*

#### Frontend

- [x] 2.7 Create `CreateEventsDialog.vue` wrapper — *shipped 2026-04-22*
- [x] 2.8 `events/TimeInput.vue` — *shipped 2026-04-22*
- [x] 2.9 `events/SingleEventForm.vue` — *shipped 2026-04-22*
- [x] 2.10 `events/EventCalendarStrip.vue` — *shipped 2026-04-22 (anchored on course.start_at; past cells greyed-but-clickable so retroactive events work)*
- [x] 2.11 `events/QuickPickChips.vue` — *shipped 2026-04-22 (chip `weeks` removed; parent enumerates across course.start_at → course.end_at)*
- [x] 2.12 `events/BulkEventsStep1Dates.vue` — *shipped 2026-04-22*
- [x] 2.13 `events/BulkEventsStep2Review.vue` — *shipped 2026-04-22 (reorder arrows dropped + summary chip dropped per UX review)*
- [x] 2.14 Wire wrapper submit — *shipped 2026-04-22*
- [x] 2.15a Loading state — *shipped 2026-04-22: Create button disabled with `:loading` during POST; el-dialog `close-on-press-escape` / `close-on-click-modal` / `show-close` all bound to `!submitting`*
- [x] 2.15b Error handling — *shipped 2026-04-22: non-row errors surface via `ElMessage` toast using `error.response.data.details` from the backend's `ApiResult#to_json`; row-level error-map hook exists client-side but backend currently short-circuits at first failure (follow-up tracked in `doc/future-work.md` "Per-row error map in bulk-event responses")*

#### Verification

- [x] 2.16 Manual verification in browser — *2026-04-22: user walked the flows in their own browser + Claude smoke-tested in a second Chrome tab. Feedback captured in "Manual test feedback" section below; all reported issues addressed before wrap-up*
- [x] 2.17 Update `doc/future-work.md` for Q3/Q5/Q6 follow-ups — *2026-04-22: added "Per-row error map in bulk-event responses" entry (backend gap surfaced during frontend wiring). Q3 / Q5 / Q6 themselves are final decisions with no deferred work*
- [x] 2.18 Add timezone-support entry to `doc/future-work.md` — *shipped 2026-04-22 under "Timezone Support" section*

#### Refactoring pass — DDD domain extraction (runs only after 2.1–2.17 are green)

> **Purpose**: Once tests pass and both flows work end-to-end, step back and look at the newly-landed code (`CreateEvents`, `create_many`, route handler, representers, the ported Vue components) for domain concepts that deserve to be first-class. **Functionality freeze**: this pass is behavior-preserving — tests stay green, no new features, no scope creep. Consult the `ray-ddd` skill for patterns.
>
> **Candidates to evaluate** (not a checklist to implement — a list to consider and reject where appropriate):
>
> - **`BulkEventRequest` value object** in `Domain::Courses::Values` — encapsulate the per-row validation shape (name / location_id / start_at / end_at) so `CreateEvent` and `CreateEvents` stop duplicating `validate_name` / `validate_location_id` / `validate_times` privately. Would pull the validation into the domain layer where it arguably belongs.
> - **`EventSeries` / `EventBatch` concept** — even though Q4 decided name-patterns aren't persisted, a transient `EventBatch` aggregate may clarify the bulk-creation flow and give `CreateEvents` a proper domain object to orchestrate rather than a raw array-of-hashes.
> - **Enriched-event representation**. Both `CreateEvent` and `CreateEvents` build ad-hoc `OpenStruct`s with `longitude` / `latitude` tacked on. This is a presentation concern leaking into services. Consider a small `EventWithLocation` read-model struct (domain or presentation layer — decide during the pass) so the representer has a typed input instead of ducking on an OpenStruct.
> - **Transaction boundary ownership**. `EventsRepository#create_many` wraps a transaction. Is that the right layer? DDD arguments for keeping it in the repository (infrastructure concern) vs. lifting to the service (use-case concern) — pick one and justify in a commit message.
> - **Shared `validate_times` helper**. Duplicated between `CreateEvent` / `CreateEvents` / `UpdateEvent`. Extract into `Domain::Courses::Values::EventTimeRange.from_strings(start_at, end_at)` returning a `Result`, so services call one helper instead of each carrying its own `parse_time`.
>
> **Non-goals for this refactoring pass**: no new DB migrations, no API-contract changes, no new routes, no Vue component restructuring beyond what the extraction forces.
>
> **Exit criteria**: full spec suite + manual verification (2.16) still pass; commit log shows each extraction as its own behavior-preserving commit so review can follow along.
>
> **Known offenses to target** (rubocop, 2026-04-22 snapshot after Slice 2 backend landed — use DDD extractions above, not mechanical splits):
>
> - `backend_app/app/application/services/events/create_events.rb:14` — `Metrics/ClassLength 124/100`. Expect to drop below threshold once `BulkEventRequest` value object pulls `validate_name` / `validate_location_id` / `validate_times` out (candidate 1), and `EventWithLocation` DTO replaces the inline `OpenStruct` enrichment (candidate 3).
> - `backend_app/app/application/services/events/create_events.rb:83` (`validate_row`) — `Metrics/AbcSize 17.52/17`, `Metrics/MethodLength 13/10`. Disappears when the row is a value object that validates itself (candidate 1).
> - `backend_app/app/application/services/events/create_events.rb:125` (`persist_events`) — `Metrics/MethodLength 15/10`. Shrinks to ~5 lines by giving `Domain::Courses::Entities::Event` a `.from_validated_row(row)` factory so the service stops hand-constructing entities.
> - `backend_app/app/application/services/events/create_events.rb:144` (`enrich_with_locations`) — `Metrics/AbcSize 18.81/17`, `Metrics/MethodLength 17/10`. Disappears with the `EventWithLocation` DTO (candidate 3) — `events.map { |e| EventWithLocation.from(event: e, location: lookup[e.location_id]) }`.
> - Sibling file `backend_app/app/application/services/events/create_event.rb` trips the same-shape cops (4 offenses, pre-existing). If `BulkEventRequest` and `EventWithLocation` are shared, this file should be refactored in lockstep so both services benefit and the pre-existing offenses also go away.
>
> **Convention gap to consider alongside the refactor**: the project has no `.rubocop.yml`, so "acceptable code" is defined by precedent only. If the refactor still leaves some methods above rubocop defaults but within the team's actual taste, consider landing a minimal `.rubocop.yml` (explicit Max values for `MethodLength`, `ClassLength`, `AbcSize`) so the cops document our standard rather than rubocop's. Decide during 2.R.1 whether to include this in the pass or defer as a follow-up chore.

- [x] 2.R.0 Re-read `/ray-ddd` skill + `backend_app/app/application/policies/CLAUDE.md` — *2026-04-22*
- [x] 2.R.1 Survey landed code + pick extractions — *2026-04-22*. **Chosen (2 of 5)**:
  - **Candidate 5 → `Value::TimeRange.parse(start_raw, end_raw)`** — extract the shared parse_time + validate end > start logic as a class factory on the existing `TimeRange` VO. Directly deduplicates `parse_time` + `validate_times` across `CreateEvent`, `CreateEvents`, and partially `UpdateEvent` (UpdateEvent has fallback-to-existing semantics so it can only reuse the helper, not the whole parse method). Keeps domain layer free of dry-monads — uses `ArgumentError` with specific messages that services catch + translate to `Failure(bad_request(...))`.
  - **Candidate 3 → reuse `Response::EventDetails` in create/update paths** — the existing `Response::EventDetails` DTO (used by `ListEvents` / `FindActiveEvents`) already has the full 10-field shape including `course_name` and `location_name`. `CreateEvent`, `CreateEvents`, and `UpdateEvent` currently build ad-hoc `OpenStruct`s with 8 fields (missing the two name fields, so the representer uses `respond_to?` guards). Switch all three services to populate the full DTO (course verified in the service already; location lookup already happens). Representer drops `respond_to?` for `course_name`/`location_name`. Creates one DTO shape across all event-returning services.
- [x] 2.R.1 **Rejected candidates + reasons**:
  - **Candidate 1 (full `BulkEventRequest` VO)** — the row is a 4-field hash. Wrapping it in a VO moves code but doesn't simplify; the 80% dedup win comes from `TimeRange.parse` alone. Extracting name/location_id validation into the VO (4 lines each) would add indirection without removing duplication.
  - **Candidate 2 (`EventSeries` / `EventBatch` aggregate)** — obsoleted by Q4 (name patterns are client-side formatting, never persisted). No domain concept to promote.
  - **Candidate 4 (transaction ownership: repo vs. service)** — current placement (`EventsRepository#create_many` wraps the transaction) is reasonable and documented in the Slice 2 plan's 2.3 audit. No observable pain; defer the stylistic debate.
- [x] 2.R.2 Implement — *2026-04-22: TimeRange.parse + parse_time shipped with 12 new specs (`backend_app/spec/domain/shared/values/time_range_spec.rb`). CreateEvent, CreateEvents, UpdateEvent all use TimeRange.parse (create services) or TimeRange.parse_time (update, due to fallback semantics). OpenStruct replaced by Response::EventDetails in all three. Representer dropped respond_to? guards for course_name / location_name (kept for user_attendance_status — that's still variant between EventDetails and ActiveEventDetails). Full spec suite: 897 runs, 0 failures, coverage 97.82% (both up from pre-refactor baseline 885 / 97.82%). Rubocop offense count on targeted services: create_events.rb 6→3, create_event.rb 4→2 (remaining offenses are at-threshold line counts on validate_input / validate_row, won't fix without bigger structural changes).*
- [ ] 2.R.3 Re-run 2.16 verification to confirm no regression
- [ ] 2.R.4 Update this plan's "Completed" section

### Slice 3 — Retrospective: feed lessons back into `/ray-branch-plan` skill

> After Slices 1 and 2 ship, reflect on what this plan did differently from a "default" branch plan and capture durable lessons for the skill at `~/.claude/skills/ray-branch-plan/SKILL.md`.

- [ ] 3.1 Re-read both plan files (this one + `PLAN.feature-multi-event-1.md`) and note what worked / what didn't (e.g. accuracy of slice scoping, usefulness of the Questions list, whether the two-slice split paid off, whether the mid-branch plan-file split was worth the ceremony)
- [ ] 3.2 Draft a short "Lessons" section below (in this file) with concrete, transferable guidance
- [ ] 3.3 Open `~/.claude/skills/ray-branch-plan/SKILL.md`, identify the right home for each lesson (template, "Planning and execution guidelines", or a new section), and propose edits. Show the diff to the user before committing to the skill file
- [ ] 3.4 Apply approved edits to the skill; commit in the `~/.claude/` repo (separate from this feature branch)

### Final pre-merge check

- [x] 4.1 **Branch-level audit passed — 2026-04-21.** Scope tightened from original "resolve any reported CVEs" to "resolve any CVEs the *branch* introduces" — a whole-codebase audit is a separate concern that doesn't belong in a feature PR's merge gate. `bundle exec rake audit` initially flagged 18 CVEs; only one (`thor 1.3.1`, low) was attributable to this branch (pulled in transitively by `bundler-audit` which Slice 1 added). Bumped to `thor 1.5.0`; lockfile diff vs `origin/main` now shows only the thor line changed. Remaining 17 CVEs (`puma`, `rack`, `rexml`) are pre-existing on `main` and are tracked as a follow-up "CVE sweep" entry in `doc/future-work.md` under Security.

**Seed observations** (to expand during Slice 3):

- **Consider an initial refactoring slice before feature work.** When a new feature will break or awkwardly extend an existing structure (e.g. renaming routes, widening a payload contract, loosening a DB constraint), plan a dedicated refactoring slice *first* — behavior-preserving, test-covered — so the feature slice only adds new behavior on top of a clean foundation. This keeps each PR reviewable and limits the blast radius of any single change.
- **Numbered slices with prefixed task IDs (1.1a, 2.3, …) scale better than a flat list** once a branch plan exceeds ~10 tasks or crosses slice boundaries.
- **Capture scope questions explicitly and resolve them before coding.** The Q1–Q9 list surfaced endpoint-shape, DB-constraint, and timezone decisions up-front that would have caused rework if discovered mid-implementation.
- **Link to any external reference designs with file paths and a summary of what to port** — the reference React prototype at `doc/design/multi-events/prototype/create-events-modal.jsx` was far more actionable once named + summarized in the plan than it would have been as a raw file. Lesson refinement during Slice 1: **check the reference into the repo** (i.e., out of `tmp/` and into `doc/`) and **pin individual tasks at specific functions/line numbers in the reference** — implicit "see the reference" lines rot the moment the prototype file is moved or a session clears. A component-index table in the Reference Design section pays dividends during Slice 2 implementation.
- **Audit the deploy / migration mechanism before planning any schema change.** We discovered mid-planning that this app had no Heroku release phase — migrations were manual and a dev could deploy code that referenced a schema that hadn't been applied yet. Plans touching the DB should start by verifying `Procfile` (or equivalent) runs migrations automatically, and add that wiring if it's missing.
- **Split the plan file at slice boundaries once a slice seals.** On 2026-04-22 we split the unified 40k-char plan into `PLAN.feature-multi-event-1.md` (shipped, reference only) and `PLAN.feature-multi-event-2.md` (active). The shipped file preserves audit evidence and deploy history; the active file stands alone for the next slice. Worth doing when the shipped slice's historical detail starts crowding the active slice's actionable tasks.

## Manual test feedback (Slice 2 frontend)

> Captured during 2.16 manual verification, 2026-04-22. Each item is a user observation to triage — some will become small follow-up tweaks before PR, others may be deferred.

- [ ] **Toggle → bulk transition feels like a new modal**, not a continuation. When user checks "Create multiple at once", the dialog instantly jumps from 560px → 820px and the whole body swaps content. Feels jarring / as if context was lost. **Decision (user, 2026-04-22)**: keep the single-modal → bulk toggle path as designed; fix the abruptness with a smooth transition. Rejected alternative: collapsing the single-event flow into "bulk with 1 row" (would remove the toggle entirely but loses the simplicity of the current single-event form for the common case). **Fix**: animate the width transition (CSS `transition: width 220ms ease` on `.el-dialog` — the prototype has this via `transition: max-width 220ms ease` on line 511 of `create-events-modal.jsx`), and consider fading the body content cross-fade style so the container reads as "same modal expanding", not "new modal replacing". Note that el-dialog sets its width via inline style, so the transition needs to land on `.el-dialog` itself — may need `:deep()` from the wrapper's scoped style or a global override.
- [x] **Existing-event dot is redundant with the light-orange cell background** — deferred on reflection. Pale-cream fill (`#fdf6ec`) on white has very low contrast for users with red/green colorblindness; the dot functions as a redundant non-color signal, so keep it. **Decision (user, 2026-04-22)**: keep the dot as-is for now. Revisit if/when we do an accessibility pass on the calendar palette.
- [ ] **Step-2 summary chip is redundant with the grid below.** The `.summary` block in `BulkEventsStep2Review.vue` ("3 dates · Pattern: Week 08 · Online (Zoom) · 09:00–10:00") duplicates info that's already visible in every row of the grid right below it. **Decision (user, 2026-04-22)**: remove. **Fix**: delete the `.summary` block from the template + CSS in `BulkEventsStep2Review.vue`, drop the `summary` prop from both the grid component's `props` and the wrapper's (`CreateEventsDialog.vue`) prop-passing and `reviewSummary` computed. Reclaim the vertical space for the grid.
- [ ] **Quick-pick chips project the wrong horizon** — the prototype hardcodes `weeks: 8` (line 78-82 of `create-events-modal.jsx`, copied to `QuickPickChips.vue`), so "Every Mon" fills 8 Mondays from today regardless of whether the course runs 4 weeks or 16. This is a *correctness* issue, not just aesthetic: for a semester course, "Every Mon" should fill every Monday in the semester. **Decision (user, 2026-04-22)**: fix by projecting across the course's actual date range. **Fix**: thread `course.start_at` / `course.end_at` from `SingleCourse.vue` down through `CreateEventsDialog.vue` into `BulkEventsStep1Dates.vue` into `QuickPickChips.vue`. Change the chip handler to enumerate every matching weekday between course-start and course-end instead of looping `weeks` × `dows`. If the course is already partially past (end_at is in the past? or today > start_at?), clamp the start to `max(today, course.start_at)` so the chip doesn't project backward in time. Also drop `weeks: 8` from the chip data; it's derived from the range now. Depends on `course.start_at` / `course.end_at` being passed as props — they're already fetched in `SingleCourse.vue` for the course card, so no new API.
- [ ] **Name pattern format options** — decision 2026-04-22: **keep all 4 (`pad2 / nopad / date-short / none`)** as currently implemented. No change needed.
- [ ] **Calendar month count should default to course span, keep + Add month escape hatch** — currently the calendar defaults to 2 months of tiles regardless of the course's term. **Decision (user, 2026-04-22)**: default to showing the full range from `max(today, course.start_at)` → `course.end_at` (so 1-month course shows 1 tile, semester shows 4–5 tiles). Keep the `+ Add month` button so instructors can tack on a date after the scheduled term (makeup session, final review after exam week, etc.). Remove or hide the `− Remove month` button since the default now corresponds to the course itself — no reason to shrink below the course span. **Fix**: same course-dates prop threading as item above; compute `monthCount` in the wrapper from `(course.end_at - max(today, course.start_at)) in months, +1`, and pass as initial value to `EventCalendarStrip.vue`. Strip keeps `+ Add month`, loses `− Remove`.
- [ ] **Weekend shading on calendar** — decision 2026-04-22: **keep** the grey weekend cells. They provide a useful visual of the week's structure (Mon–Fri clustering, Sat/Sun flanks), not a nudge against weekend events.
- [ ] **Redundant step-1 hint text should live behind a `?` tooltip.** Currently `BulkEventsStep1Dates.vue` has ambient demo-copy: "You can edit any individual name on the next step." and "These apply to every date. You can override individual events on the next step." Both are true but chatty — first-time-user training that returning users read past. **Decision (user, 2026-04-22)**: move to `?` tooltips next to the relevant section labels ("Name pattern" and "Shared details"). **Fix**: replace the inline `<div class="panel__hint">…</div>` blocks with an `el-tooltip` wrapping a small `?` icon (or use Element Plus's `QuestionFilled` from `@element-plus/icons-vue`). Keep the exact wording inside the tooltip — it's still useful on hover.
- [x] **Bug: calendar first tile always "this month", ignoring course start** — reported & fixed 2026-04-22. The strip was anchored on `new Date()` (today's month), so a course running Jan–May viewed in April only showed Apr–May, losing semester context. **Fix**: `EventCalendarStrip.vue` now takes a `courseStartAt` prop and computes its `anchor` at course.start_at's month regardless of today. Wrapper's `computeMonthSpan` switched to span anchor → end.
- [x] **`buildName` forced a space between prefix and number** — `buildName` in `BulkEventsStep1Dates.vue` always output `"${prefix} ${number}"` (forced space), so typing "Week" produced "Week 01" regardless of user intent. User preference 2026-04-22: respect what the user typed — no forced spacing. **Fix**: `pad2` / `nopad` / `none` now concat directly (`${p}${pad2(n)}`), no `.trim()`, no forced space. If the user wants a gap they type "Week " with trailing space. `date-short` still normalizes the separator (" — ") because the em-dash is an intentional label/date divider, not user-provided spacing. Preview and actual row names now match exactly.
- [x] **Name-pattern `startNum` default was `8` (prototype cargo)** — the React prototype showed "Week 8" as a demo. Changed default to `'1'` (start-of-semester, most common case). Rejected alternatives: `existing_events.length + 1` (brittle if events deleted), `current_week_of_course + 1` (assumes week numbering aligns with course weeks).
- [x] **Allow retroactive event creation on past dates** — follow-up decision 2026-04-22. The instructor may have forgotten to set up Week 1 events and wants to create them after the fact to record attendance. **Fix**: (a) removed the `isPast` early-return in `EventCalendarStrip.toggle()` so past cells are clickable like future ones; (b) kept the greyer text color on unselected past cells as a subtle visual cue that the date is in the past, but stripped `cursor: not-allowed` so the affordance reads as clickable; selected past cells use the same orange fill as future selected cells (no special styling); (c) `applyQuickPick` in `BulkEventsStep1Dates.vue` now uses `course.start_at` as the range's `from` (not `max(today, start)`), so "Every Mon" over a mid-semester course picks up the past Mondays too — user can unselect the ones they don't want. Backend `CreateEvents` already accepts past timestamps (no "must be future" validation), so no server-side change needed.
- [ ] **Row reorder arrows in the review grid serve no purpose.** Events are always rendered in the attendance events list in date order (server `ORDER BY start_at`). So moving row 5 above row 3 doesn't change anything about how they appear after creation — only the in-modal row number (#) shifts, which is cosmetic. The one edge case is name-pattern numbering (`Week 08`, `Week 09`, …) which uses row index — but in step 1 dates are pre-sorted before names are assigned, and step 2 lets the user edit any name directly, so reordering is a clunky way to change names. **Decision (user, 2026-04-22)**: remove only the reorder arrows. Keep per-row edit, delete, and add-new-row — the latter is genuinely useful for tacking on a one-off date the user forgot in step 1 without having to cancel and restart. **Fix**: drop the `↑` / `↓` buttons from `BulkEventsStep2Review.vue` (remove the two `<button title="Move up/down">` elements + the `move()` method). Keep `×` (remove) and the `+ Add event` button. Leave the row number (#) column as a passive index.

## Completed

(none yet)

---

Last updated: 2026-04-22
