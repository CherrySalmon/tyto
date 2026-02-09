# Branch Plan: Enriched Event Responses

> **Branch**: `ray/refactor-event-responses`
> **Parent plan**: `CLAUDE.refactor-frontend-ddd.md` → Slice 5
> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this branch.

## Goal

Enrich event API responses with `course_name`, `location_name`, and `user_attendance_status` so the frontend can display event cards without making N+1 HTTP requests per event.

## Problem

Both `AttendanceTrack.vue` and `AllCourse.vue` fetch active events from `/api/current_event/`, then for **each event** make 3 additional HTTP calls:

1. `GET /course/:id` → extract `course_name`
2. `GET /course/:id/location/:id` → extract `location_name`
3. `GET /course/:id/attendance` → filter client-side for `isAttendanceExisted`

For N events this produces 3N+1 HTTP requests. This branch reduces it to **1 request** by embedding all three fields in the event response.

## Scope

**Two endpoints** serve event lists and need enrichment:

| Endpoint | Service | Route file | Used by |
| -------- | ------- | ---------- | ------- |
| `GET /api/current_event/` | `FindActiveEvents` | `current_event.rb` | `AttendanceTrack.vue`, `AllCourse.vue` |
| `GET /api/course/:id/event/` | `ListEvents` | `course.rb` (line 198) | `SingleCourse.vue` (event management) |

**New fields** added to every event object in the response:

| Field | Type | Source | Notes |
| ----- | ---- | ------ | ----- |
| `course_name` | `string` | Course record | Already available via `course_id` foreign key |
| `location_name` | `string` | Location record | Currently fetched N+1; will batch |
| `user_attendance_status` | `boolean` | Attendance records | `FindActiveEvents` only: `true` if requesting user has an attendance record for this event; `false` otherwise. Omitted from `ListEvents` (requestor-agnostic management endpoint). |

**Existing fields** kept as-is: `id`, `course_id`, `location_id`, `name`, `start_at`, `end_at`, `longitude`, `latitude`.

## Architecture Decisions

### 1. Enrichment lives in the service layer, not the repository

The repository returns pure domain entities (`Entity::Event`). Enrichment combines data from multiple repositories (events + locations + courses + attendances) — this is orchestration, which belongs in the service.

### 2. Batch lookups replace N+1 queries

Instead of calling `locations_repo.find_id(id)` per event, batch all location IDs and course IDs into single queries:

```ruby
location_ids = events.map(&:location_id).uniq
locations_index = locations_repo.find_ids(location_ids)  # new repo method → {id => entity}

course_ids = events.map(&:course_id).uniq
courses_index = courses_repo.find_ids(course_ids)        # new repo method → {id => entity}
```

For attendance status (current_event only — requestor-scoped):

```ruby
event_ids = events.map(&:id)
attended_event_ids = attendances_repo.find_attended_event_ids(account_id, event_ids)  # new repo method → Set<event_id>
```

### 3. OpenStruct enrichment pattern (kept from existing code)

Both services already build `OpenStruct` wrappers for enrichment (adding `longitude`/`latitude`). We extend this pattern with the new fields. The `Event` representer already uses `respond_to?` guards, so adding new properties is safe.

### 4. `user_attendance_status` only on requestor-aware endpoints

- `FindActiveEvents` is already requestor-aware (scopes events to the user's enrolled courses) → adding `user_attendance_status` (boolean) is consistent.
- `ListEvents` uses `requestor` only for **authorization** (teaching staff gate) — the response data is requestor-agnostic (any staff member sees the same events). We **omit** `user_attendance_status` entirely to preserve this boundary. The representer's `respond_to?` guards handle this naturally: no field on the OpenStruct → no field in the JSON.

### 5. No domain entity changes

`Entity::Event` stays minimal (DDD boundary). Enriched data is a presentation concern composed by the service. No new domain entities or value objects needed — this is simpler than Slice 4.

---

## Phases

### Phase 1: Backend — New repository methods + tests

Add batch lookup methods to eliminate N+1 queries.

**Tasks**:

- [ ] **5.1a** Add `Repository::Locations#find_ids(ids)` method
  - Input: `Array<Integer>` of location IDs
  - Output: `Hash{Integer => Entity::Location}` (id → entity)
  - Implementation: single `WHERE id IN (...)` query
  - Test: `spec/infrastructure/database/repositories/locations_spec.rb`
    - Returns hash keyed by ID
    - Handles empty array (returns `{}`)
    - Handles IDs not found (omits them)

- [ ] **5.1b** Add `Repository::Courses#find_ids(ids)` method
  - Input: `Array<Integer>` of course IDs
  - Output: `Hash{Integer => Entity::Course}` (id → entity)
  - Implementation: single `WHERE id IN (...)` query
  - Test: `spec/infrastructure/database/repositories/courses_spec.rb`
    - Returns hash keyed by ID
    - Handles empty array
    - Handles IDs not found

- [ ] **5.1c** Add `Repository::Attendances#find_attended_event_ids(account_id, event_ids)` method
  - Input: `account_id` (Integer), `event_ids` (`Array<Integer>`)
  - Output: `Set<Integer>` of event IDs where the account has attendance
  - Implementation: single `WHERE account_id = ? AND event_id IN (...)` query, `select_map(:event_id)`
  - Test: `spec/infrastructure/database/repositories/attendances_spec.rb`
    - Returns set of attended event IDs
    - Excludes events not attended
    - Handles empty event_ids array
    - Handles account with no attendances

### Phase 2: Backend — Service enrichment + tests

Refactor both services to use batch lookups and add new fields.

**Tasks**:

- [ ] **5.2a** Refactor `FindActiveEvents#enrich_events_with_locations` → `enrich_events`
  - Inject `courses_repo` and `attendances_repo` dependencies (constructor)
  - Accept `requestor` in enrichment to compute `user_attendance_status`
  - Batch lookup: locations, courses, attendance status
  - Build OpenStruct with new fields: `course_name`, `location_name`, `user_attendance_status`
  - Keep existing fields: `id`, `course_id`, `location_id`, `name`, `start_at`, `end_at`, `longitude`, `latitude`

- [ ] **5.2b** Add FindActiveEvents enrichment tests
  - Test file: `spec/application/services/events/find_active_events_spec.rb`
  - Test: response includes `course_name` matching course record
  - Test: response includes `location_name` matching location record
  - Test: `user_attendance_status` is `true` when user has attendance for event
  - Test: `user_attendance_status` is `false` when user has no attendance for event
  - Test: multiple events from different courses have correct names
  - Test: event with missing location gracefully handles nil

- [ ] **5.2c** Refactor `ListEvents#enrich_with_location` → `enrich_events`
  - Accept course (already fetched in `verify_course_exists`) for `course_name`
  - Batch lookup: locations
  - Build OpenStruct with: `course_name`, `location_name` (no `user_attendance_status` — requestor-agnostic endpoint)
  - Keep existing fields

- [ ] **5.2d** Add ListEvents enrichment tests
  - Test file: `spec/application/services/events/list_events_spec.rb`
  - Test: response includes `course_name`
  - Test: response includes `location_name`
  - Test: response does NOT include `user_attendance_status` (requestor-agnostic endpoint)
  - Test: multiple events share same location (batch efficiency)

### Phase 3: Backend — Representer + route integration tests

Update representer to output new fields and verify end-to-end.

**Tasks**:

- [ ] **5.3a** Update `Representer::Event` with new properties
  - Add `property :course_name, exec_context: :decorator`
  - Add `property :location_name, exec_context: :decorator`
  - Add `property :user_attendance_status, exec_context: :decorator`
  - Each uses `respond_to?` guard (safe for existing callers)

- [ ] **5.3b** Add route integration tests for `GET /api/current_event/`
  - Test file: `spec/routes/current_event_route_spec.rb`
  - Test: response event includes `course_name` field
  - Test: response event includes `location_name` field
  - Test: `user_attendance_status` is `false` when no attendance recorded
  - Test: `user_attendance_status` is `true` when attendance exists
  - Test: location coordinates (`longitude`, `latitude`) still present

- [ ] **5.3c** Add route integration tests for `GET /api/course/:id/event/`
  - Test file: `spec/routes/event_route_spec.rb`
  - Test: response event includes `course_name` field
  - Test: response event includes `location_name` field
  - Test: response event does NOT include `user_attendance_status` field

- [ ] **5.3d** Run full test suite — all existing + new tests pass
  - `bundle exec rake spec`
  - No regressions in existing 763+ tests

### Phase 4: Frontend — Consume enriched data

Remove N+1 fetch logic and use pre-computed fields from the API.

**Tasks**:

- [ ] **5.4a** Update `AttendanceTrack.vue`
  - Remove `getCourseName()` method
  - Remove `getLocationName()` method
  - Remove `findAttendance()` method
  - Update `fetchEventData()` to use `event.course_name`, `event.location_name` directly from response
  - Map `event.user_attendance_status` to `isAttendanceExisted`
  - Keep `getLocalDateString()` for date formatting (frontend display concern)
  - Keep `getLocation()`, `showPosition()`, `showError()`, `postAttendance()`, `updateEventAttendanceStatus()` (attendance recording flow — unchanged)

- [ ] **5.4b** Update `AllCourse.vue`
  - Remove `getCourseName()` method
  - Remove `getLocationName()` method
  - Remove `findAttendance()` method
  - Update `fetchEventData()` to use enriched fields directly
  - Map `event.user_attendance_status` to `isAttendanceExisted`
  - Keep all other methods unchanged

### Phase 5: Verification

- [ ] **5.5** Manual verification
  - Start backend: `rake run:api`
  - Start frontend: `rake run:frontend`
  - Open browser to `http://localhost:9292`
  - Log in as a student enrolled in a course with an active event
  - Verify: event card shows correct `course_name` and `location_name`
  - Verify: "Mark Attendance" button shown (not already recorded)
  - Mark attendance, verify button changes to "Attendance Recorded"
  - Navigate to AllCourse page, verify events display correctly
  - Open Network tab: confirm no `/course/:id` or `/location/:id` fetches per event
  - Log in as owner, verify course event list shows event details

---

## Files Changed (Expected)

### Backend (modified)

| File | Change |
| ---- | ------ |
| `app/infrastructure/database/repositories/locations.rb` | Add `find_ids` batch method |
| `app/infrastructure/database/repositories/courses.rb` | Add `find_ids` batch method |
| `app/infrastructure/database/repositories/attendances.rb` | Add `find_attended_event_ids` method |
| `app/application/services/events/find_active_events.rb` | Batch enrichment with 3 new fields |
| `app/application/services/events/list_events.rb` | Batch enrichment with `course_name`, `location_name` (no attendance field) |
| `app/presentation/representers/event.rb` | Add `course_name`, `location_name`, `user_attendance_status` |

### Backend (new test files)

| File | Tests |
| ---- | ----- |
| `spec/infrastructure/database/repositories/locations_spec.rb` | `find_ids` batch method (new file or added to existing) |
| `spec/infrastructure/database/repositories/courses_spec.rb` | `find_ids` batch method (new file or added to existing) |
| `spec/infrastructure/database/repositories/attendances_spec.rb` | `find_attended_event_ids` (new file or added to existing) |
| `spec/application/services/events/find_active_events_spec.rb` | Enrichment tests (new file) |
| `spec/application/services/events/list_events_spec.rb` | Enrichment tests (new file) |

### Backend (modified test files)

| File | Change |
| ---- | ------ |
| `spec/routes/current_event_route_spec.rb` | Add enrichment field assertions |
| `spec/routes/event_route_spec.rb` | Add enrichment field assertions |

### Frontend (modified)

| File | Change |
| ---- | ------ |
| `frontend_app/pages/course/AttendanceTrack.vue` | Remove 3 fetch methods, use enriched data |
| `frontend_app/pages/course/AllCourse.vue` | Remove 3 fetch methods, use enriched data |

---

## Questions

- [ ] Should `location_name` be a top-level field or nested under a `location` object? **Proposal: top-level** — matches existing flat `longitude`/`latitude` pattern and simplifies frontend consumption. Nested `location: { name, longitude, latitude }` is cleaner but breaks existing frontend consumers of `longitude`/`latitude`.

---

## Dependencies

- No new gems or npm packages
- No database migrations
- No new domain entities or value objects
- Sequel ORM relationships (`many_to_one :location`, `many_to_one :course`) already defined

---

## Risk Assessment

| Risk | Mitigation |
| ---- | ---------- |
| Breaking existing event response consumers | `respond_to?` guards in representer; new fields are additive |
| N+1 → batch query performance | Batch queries use `WHERE IN` — well-optimized by SQLite/PostgreSQL |
| `user_attendance_status` leaking cross-user data | Scoped to `requestor.account_id` — only reveals own attendance |
| Frontend components miss a field rename | Template uses `event.course_name` and `event.location_name` — same names as current computed fields |

---

Last updated: 2026-02-09
