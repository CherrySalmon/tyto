# Testing Strategy for Frontend-to-Backend Refactoring

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for testing during this refactoring.

> **SYNC REQUIRED**: This document must stay aligned with `CLAUDE.refactor-frontend-ddd.md`. Task IDs must match across both files. When updating tasks in one file, update the other.

## Branch

`refactor-frontend-ddd`

## Goal

Establish testing coverage that:

1. Validates new backend behavior as logic moves from frontend
2. Catches regressions during refactoring
3. Documents expected API contracts
4. Remains useful after refactoring is complete

## Strategy: Test-First Vertical Slices

Testing is integrated into each vertical slice (see main refactoring plan):

1. **Write failing backend test** — Documents expected behavior
2. **Implement backend** — Make the test pass
3. **Update frontend** — Remove old logic, consume new API
4. **Verify end-to-end** — Manual test or E2E automation

This ensures tests are written for features the frontend actually needs, not speculative functionality.

## Current State

- [x] Testing strategy defined
- [x] Backend spec coverage reviewed
- [x] Vertical slice strategy adopted
- [ ] E2E framework selected (deferred until needed)
- [ ] Slice 1 tests written

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

---

## Slice Testing Details

### Slice 1: Geo-fence Validation Tests

**File**: `spec/application/services/attendances/record_attendance_spec.rb` (add to existing)

```ruby
describe 'geo-fence validation' do
  def create_location_at(course, lat:, lng:)
    Tyto::Location.create(
      course_id: course.id,
      name: 'Test Location',
      latitude: lat,
      longitude: lng
    )
  end

  def create_event_with_geo_fence(course, location, radius_m: nil)
    attrs = {
      course_id: course.id,
      location_id: location.id,
      name: 'Test Event',
      start_at: Time.now - 1800,
      end_at: Time.now + 1800
    }
    attrs[:geo_fence_radius_m] = radius_m if radius_m
    Tyto::Event.create(attrs)
  end

  it 'accepts attendance within geo-fence radius' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_location_at(course, lat: 40.7128, lng: -74.0060)
    event = create_event_with_geo_fence(course, location, radius_m: 100)

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    result = Tyto::Service::Attendances::RecordAttendance.new.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: {
        'event_id' => event.id,
        'latitude' => 40.7128,   # Same as location
        'longitude' => -74.0060
      }
    )

    _(result.success?).must_equal true
  end

  it 'rejects attendance outside geo-fence with specific error' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_location_at(course, lat: 40.7128, lng: -74.0060)
    event = create_event_with_geo_fence(course, location, radius_m: 100)

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    result = Tyto::Service::Attendances::RecordAttendance.new.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: {
        'event_id' => event.id,
        'latitude' => 41.0,      # ~30km away
        'longitude' => -74.0
      }
    )

    _(result.failure?).must_equal true
    _(result.failure.status).must_equal :forbidden
    _(result.failure.message).must_match(/outside.*range|too far/i)
  end

  it 'uses event-specific geo_fence_radius_m' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_location_at(course, lat: 40.7128, lng: -74.0060)
    # Very small radius (10m) - coords ~50m away should fail
    tight_event = create_event_with_geo_fence(course, location, radius_m: 10)

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    result = Tyto::Service::Attendances::RecordAttendance.new.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: {
        'event_id' => tight_event.id,
        'latitude' => 40.7132,   # ~50m north
        'longitude' => -74.0060
      }
    )

    _(result.failure?).must_equal true
  end

  it 'defaults to 55m radius when event has no custom radius' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_location_at(course, lat: 40.7128, lng: -74.0060)
    default_event = create_event_with_geo_fence(course, location) # no radius_m

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    result = Tyto::Service::Attendances::RecordAttendance.new.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: {
        'event_id' => default_event.id,
        'latitude' => 40.71305,  # ~30m north, should pass 55m default
        'longitude' => -74.0060
      }
    )

    _(result.success?).must_equal true
  end
end
```

**Tasks**:

- [ ] 1.1a Add geo-fence acceptance test (within radius)
- [ ] 1.1b Add geo-fence rejection test (outside radius)
- [ ] 1.1c Add test for event-specific radius
- [ ] 1.1d Add test for default radius fallback

---

### Slice 2: Duplicate Attendance Tests

**File**: `spec/application/services/attendances/record_attendance_spec.rb` (add to existing)

```ruby
describe 'duplicate prevention' do
  it 'rejects duplicate attendance for same account+event' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_test_location(course)
    event = create_test_event(course, location)

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    service = Tyto::Service::Attendances::RecordAttendance.new

    # First attendance succeeds
    first_result = service.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: { 'event_id' => event.id }
    )
    _(first_result.success?).must_equal true

    # Second attendance fails
    second_result = service.call(
      requestor: requestor,
      course_id: course.id,
      attendance_data: { 'event_id' => event.id }
    )

    _(second_result.failure?).must_equal true
    _(second_result.failure.status).must_equal :conflict
  end

  it 'returns informative error message on duplicate' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_test_location(course)
    event = create_test_event(course, location)

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    service = Tyto::Service::Attendances::RecordAttendance.new

    service.call(requestor: requestor, course_id: course.id,
                 attendance_data: { 'event_id' => event.id })

    result = service.call(requestor: requestor, course_id: course.id,
                          attendance_data: { 'event_id' => event.id })

    _(result.failure.message).must_match(/already recorded|duplicate/i)
  end

  it 'allows same user to attend different events' do
    owner = create_test_account(roles: ['creator'])
    course = create_test_course(owner)
    location = create_test_location(course)
    event1 = create_test_event(course, location, name: 'First Event')
    event2 = create_test_event(course, location, name: 'Second Event')

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    requestor = Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: student.id, roles: ['member'])
    service = Tyto::Service::Attendances::RecordAttendance.new

    result1 = service.call(requestor: requestor, course_id: course.id,
                           attendance_data: { 'event_id' => event1.id })
    result2 = service.call(requestor: requestor, course_id: course.id,
                           attendance_data: { 'event_id' => event2.id })

    _(result1.success?).must_equal true
    _(result2.success?).must_equal true
  end
end
```

**Tasks**:

- [ ] 2.1a Add duplicate rejection test
- [ ] 2.1b Add error message clarity test
- [ ] 2.1c Add test allowing different events

---

### Slice 3: Assignable Roles Tests

**File**: `spec/application/services/enrollments/get_assignable_roles_spec.rb` (NEW)

```ruby
# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Enrollments::GetAssignableRoles' do
  include TestHelpers

  def create_test_course(owner_account, name: 'Test Course')
    course = Tyto::Course.create(name: name)
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(
      course_id: course.id,
      account_id: owner_account.id,
      role_id: owner_role.id
    )
    course
  end

  def enroll_as(account, course, role_name)
    role = Tyto::Role.find(name: role_name)
    Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: role.id)
  end

  def make_requestor(account)
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member'])
  end

  describe '#call' do
    describe 'owner requesting' do
      it 'returns all assignable roles (instructor, staff, student)' do
        owner = create_test_account(roles: ['creator'])
        course = create_test_course(owner)
        requestor = make_requestor(owner)

        result = Tyto::Service::Enrollments::GetAssignableRoles.new.call(
          requestor: requestor, course_id: course.id
        )

        _(result.success?).must_equal true
        role_names = result.value!.message.map { |r| r[:name] }
        _(role_names).must_include 'instructor'
        _(role_names).must_include 'staff'
        _(role_names).must_include 'student'
      end

      it 'excludes owner role (cannot assign another owner)' do
        owner = create_test_account(roles: ['creator'])
        course = create_test_course(owner)
        requestor = make_requestor(owner)

        result = Tyto::Service::Enrollments::GetAssignableRoles.new.call(
          requestor: requestor, course_id: course.id
        )

        role_names = result.value!.message.map { |r| r[:name] }
        _(role_names).wont_include 'owner'
      end
    end

    describe 'instructor requesting' do
      it 'returns staff and student roles only' do
        owner = create_test_account(roles: ['creator'])
        course = create_test_course(owner)

        instructor = create_test_account(name: 'Instructor', roles: ['member'])
        enroll_as(instructor, course, 'instructor')
        requestor = make_requestor(instructor)

        result = Tyto::Service::Enrollments::GetAssignableRoles.new.call(
          requestor: requestor, course_id: course.id
        )

        _(result.success?).must_equal true
        role_names = result.value!.message.map { |r| r[:name] }
        _(role_names).must_include 'staff'
        _(role_names).must_include 'student'
        _(role_names).wont_include 'instructor'
        _(role_names).wont_include 'owner'
      end
    end

    describe 'student requesting' do
      it 'returns empty list' do
        owner = create_test_account(roles: ['creator'])
        course = create_test_course(owner)

        student = create_test_account(name: 'Student', roles: ['member'])
        enroll_as(student, course, 'student')
        requestor = make_requestor(student)

        result = Tyto::Service::Enrollments::GetAssignableRoles.new.call(
          requestor: requestor, course_id: course.id
        )

        _(result.success?).must_equal true
        _(result.value!.message).must_be_empty
      end
    end

    describe 'non-enrolled user' do
      it 'returns forbidden' do
        owner = create_test_account(roles: ['creator'])
        course = create_test_course(owner)

        outsider = create_test_account(name: 'Outsider', roles: ['member'])
        requestor = make_requestor(outsider)

        result = Tyto::Service::Enrollments::GetAssignableRoles.new.call(
          requestor: requestor, course_id: course.id
        )

        _(result.failure?).must_equal true
        _(result.failure.status).must_equal :forbidden
      end
    end
  end
end
```

**Route test** in `spec/routes/course_route_spec.rb`:

```ruby
describe 'GET /api/courses/:id/assignable_roles' do
  it 'returns roles for authorized user' do
    account, header = authenticated_header(roles: ['creator'])
    course = Tyto::Course.create(name: 'Test Course')
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: owner_role.id)

    get "/api/courses/#{course.id}/assignable_roles", nil, header

    _(last_response.status).must_equal 200
    _(json_response).must_be_kind_of Array
  end
end
```

**Tasks**:

- [ ] 3.1a Create spec file with owner permission tests
- [ ] 3.1b Add instructor permission tests
- [ ] 3.1c Add student permission tests
- [ ] 3.1d Add route integration test

---

### Slice 4: Attendance Report Tests

**File**: `spec/application/services/attendances/generate_report_spec.rb` (NEW)

```ruby
# frozen_string_literal: true

require_relative '../../../spec_helper'

describe 'Service::Attendances::GenerateReport' do
  include TestHelpers

  def create_test_course(owner_account)
    course = Tyto::Course.create(name: 'Test Course')
    owner_role = Tyto::Role.find(name: 'owner')
    Tyto::AccountCourse.create(course_id: course.id, account_id: owner_account.id, role_id: owner_role.id)
    course
  end

  def enroll_as(account, course, role_name)
    role = Tyto::Role.find(name: role_name)
    Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: role.id)
  end

  def make_requestor(account)
    Tyto::Domain::Accounts::Values::AuthCapability.new(account_id: account.id, roles: ['member'])
  end

  describe '#call' do
    it 'aggregates attendance by event' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      location = create_test_location(course)
      event = create_test_event(course, location)

      # Create some attendances
      student = create_test_account(name: 'Student', roles: ['member'])
      enroll_as(student, course, 'student')
      Tyto::Attendance.create(account_id: student.id, course_id: course.id, event_id: event.id)

      staff = create_test_account(name: 'Staff', roles: ['member'])
      enroll_as(staff, course, 'staff')
      requestor = make_requestor(staff)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor, course_id: course.id
      )

      _(result.success?).must_equal true
      report = result.value!.message
      _(report[:events]).must_be_kind_of Array
      _(report[:events].first).must_include :event_name
      _(report[:events].first).must_include :attendance_count
    end

    it 'includes attendance counts and percentages' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      requestor = make_requestor(owner)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor, course_id: course.id
      )

      report = result.value!.message
      _(report[:summary]).must_include :total_events
      _(report[:summary]).must_include :total_attendances
    end

    it 'returns CSV format when requested' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)
      requestor = make_requestor(owner)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor,
        course_id: course.id,
        format: :csv
      )

      _(result.success?).must_equal true
      _(result.value!.message).must_be_kind_of String
      _(result.value!.message).must_include 'Event,Date,Attendees'
    end

    it 'requires staff+ authorization' do
      owner = create_test_account(roles: ['creator'])
      course = create_test_course(owner)

      student = create_test_account(name: 'Student', roles: ['member'])
      enroll_as(student, course, 'student')
      requestor = make_requestor(student)

      result = Tyto::Service::Attendances::GenerateReport.new.call(
        requestor: requestor, course_id: course.id
      )

      _(result.failure?).must_equal true
      _(result.failure.status).must_equal :forbidden
    end
  end
end
```

**Tasks**:

- [ ] 4.1a Create spec file with aggregation tests
- [ ] 4.1b Add summary statistics tests
- [ ] 4.1c Add CSV format test
- [ ] 4.1d Add authorization test
- [ ] 4.1e Add route integration test

---

### Slice 5: Enriched Event Response Tests

**File**: `spec/presentation/representers/event_representer_spec.rb` or route spec

```ruby
describe 'Event representer with enriched data' do
  include TestHelpers

  def setup_course_with_event
    owner = create_test_account(roles: ['creator'])
    course = Tyto::Course.create(name: 'Test Course')
    location = Tyto::Location.create(
      course_id: course.id, name: 'Room 101',
      latitude: 40.7128, longitude: -74.0060
    )
    event = Tyto::Event.create(
      course_id: course.id, location_id: location.id,
      name: 'Lecture 1', start_at: Time.now, end_at: Time.now + 3600
    )
    [course, location, event, owner]
  end

  it 'includes embedded location object' do
    course, location, event, _owner = setup_course_with_event
    json = Tyto::Representer::Event.new(event).to_hash

    _(json['location']).must_be_kind_of Hash
    _(json['location']['name']).must_equal 'Room 101'
    _(json['location']['latitude']).must_equal 40.7128
  end

  it 'includes course_name' do
    course, _location, event, _owner = setup_course_with_event
    json = Tyto::Representer::Event.new(event).to_hash

    _(json['course_name']).must_equal 'Test Course'
  end

  it 'includes user_attendance_status when user has attended' do
    course, location, event, owner = setup_course_with_event
    Tyto::Attendance.create(account_id: owner.id, course_id: course.id, event_id: event.id)

    json = Tyto::Representer::Event.new(event, user_context: owner).to_hash

    _(json['user_attendance_status']).must_equal 'recorded'
  end

  it 'returns nil user_attendance_status when user has not attended' do
    _course, _location, event, owner = setup_course_with_event

    json = Tyto::Representer::Event.new(event, user_context: owner).to_hash

    _(json['user_attendance_status']).must_be_nil
  end
end
```

**Tasks**:

- [ ] 5.1a Add embedded location test
- [ ] 5.1b Add course_name test
- [ ] 5.1c Add user_attendance_status tests

---

### Slice 6: Capabilities Tests

**File**: `spec/presentation/representers/course_representer_spec.rb` or route spec

```ruby
describe 'Course representer with capabilities' do
  include TestHelpers

  def create_course_with_enrollment(account, role_name)
    course = Tyto::Course.create(name: 'Test Course')
    role = Tyto::Role.find(name: role_name)
    Tyto::AccountCourse.create(course_id: course.id, account_id: account.id, role_id: role.id)
    course
  end

  it 'includes full capabilities for owner' do
    owner = create_test_account(roles: ['creator'])
    course = create_course_with_enrollment(owner, 'owner')

    json = Tyto::Representer::Course.new(course, user_context: owner).to_hash

    _(json['capabilities']['can_edit']).must_equal true
    _(json['capabilities']['can_delete']).must_equal true
    _(json['capabilities']['can_manage_enrollments']).must_equal true
  end

  it 'includes partial capabilities for instructor' do
    owner = create_test_account(roles: ['creator'])
    course = create_course_with_enrollment(owner, 'owner')

    instructor = create_test_account(name: 'Instructor', roles: ['member'])
    instructor_role = Tyto::Role.find(name: 'instructor')
    Tyto::AccountCourse.create(course_id: course.id, account_id: instructor.id, role_id: instructor_role.id)

    json = Tyto::Representer::Course.new(course, user_context: instructor).to_hash

    _(json['capabilities']['can_edit']).must_equal true
    _(json['capabilities']['can_delete']).must_equal false
    _(json['capabilities']['can_manage_enrollments']).must_equal true
  end

  it 'includes limited capabilities for student' do
    owner = create_test_account(roles: ['creator'])
    course = create_course_with_enrollment(owner, 'owner')

    student = create_test_account(name: 'Student', roles: ['member'])
    student_role = Tyto::Role.find(name: 'student')
    Tyto::AccountCourse.create(course_id: course.id, account_id: student.id, role_id: student_role.id)

    json = Tyto::Representer::Course.new(course, user_context: student).to_hash

    _(json['capabilities']['can_edit']).must_equal false
    _(json['capabilities']['can_delete']).must_equal false
    _(json['capabilities']['can_manage_enrollments']).must_equal false
  end
end
```

**Tasks**:

- [ ] 6.1a Add capabilities tests for owner
- [ ] 6.1b Add capabilities tests for instructor
- [ ] 6.1c Add capabilities tests for student

---

## E2E Testing (Deferred)

E2E tests will be added if manual verification proves insufficient. Candidates:

| User Flow | Priority | Status |
|-----------|----------|--------|
| Record attendance (happy path) | HIGH | [ ] Deferred |
| Record attendance (outside geo-fence) | HIGH | [ ] Deferred |
| View attendance report | MEDIUM | [ ] Deferred |

**Framework**: Playwright (recommended when needed)

---

## Questions

- [ ] Should E2E tests mock geolocation or use a test location?
- [x] ~~What's the CI/CD situation? Will tests run automatically?~~ **Yes — GitHub Actions CI now runs on all PRs and pushes to main**
- [x] ~~Should we use factories (factory_bot) for test data?~~ **No — existing test helpers work well**

## Completed

- [x] **GitHub Actions CI** — Added `.github/workflows/ci.yml` that runs backend tests automatically on PRs (any branch), pushes to main, and manual dispatch. Setup includes libsodium, Ruby (from `.ruby-version`), SQLite, JWT key generation, and test database migration/seeding.
- [x] **Fix `rake generate:jwt_key`** — Task was broken after DDD refactor (referenced removed `Tyto::JWTCredential`). Fixed to use `Tyto::AuthToken::Gateway.generate_key` and require only the gateway file (no database connection needed). This also fixed a chicken-and-egg problem where the task couldn't run without `secrets.yml` already existing.
- [x] **Remove dead `load_lib` rake task** — No longer referenced after `generate:jwt_key` was decoupled from it.

---

*Last updated: 2026-02-06*
