# Testing Strategy for Frontend-to-Backend Refactoring

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for testing during this refactoring.

## Branch

`refactor-frontend-ddd`

## Goal

Establish testing coverage that:

1. Validates new backend behavior as logic moves from frontend
2. Catches regressions during refactoring
3. Documents expected API contracts
4. Remains useful after refactoring is complete

## Current State

- [x] Testing strategy defined
- [x] Backend spec coverage reviewed
- [ ] E2E framework selected
- [ ] Critical path tests written

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
| Attendance Recording | ✅ Good (basic) | ✅ Good | ❌ Geo-fence, duplicates |
| Role Assignment | ✅ Excellent | ✅ Good | ❌ Assignable roles logic |
| Event Responses | ✅ Good | ✅ Good | ❌ Enriched data |
| Course Reports | ❌ None | ❌ None | ❌ Everything |
| Repositories | ✅ Excellent | — | ❌ Duplicate query |
| Policies | ✅ Excellent | ✅ Good | ❌ Capabilities matrix |

### Existing Test Infrastructure

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
| Policy test template | `spec/application/policies/attendance_policy_spec.rb` |
| Domain entity test | `spec/domain/attendance/entities/attendance_spec.rb` |

## Testing Layers

### Layer 1: Backend API Specs (Priority: HIGH)

**Purpose**: Verify new backend logic works correctly as it's implemented.

**Location**: `backend_app/spec/`

**Focus Areas**:

| Feature | Spec File | Status |
|---------|-----------|--------|
| Geo-fence validation | `spec/integration/attendances_spec.rb` | [ ] |
| Duplicate attendance check | `spec/integration/attendances_spec.rb` | [ ] |
| Assignable roles endpoint | `spec/integration/enrollments_spec.rb` | [ ] |
| Attendance report endpoint | `spec/integration/courses_spec.rb` | [ ] |
| Enriched event responses | `spec/integration/events_spec.rb` | [ ] |
| Capabilities in responses | `spec/integration/courses_spec.rb` | [ ] |

**Example Spec Structure**:

```ruby
# spec/integration/attendances_spec.rb
describe 'POST /api/events/:id/attendances' do
  context 'geo-fence validation' do
    it 'accepts attendance within radius'
    it 'rejects attendance outside radius with clear error'
    it 'uses event-specific geo_fence_radius_m'
  end

  context 'duplicate prevention' do
    it 'rejects duplicate attendance for same account+event'
    it 'returns existing attendance info on duplicate attempt'
  end
end
```

### Layer 2: E2E Acceptance Tests (Priority: MEDIUM)

**Purpose**: Verify user-facing behavior remains consistent through refactoring.

**Framework Options**:

- [ ] **Playwright** (Recommended: modern, fast, good Vue support)
- [ ] Cypress
- [ ] Other: ___________

**Critical Paths to Test**:

| User Flow | Priority | Status |
|-----------|----------|--------|
| Record attendance (happy path) | HIGH | [ ] |
| Record attendance (outside geo-fence) | HIGH | [ ] |
| View attendance report | HIGH | [ ] |
| Assign role to enrollment | MEDIUM | [ ] |
| Create/edit course | LOW | [ ] |

**Location**: `e2e/` or `frontend_app/e2e/`

### Layer 3: Frontend Unit Tests (Priority: LOW)

**Purpose**: Only for presentation logic that remains in frontend after refactoring.

**Note**: Do NOT write tests for logic that's moving to backend — those tests become obsolete.

**Candidates for Frontend Tests** (post-refactoring):
- Geolocation utility (`lib/geolocation.js`)
- Date formatting utility (`lib/dateFormatter.js`)
- Component rendering states

## Implementation Plan

### Phase 0: Setup & Review

- [ ] 0.1 Review existing backend spec coverage
- [ ] 0.2 Identify gaps in current specs
- [ ] 0.3 Choose E2E framework
- [ ] 0.4 Set up E2E infrastructure

### Phase 1: Backend Specs (Before Each Feature)

Write specs *before* implementing each feature from the main refactoring plan.

#### 1.1 Geo-fence Validation (`spec/application/services/attendances/record_attendance_spec.rb`)

Add to existing spec file:

```ruby
context 'geo-fence validation' do
  it 'accepts attendance within event geo-fence radius'
  it 'rejects attendance outside geo-fence with specific error message'
  it 'uses event-specific geo_fence_radius_m (not hardcoded)'
  it 'defaults to 55m radius when event has no custom radius'
end
```

- [ ] 1.1a Add geo-fence acceptance test (within radius)
- [ ] 1.1b Add geo-fence rejection test (outside radius)
- [ ] 1.1c Add test for event-specific radius
- [ ] 1.1d Add test for default radius fallback

#### 1.2 Duplicate Attendance (`spec/application/services/attendances/record_attendance_spec.rb`)

```ruby
context 'duplicate prevention' do
  it 'rejects duplicate attendance for same account+event'
  it 'returns informative error on duplicate attempt'
end
```

- [ ] 1.2a Add duplicate rejection test
- [ ] 1.2b Add test for error message clarity

#### 1.3 Assignable Roles Endpoint (NEW FILE)

Create `spec/application/services/enrollments/assignable_roles_spec.rb`:

```ruby
describe Services::Enrollments::AssignableRoles do
  context 'owner requesting' do
    it 'returns all assignable roles'
  end
  context 'instructor requesting' do
    it 'returns roles they can assign (student, staff)'
    it 'excludes owner role'
  end
  context 'student requesting' do
    it 'returns empty list'
  end
end
```

- [ ] 1.3a Create spec file with permission matrix tests
- [ ] 1.3b Add route test in `course_route_spec.rb`

#### 1.4 Attendance Report Endpoint (NEW FILE)

Create `spec/application/services/attendances/generate_report_spec.rb`:

```ruby
describe Services::Attendances::GenerateReport do
  it 'aggregates attendance by event'
  it 'includes attendance counts per role'
  it 'returns CSV format when requested'
  it 'requires staff+ authorization'
end
```

- [ ] 1.4a Create spec file with aggregation tests
- [ ] 1.4b Add CSV format test
- [ ] 1.4c Add route test in `course_route_spec.rb`

### Phase 2: E2E Critical Paths

- [ ] 2.1 Set up E2E test infrastructure
- [ ] 2.2 Write attendance recording flow test
- [ ] 2.3 Write attendance report flow test
- [ ] 2.4 Write role assignment flow test

### Phase 3: Maintain During Refactoring

- [ ] Update specs as API contracts evolve
- [ ] Run E2E tests after each major change
- [ ] Remove obsolete frontend tests

## Questions

- [ ] Should E2E tests mock geolocation or use a test location?
- [ ] What's the CI/CD situation? Will tests run automatically?
- [x] ~~Should we use factories (factory_bot) for test data?~~ **No — existing test helpers (`create_test_account`, etc.) work well; keep using them**

## Completed

(none yet)

---

*Last updated: 2025-02-05 (coverage review completed)*
