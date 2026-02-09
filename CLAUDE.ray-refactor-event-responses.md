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

Instead of calling `locations_repo.find_id(id)` per event, batch all location IDs and course IDs into single queries. Repository batch methods return plain Ruby collections of domain objects — no wrapper entities needed:

```ruby
location_ids = events.map(&:location_id).uniq
locations = locations_repo.find_ids(location_ids)  # new repo method → Hash<Integer, Entity::Location>

course_ids = events.map(&:course_id).uniq
courses = courses_repo.find_ids(course_ids)        # new repo method → Hash<Integer, Entity::Course>
```

Service accesses individual entities via hash lookup:

```ruby
course   = courses[event.course_id]
location = locations[event.location_id]
```

For attendance status (current_event only — requestor-scoped):

```ruby
event_ids = events.map(&:id)
attended_event_ids = attendances_repo.find_attended_event_ids(account_id, event_ids)  # new repo method → Set<Integer>
```

All three batch methods return standard Ruby collections (`Hash`, `Set`) containing domain objects. This is consistent with existing repository conventions (e.g., `find_all → Array<Entity::Course>`) — the constraint is "domain vocabulary," not "must be an entity." A `Hash<id, Entity>` is no different from the `Array<Entity>` that `find_all` already returns.

### 3. Response DTOs replace OpenStruct enrichment

Both services currently build `OpenStruct` wrappers for enrichment (adding `longitude`/`latitude`). We replace these with typed `Data.define` response DTOs in `application/responses/`:

- **`Response::EventDetails`** — event fields + location coordinates + `course_name`, `location_name`. Used by `ListEvents`.
- **`Response::ActiveEventDetails`** — all `EventDetails` fields + `user_attendance_status`. Used by `FindActiveEvents`.

`Data.define` gives immutable, equality-comparable objects with a guaranteed shape — the representer can rely on the DTO contract instead of `respond_to?` guards. The `application/responses/` directory already exists (`ApiResult` lives there), so this follows the established pattern.

> **Follow-up**: `CreateEvent` and `UpdateEvent` also use `OpenStruct` for location enrichment. Migrating those to a response DTO is out of scope for this branch but should follow.

### 4. `user_attendance_status` only on requestor-aware endpoints

- `FindActiveEvents` is already requestor-aware (scopes events to the user's enrolled courses) → adding `user_attendance_status` (boolean) is consistent. Uses `Response::ActiveEventDetails`.
- `ListEvents` uses `requestor` only for **authorization** (teaching staff gate) — the response data is requestor-agnostic (any staff member sees the same events). We **omit** `user_attendance_status` entirely to preserve this boundary. Uses `Response::EventDetails` (no attendance field in the DTO shape).

### 5. No aggregate collection entities — repos return plain collections

Earlier iterations proposed `Entity::Courses` and `Entity::Locations` as Dry::Struct wrappers around `{id => entity}` hashes. These were dropped after analysis: they fail both DDD classification tests. They aren't entities (nobody recognizes "the courses collection" as a domain thing), and they aren't value objects (they don't describe any parent entity — the "belongingness test" fails). They're transient infrastructure conveniences for a service method's batch step, so a plain `Hash<id, Entity>` is the right representation — same as `Set<Integer>` for attended event IDs.

`Entity::Event` stays minimal (DDD boundary). Enriched data is an application-layer concern: the service composes data from multiple repositories into a response DTO (`Data.define`).

---

## Phases

### Phase 1: Backend — Repository batch methods + tests ✅ DONE

Added batch lookup repository methods to eliminate N+1 queries. Methods return plain Ruby collections (`Hash`, `Set`) of domain objects.

**Tasks**:

- [x] **5.1a** Add `Repository::Locations#find_ids(ids)` method
  - Input: `Array<Integer>` of location IDs
  - Output: `Hash<Integer, Entity::Location>` (id → entity)
  - Implementation: single `WHERE id IN (...)` query, build hash from results via `rebuild_entity`
  - Test: `spec/infrastructure/database/repositories/locations_spec.rb`
    - Returns hash with correct entities keyed by ID
    - Handles empty array (returns empty hash)
    - Handles IDs not found (omits them)

- [x] **5.1b** Add `Repository::Courses#find_ids(ids)` method
  - Input: `Array<Integer>` of course IDs
  - Output: `Hash<Integer, Entity::Course>` (id → entity, children not loaded)
  - Implementation: single `WHERE id IN (...)` query, build hash from results via `rebuild_entity`
  - Test: `spec/infrastructure/database/repositories/courses_spec.rb`
    - Returns hash with correct entities keyed by ID
    - Handles empty array (returns empty hash)
    - Handles IDs not found (omits them)
    - Returns courses without children loaded

- [x] **5.1c** Add `Repository::Attendances#find_attended_event_ids(account_id, event_ids)` method
  - Input: `account_id` (Integer), `event_ids` (`Array<Integer>`)
  - Output: `Set<Integer>` of event IDs where the account has attendance
  - Implementation: single `WHERE account_id = ? AND event_id IN (...)` query, `select_map(:event_id)`, wrap in `Set`
  - Test: `spec/infrastructure/database/repositories/attendances_spec.rb`
    - Returns set of attended event IDs
    - Excludes events not attended
    - Handles empty event_ids array
    - Excludes attendances from other accounts

### Phase 2: Backend — Response DTOs + service enrichment + tests ✅ DONE

Created response DTOs and refactored both services to use batch lookups and typed responses.

**Tasks**:

- [x] **5.2a** Create response DTOs in `app/application/responses/`
  - `Response::EventDetails` = `Data.define(:id, :course_id, :location_id, :name, :start_at, :end_at, :longitude, :latitude, :course_name, :location_name)`
  - `Response::ActiveEventDetails` = `Data.define(:id, :course_id, :location_id, :name, :start_at, :end_at, :longitude, :latitude, :course_name, :location_name, :user_attendance_status)`
  - Both under `Tyto::Response` module (alongside existing `ApiResult`)

- [x] **5.2b** Refactor `FindActiveEvents#enrich_events_with_locations` → `enrich_events`
  - Injected `courses_repo` and `attendances_repo` dependencies (constructor)
  - Accepts `requestor` in enrichment to compute `user_attendance_status`
  - Batch lookup: locations, courses, attendance status (3 queries total instead of 3N)
  - Builds `Response::ActiveEventDetails` (replaces OpenStruct)

- [x] **5.2c** Add FindActiveEvents enrichment tests
  - Test file: `spec/application/services/events/find_active_events_spec.rb`
  - Test: response includes `course_name` matching course record
  - Test: response includes `location_name` matching location record
  - Test: `user_attendance_status` is `false` when user has no attendance for event
  - Test: `user_attendance_status` is `true` when user has attendance for event

- [x] **5.2d** Refactor `ListEvents#enrich_with_location` → `enrich_events`
  - Accepts course (captured from `verify_course_exists` step) for `course_name`
  - Batch lookup: locations via `find_ids` (single query for all event locations)
  - Builds `Response::EventDetails` (replaces OpenStruct, no `user_attendance_status`)

- [x] **5.2e** Add ListEvents enrichment tests
  - Test file: `spec/application/services/events/list_events_spec.rb`
  - Test: response includes `course_name`
  - Test: response includes `location_name`
  - Test: response does NOT include `user_attendance_status` (requestor-agnostic endpoint)

### Phase 3: Backend — Representer + route integration tests ✅ DONE

Updated representer to output new fields and verified end-to-end.

**Tasks**:

- [x] **5.3a** Update `Representer::Event` with new properties
  - Added `property :course_name, exec_context: :decorator` with `respond_to?` guard
  - Added `property :location_name, exec_context: :decorator` with `respond_to?` guard
  - Added `property :user_attendance_status, exec_context: :decorator` with `respond_to?` guard (present on `ActiveEventDetails`, returns `nil` for `EventDetails`)

- [x] **5.3b** Add route integration tests for `GET /api/current_event/`
  - Test file: `spec/routes/current_event_route_spec.rb`
  - Test: response event includes `course_name` and `location_name` fields with correct values
  - Test: `user_attendance_status` is `false` when no attendance recorded
  - Test: `user_attendance_status` is `true` when attendance exists

- [x] **5.3c** Add route integration tests for `GET /api/course/:id/event/`
  - Test file: `spec/routes/event_route_spec.rb`
  - Test: response event includes `course_name` and `location_name` fields with correct values
  - Test: `user_attendance_status` is `nil` (not present on EventDetails DTO)

- [x] **5.3d** Run full test suite — all existing + new tests pass
  - `bundle exec rake spec` → **795 tests, 0 failures, 0 errors, 98% coverage**

### Phase 4: Frontend — Consume enriched data ✅ DONE

Removed N+1 fetch logic and used pre-computed fields from the API.

**Tasks**:

- [x] **5.4a** Update `AttendanceTrack.vue`
  - Removed `getCourseName()` method
  - Removed `getLocationName()` method
  - Removed `findAttendance()` method
  - Simplified `fetchEventData()` to use `event.course_name`, `event.location_name` directly from response
  - Mapped `event.user_attendance_status` → `isAttendanceExisted`
  - Kept `getLocalDateString()`, `getLocation()`, `showPosition()`, `showError()`, `postAttendance()`, `updateEventAttendanceStatus()`

- [x] **5.4b** Update `AllCourse.vue`
  - Removed `getCourseName()` method
  - Removed `getLocationName()` method
  - Removed `findAttendance()` method
  - Simplified `fetchEventData()` to use enriched fields directly
  - Mapped `event.user_attendance_status` → `isAttendanceExisted`
  - Kept all other methods unchanged

### Phase 5: Verification ✅ DONE

- [x] **5.5a** Automated tests: `bundle exec rake spec` → **795 tests, 0 failures, 0 errors, 98% coverage**
- [x] **5.5b** Manual frontend verification — confirmed via browser:
  - `AllCourse.vue`: event cards display `course_name` and `location_name` from enriched response
  - `AllCourse.vue`: `user_attendance_status` correctly maps to attendance button state (Mark Attendance → Attendance Recorded after POST)
  - `AllCourse.vue`: status persists across page refresh (read from API, not local state)
  - `SingleCourse` attendance page: event cards display `location_name` inline
  - Network: `/api/current_event/` makes 4 batch queries (events, locations, courses, attendances) — no N+1
  - Network: `/api/course/:id/event/` makes 2 batch queries (events, locations) — no attendances query (correct)

---

## Files Changed

### Backend (new)

| File | Change |
| ---- | ------ |
| `app/application/responses/event_details.rb` | Response DTO for event list endpoints (`Data.define`) |
| `app/application/responses/active_event_details.rb` | Response DTO for active events with attendance status (`Data.define`) |

### Backend (modified)

| File | Change |
| ---- | ------ |
| `app/infrastructure/database/repositories/locations.rb` | Added `find_ids` batch method → `Hash<id, Entity::Location>` |
| `app/infrastructure/database/repositories/courses.rb` | Added `find_ids` batch method → `Hash<id, Entity::Course>` |
| `app/infrastructure/database/repositories/attendances.rb` | Added `require 'set'` + `find_attended_event_ids` method → `Set<Integer>` |
| `app/application/services/events/find_active_events.rb` | Batch enrichment → `Response::ActiveEventDetails`; added `courses_repo` and `attendances_repo` dependencies |
| `app/application/services/events/list_events.rb` | Batch enrichment → `Response::EventDetails`; captured `course` from `verify_course_exists` |
| `app/presentation/representers/event.rb` | Added `course_name`, `location_name`, `user_attendance_status` with `respond_to?` guards |

### Backend (modified test files)

| File | Change |
| ---- | ------ |
| `spec/infrastructure/database/repositories/locations_spec.rb` | Added `#find_ids` describe block (3 tests) |
| `spec/infrastructure/database/repositories/courses_spec.rb` | Added `#find_ids` describe block (4 tests) |
| `spec/infrastructure/database/repositories/attendances_spec.rb` | Added `#find_attended_event_ids` describe block (4 tests) |
| `spec/application/services/events/find_active_events_spec.rb` | Added enrichment tests: `course_name`, `location_name`, `user_attendance_status` (4 tests) |
| `spec/application/services/events/list_events_spec.rb` | Added enrichment tests: `course_name`, `location_name`, no `user_attendance_status` (3 tests) |
| `spec/routes/current_event_route_spec.rb` | Added `course_name`, `location_name`, `user_attendance_status` assertions (1 new test + expanded existing) |
| `spec/routes/event_route_spec.rb` | Added `course_name`, `location_name` assertions + confirmed `user_attendance_status` nil |

### Frontend (modified)

| File | Change |
| ---- | ------ |
| `frontend_app/pages/course/AttendanceTrack.vue` | Removed `getCourseName()`, `getLocationName()`, `findAttendance()`; simplified `fetchEventData()` |
| `frontend_app/pages/course/AllCourse.vue` | Removed `getCourseName()`, `getLocationName()`, `findAttendance()`; simplified `fetchEventData()` |

---

## Questions

- [x] Should `location_name` be a top-level field or nested under a `location` object? **Decision: top-level** — matches existing flat `longitude`/`latitude` pattern and simplifies frontend consumption.

---

## Dependencies

- No new gems or npm packages
- No database migrations
- No new domain entities — batch methods return plain Ruby collections (`Hash`, `Set`) of existing entities
- Sequel ORM relationships (`many_to_one :location`, `many_to_one :course`) already defined

---

## Risk Assessment

| Risk | Mitigation |
| ---- | ---------- |
| Breaking existing event response consumers | Response DTOs guarantee shape; new fields are additive; `respond_to?` guard only for `user_attendance_status` (differs between endpoints) |
| N+1 → batch query performance | Batch queries use `WHERE IN` — well-optimized by SQLite/PostgreSQL |
| `user_attendance_status` leaking cross-user data | Scoped to `requestor.account_id` — only reveals own attendance |
| Frontend components miss a field rename | Template uses `event.course_name` and `event.location_name` — same names as current computed fields |

---

Last updated: 2026-02-09
