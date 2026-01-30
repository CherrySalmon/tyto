# DDD Refactoring Plan for Tyto

## Overview

This document tracks the incremental extraction of domain code into a clean DDD architecture, following the patterns established in `api-codepraise`.

**Strategy**: Move first, transform later. We reorganize existing code into the target structure before introducing new abstractions (entities, repositories, etc.).

## Target Architecture

```text
backend_app/
├── domain/                        # Pure domain layer (no framework dependencies)
│   ├── types.rb                   # Shared constrained types (CourseName, Email, etc.)
│   ├── courses/                   # Course bounded context
│   │   ├── entities/
│   │   └── values/
│   ├── accounts/                  # Account bounded context
│   │   ├── entities/
│   │   └── values/
│   ├── attendance/                # Attendance bounded context
│   │   ├── entities/
│   │   └── values/
│   └── shared/                    # Shared kernel (cross-context values)
│       └── values/
│
├── infrastructure/                # External adapters
│   ├── database/
│   │   ├── orm/                   # Sequel models (moved from models/)
│   │   ├── repositories/          # Data mappers between ORM and domain
│   │   ├── migrations/            # Database schema migrations
│   │   ├── seeds/                 # Seed data
│   │   └── store/                 # SQLite files (dev/test)
│   └── auth/                      # SSO/OAuth gateway
│
├── application/                   # Use cases and orchestration
│   ├── services/                  # Refactored from services/
│   ├── policies/                  # Authorization (moved from policies/)
│   ├── contracts/                 # Input validation (dry-validation, imports domain types)
│   └── responses/                 # Response DTOs
│
├── presentation/                  # API responses
│   └── representers/              # JSON serialization
│
├── controllers/                   # Keep existing Roda routes (thin)
├── config/
└── spec/
```

## Bounded Contexts Identified

### Courses (Aggregate Root: Course)

- **Entities**: Course, Event, Location
- **Values**: TimeRange, GeoLocation

### Accounts (Aggregate Root: Account)

- **Entities**: Account
- **Values**: Email, Role

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
module Todo
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
    required(:name).filled(Todo::Types::CourseName)  # Reuse domain type
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

### 6.0 Refactor EventService (First)

Start with EventService as the pattern. Break into focused use case classes:

- [ ] Create `application/services/events/` folder
- [ ] `ListEvents` - list events for a course
  - Uses `Repository::Events.find_by_course`
  - Returns `Success(events)` or `Failure(error)`
- [ ] `CreateEvent` - create a new event
  - Uses `Repository::Events.create`
  - Validates with contract before creating entity
- [ ] `UpdateEvent` - update existing event
- [ ] `DeleteEvent` - delete an event
- [ ] `FindActiveEvents` - find events active at given time
- [ ] Update controllers to use new service classes
- [ ] Delete old `EventService` once all methods migrated
- [ ] Run integration tests to verify controllers work

### 6.1 Refactor LocationService

- [ ] Create `application/services/locations/` folder
- [ ] `ListLocations`, `GetLocation`, `CreateLocation`, `UpdateLocation`, `DeleteLocation`
- [ ] Update controllers
- [ ] Delete old `LocationService`

### 6.2 Refactor AttendanceService

- [ ] Create `application/services/attendances/` folder
- [ ] `ListAttendances`, `ListAttendancesByEvent`, `ListUserAttendances`, `RecordAttendance`
- [ ] Update controllers
- [ ] Delete old `AttendanceService`

### 6.3 Refactor CourseService

- [ ] Create `application/services/courses/` folder
- [ ] `ListAllCourses`, `ListUserCourses`, `GetCourse`, `CreateCourse`, `UpdateCourse`, `DeleteCourse`
- [ ] Create `application/services/courses/enrollments/` subfolder
- [ ] `ListEnrollments`, `AddEnrollment`, `UpdateEnrollment`, `RemoveEnrollment`
- [ ] Update controllers
- [ ] Delete old `CourseService`

### 6.4 Refactor AccountService

- [ ] Create `application/services/accounts/` folder
- [ ] `ListAccounts`, `CreateAccount`, `UpdateAccount`, `DeleteAccount`
- [ ] Update controllers
- [ ] Delete old `AccountService`

### 6.5 Railway-oriented error handling (dry-monads)

Add after service restructuring is complete:

- [ ] Add `dry-monads` and `dry-transaction` to Gemfile
- [ ] Each service class includes `Dry::Transaction`
- [ ] Define steps for multi-step operations
- [ ] Return `Success(result)` or `Failure(ApiResult.new(...))`
- [ ] Update controllers to pattern-match on results
- [ ] Remove rescue blocks from controllers

### 6.6 Contracts and Response objects

- [ ] Create `application/contracts/` folder
- [ ] Create contracts importing domain types:
  - `CreateEventContract`, `UpdateEventContract`
  - `CreateCourseContract`, `CreateAccountContract`
  - `EnrollmentContract`
- [ ] Services validate with contracts before creating entities
- [ ] Create `application/responses/api_result.rb` for standardized responses

---

## Phase 7: Presentation Layer

### 7.1 Representers

- [ ] Add Roar gem (or similar representer pattern)
- [ ] Create representers for JSON/API serialization of domain entities
- [ ] Create persistence mappers (entity ↔ ORM hash) - currently inline in repositories
- [ ] Remove `attributes` methods from ORM models
- [ ] Domain entities remain pure - no `to_hash`, `to_json`, or persistence methods

---

## Migration Strategy

Each phase should:

1. Create new structure alongside existing code when possible
2. Move/update code incrementally
3. Verify tests pass after each step
4. Only remove old code after new code is proven

---

## Current Status

**Phase**: 6 - Application Layer Refactoring (In Progress)
**Completed**: Phase 2 ✅, Phase 3 ✅, Phase 4 ✅, Phase 5 ✅
**Next**: Phase 6.0 - Refactor EventService into focused use case classes

### Built but Not Yet Wired (Phase 6 will address)

The following domain objects and repository methods exist but services haven't been updated to use them:

| Component | Status | Blocked By |
| --------- | ------ | ---------- |
| `Repository::Events` | ✅ Wired | EventService uses it (will be restructured) |
| `Repository::Locations` | ✅ Built | LocationService still uses ORM |
| `Repository::Accounts` | ✅ Built | AccountService still uses ORM |
| `Repository::Attendances` | ✅ Built | AttendanceService still uses ORM |
| `Course#find_event`, `#find_location` | ✅ Built | Services need aggregate loading |
| `Course#find_enrollment`, `#teaching_staff`, `#students` | ✅ Built | Services need aggregate loading |
| `Courses#find_with_events`, `#find_with_enrollments`, etc. | ✅ Built | Services need refactoring |
| `Account#admin?`, `#creator?`, etc. | ✅ Built | Services need refactoring |
| `Attendance#within_range?`, etc. | ✅ Built | AttendanceService needs refactoring |
| `Enrollment#owner?`, `#teaching?`, etc. | ✅ Built | CourseService needs refactoring |

**Note**: God object services (e.g., `CourseService` with 10+ methods) will be broken into focused use case classes following `api-codepraise` patterns.

**Not part of this refactoring** (see `doc/future-work.md`):

- `GeoLocation#distance_to` - For backend attendance proximity validation
- `TimeRange#overlaps?`, `#contains?` - For scheduling conflict detection

---

## Reference

- Pattern source: `~/ossdev/projects/codepraise/api-codepraise`
- Key gems: dry-struct, dry-types (transitive via dry-validation), roar (for representers)
- dry-rb community discussions:
  - [Best practices for dry-types, dry-struct, dry-validation](https://discourse.dry-rb.org/t/best-practices-for-using-dry-types-dry-schema-dry-validation-and-dry-struct-together-in-our-apps/1821)
  - [Validation approach for Domain Objects](https://discourse.dry-rb.org/t/validation-approach-for-domain-objects/73)

## Notes

- Controllers remain in `controllers/` (thin routing layer)
- `config/`, `lib/` stay in place
- `db/` moved to `infrastructure/database/` (migrations, seeds, store)
- Specs will need path updates as code moves
- **Types in domain layer**: Domain types (`domain/types.rb`) are imported by application contracts. Dependencies flow inward (application → domain).
- **Shared constrained types**: Avoid duplication between dry-struct and dry-validation by defining constrained types once in domain layer.
- **Immutable updates**: dry-struct `new()` method re-enforces type constraints (raises `Dry::Struct::Error` on violation). Note that custom invariant checks in class-level `new` overrides only apply on initial construction, not instance updates.
- **Entity purity**: Domain entities must have NO persistence or serialization methods (`to_hash`, `to_json`, `to_persistence_hash`, `attributes`). ORM ↔ entity mapping belongs in repositories; entity → JSON mapping belongs in representers (`presentation/representers/`). Create representers early to avoid polluting entities.
- **dry-monads analysis**: Reference project (api-codepraise) uses dry-transaction and Dry::Monads::Result for railway-oriented flow. Tyto currently has 50+ rescue blocks in controllers. Migration to dry-monads is deferred to Phase 6 to avoid scope creep during domain extraction.
