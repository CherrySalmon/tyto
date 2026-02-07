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
| Application policy test | `spec/application/policies/attendance_policy_spec.rb` |
| Domain policy test | `spec/domain/attendance/policies/attendance_proximity_spec.rb` |
| Domain entity test | `spec/domain/attendance/entities/attendance_spec.rb` |

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
| Course Reports | None | None | Everything |
| Repositories | Excellent | — | Duplicate query |
| Policies | Excellent | Good | Capabilities matrix |

## Per-Slice Test Plan

Each slice's test tasks (1.1a, 2.1a, etc.) are listed in `CLAUDE.refactor-frontend-ddd.md`. Below are testing-specific notes for each slice.

### Slice 1: Geo-fence Validation ✅

Two levels of testing — domain policy (business rule) and service (orchestration):

**Domain policy spec**: `spec/domain/attendance/policies/attendance_proximity_spec.rb`
- 1.1e Threshold constant is 0.055 km (~55m)
- Satisfied when at event location (exact match)
- Satisfied when within 55m (~30m away)
- Not satisfied when beyond 55m (~32km away)
- Satisfied when event location is nil (nothing to validate against)
- Satisfied when event location has no coordinates
- Not satisfied when attendance has no coordinates but event location does

**Service spec**: `spec/application/services/attendances/record_attendance_spec.rb`
- Tests in `describe 'Geo-fence validation'` block:
  - 1.1a Accept within radius — student coords match location (40.7128, -74.0060) → Success
  - 1.1b Reject outside radius — student at (41.0, -74.0) ~32km away → Failure(:forbidden) with "geo-fence" message
  - 1.1d Reject when no coordinates — missing lat/lng is a bypass attempt → Failure(:forbidden) with "coordinates" message
- **Existing tests updated**: "auto-generated name", "persists attendance", and "Representer integration" tests now send coordinates to remain passing after geo-fence enforcement
- **Note**: Domain entity tests for `within_range?` already exist — domain policy tests cover the business rule (threshold + edge cases), service tests cover orchestration
- **Dropped**: ~~1.1c event-specific radius~~ — variable fencing deferred to future work

### Slice 2: Duplicate Attendance Prevention

- **Add to**: `spec/application/services/attendances/record_attendance_spec.rb`
- **Test scenarios**: Reject same account+event, informative error message, allow different events

### Slice 3: Assignable Roles

- **New file**: `spec/application/services/enrollments/get_assignable_roles_spec.rb`
- **Add route test to**: `spec/routes/course_route_spec.rb`
- **Test scenarios**: Owner sees all assignable roles (not owner), instructor sees staff+student, student sees empty, non-enrolled gets forbidden

### Slice 4: Attendance Report

- **New file**: `spec/application/services/attendances/generate_report_spec.rb`
- **Add route test to**: `spec/routes/course_route_spec.rb`
- **Test scenarios**: Aggregation by event, summary stats, CSV format, staff+ authorization required

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

*Last updated: 2026-02-07*
