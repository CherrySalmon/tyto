# Refactor Frontend Domain Logic to Backend DDD API

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.
>
> **SYNC REQUIRED**: This document must stay aligned with `CLAUDE.refactor-frontend-ddd[tests].md`. Task IDs must match across both files. When updating tasks in one file, update the other.

## Branch

`refactor-frontend-ddd`

## Goal

Move all major domain logic from the Vue frontend to the backend's DDD-architected API. The frontend should become a thin presentation layer that consumes rich, pre-validated, pre-computed data from the backend.

## Strategy: Vertical Slices

Each slice delivers a complete, end-to-end feature:

1. **Backend test** — Write failing test for new behavior
2. **Backend implementation** — Make the test pass
3. **Frontend update** — Remove old logic, consume new API
4. **Verify** — Manual or E2E test confirms behavior

This approach ensures we only build what the frontend actually needs, with immediate feedback on API design.

## Current State

- [x] Plan created
- [x] Frontend domain logic analyzed
- [x] Backend DDD architecture reviewed
- [x] Vertical slice strategy adopted
- [x] Slice 1 backend completed (geo-fence enforcement in RecordAttendance)
- [x] Slice 1 frontend (remove client-side geo-fence logic, show backend errors)
- [x] Slice 1 hardening: event time-window enforcement via domain policy
- [x] Slice 1 complete (manual verification passed)
- [x] Slice 2 dropped — idempotent by design (see Slice 2 notes)
- [x] Slice 3 backend complete (domain policy, service, route, 18 tests)
- [x] Slice 3 frontend complete (ManagePeopleCard fetches roles from API)
- [x] Slice 3 manual verification complete (task 3.5)
- [x] Slice 4 complete (attendance report endpoint + DDD entity refactoring)
- [x] Slice 5 complete (enriched event responses with batch lookups + response DTOs)
- [x] Slice 6 backend complete (policy summaries in course responses, 4 route tests)
- [x] Slice 6 frontend complete (SingleCourse + CourseInfoCard use policies instead of role strings)

## Key Findings

### Frontend Domain Logic to Move

| Issue | Location | Priority | Backend Status |
| ----- | -------- | -------- | -------------- |
| **Attendance Geo-fence Validation** | AttendanceTrack, AllCourse | HIGH | `Attendance#within_range?()` exists - not being used! |
| **Attendance Deduplication** | AttendanceTrack, AllCourse | HIGH | Should be backend validation |
| **Role-based Permission Hierarchy** | ManagePeopleCard | HIGH | Policies exist but frontend hardcodes role mapping |
| **Attendance Report/CSV Generation** | AttendanceEventCard | HIGH | Complex aggregation logic in frontend |
| **Event Data Enrichment (N+1)** | AttendanceTrack, AllCourse | HIGH | Backend can return enriched data |
| **Date/Time Transformation** | Multiple components | MEDIUM | Backend should return formatted strings |
| **Enrollment Email Parsing** | ManagePeopleCard | MEDIUM | Backend should validate |
| **Course Form Field Manipulation** | SingleCourse | MEDIUM | API contract issue |
| **Feature Visibility Logic** | AllCourse, SingleCourse | MEDIUM | Should be API-driven capabilities |
| **Geolocation Code Duplication** | 3 components | LOW | Frontend concern, but needs cleanup |

### Backend DDD Capabilities (Already Exists)

- **Domain Layer**: `Attendance#within_range?(max_distance_km)`, `GeoLocation#distance_to()`
- **Policies**: `CoursePolicy`, `AttendanceAuthorization` with role-based authorization
- **Services**: Railway-oriented operations with proper validation
- **Repositories**: Lazy loading strategies (find_full, find_with_events, etc.)

---

## Cross-Cutting Decisions

### Response DTOs replace OpenStruct enrichment

**Introduced in**: Slice 5. **Applies to**: all slices that compose multi-entity API responses.

Multiple services currently build `OpenStruct` wrappers to combine data from different repositories (e.g., event + location coordinates, course + enrollment roles). `OpenStruct` has no guaranteed shape — representers must use `respond_to?` guards, and typos silently produce `nil`.

**Convention**: Use `Data.define` response DTOs in `application/responses/`. Each DTO defines the exact shape of a use case's response. The representer can rely on the contract instead of runtime guards.

See the `/ddd` skill → "Response DTOs" for the full pattern and guidelines.

**Migration roadmap** (by slice):

| Slice | Services using OpenStruct | Response DTO |
| ----- | ------------------------ | ------------ |
| 5 | `FindActiveEvents`, `ListEvents` | `Response::ActiveEventDetails`, `Response::EventDetails` |
| 6 | `GetCourse`, `ListUserCourses` | `Response::CourseDetails` |
| Post-slice | `CreateEvent`, `UpdateEvent` | `Response::EventWithLocation` (or reuse `EventDetails`) |

## Vertical Slices

### Slice 1: Geo-fence Attendance Validation

**Why first**: Security-critical; domain logic already exists but isn't wired up.

**Scope**: Domain policy radius (~55m). No new DB columns, no per-event configuration. Variable fencing deferred to future work.

**Shape change**: The original frontend used a bounding box (square ±0.0005°), which allowed ~78m at corners (55m × √2). The backend uses Haversine (circle), giving a uniform 55m radius — more correct.

**Boundary**: Geo-fence enforcement applies only to self-reported student attendance (gated by `AttendanceAuthorization.can_create?` → `self_enrolled?`). Teacher/TA/owner/admin manual attendance flagging bypasses geo-fence — deferred to future work.

**Architecture** (domain policy vs. application policy):

- `Policy::AttendanceEligibility` (domain) — actor-agnostic business rule: "attendance is valid when the student is at the right place at the right time." Checks both time window (`Event#active?`) and proximity (Haversine ≤ 55m). Returns `:time_window`, `:proximity`, or `nil` (eligible).
- `AttendanceAuthorization` (application) — actor-dependent: "who can record attendance?" Checks enrollment/roles.
- `RecordAttendance` service (application) — orchestrates both: checks who can act, requires coordinates for self-reported attendance, delegates eligibility check to domain policy.

**Backend changes**:

- New domain policy: `domain/attendance/policies/attendance_eligibility.rb`
  - `Policy::AttendanceEligibility.check(attendance:, event:, location:, time:)` — returns `nil` (eligible), `:time_window`, or `:proximity`
  - `MAX_DISTANCE_KM = 0.055` (~55m) — business rule constant
  - Gracefully handles missing time ranges and missing coordinates
  - Prevents stale-browser and direct HTTP request bypass
- Enhanced `Services::Attendances::RecordAttendance` with:
  - `locations_repo` dependency (injected, same pattern as other repos)
  - `verify_eligibility` step between `validate_input` and `persist_attendance`
  - Rejects missing coordinates as forbidden (bypass attempt)
  - Delegates eligibility decision to `Policy::AttendanceEligibility`

**Frontend changes**:

- Remove geo-fence validation from `AttendanceTrack.vue` and `AllCourse.vue`
- Display backend error message when attendance is rejected

**Tasks**:

- [x] 1.1a Add geo-fence acceptance test (within radius)
- [x] 1.1b Add geo-fence rejection test (outside radius)
- [x] 1.1d Add geo-fence rejection test (no coordinates — bypass attempt)
- [x] 1.1e Add domain policy spec (`attendance_proximity_spec.rb`)
- [x] 1.4a Wire up geo-fence check in RecordAttendance service
- [x] 1.4b Extract domain policy `Policy::AttendanceProximity` from service
- [x] 1.5 Update frontend to remove geo-fence logic and show backend errors
- [x] 1.7a Add domain policy spec (`event_time_window_spec.rb`)
- [x] 1.7b Add event time-window rejection test (ended event)
- [x] 1.7c Add event time-window rejection test (future event)
- [x] 1.7d Wire up time-window check in RecordAttendance service via domain policy
- [x] 1.6 Manual verification: test inside/outside geo-fence and time-window scenarios

**Dropped** (deferred to future work):

- ~~1.1c Test for event-specific radius~~ — variable fencing deferred
- ~~1.2 Add `geo_fence_radius_m` migration~~ — no per-event config needed
- ~~1.3 Add `geo_fence_radius_m` to Event entity and representer~~ — no per-event config needed
- GPS accuracy enforcement — browser reports `coords.accuracy` (radius in meters); reject when accuracy > fence radius (position too imprecise). Requires new DB column + frontend to send accuracy field.

---

### ~~Slice 2: Duplicate Attendance Prevention~~ (Dropped)

**Status**: Unnecessary — attendance recording is **idempotent by design**.

**Why dropped**: The repository uses `find_or_create()` backed by a database unique constraint on `[course_id, account_id, event_id]`. A duplicate request silently returns the existing record — no error, no side effect. This is better REST semantics than returning 409 Conflict, which would break idempotency (same request succeeding first time, failing second time) and is particularly problematic for unreliable mobile networks where retries are expected.

**Remaining frontend concern → moved to Slice 7**: Both `AttendanceTrack.vue` and `AllCourse.vue` have a `findAttendance()` method that fetches all course attendances and filters client-side to determine button state ("Mark Attendance" vs "Attendance Recorded"). This is a **read/display concern** (not a write/validation concern) and should be consolidated as part of the shared attendance composable extraction in Slice 7.

---

### Slice 3: Assignable Roles Endpoint

**Why third**: Correctness; frontend currently hardcodes role hierarchy.

**Design decision**: Owner CAN assign the owner role (matches current frontend behavior; no DB/service restriction on multiple owners per course).

**Role hierarchy** (requestor → assignable roles):

- owner → owner, instructor, staff, student (all course roles)
- instructor → staff, student
- staff → student
- student → [] (empty)
- non-enrolled → 403 Forbidden

**Architecture** (domain policy + service):

- `Policy::RoleAssignment` (domain) — actor-agnostic business rule: "which roles can a given role assign?" Owns `HIERARCHY` and `ASSIGNABLE` constants. Raises `UnknownRoleError` for invalid roles. Two entry points: `assignable_roles(role)` for a single role, `for_enrollment(course_roles)` for a CourseRoles collection (uses highest role).
- `Service::Courses::GetAssignableRoles` (application) — thin orchestrator: validate course_id → find course → authorize (enrolled?) → delegate to `Policy::RoleAssignment.for_enrollment`.
- Route: `GET /api/course/:id/assignable_roles` → returns `{ success: true, data: ["owner", ...] }`

**Frontend changes**:

- `SingleCourse.vue` fetches assignable roles from API, passes as `assignableRoles` prop
- `ManagePeopleCard.vue` removed hardcoded `peopleform`/`peopleRoleList`/`checkIsModifable`; role dropdown iterates over `assignableRoles` prop directly

**Tasks**:

- [x] 3.1a Create spec file with owner permission tests
- [x] 3.1b Add instructor permission tests
- [x] 3.1c Add student permission tests (+ staff + non-enrolled + invalid course)
- [x] 3.1d Add route integration test (owner, instructor, non-enrolled)
- [x] 3.2 Create GetAssignableRoles service
- [x] 3.3 Add route to course routes (`GET /api/course/:id/assignable_roles`)
- [x] 3.4 Update ManagePeopleCard to fetch and use API roles
- [x] 3.5 Manual verification: test role assignment as different user types

---

### Slice 4: Attendance Report Endpoint

**Why fourth**: Complexity reduction; removes significant frontend logic.

**Status**: Complete. Implemented in 3 phases on branch `ray/refactor-generate-report` — see `CLAUDE.ray-refactor-generate-report.md` for full branch plan.

**Architecture**:

```text
Route (course.rb)  GET /api/course/:id/attendance/report[?format=csv]
  --> Service::Attendances::GenerateReport  (orchestration only)
      --> courses_repo.find_full()
      --> attendances_repo.find_by_course()
      --> AttendanceAuthorization.can_view_all?
      --> Entity::AttendanceReport.build(course:, attendances:)  (domain layer)
            --> AttendanceRegister.build(attendances:)   (index for O(1) queries)
            --> StudentAttendanceRecord.build(enrollment:, events:, register:)  (per student)
  --> Representer::AttendanceReport             (JSON, default)
  --> Presentation::Formatters::AttendanceReportCsv  (CSV, format=csv)
```

**Domain design**:

- `Entity::AttendanceReport` — domain entity with `.build` factory; coordinates value objects. Attributes: `course_name`, `generated_at`, `events` (ReportEvent[]), `student_records` (StudentAttendanceRecord[])
- `AttendanceRegister` — value object wrapping `account_id → Set<event_id>` index for O(1) attendance queries via `#attended?`
- `StudentAttendanceRecord` — value object with `.build` factory owning its own aggregation (sum, percent, per-event presence)

**Backend files created**:

- `app/domain/attendance/entities/attendance_report.rb` — entity with `.build` factory
- `app/domain/attendance/values/attendance_register.rb` — O(1) lookup index
- `app/domain/attendance/values/student_attendance_record.rb` — per-student stats
- `app/application/services/attendances/generate_report.rb` — orchestration service
- `app/presentation/representers/attendance_report.rb` — JSON serialization (Roar)
- `app/presentation/formatters/attendance_report_csv.rb` — CSV output

**Frontend changes**:

- `AttendanceEventCard.vue` — replaced client-side CSV generation with API call to report endpoint
- `lib/downloadFile.js` — new utility for blob download via temporary `<a>` element

**Tests**: 29 tests across 6 spec files (see testing doc for details). 763 tests total, 0 failures, 97.99% coverage.

**Tasks**:

- [x] 4.1a Create spec file with aggregation tests
- [x] 4.1b Add summary statistics tests
- [x] 4.1c Add CSV format test
- [x] 4.1d Add authorization test
- [x] 4.1e Add route integration test
- [x] 4.2 Create GenerateReport service with aggregation logic
- [x] 4.3 Add CSV formatting support
- [x] 4.4 Add route to course routes
- [x] 4.5 Update AttendanceEventCard to use report endpoint
- [x] 4.6 Domain entity refactoring (AttendanceReport, AttendanceRegister, StudentAttendanceRecord)
- [x] 4.7 Push aggregation into value objects (`.build` factories)
- [x] 4.8 Full test suite pass (763 tests, 0 failures, 97.99% coverage)

---

### Slice 5: Enriched Event Responses

**Why fifth**: Performance; eliminates N+1 fetching in frontend.

**Status**: Complete. Implemented on branch `ray/refactor-event-responses` in 5 phases — see `CLAUDE.ray-refactor-event-responses.md` for full branch plan.

**Problem**: Both `AttendanceTrack.vue` and `AllCourse.vue` fetched active events, then for each event made 3 additional HTTP calls (course, location, attendance). For N events this produced 3N+1 requests. Reduced to **1 request** by embedding all three fields in the event response.

**Architecture**:

- **Batch lookups** in repositories replace N+1 queries: `find_ids(ids) → Hash<id, Entity>` for courses/locations, `find_attended_event_ids(account_id, event_ids) → Set<Integer>` for attendance status
- **Response DTOs** (`Data.define`) replace `OpenStruct` enrichment: `Response::EventDetails` (list events) and `Response::ActiveEventDetails` (active events + `user_attendance_status`)
- **Enrichment in service layer**: services compose data from multiple repos into response DTOs — repositories return pure domain entities
- **`user_attendance_status`** only on requestor-aware endpoint (`FindActiveEvents`); omitted from requestor-agnostic `ListEvents`

**Two endpoints enriched**:

| Endpoint | Service | Response DTO |
| -------- | ------- | ------------ |
| `GET /api/current_event/` | `FindActiveEvents` | `Response::ActiveEventDetails` |
| `GET /api/course/:id/event/` | `ListEvents` | `Response::EventDetails` |

**Backend files created**:

- `app/application/responses/event_details.rb` — `Data.define` DTO for event list endpoints
- `app/application/responses/active_event_details.rb` — `Data.define` DTO with attendance status

**Backend files modified**:

- `app/infrastructure/database/repositories/locations.rb` — added `find_ids` batch method
- `app/infrastructure/database/repositories/courses.rb` — added `find_ids` batch method
- `app/infrastructure/database/repositories/attendances.rb` — added `find_attended_event_ids` method
- `app/application/services/events/find_active_events.rb` — batch enrichment → `Response::ActiveEventDetails`
- `app/application/services/events/list_events.rb` — batch enrichment → `Response::EventDetails`
- `app/presentation/representers/event.rb` — added `course_name`, `location_name`, `user_attendance_status` properties

**Frontend changes**:

- `AttendanceTrack.vue` — removed `getCourseName()`, `getLocationName()`, `findAttendance()`; simplified `fetchEventData()` to use enriched fields
- `AllCourse.vue` — removed `getCourseName()`, `getLocationName()`, `findAttendance()`; simplified `fetchEventData()` to use enriched fields

**Tests**: 18 new tests across 7 spec files. 795 tests total, 0 failures, 98% coverage.

**Tasks**:

- [x] 5.1a Add `Repository::Locations#find_ids` batch method + tests (3 tests)
- [x] 5.1b Add `Repository::Courses#find_ids` batch method + tests (4 tests)
- [x] 5.1c Add `Repository::Attendances#find_attended_event_ids` method + tests (4 tests)
- [x] 5.2a Create response DTOs (`EventDetails`, `ActiveEventDetails`) in `application/responses/`
- [x] 5.2b Refactor `FindActiveEvents` service — batch enrichment → `Response::ActiveEventDetails`
- [x] 5.2c Add `FindActiveEvents` enrichment tests (4 tests: `course_name`, `location_name`, `user_attendance_status` true/false)
- [x] 5.2d Refactor `ListEvents` service — batch enrichment → `Response::EventDetails`
- [x] 5.2e Add `ListEvents` enrichment tests (3 tests: `course_name`, `location_name`, no `user_attendance_status`)
- [x] 5.3a Update `Representer::Event` with `course_name`, `location_name`, `user_attendance_status` properties
- [x] 5.3b Add route integration tests for `GET /api/current_event/` (enriched fields + attendance status)
- [x] 5.3c Add route integration tests for `GET /api/course/:id/event/` (enriched fields, no attendance status)
- [x] 5.3d Full test suite pass (795 tests, 0 failures, 98% coverage)
- [x] 5.4a Update `AttendanceTrack.vue` — remove N+1 fetch methods, use enriched response
- [x] 5.4b Update `AllCourse.vue` — remove N+1 fetch methods, use enriched response
- [x] 5.5 Manual verification: confirmed enriched data in browser, no N+1 in network tab

---

### Slice 6: Capabilities-Based Visibility

**Why sixth**: Cleaner authorization; frontend uses capabilities instead of role strings.

**Status**: Complete (pending manual verification). Implemented on branch `ray/refactor-capabilities-visibility` — see `CLAUDE.ray-refactor-capabilities-visibility.md` for full branch plan.

**Design decision**: Used `policies` as the response key (matching `CoursePolicy#summary` terminology) rather than `capabilities`. The summary is returned as-is from the existing policy — no new predicates needed.

**Response shape**:

```json
{
  "id": 1,
  "name": "Course Name",
  "enroll_identity": ["owner"],
  "policies": {
    "can_view": true,
    "can_create": false,
    "can_update": true,
    "can_delete": true
  }
}
```

Key mapping: `can_update` replaces all frontend role string comparisons for teaching staff visibility (owner, instructor, staff).

**Architecture**:

- `CoursePolicy#summary` (existing) — returns hash of all capability checks
- `Response::CourseDetails` (`Data.define` DTO) — replaces `OpenStruct` in both `GetCourse` and `ListUserCourses`; includes `policies` field
- `CourseWithEnrollment` representer — new `policies` property with defensive `respond_to?` fallback to `nil`
- Services build policy from enrollment, merge `policy.summary` into DTO

**Backend files created**:

- `app/application/responses/course_details.rb` — `Data.define` DTO with `policies` field

**Backend files modified**:

- `app/application/services/courses/get_course.rb` — builds DTO, merges `CoursePolicy#summary`
- `app/application/services/courses/list_user_courses.rb` — builds DTO with policies per course
- `app/presentation/representers/course.rb` — added `policies` property to `CourseWithEnrollment`

**Frontend changes**:

- `SingleCourse.vue` — 4 role string comparisons → `course.policies.can_update`
- `CourseInfoCard.vue` — 1 role string comparison → `course.policies.can_update`

**Tests**: 4 new route tests in `spec/routes/course_route_spec.rb` (owner, instructor, student, list).

**Tasks**:

- [x] 6.1a Add route test: owner gets `policies` (`can_update: true, can_delete: true`)
- [x] 6.1b Add route test: instructor gets `policies` (`can_update: true, can_delete: false`)
- [x] 6.1c Add route test: student gets `policies` (`can_update: false, can_delete: false`)
- [x] 6.1d Add route test: course list includes `policies` per course
- [x] 6.2a Create `Response::CourseDetails` DTO
- [x] 6.2b Refactor `GetCourse` — build DTO, merge `CoursePolicy#summary`
- [x] 6.2c Refactor `ListUserCourses` — build DTO with policies per course
- [x] 6.2d Update `CourseWithEnrollment` representer — add `policies` property
- [x] 6.3a `SingleCourse.vue` — replace role comparisons with `course.policies.can_update`
- [x] 6.3b `CourseInfoCard.vue` — replace `currentRole != 'student'` with `policies.can_update`
- [ ] 6.4 Manual verification: test as owner, instructor, staff, student

---

### Slice 7: Frontend Utilities (Cleanup)

**Why last**: Pure frontend cleanup; no backend changes.

**Frontend changes**:

- Extract `frontend_app/lib/geolocation.js` utility (shared across components)
- Extract `frontend_app/lib/dateFormatter.js` utility
- Extract shared attendance logic (composable or service) — `postAttendance()`, `getLocation()`, `showPosition()`, `showError()`, `updateEventAttendanceStatus()` are duplicated across `AttendanceTrack.vue` and `AllCourse.vue`
  - **Note**: `findAttendance()` and the N+1 fetch methods (`getCourseName()`, `getLocationName()`) were already removed in Slice 5 — the API now returns enriched data with `user_attendance_status`.
- Remove any remaining deprecated domain logic

**Tasks**:

- [ ] 7.1 Create geolocation utility with shared functions
- [ ] 7.2 Create date formatting utility
- [ ] 7.3 Extract shared attendance logic from AttendanceTrack and AllCourse
- [ ] 7.4 Update components to use utilities
- [ ] 7.5 Remove deprecated logic from components

---

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Should the geo-fence radius be configurable per-course or global?~~ **Decision: Hardcoded policy constant (~55m) for now. Variable per-event fencing deferred to future work.**
- [x] ~~Should CSV export be a streaming download or return data for frontend to format?~~ **Decision: Backend generates CSV via `AttendanceReportCsv` formatter. Frontend receives blob and triggers download via `downloadFile.js` utility.**
- [ ] What date format should the API return? ISO 8601 with timezone, or pre-formatted locale string?
- [x] ~~Should capabilities be embedded in every response or a separate endpoint?~~ **Decision: Embedded in course response as `policies` key. Follows Credence pattern — service merges `CoursePolicy#summary` into DTO. One request, no extra round-trip.**

## Completed

- [x] **CI pipeline** — GitHub Actions on Ubuntu + macOS, triggers on PRs/main/manual
- [x] **Fix `rake generate:jwt_key`** — Updated for DDD refactor, no DB dependency
- [x] **Bump sqlite3 to 2.x** — Ruby 3.4 + ARM macOS compatibility

---

**Last updated**: 2026-02-09
