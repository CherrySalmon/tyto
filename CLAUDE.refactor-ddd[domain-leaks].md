# Domain Logic Leaks - Triage Document

This document tracks domain logic that has leaked outside of `backend_app/app/domain/`. These issues should be addressed to complete the DDD refactoring.

**Related**: See `CLAUDE.refactor-ddd.md` for the main refactoring plan.

---

## Summary

| # | Leak Type | Location | Severity | Status |
|---|-----------|----------|----------|--------|
| 1 | Policy role checking + service ORM queries | 4 policies, 20+ services | CRITICAL | Complete |
| 2 | ORM business logic (enrollment, accounts, roles) | `orm/course.rb` | CRITICAL | Complete |
| 3 | Coordinate validation duplication | `record_attendance.rb`, `create_location.rb` | HIGH | Pending |
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

## Leak #3: Coordinate Validation Duplication — PENDING

**Problem**: Coordinate validation exists in both domain types AND services.

**Domain** (`domain/courses/values/geo_location.rb`):

```ruby
attribute :longitude, Types::Float.constrained(gteq: -180.0, lteq: 180.0)
attribute :latitude, Types::Float.constrained(gteq: -90.0, lteq: 90.0)
```

**Services** (`record_attendance.rb`, `create_location.rb`):

```ruby
return Failure(bad_request('Longitude must be between -180 and 180')) unless lng.between?(-180, 180)
```

**Fix**: Services should create `GeoLocation` and catch constraint errors instead of duplicating validation.

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
