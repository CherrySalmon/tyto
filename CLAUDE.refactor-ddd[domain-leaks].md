# Domain Logic Leaks - Triage Document

This document tracks domain logic that has leaked outside of `backend_app/app/domain/`. These issues should be addressed to complete the DDD refactoring.

**Related**: See `CLAUDE.refactor-ddd.md` for the main refactoring plan.

---

## Summary

| # | Leak Type | Location | Severity | Status |
|---|-----------|----------|----------|--------|
| 1 | Policy role checking + service ORM queries | 4 policies, 20+ services | CRITICAL | Complete |
| 2 | ORM business logic (enrollment, accounts, roles) | `orm/course.rb` | CRITICAL | Complete |
| 3 | Coordinate validation duplication | `record_attendance.rb`, `create_location.rb` | HIGH | Complete |
| 4 | Time range logic in ORM | `orm/event.rb` | HIGH | Pending |

---

## Leak #1: Policy Role Checking + Service ORM Queries — COMPLETE

**Problem**: Policies duplicated role-checking logic, and 20+ services had inline ORM queries for enrollment lookup.

**Solution**:

- Added `find_enrollment(account_id:, course_id:)` to `Repository::Courses`
- Refactored all 4 policies to accept `Enrollment` entity and delegate to its predicates
- Updated all services to use repository method

**Completed**: 2026-01-30 | **Tests**: 621 pass | **Coverage**: 96.8%

---

## Leak #2: ORM Business Logic — COMPLETE

**Problem**: `orm/course.rb` contained ~150 lines of business logic that belonged in services/repositories.

**Solution**:

- Added `create_with_owner(entity, owner_account_id:)` to Courses repository
- Added `set_enrollment_roles(course_id:, account_id:, roles:)` to Courses repository
- Added `add_enrollment(course_id:, account_id:, roles:)` to Courses repository
- Added `find_or_create_by_email(email)` to Accounts repository (domain rule: new accounts get 'member' role)
- Updated `CreateCourse` service to use repository
- Updated `UpdateEnrollment` and `UpdateEnrollments` services to use repositories
- Removed 7 ORM methods: `create_course`, `add_or_update_enrollments`, `update_single_enrollment`, `add_or_find_account`, `update_course_account_roles`, `listByAccountID`, `get_enrollments`

**Completed**: 2026-01-30 | **Tests**: 634 pass | **Coverage**: 97.2%

---

## Leak #3: Coordinate Validation Duplication — COMPLETE

**Problem**: Coordinate validation existed in both domain types AND 3 services.

**Solution**:

- Added `GeoLocation.build` factory method with `InvalidCoordinatesError`
- Created `CoordinateValidation` concern module for shared validation logic
- Refactored 3 services to use the shared module (removed ~50 lines of duplicated code)

### Design Decision: Service calls GeoLocation directly (not through aggregate root)

**Rationale**:

1. **Value objects are self-validating** — `GeoLocation` validates at construction via dry-types. No need for aggregate root mediation.

2. **Type constraint, not business invariant** — "Latitude must be -90 to 90" is a type constraint, not a business rule spanning entities.

3. **Course aggregate has no role here** — Adding `Course#build_location(...)` would be artificial coupling.

4. **Attendance is in different bounded context** — It imports `GeoLocation` from `courses/values/`. Going through `Course` would couple contexts.

**Completed**: 2026-01-30 | **Tests**: 651 pass | **Coverage**: 97.3%

---

## Leak #4: Time Range Logic in ORM — PENDING

**Problem**: Event active check is in ORM query, not domain predicate.

**ORM** (`orm/event.rb`):

```ruby
events = Event.where{start_at <= time}.where{end_at >= time}
```

**Fix**: Domain `Event` should have `active_at?(time)` predicate using `TimeRange#contains?(time)`.

---

## Completed Work Log

### 2026-01-30: Leak #3 Complete

**Domain changes**:

- `GeoLocation.build(longitude:, latitude:)` — Factory method with friendly error messages
- `GeoLocation::InvalidCoordinatesError` — Domain-specific exception

**Shared concern created**:

- `services/concerns/coordinate_validation.rb` — `CoordinateValidation` module with `validate_coordinates` method

**Services refactored**:

- `CreateLocation` — Removed 18 lines, now uses shared module
- `UpdateLocation` — Removed 21 lines, uses `resolve_coordinates` + shared module
- `RecordAttendance` — Removed 17 lines, now uses shared module

**Tests added**: 17 new tests

- `spec/domain/courses/values/geo_location_spec.rb` — 7 tests for `.build` factory
- `spec/application/services/concerns/coordinate_validation_spec.rb` — 10 tests for shared module

---

### 2026-01-30: Leak #2 Complete

**Repository methods added**:

- `Courses#create_with_owner(entity, owner_account_id:)` - Creates course with owner enrollment
- `Courses#set_enrollment_roles(course_id:, account_id:, roles:)` - Syncs enrollment roles
- `Courses#add_enrollment(course_id:, account_id:, roles:)` - Adds enrollment with roles
- `Accounts#find_or_create_by_email(email)` - Finds or creates account with 'member' role

**Services refactored**:

- `CreateCourse` - Now uses repository instead of ORM
- `UpdateEnrollment` - Uses repositories for email update and role sync
- `UpdateEnrollments` - Uses repositories for account lookup and role assignment

**ORM cleanup**:

- Removed 7 methods from `orm/course.rb` (~100 lines)
- Only `attributes` and `get_enroll_identity` remain (for API responses)

**Tests added**: 10 new tests for repository methods

### 2026-01-30: Leak #1 Complete

**Changes**:

- Added `find_enrollment(account_id:, course_id:)` to `Repository::Courses`
- Refactored `EventPolicy`, `LocationPolicy`, `AttendancePolicy`, `CoursePolicy`
- Updated 20+ services to use repository method
- Added `module Tyto` namespace to `CoursePolicy`
- Fixed double-lookup bug in `GetCourse` service

**Tests added**:

- `spec/infrastructure/database/repositories/courses_spec.rb` - 6 tests
- `spec/application/policies/event_policy_spec.rb` - 8 tests
- `spec/application/policies/location_policy_spec.rb` - 7 tests
- `spec/application/policies/attendance_policy_spec.rb` - 7 tests
- `spec/application/policies/course_policy_spec.rb` - 10 tests
