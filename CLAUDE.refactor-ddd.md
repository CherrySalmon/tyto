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

- [ ] Create `domain/courses/entities/event.rb`
- [ ] Create `infrastructure/database/repositories/events.rb`

### 2.2 Location entity and GeoLocation value

- [ ] Create `domain/courses/entities/location.rb`
- [ ] Create `domain/courses/values/geo_location.rb`
- [ ] Create repository

### 2.3 Course as Aggregate Root

- [ ] Course entity owns: events, locations, enrollments
- [ ] Course repository loads full aggregate
- [ ] Child entities only accessed through Course

---

## Phase 3: Accounts Context

### 3.1 Account entity

- [ ] Create `domain/accounts/entities/account.rb`
- [ ] Create `domain/accounts/values/email.rb` (validated email)
- [ ] Create repository

### 3.2 Role handling

- [ ] Create `domain/shared/values/role.rb` (enum-like)
- [ ] System roles: admin, creator, member
- [ ] Course roles: owner, instructor, staff, student

---

## Phase 4: Attendance Context

### 4.1 Attendance entity

- [ ] Create `domain/attendance/entities/attendance.rb`
- [ ] Create `domain/attendance/values/check_in_data.rb`
- [ ] Repository with event-scoped queries

---

## Phase 5: Enrollments

### 5.1 Enrollment as first-class concept

- [ ] Decide: Enrollment as Course child or separate context
- [ ] Create enrollment entity/value object
- [ ] Move enrollment logic from CourseService

---

## Phase 6: Application Layer Refactoring

### 6.1 Railway-oriented error handling (dry-monads)

**Current state**: Exception-based error handling with 50+ rescue blocks scattered across controllers. Each service defines its own error classes (`ForbiddenError`, `NotFoundError`, etc.).

**Target state**: Railway-oriented programming with `Success`/`Failure` returns.

- [ ] Add `dry-monads` to Gemfile
- [ ] Add `Dry::Monads::Result::Mixin` to services
- [ ] Replace `raise ForbiddenError` with `Failure(ApiResult.forbidden(...))`
- [ ] Replace `return course` with `Success(course)`
- [ ] Update controllers to pattern-match on results instead of rescue blocks
- [ ] Consider `dry-transaction` for multi-step service composition
- [ ] Update repositories to return `Success`/`Failure` for database error handling

**Note:** Infrastructure adapters (repositories, external gateways) should also use monads to handle external failures explicitly at the boundary (database errors, API timeouts, network failures).

### 6.2 Service refactoring

- [ ] Services return domain entities wrapped in Success, not hashes
- [ ] Remove exception-based error classes from services

### 6.3 Contracts and Response objects

- [ ] Create `application/contracts/` folder
- [ ] Create contracts importing domain types:
  - `CreateCourseContract` - uses `Types::CourseName`
  - `CreateAccountContract` - uses `Types::Email`
  - `EnrollmentContract` - uses `Types::CourseRole`
- [ ] Services validate with contracts before creating entities
- [ ] Create response DTOs for API output

---

## Phase 7: Presentation Layer

### 7.1 Representers

- [ ] Add Roar gem
- [ ] Create representers for JSON serialization
- [ ] Remove `attributes` methods from domain entities

---

## Migration Strategy

Each phase should:

1. Create new structure alongside existing code when possible
2. Move/update code incrementally
3. Verify tests pass after each step
4. Only remove old code after new code is proven

---

## Current Status

**Phase**: 1 - Foundation (Domain Layer Setup) ✅ COMPLETE
**Next Phase**: 2 - Complete Courses Context (Event entity, Location entity, Aggregate Root)

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
- **dry-monads analysis**: Reference project (api-codepraise) uses dry-transaction and Dry::Monads::Result for railway-oriented flow. Tyto currently has 50+ rescue blocks in controllers. Migration to dry-monads is deferred to Phase 6 to avoid scope creep during domain extraction.
