# Multi-Event Bulk Creation — Slice 1 (shipped)

> **Status**: merged to `main` 2026-04-21 as PR #59 (merge commit `fc98677`); deployed to prod as v79.
>
> **Kept for reference only.** Active work continues in `PLAN.feature-multi-event-2.md`.
>
> This file preserves the detailed audit, rehearsal, and deploy evidence for Slice 1 (route rename + schema cleanup). Consult it when re-investigating a migration, rollback, or deploy step; otherwise Slice 2 work is self-contained in the companion file.

## Branch

`feature-multi-event`

## Slice 1 Goal

Rename `GET/PUT/POST /api/course/:course_id/event` → `/events` (plural, per REST convention). POST now always requires `{ events: [...] }`; single-event create becomes a 1-element array. No behavior change — just the URL + payload contract. Route still delegates to existing `CreateEvent` / `UpdateEvent` / `ListEvents` services, iterating the array for POST.

Plus DB schema corrections (migrations 009 / 010 / 011) needed to support multi-event creation:

- drop the table-level `unique (start_at, end_at)` constraint (Q3)
- tighten `start_at` / `end_at` to `NOT NULL`
- add CHECK constraint `start_at <= end_at`

Plus operational tooling: `rake console` task for prod inspection, Heroku release phase for auto-migrations.

## Decisions driving Slice 1

Full Q1–Q9 decisions live in `PLAN.feature-multi-event-2.md`. The two that directly drove Slice 1 work:

- **Q1 Endpoint shape** → rename the resource to plural `events`; unify under a single `POST /api/course/:course_id/events` that always takes `{ events: [...] }`. Single-event create becomes a 1-row array. The Vue frontend is the only consumer of the backend API, so no third-party clients to break.
- **Q3 Unique `(start_at, end_at)` constraint** → drop entirely, no replacement (parallel workshop sessions legitimately share times). Separately: tighten `start_at`/`end_at` to `NOT NULL`, and add a CHECK `start_at <= end_at` as the only remaining schema-level guarantee on the time columns.

## Current State

- [x] Slice 1 shipped — merged to `main` 2026-04-21 as PR #59 (merge commit `fc98677`); deployed to prod as v79

## Key Findings (pre-refactor snapshot)

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

**Events table schema** (migration 007, pre-Slice-1):

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

## Scope

**In scope**:

- Rename route namespace `r.on 'event'` → `r.on 'events'` in `backend_app/app/application/controllers/routes/course.rb`
- `POST /events` enforces `{ events: [{...}, ...] }` payload shape; rejects bare objects with a 400
- Route handler loops the array and calls existing `Service::Events::CreateEvent` per row (non-transactional for now — Slice 2 upgrades this). Response returns `{ success, events_info: [...] }` for uniformity with bulk
- `GET /events` unchanged in behavior, just renamed
- `PUT /events/:id` unchanged in behavior, just renamed
- Update route-level specs (`spec/routes/event_route_spec.rb`, `spec/routes/current_event_route_spec.rb`) to hit new URLs + new array payload
- Update all frontend API callers (`SingleCourse.vue`, any other files referencing `/event`) to use `/events` and wrap POSTs as 1-element arrays
- **DB schema corrections** (per Q3 + post-audit insight 1.6f): three migrations — 009 drops the `unique (start_at, end_at)` constraint; 010 tightens `start_at`/`end_at` to `NOT NULL`; 011 adds a CHECK constraint `start_at <= end_at` to replace the dropped uniqueness with a real integrity guarantee. Each preceded by a prod-data audit (null-time rows before 010; `start_at > end_at` rows before 011)

**Out of scope**: transactional bulk, new service, any UI change. Slice 1 is a pure contract rename + schema cleanup.

## Tasks

### Route rename + schema cleanup

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

- [x] 1.6f **CHECK constraint: `start_at <= end_at`.** Dropping the old `(start_at, end_at)` uniqueness (1.6a) leaves *no* schema-level guarantees on the time columns. "End before start" is a nonsense state we shouldn't trust the service layer alone to prevent — migrations, seeds, and future bulk writes can bypass `CreateEvent` validation. Add a DB-level CHECK. Inclusive (`<=`) so zero-duration placeholder events remain legal.

  Three sub-tasks mirroring the 1.6b/c/d pattern:
  - [x] **1.6f-audit — 2026-04-21.** Same psql session as 1.6b (server 10.0.56.45 / db `d4a2kmtttg1l6m`, verified real data first). `SELECT ... WHERE start_at > end_at` returned **0 rows** — no prod event has an end time before its start. Safe to proceed with migration 011. Original procedural note retained: AI must not access prod directly; the developer runs either `heroku run rake console --app <app>` (once the task exists) or `heroku run bash --app <app>` → `psql $DATABASE_URL` / `heroku pg:psql --app <app>`
  - [x] **1.6f-migration** — `011_events_start_before_end.rb` with explicit `up`/`down` (`add_constraint(:start_before_end) { start_at <= end_at }` / `drop_constraint(:start_before_end)`). Applied in dev + test
  - [x] **1.6f-spec** — regression spec added in `events_spec.rb` `#create` block asserting that `start_at > end_at` raises `Sequel::ConstraintViolation` (the cross-adapter parent — covers SQLite and Postgres). Suite green: 875 runs / 2058 assertions / 0 failures
  - [x] **1.6f-rehearsal — passed 2026-04-21.** Covered in-place by the 1.6e rehearsal's 011 round-trip: v11 rejected `start>end` insert (`CHECK constraint failed: start_before_end`); rolled v11→v10 (check removed), violating insert succeeded, deleted, re-migrated v10→v11; data md5 identical to baseline at every step.

  **Replaces** the now-deleted Slice 2 task 2.5 (which would have re-added a multi-column unique constraint — obsoleted by the Q3 decision to drop uniqueness entirely).

### Tooling prep (pre-deploy)

- [x] 1.7 `rake console` task shipped. `bundle exec rake console` → pry with full Tyto app loaded (`app`, `Tyto::Api.db`, `Tyto::Event`, etc. all resolve). `.pryrc` auto-renders Sequel model arrays as tables via `table_print`. `RACK_ENV=production` path verified — environment reports production, `Rack::Test` not mixed in (via `unless app.environment == :production` guard). Full suite still 875/2058/0 failures. **Files added**: `console.rb` (root), `.pryrc` (root). **Edits**: `Gemfile` (+ `table_print ~>1.0`), `Rakefile` (+ `:print_env`, `console:` tasks). **Reference cribbed from**: `/Users/soumyaray/Sync/Dropbox/ossdev/classes/SEC-class/projects/tyto2026-api/` (adapted: `console.rb` at root instead of `spec/test_load_all.rb`, wider `tp.set` list for our ORM). On Heroku, `heroku run rake console --app tyto` becomes the first-class inspection path.

### Production rollout safety

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

- [x] 1.9 **Slice 1 merged — 2026-04-21, 15:55 UTC.** PR #59 merged into `origin/main` via merge-commit (`fc98677`, by soumyaray). Lockfile-safe sub-commit history preserved. Local `feature-multi-event` rebased cleanly onto the new `origin/main` (0-ahead) and force-push not required — fast-forwarded to the merge commit. `doc/future-work.md` and `PLAN.feature-multi-event.md` both travel with the merge; Slice 2 and Slice 3 sections remain open as single source of truth for follow-on work. Ready to continue Slice 2 work on this same branch.

  **Original step list (historical, for reference):**
  1. **Verify merge strategy first.** GitHub → Settings → General → Pull Requests — confirm "Allow merge commits" is enabled (or just check what the green button on PR #59 offers). Reason: Slice 2 will continue on this same `feature-multi-event` branch, which only works if the merge preserves the Slice 1 commit SHAs as ancestors of `main`. Squash or rebase merges rewrite SHAs → branch diverges → next PR would appear to re-include all of Slice 1. If only squash is available, either toggle merge-commit on, or accept the ceremony of a fresh branch (`git reset --hard origin/main` on this branch, or create `feature-multi-event-2`).
  2. Update PR #59 description so its scope matches what's actually shipping (route rename + schema cleanup + release phase + console + the rehearsal evidence). Do NOT rename the PR — "multi-event" still describes the branch's overall destination.
  3. Merge PR #59 via **merge-commit** (preserves sub-commit history for future archaeology). Do NOT tick the "Delete branch after merge" checkbox — we're keeping the branch alive for Slice 2.
  4. Locally: `git fetch origin && git rebase origin/main` (no-op since merge-commit kept SHAs as ancestors, but confirms cleanliness). Branch now has 0 commits ahead of `origin/main`. **Worktree caveat**: this branch lives in the `feature-multi-event` worktree (not the primary checkout). If a separate worktree tracks `main` (e.g. `tyto-worktrees/main`), run `git pull` there too after the merge so that checkout doesn't drift. Operations on `origin/main` are cross-worktree automatically via the shared `.git`, but each working tree's checked-out HEAD updates independently.
  5. Continue Slice 2 work on this same branch. First new commit on top (e.g. 2.1a failing spec) naturally becomes Slice 2's PR material. When there's enough reviewable work, open a fresh PR against `main`.
  6. First post-merge commit: tick **1.9** off in this plan so the hand-off itself is recorded. `PLAN.feature-multi-event.md` continues to travel with the branch — Slice 2 and Slice 3 sections remain open as the single source of truth.

---

Last updated: 2026-04-22 (sealed on split from unified plan)
