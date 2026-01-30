# DDD Refactoring Plan for Tyto

## Overview

This document tracks the incremental extraction of domain code into a clean DDD architecture, following the patterns established in `api-codepraise`.

**Strategy**: Move first, transform later. We reorganize existing code into the target structure before introducing new abstractions (entities, repositories, etc.).

## Target Architecture

```text
backend_app/
├── app/                           # All runtime code
│   ├── domain/                    # Pure domain layer (no framework dependencies)
│   │   ├── types.rb               # Shared constrained types (CourseName, Email, etc.)
│   │   ├── courses/               # Course bounded context
│   │   │   ├── entities/
│   │   │   └── values/
│   │   ├── accounts/              # Account bounded context
│   │   │   ├── entities/
│   │   │   └── values/
│   │   ├── attendance/            # Attendance bounded context
│   │   │   ├── entities/
│   │   │   └── values/
│   │   └── shared/                # Shared kernel (cross-context values)
│   │       └── values/
│   │
│   ├── infrastructure/            # External adapters
│   │   ├── database/
│   │   │   ├── orm/               # Sequel models
│   │   │   └── repositories/      # Data mappers between ORM and domain
│   │   └── auth/                  # Authentication boundary adapters
│   │       ├── sso_auth.rb        # Google OAuth verification
│   │       └── auth_token/        # JWT token handling
│   │           ├── gateway.rb     # Encryption/decryption (RbNaCl)
│   │           └── mapper.rb      # AuthCapability ↔ token transformation
│   │
│   ├── application/               # Use cases and orchestration
│   │   ├── controllers/           # Roda routes (thin HTTP layer)
│   │   ├── services/              # Use case classes
│   │   ├── policies/              # Authorization
│   │   ├── contracts/             # Input validation (dry-validation, imports domain types)
│   │   └── responses/             # Response DTOs
│   │
│   ├── presentation/              # API responses
│   │   └── representers/          # JSON serialization
│   │
│   └── lib/                       # Cross-cutting utilities (currently empty)
│
├── config/
├── db/                            # Database tooling (not auto-loaded)
│   ├── migrations/                # Sequel migrations
│   ├── seeds/                     # Seed data
│   └── store/                     # SQLite files (dev/test)
│
└── spec/
```

## Bounded Contexts Identified

### Courses (Aggregate Root: Course)

- **Entities**: Course, Event, Location
- **Values**: TimeRange, GeoLocation

### Accounts (Aggregate Root: Account)

- **Entities**: Account
- **Values**: Email, Role, AuthCapability (authenticated identity from JWT)

### Attendance (Aggregate Root: Attendance)

- **Entities**: Attendance
- **Values**: CheckInData

### Enrollments (Aggregate Root: Course or separate)

- **Entities**: Enrollment (AccountCourse)
- **Values**: CourseRole

---

## Type System and Validation Strategy

We use **dry-struct** for domain entities and **dry-validation** for input contracts, with **shared constrained types** to avoid duplication.

### Layered Responsibilities

| Layer           | Tool                      | Responsibility                                         |
|-----------------|---------------------------|--------------------------------------------------------|
| **Domain**      | dry-struct + shared Types | Structure, type safety, immutable updates              |
| **Application** | dry-validation contracts  | Business rules, input coercion, cross-field validation |

### Shared Types (domain/types.rb)

Types live in the **domain layer** because they express domain vocabulary. Application contracts import from domain (dependency flows inward).

```ruby
# domain/types.rb
module Tyto
  module Types
    include Dry.Types()

    # Constrained types - shared by entities AND contracts
    CourseName = Types::String.constrained(min_size: 1, max_size: 200)
    Email = Types::String.constrained(format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i)
    CourseRole = Types::String.enum('owner', 'instructor', 'staff', 'student')
  end
end
```

### Domain Entities (dry-struct)

Entities use shared types for structure. **Type constraints are enforced on construction AND immutable updates**:

```ruby
# domain/courses/entities/course.rb
class Course < Dry::Struct
  attribute :id, Types::Integer.optional
  attribute :name, Types::CourseName        # Constrained type
  attribute :start_at, Types::Time
  attribute :end_at, Types::Time

  def active? = Time.now.between?(start_at, end_at)
end

# Type constraints enforced on immutable updates:
course.new(name: "")  # ❌ Raises Dry::Struct::Error
```

**Note on custom invariants**: Custom class-level `new` overrides (e.g., for cross-field validation like "end_at must be after start_at") are only invoked on initial construction, not on instance `new()` updates. This is a dry-struct limitation. Cross-field invariants should be enforced at the contract/service layer.

### Application Contracts (dry-validation)

Contracts handle input validation and complex business rules, importing domain types:

```ruby
# application/contracts/create_course_contract.rb
require_relative '../../domain/types'

class CreateCourseContract < Dry::Validation::Contract
  params do
    required(:name).filled(Tyto::Types::CourseName)  # Reuse domain type
    required(:start_at).filled(:time)
    required(:end_at).filled(:time)
  end

  # Business rules stay in contracts
  rule(:start_at, :end_at) do
    key(:end_at).failure('must be after start_at') if values[:end_at] <= values[:start_at]
  end
end
```

### Workflow

1. **Validate input** with contract (coerces strings, checks business rules)
2. **Create entity** from validated data (type-safe, immutable)
3. **Entity updates** via `new()` re-enforce constraints

```ruby
result = CreateCourseContract.new.call(params)
return Failure(result.errors) if result.failure?

course = Course.new(result.to_h)  # Safe - already validated
```

---

## Phase 0: Reorganize Existing Code (Complete)

**Goal**: Move existing files to new folder structure without changing behavior. All tests must pass after each step.

### 0.1 Create folder structure

- [x] Create `backend_app/infrastructure/database/orm/`
- [x] Create `backend_app/application/services/`
- [x] Create `backend_app/application/policies/`
- [x] Create `backend_app/infrastructure/auth/`

### 0.2 Move ORM models

Move models to `infrastructure/database/orm/`:

- [x] `models/account.rb` → `infrastructure/database/orm/account.rb`
- [x] `models/account_course.rb` → `infrastructure/database/orm/account_course.rb`
- [x] `models/account_role.rb` → `infrastructure/database/orm/account_role.rb`
- [x] `models/attendance.rb` → `infrastructure/database/orm/attendance.rb`
- [x] `models/course.rb` → `infrastructure/database/orm/course.rb`
- [x] `models/event.rb` → `infrastructure/database/orm/event.rb`
- [x] `models/location.rb` → `infrastructure/database/orm/location.rb`
- [x] `models/role.rb` → `infrastructure/database/orm/role.rb`
- [x] Delete empty `models/` folder
- [x] Update `require_app.rb` to load from new path
- [x] Run tests to verify

### 0.3 Move services

Move services to `application/services/`:

- [x] `services/account_service.rb` → `application/services/account_service.rb`
- [x] `services/attendance_service.rb` → `application/services/attendance_service.rb`
- [x] `services/course_service.rb` → `application/services/course_service.rb`
- [x] `services/event_service.rb` → `application/services/event_service.rb`
- [x] `services/location_service.rb` → `application/services/location_service.rb`
- [x] `services/sso_auth.rb` → `infrastructure/auth/sso_auth.rb`
- [x] Delete empty `services/` folder
- [x] Update `require_app.rb` to load from new paths
- [x] Update `require_relative` paths in services for policies
- [x] Run tests to verify

### 0.4 Move policies

Move policies to `application/policies/`:

- [x] `policies/account_policy.rb` → `application/policies/account_policy.rb`
- [x] `policies/attendance_policy.rb` → `application/policies/attendance_policy.rb`
- [x] `policies/course_policy.rb` → `application/policies/course_policy.rb`
- [x] `policies/course_scopes.rb` → `application/policies/course_scopes.rb`
- [x] `policies/event_policy.rb` → `application/policies/event_policy.rb`
- [x] `policies/location_policy.rb` → `application/policies/location_policy.rb`
- [x] `policies/role_policy.rb` → `application/policies/role_policy.rb`
- [x] Delete empty `policies/` folder
- [x] Update `require_relative` paths in services
- [x] Run tests to verify

### 0.5 Update controller requires

- [x] Update `controllers/app.rb` require paths
- [x] Update any other files with direct requires
- [x] Run full test suite
- [x] Commit: "Reorganize backend into DDD folder structure"

---

## Phase 1: Foundation - Domain Layer Setup

**Testing approach**: Write unit tests immediately after creating entities/values. Run existing integration tests after service changes.

### 1.1 Add DDD dependencies

- [x] Add `dry-struct` to Gemfile (dry-types comes as dependency)
- [x] `bundle install`
- [x] Run existing tests (sanity check)
- [x] Create `backend_app/domain/` folder structure
- [x] Create `domain/types.rb` with shared constrained types:
  - `Types::CourseName` (string, min 1 char)
  - `Types::Email` (string, email format)
  - `Types::CourseRole` (enum: owner, instructor, staff, student)
  - `Types::SystemRole` (enum: admin, creator, member)
- [x] Create loader/initializer for domain layer
- [x] Write unit tests for constrained types (`spec/domain/types_spec.rb`)

### 1.2 Extract first entity: Course

- [x] Create `domain/courses/entities/course.rb`
  - Pure Ruby class using Dry::Struct
  - No Sequel dependencies
  - Uses `Types::CourseName` for name attribute
  - Type-safe attributes: id, name, logo, start_at, end_at
  - Computed methods: `duration`, `active?`, `upcoming?`
- [x] Create `domain/shared/values/time_range.rb` (start_at/end_at pair)
- [x] Write unit tests for Course entity (`spec/domain/courses/entities/course_spec.rb`)
  - Include tests for constraint enforcement on `new()` updates
- [x] Write unit tests for TimeRange value (`spec/domain/shared/values/time_range_spec.rb`)
- [x] Run new unit tests

### 1.3 Create Course repository

- [x] Create `infrastructure/database/repositories/courses.rb`
  - `find_id(id)` → returns Domain::Entity::Course
  - `find_all` → returns array of Domain::Entity::Course
  - `create(course_entity)` → persists and returns entity
  - `rebuild_entity(orm_record)` → private mapper method
- [x] ORM remains in `orm/course.rb` (already moved in Phase 0)
- [x] Write integration tests for repository (`spec/infrastructure/database/repositories/courses_spec.rb`)
- [x] Run repository tests

### 1.4 Update CourseService to use repository

- [x] Inject repository instead of direct ORM access (incremental: list_all uses repository)
- [x] Add entity_to_hash bridge for API compatibility
- [x] Run ALL tests (existing + new) to verify integration
- [x] Commit Phase 1

---

## Phase 2: Complete Courses Context

### 2.1 Event entity

- [x] Add `Types::EventName` to `domain/types.rb`
- [x] Add `Types::LocationName`, `Types::Longitude`, `Types::Latitude` to `domain/types.rb`
- [x] Create `domain/courses/entities/event.rb`
- [x] Write unit tests for Event entity (`spec/domain/courses/entities/event_spec.rb`)
- [x] Create `infrastructure/database/repositories/events.rb`
- [x] Write integration tests for Events repository (`spec/infrastructure/database/repositories/events_spec.rb`)

### 2.2 Location entity and GeoLocation value

- [x] Create `domain/courses/values/geo_location.rb`
- [x] Create `domain/courses/values/null_geo_location.rb`
- [x] Write unit tests for GeoLocation and NullGeoLocation
- [x] Create `domain/courses/entities/location.rb`
- [x] Write unit tests for Location entity
- [x] Create `infrastructure/database/repositories/locations.rb`
- [x] Write integration tests for Locations repository

### 2.3 Course as Aggregate Root

- [x] Course entity has optional `events` and `locations` collections
- [x] Loading convention: `nil` = not loaded, `[]` = loaded but empty
- [x] Entity raises `ChildrenNotLoadedError` if business logic requires unloaded children
- [x] Repository methods: `find_id` (no children), `find_with_events`, `find_with_locations`, `find_full`
- [x] Write unit tests for Course aggregate behavior
- [x] Write integration tests for repository loading methods

---

## Phase 3: Accounts Context

### 3.1 Account entity

- [x] Create `domain/accounts/entities/account.rb`
- [x] Email validation via `Types::Email` (already in types.rb)
- [x] Roles as optional array with loading convention (nil = not loaded)
- [x] Role predicate methods: `admin?`, `creator?`, `member?`, `has_role?`
- [x] `RolesNotLoadedError` for fail-fast when roles required
- [x] Create `infrastructure/database/repositories/accounts.rb`
- [x] Repository methods: `find_with_roles`, `find_by_email`, `find_by_email_with_roles`
- [x] Write unit tests for Account entity
- [x] Write integration tests for Accounts repository

### 3.2 Role handling

- [x] System roles defined in `Types::SystemRole` enum: admin, creator, member
- [x] Course roles defined in `Types::CourseRole` enum: owner, instructor, staff, student
- [ ] *(Deferred)* Separate Role value object if needed for complex role logic

---

## Phase 4: Attendance Context

### 4.1 Attendance entity

- [x] Create `domain/attendance/entities/attendance.rb`
  - `check_in_location` returns GeoLocation or NullGeoLocation
  - `distance_to_event(location)` calculates distance from check-in to event
  - `within_range?(location, max_distance_km:)` for proximity validation
  - `has_coordinates?` predicate
- [x] Repository with event-scoped queries
  - `find_by_course(course_id)`
  - `find_by_event(event_id)`
  - `find_by_account_course(account_id, course_id)`
  - `find_by_account_event(account_id, event_id)`
- [x] Write unit tests for Attendance entity
- [x] Write integration tests for Attendances repository

---

## Phase 5: Enrollments

### 5.1 Enrollment as Course child entity

Decision: Enrollment is a **child entity of the Course aggregate** (like Events and Locations).
Rationale: Enrollments are always accessed in the context of a course, and course roles are course-specific vocabulary.

- [x] Create `domain/courses/entities/enrollment.rb`
  - Aggregates multiple roles per account into single entity
  - Role predicates: `owner?`, `instructor?`, `staff?`, `student?`
  - `teaching?` returns true for owner/instructor/staff
  - `has_role?(role_name)` for checking specific roles
- [x] Update Course entity with `enrollments` attribute
  - Loading convention: `nil` = not loaded, `[]` = loaded but empty
  - `find_enrollment(account_id)` to find by account
  - `enrollments_with_role(role)` to filter by role
  - `teaching_staff` and `students` helper methods
- [x] Update Courses repository
  - `find_with_enrollments` - loads enrollments only
  - `find_full` - now loads events, locations, AND enrollments
  - Aggregates AccountCourse rows into Enrollment entities
- [x] Write unit tests for Enrollment entity
- [x] Write integration tests for repository enrollment loading

---

## Phase 6: Application Layer Refactoring

### Problem: God Object Services

Current services violate Single Responsibility Principle. Comparison with `api-codepraise`:

| Aspect | Tyto (Anti-pattern) | Codepraise (DDD Convention) |
|--------|---------------------|----------------------------|
| Structure | 10+ methods per class | 1 use case per class |
| Naming | `CourseService` | `CreateCourse`, `ListCourses` |
| Authorization | `verify_policy` in every method | Separate request/policy layer |
| Error handling | `raise ForbiddenError` | `Success`/`Failure` results |
| Method style | Class methods (`self.`) | Instance with `call` |

**Example - Current `CourseService`** (God object with 10+ responsibilities):
- `list_all`, `list`, `create`, `get`, `update`, `remove` (CRUD)
- `remove_enroll`, `get_enrollments`, `update_enrollments`, `update_enrollment` (Enrollment management)

### Target Structure

Break monolithic services into focused use case classes:

```text
application/services/
├── events/
│   ├── list_events.rb           # Service::Events::ListEvents
│   ├── create_event.rb          # Service::Events::CreateEvent
│   ├── update_event.rb          # Service::Events::UpdateEvent
│   ├── delete_event.rb          # Service::Events::DeleteEvent
│   └── find_active_events.rb    # Service::Events::FindActiveEvents
├── locations/
│   ├── list_locations.rb
│   ├── create_location.rb
│   ├── update_location.rb
│   └── delete_location.rb
├── courses/
│   ├── list_all_courses.rb
│   ├── list_user_courses.rb
│   ├── create_course.rb
│   ├── get_course.rb
│   ├── update_course.rb
│   ├── delete_course.rb
│   └── enrollments/
│       ├── list_enrollments.rb
│       ├── add_enrollment.rb
│       ├── update_enrollment.rb
│       └── remove_enrollment.rb
├── attendances/
│   ├── list_attendances.rb
│   ├── list_attendances_by_event.rb
│   ├── record_attendance.rb
│   └── list_user_attendances.rb
└── accounts/
    ├── list_accounts.rb
    ├── create_account.rb
    ├── update_account.rb
    └── delete_account.rb
```

### Vertical Slice Approach

**Strategy change:** Instead of refactoring layer-by-layer (all services, then all representers), we implement each use case as a **complete vertical slice**:

```
Service + Representer + Controller update + Tests
```

This avoids writing code we won't need and ensures each endpoint works end-to-end before moving on.

**Each use case includes:**
1. Railway service class (dry-monads Success/Failure)
2. Representer for JSON output (if new entity type)
3. Controller updated to pattern-match on result
4. Unit tests for service
5. Integration tests pass

### Foundation (Complete)

- [x] Add `dry-monads` gem to Gemfile
- [x] Add `dry-operation` gem to Gemfile (modern replacement for dry-transaction)
- [x] Add `roar` + `multi_json` gems for representers
- [x] Create `application/responses/api_result.rb` - standardized response object
- [x] Create `application/services/application_operation.rb` - base class with response helpers
- [x] Create `presentation/representers/` folder

### Input Handling Philosophy

**Keep validation in services. Avoid premature abstraction.**

We deliberately avoid:
- **dry-validation contracts** - Add indirection without clear benefit for simple inputs
- **Request objects** - Solve a problem we don't have (computed derived values)

**Why validation belongs in services:**

1. **Cohesion** - Service IS the use case. Validation is part of that use case. One file to understand complete flow.
2. **YAGNI** - No proven need for reusable validation. CreateEvent and UpdateEvent validation will differ.
3. **Visibility** - Validation steps are explicit in the railway flow, not hidden in separate classes.

**Controller responsibility is minimal:**
- Parse JSON (or return 400 on parse error)
- Call service with parsed data
- Pattern match on result

**When to revisit:**
- Multiple services share complex validation logic
- You need computed derived values (cache keys, slugs)
- Validation rules become genuinely complex (nested objects, conditional fields)

### ApplicationOperation Base Class

All services inherit from `Service::ApplicationOperation` which provides response helpers:

```ruby
# application/services/application_operation.rb
class ApplicationOperation < Dry::Operation
  private

  def ok(message) = Response::ApiResult.new(status: :ok, message:)
  def created(message) = Response::ApiResult.new(status: :created, message:)
  def bad_request(message) = Response::ApiResult.new(status: :bad_request, message:)
  def not_found(message) = Response::ApiResult.new(status: :not_found, message:)
  def forbidden(message) = Response::ApiResult.new(status: :forbidden, message:)
  def internal_error(message) = Response::ApiResult.new(status: :internal_error, message:)
end
```

### Service Pattern

Services inherit from `ApplicationOperation` and use `step` for railway-oriented flow:

```ruby
class CreateEvent < ApplicationOperation
  def initialize(events_repo: Repository::Events.new)
    @events_repo = events_repo
    super()  # Required after setting instance variables
  end

  def call(requestor:, course_id:, event_data:)
    course_id = step validate_course_id(course_id)
    step verify_course_exists(course_id)
    step authorize(requestor, course_id)
    validated = step validate_input(event_data, course_id)  # Validation HERE
    event = step persist_event(validated)

    created(event)  # Uses helper from base class
  end

  private

  def validate_course_id(course_id)
    id = course_id.to_i
    return Failure(bad_request('Invalid course ID')) if id.zero?
    Success(id)
  end

  def validate_input(event_data, course_id)
    # Validation lives in service steps, NOT in separate contracts
    name = event_data['name']
    return Failure(bad_request('Name is required')) if name.nil? || name.strip.empty?
    Success(name: name.strip, course_id:)
  end
end
```

Each step returns `Success(value)` or `Failure(ApiResult)`. The final return is auto-wrapped in `Success`.

### Controller Pattern Matching

Controllers use Ruby pattern matching on service results:

```ruby
require 'dry/monads'

class Courses < Roda
  include Dry::Monads[:result]  # Required for Success/Failure constants

  route do |r|
    # GET api/course/:course_id/event
    r.get do
      case Service::Events::ListEvents.new.call(requestor:, course_id:)
      in Success(api_result)
        response.status = api_result.http_status_code
        { success: true, data: Representer::EventsList.from_entities(api_result.message).to_array }.to_json
      in Failure(api_result)
        response.status = api_result.http_status_code
        api_result.to_json
      end
    end
  end
end
```

**Key points:**
- Include `Dry::Monads[:result]` in controller class for `Success`/`Failure` constants
- Use `case/in` pattern matching (Ruby 3.0+)
- `in Success(api_result)` destructures the wrapped value
- HTTP status flows from `ApiResult`

### 6.0 Events

| Use Case | Status | Notes |
|----------|--------|-------|
| `ListEvents` | ✅ Complete | Full DDD pattern established |
| `CreateEvent` | ✅ Complete | Validation in service, representer integration |
| `UpdateEvent` | ✅ Complete | Partial updates, cross-field time validation |
| `DeleteEvent` | ✅ Complete | Course ownership validation |
| `FindActiveEvents` | ✅ Complete | Used by `/api/current_event` |

**Cleanup:** EventService can now be deleted - all methods migrated ✅

### 6.1 Locations

| Use Case | Status | Notes |
|----------|--------|-------|
| `ListLocations` | ✅ Complete | Created Location representer |
| `GetLocation` | ✅ Complete | Auth via course enrollment |
| `CreateLocation` | ✅ Complete | Coordinate validation |
| `UpdateLocation` | ✅ Complete | Partial updates supported |
| `DeleteLocation` | ✅ Complete | Prevents deletion with associated events |

**Cleanup:** LocationService can now be deleted - all methods migrated ✅

### 6.2 Attendances

| Use Case | Status | Notes |
|----------|--------|-------|
| `ListAllAttendances` | ✅ Complete | Created Attendance representer, for teaching staff |
| `ListAttendancesByEvent` | ✅ Complete | Filter by event within course |
| `ListUserAttendances` | ✅ Complete | Student's own attendance records |
| `RecordAttendance` | ✅ Complete | Auto-generated name, coordinate validation |

**Cleanup:** AttendanceService can now be deleted - all methods migrated ✅

### 6.3 Courses

| Use Case | Status | Notes |
|----------|--------|-------|
| `ListAllCourses` | ✅ Complete | Created Course, CoursesList representers |
| `ListUserCourses` | ✅ Complete | CourseWithEnrollment representer |
| `GetCourse` | ✅ Complete | Returns course with enrollment identity |
| `CreateCourse` | ✅ Complete | Creates owner enrollment automatically |
| `UpdateCourse` | ✅ Complete | Partial updates supported |
| `DeleteCourse` | ✅ Complete | Admin/owner authorization |

**Enrollments (Course sub-resource):**

| Use Case | Status | Notes |
|----------|--------|-------|
| `GetEnrollments` | ✅ Complete | Created Enrollment, EnrollmentsList representers |
| `UpdateEnrollments` | ✅ Complete | Bulk enrollment add/update |
| `UpdateEnrollment` | ✅ Complete | Single account enrollment update |
| `RemoveEnrollment` | ✅ Complete | Remove account from course |

**Cleanup:** CourseService can now be deleted - all methods migrated ✅

### 6.4 Accounts

| Use Case | Status | Notes |
|----------|--------|-------|
| `ListAllAccounts` | ✅ Complete | Created Account, AccountsList representers |
| `CreateAccount` | ✅ Complete | Email validation, role assignment |
| `UpdateAccount` | ✅ Complete | Self or admin can update |
| `DeleteAccount` | ✅ Complete | Self or admin can delete |

**Cleanup:** AccountService can now be deleted - all methods migrated ✅

### Validation Approach

**Validation lives in service steps, not separate contracts.** This keeps the use case cohesive and avoids premature abstraction.

Each service validates its own input inline:

```ruby
def validate_input(event_data, course_id)
  name = event_data['name']
  return Failure(bad_request('Name is required')) if name.nil? || name.strip.empty?
  # ... more validation ...
  Success(validated_data)
end
```

If validation becomes complex or needs sharing across services, extract to dry-validation contracts at that point (YAGNI).

---

## Migration Strategy

**Vertical slice approach:** Implement each use case fully before moving to the next.

For each use case:

1. Create railway service class with dry-monads Success/Failure
2. Create/update representer if needed for the entity type
3. Update controller to pattern-match on service result
4. Write unit tests for service (success and failure paths)
5. Run integration tests to verify controller behavior
6. Only delete old service method once new service is proven

**Benefits:**

- Each endpoint works end-to-end before moving on
- Avoids writing code that might not be needed
- Easy to pause and resume - each slice is self-contained
- Tests validate the complete flow immediately

---

## Current Status

**Phase**: Post-Refactoring Cleanup ✅ **IN PROGRESS**
**Completed**: Phase 0 ✅, Phase 1 ✅, Phase 2 ✅, Phase 3 ✅, Phase 4 ✅, Phase 5 ✅, Phase 6 ✅

### Post-Refactoring Tasks

- [x] **Move controllers to application layer** (2026-01-30)
  - Moved `backend_app/controllers/` → `backend_app/application/controllers/`
  - Updated controller internal require paths (`./routes/` instead of `../controllers/routes/`)
  - All 539 tests pass ✅

- [x] **Simplify require_app and reorganize database tooling** (2026-01-30)
  - Moved database tooling: `infrastructure/database/{migrations,seeds,store}` → `backend_app/db/`
  - Simplified `require_app.rb` to load only top-level directories: `domain config infrastructure application presentation lib`
  - Deleted dead code `course_scopes.rb` (defined conflicting `Todo::CoursePolicy` that shadowed the real policy)
  - Removed redundant `require_relative` for policies from services (auto-loaded now)
  - Updated paths in Rakefile and config files
  - Result: Clean separation of runtime code vs database tooling; no skips or exceptions in require_app
  - All 539 tests pass ✅

- [x] **Consolidate runtime code into app/ folder** (2026-01-30)
  - Moved `domain/`, `infrastructure/`, `application/`, `presentation/`, `lib/` into `backend_app/app/`
  - Result: Only 4 top-level folders: `app/`, `config/`, `db/`, `spec/`
  - `lib/` contains cross-cutting utilities (jwt_credential.rb) - no external I/O, just crypto helpers
  - Updated `require_app.rb` to load config first, then app/ subdirectories
  - All 539 tests pass ✅

- [x] **Rename Todo module to Tyto** (2026-01-30)
  - Renamed `module Todo` → `module Tyto` and `Todo::` → `Tyto::` across 111 backend files (916 occurrences)
  - Updated CLAUDE documentation to reflect new module name
  - All tests pass ✅

- [x] **Split JWTCredential into domain and infrastructure** (2026-01-30)
  - **Problem**: `lib/jwt_credential.rb` conflated two concerns:
    1. Domain concept: authenticated identity (`account_id` + `roles`)
    2. Encoding mechanism: JWT encryption/decryption
  - **Solution**: Split into proper DDD layers:
    - `domain/accounts/values/requestor.rb` - Value object representing authenticated identity
      - Attributes: `account_id`, `roles` (uses `Types::Role` for all role types)
      - Predicates: `admin?`, `creator?`, `member?`, `has_role?(name)`
    - `infrastructure/auth/auth_token/` - Boundary adapters for JWT encoding (gateway + mapper pattern)
      - `AuthToken::Gateway` - Pure encryption/decryption (RbNaCl SecretBox)
        - `encrypt(payload)` → encrypted token string
        - `decrypt(token)` → payload string
        - `generate_key` → Base64 key
      - `AuthToken::Mapper` - AuthCapability ↔ token transformation
        - `to_token(requestor)` → token string
        - `from_auth_header(auth_header)` → AuthCapability
        - `from_credentials(account_id, roles)` → token string (convenience)
  - **Updated consumers**:
    - Controllers: `AuthToken::Mapper.new.from_auth_header(auth_header)` returns `AuthCapability`
    - Services/policies: `requestor.account_id` instead of `requestor['account_id']`
    - Policies: `requestor.admin?` instead of `requestor['roles'].include?('admin')`
  - Deleted: `lib/jwt_credential.rb`, `spec/lib/jwt_credential_spec.rb`
  - Added: Unit tests for AuthCapability, AuthToken::Gateway, AuthToken::Mapper
  - All 561 tests pass ✅

### Completed Use Cases

| Use Case | Service | Representer | Controller | Tests |
|----------|---------|-------------|------------|-------|
| ListEvents | ✅ | ✅ Event, EventsList | ✅ | ✅ |
| CreateEvent | ✅ | ✅ Event | ✅ | ✅ |
| UpdateEvent | ✅ | ✅ Event | ✅ | ✅ |
| DeleteEvent | ✅ | N/A (string message) | ✅ | ✅ |
| FindActiveEvents | ✅ | ✅ EventsList | ✅ | ✅ |
| ListLocations | ✅ | ✅ Location, LocationsList | ✅ | ✅ |
| GetLocation | ✅ | ✅ Location | ✅ | ✅ |
| CreateLocation | ✅ | ✅ Location | ✅ | ✅ |
| UpdateLocation | ✅ | ✅ Location | ✅ | ✅ |
| DeleteLocation | ✅ | N/A (string message) | ✅ | ✅ |
| ListAllAttendances | ✅ | ✅ Attendance, AttendancesList | ✅ | ✅ |
| ListAttendancesByEvent | ✅ | ✅ AttendancesList | ✅ | ✅ |
| ListUserAttendances | ✅ | ✅ AttendancesList | ✅ | ✅ |
| RecordAttendance | ✅ | ✅ Attendance | ✅ | ✅ |
| ListAllCourses | ✅ | ✅ Course, CoursesList | ✅ | ✅ |
| ListUserCourses | ✅ | ✅ CourseWithEnrollment | ✅ | ✅ |
| GetCourse | ✅ | ✅ CourseWithEnrollment | ✅ | ✅ |
| CreateCourse | ✅ | ✅ CourseWithEnrollment | ✅ | ✅ |
| UpdateCourse | ✅ | N/A (string message) | ✅ | ✅ |
| DeleteCourse | ✅ | N/A (string message) | ✅ | ✅ |
| GetEnrollments | ✅ | ✅ Enrollment, EnrollmentsList | ✅ | ✅ |
| UpdateEnrollments | ✅ | N/A (string message) | ✅ | ✅ |
| UpdateEnrollment | ✅ | N/A (string message) | ✅ | ✅ |
| RemoveEnrollment | ✅ | N/A (string message) | ✅ | ✅ |
| ListAllAccounts | ✅ | ✅ Account, AccountsList | ✅ | ✅ |
| CreateAccount | ✅ | ✅ Account | ✅ | ✅ |
| UpdateAccount | ✅ | N/A (string message) | ✅ | ✅ |
| DeleteAccount | ✅ | N/A (string message) | ✅ | ✅ |

### Infrastructure Ready (Built in earlier phases)

Repositories and domain entities are ready - services will use them as each use case is implemented:

| Repository | Domain Entities | Ready |
|------------|-----------------|-------|
| `Repository::Events` | Event | ✅ (used by ListEvents) |
| `Repository::Locations` | Location, GeoLocation | ✅ Built |
| `Repository::Courses` | Course, TimeRange, Enrollment | ✅ Built |
| `Repository::Accounts` | Account | ✅ Built |
| `Repository::Attendances` | Attendance | ✅ Built |

### Legacy Services (To be replaced)

These God object services will be incrementally replaced by focused use case classes:

| Service | Methods | Migrated | Remaining |
|---------|---------|----------|-----------|
| `EventService` | 6 | 6 ✅ **COMPLETE** | 0 |
| `LocationService` | 5 | 5 ✅ **COMPLETE** | 0 |
| `AttendanceService` | 4 | 4 ✅ **COMPLETE** | 0 |
| `CourseService` | 10 | 10 ✅ **COMPLETE** | 0 |
| `AccountService` | 4 | 4 ✅ **COMPLETE** | 0 |

**All legacy God Object services have been migrated to focused use case classes!**

**Cleanup completed:**
- Deleted all 5 legacy service files (EventService, LocationService, AttendanceService, CourseService, AccountService)
- Added unit tests for new services in `backend_app/spec/application/services/`

**Not part of this refactoring** (see `doc/future-work.md`):

- `GeoLocation#distance_to` - For backend attendance proximity validation
- `TimeRange#overlaps?`, `#contains?` - For scheduling conflict detection

**Future Database Migrations Required:**

- **accounts table**: Add `created_at` and `updated_at` timestamp columns
  - The Account entity/representer currently omits timestamps because the DB table lacks them
  - Create migration: `add_column :accounts, :created_at, DateTime` and `updated_at`
  - Update Account ORM with `plugin :timestamps`
  - Update repository and representer to include timestamps
  - **Note**: Requires running migration on production database

---

## Reference

- Pattern source: `~/ossdev/projects/codepraise/api-codepraise`
- Key gems: dry-struct, dry-types, dry-operation (v1.0+), roar (for representers)
- dry-operation docs: https://dry-rb.org/gems/dry-operation/1.0/
- dry-rb community discussions:
  - [Best practices for dry-types, dry-struct, dry-validation](https://discourse.dry-rb.org/t/best-practices-for-using-dry-types-dry-schema-dry-validation-and-dry-struct-together-in-our-apps/1821)
  - [Validation approach for Domain Objects](https://discourse.dry-rb.org/t/validation-approach-for-domain-objects/73)

## Notes

- All runtime code lives in `app/` folder: `domain/`, `infrastructure/`, `application/`, `presentation/`
- `lib/` folder exists but is currently empty (JWT handling moved to proper DDD locations)
- Authentication boundary adapters live in `infrastructure/auth/` (TokenEncoder for JWT, SSOAuth for Google OAuth)
- `config/` stays at top level (loaded before app code)
- `db/` contains database tooling (migrations, seeds, store) - not auto-loaded
- Specs will need path updates as code moves
- **Types in domain layer**: Domain types (`domain/types.rb`) are imported by application contracts. Dependencies flow inward (application → domain).
- **Shared constrained types**: Avoid duplication between dry-struct and dry-validation by defining constrained types once in domain layer.
- **Immutable updates**: dry-struct `new()` method re-enforces type constraints (raises `Dry::Struct::Error` on violation). Note that custom invariant checks in class-level `new` overrides only apply on initial construction, not instance updates.
- **Entity purity**: Domain entities must have NO persistence or serialization methods (`to_hash`, `to_json`, `to_persistence_hash`, `attributes`). ORM ↔ entity mapping belongs in repositories; entity → JSON mapping belongs in representers (`presentation/representers/`). Create representers early to avoid polluting entities.
- **dry-monads analysis**: Reference project (api-codepraise) uses dry-transaction and Dry::Monads::Result for railway-oriented flow. Tyto currently has 50+ rescue blocks in controllers. Migration to dry-monads is deferred to Phase 6 to avoid scope creep during domain extraction.
