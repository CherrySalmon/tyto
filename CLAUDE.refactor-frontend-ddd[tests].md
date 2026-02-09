# Testing Strategy for Frontend-to-Backend Refactoring

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for testing during this refactoring.

> **SYNC REQUIRED**: This document must stay aligned with `CLAUDE.refactor-frontend-ddd.md`. Slice numbering and test task IDs (e.g., 1.1a) must match across both files.

## CI

GitHub Actions runs backend tests on every PR (any branch), push to main, and manual dispatch.

- **Workflow**: `.github/workflows/ci.yml`
- **Matrix**: `ubuntu-latest` + `macos-latest`
- **Steps**: Install libsodium, Ruby (from `.ruby-version`), generate JWT key, migrate test DB, run `rake spec`
- **Env**: `BUNDLE_WITHOUT=production` (skips `pg` gem)

## Strategy: Test-First Vertical Slices

Testing is integrated into each vertical slice (see `CLAUDE.refactor-frontend-ddd.md`):

1. **Write failing backend test** — Documents expected behavior
2. **Implement backend** — Make the test pass
3. **Update frontend** — Remove old logic, consume new API
4. **Verify end-to-end** — Manual test or E2E automation

## Test Infrastructure

- **Framework**: Minitest with spec-style (`describe`/`it`)
- **Isolation**: Transaction rollback per test with savepoints
- **Helpers** (`spec/support/test_helpers.rb`):
  - `create_test_account(roles:)` — Creates account with roles
  - `authenticated_header(roles:)` — Returns account + JWT header
  - `json_response()` — Parses response body
  - `json_headers()` — Content-Type headers
- **Services**: Railway-oriented with `Dry::Monads` (Success/Failure)

### Key Spec Files for Reference

| Purpose | File |
|---------|------|
| Service test template | `spec/application/services/attendances/record_attendance_spec.rb` |
| Route test template | `spec/routes/course_route_spec.rb` |
| Application authorization test | `spec/application/policies/attendance_authorization_spec.rb` |
| Domain policy test | `spec/domain/attendance/policies/attendance_proximity_spec.rb` |
| Domain entity test | `spec/domain/attendance/entities/attendance_spec.rb` |
| Domain entity test (report) | `spec/domain/attendance/entities/attendance_report_spec.rb` |
| Domain value test (register) | `spec/domain/attendance/values/attendance_register_spec.rb` |
| Domain value test (student record) | `spec/domain/attendance/values/student_attendance_record_spec.rb` |
| Service test (report) | `spec/application/services/attendances/generate_report_spec.rb` |
| Presentation test (CSV) | `spec/presentation/formatters/attendance_report_csv_spec.rb` |

## Existing Coverage Analysis

**Review completed**: 2025-02-05

### Critical Discovery

**Geo-fence validation EXISTS but is UNUSED!**

- `Attendance#within_range?(max_distance_km)` is defined and tested in domain layer
- `RecordAttendance` service does NOT call it
- The domain logic works — it just needs to be wired up in the service

### Coverage Summary

| Area | Unit Tests | Integration Tests | Gaps |
|------|-----------|------------------|------|
| Attendance Recording | Good (geo-fence enforced) | Good | Duplicates |
| Role Assignment | Excellent | Good | Assignable roles logic |
| Event Responses | Good | Good | Enriched data |
| Course Reports | Excellent (29 tests) | Good (3 route tests) | — |
| Repositories | Excellent | — | Duplicate query |
| Policies | Excellent | Good | Capabilities matrix |

## Per-Slice Test Plan

Each slice's test tasks (1.1a, 2.1a, etc.) are listed in `CLAUDE.refactor-frontend-ddd.md`. Below are testing-specific notes for each slice.

### Slice 1: Geo-fence + Time-Window Validation ✅

Two levels of testing — domain policy (business rules) and service (orchestration):

**Domain policy spec**: `spec/domain/attendance/policies/attendance_eligibility_spec.rb`
- Merged `AttendanceProximity` + `EventTimeWindow` into single `AttendanceEligibility` policy
- 13 tests covering both time window and proximity facets:
  - Threshold constant is 0.055 km (~55m)
  - Time window: eligible when active, `:time_window` when ended, `:time_window` when not started, eligible when no time range, boundary tests at exact start/end
  - Proximity: eligible at exact location, eligible within 55m, `:proximity` beyond 55m, eligible when location nil, eligible when location has no coordinates, `:proximity` when attendance has no coordinates

**Service spec**: `spec/application/services/attendances/record_attendance_spec.rb`
- Geo-fence tests: accept within radius, reject outside radius, reject missing coordinates
- Time-window tests: reject ended event, reject future event
- **Existing tests**: all use active events and pass unchanged
- **Dropped**: ~~1.1c event-specific radius~~ — variable fencing deferred
- **Frontend** (1.5): Removed client-side bounding box checks from `AttendanceTrack.vue` and `AllCourse.vue`. Error handling distinguishes geo-fence 403 from other errors.

### Slice 2: Duplicate Attendance Prevention

- **Add to**: `spec/application/services/attendances/record_attendance_spec.rb`
- **Test scenarios**: Reject same account+event, informative error message, allow different events

### Slice 3: Assignable Roles ✅

- **Domain policy spec**: `spec/domain/courses/policies/role_assignment_spec.rb` (9 tests)
  - `assignable_roles`: owner→all 4, instructor→staff+student, staff→student, student→empty, unknown→UnknownRoleError
  - `for_enrollment`: uses highest role, handles multi-role and empty roles
  - HIERARCHY constant test
- **Service spec**: `spec/application/services/courses/get_assignable_roles_spec.rb` (6 tests)
  - owner/instructor/staff/student permissions, non-enrolled→403, invalid course→404
- **Route tests**: added to `spec/routes/course_route_spec.rb` (3 tests)
  - owner→all roles, instructor→staff+student, non-enrolled→403
- **Design decision**: Owner CAN assign owner role (matches current frontend; no DB constraint on multiple owners)
- **Manual verification** (3.5): Confirmed via browser (owner sees 4-role dropdown) and API curl tests (owner→4 roles, instructor→staff+student, student→empty, non-enrolled→403, invalid course→404)

### Slice 4: Attendance Report ✅

**Status**: Complete. 29 tests across 6 spec files. Implemented on branch `ray/refactor-generate-report` in 3 phases.

**Service spec**: `spec/application/services/attendances/generate_report_spec.rb` (9 tests)
- Success flows: owner gets report, instructor gets report
- Authorization: student forbidden, non-enrolled forbidden
- Statistics: correct aggregation (1 event, 2 students), per-student sums and percentages
- Edge cases: zero events, invalid course ID

**Domain entity spec**: `spec/domain/attendance/entities/attendance_report_spec.rb` (7 tests)
- Report construction, event/student data structure
- Statistics for multiple students/events
- Zero events, empty enrollments
- StudentAttendanceRecord type verification

**Domain value specs**:
- `spec/domain/attendance/values/student_attendance_record_spec.rb` (4 tests) — full attendance (100%), partial (50%), zero events, value equality
- `spec/domain/attendance/values/attendance_register_spec.rb` (2 tests) — build from attendances, `#attended?` queries

**Presentation spec**: `spec/presentation/formatters/attendance_report_csv_spec.rb` (4 tests)
- CSV header generation, student rows with attendance, empty report, students with no events

**Route spec** (in `spec/routes/course_route_spec.rb`): 3 tests
- JSON response format, CSV download with correct headers, forbidden for students

### Slice 5: Enriched Event Responses

- **Add to**: route spec or new representer spec
- **Test scenarios**: Embedded location object, course_name field, user_attendance_status present/absent

### Slice 6: Capabilities-Based Visibility

- **Add to**: route spec or new representer spec
- **Test scenarios**: Owner gets full capabilities, instructor gets partial, student gets limited

## E2E Testing (Deferred)

E2E tests will be added if manual verification proves insufficient. Candidates:

| User Flow | Priority |
|-----------|----------|
| Record attendance (happy path) | HIGH |
| Record attendance (outside geo-fence) | HIGH |
| View attendance report | MEDIUM |

**Framework**: Playwright (recommended when needed)

## Questions

- [ ] Should E2E tests mock geolocation or use a test location?

## Completed

- [x] **GitHub Actions CI** — `.github/workflows/ci.yml` runs on Ubuntu + macOS, on PRs, main pushes, and manual dispatch. Generates JWT key, migrates test DB, runs full spec suite.
- [x] **Fix `rake generate:jwt_key`** — Updated to `Tyto::AuthToken::Gateway.generate_key`, requires only the gateway file (no DB connection needed). Fixed chicken-and-egg problem.
- [x] **Remove dead `load_lib` rake task** — No longer referenced.
- [x] **Bump sqlite3 to 2.x** — 1.7.3 arm64-darwin incompatible with Ruby 3.4. Widened constraint to `>= 1.0`, resolved to 2.9.0.

---

*Last updated: 2026-02-08*
