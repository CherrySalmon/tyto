# DDD Refactoring Plan for Tyto

## Overview

This document tracks the incremental extraction of domain code into a clean DDD architecture, following the patterns established in `api-codepraise`.

**Strategy**: Move first, transform later. We reorganize existing code into the target structure before introducing new abstractions (entities, repositories, etc.).

## Target Architecture

```text
backend_app/
├── domain/                        # Pure domain layer (no framework dependencies)
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
│   │   └── repositories/          # Data mappers between ORM and domain
│   └── auth/                      # SSO/OAuth gateway
│
├── application/                   # Use cases and orchestration
│   ├── services/                  # Refactored from services/
│   ├── policies/                  # Authorization (moved from policies/)
│   ├── requests/                  # Input validation
│   └── responses/                 # Response DTOs
│
├── presentation/                  # API responses
│   └── representers/              # JSON serialization
│
├── controllers/                   # Keep existing Roda routes (thin)
├── config/
├── db/
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

## Phase 0: Reorganize Existing Code (Current Phase)

**Goal**: Move existing files to new folder structure without changing behavior. All tests must pass after each step.

### 0.1 Create folder structure

- [ ] Create `backend_app/infrastructure/database/orm/`
- [ ] Create `backend_app/application/services/`
- [ ] Create `backend_app/application/policies/`
- [ ] Create `backend_app/infrastructure/auth/`

### 0.2 Move ORM models

Move models to `infrastructure/database/orm/`:

- [ ] `models/account.rb` → `infrastructure/database/orm/account.rb`
- [ ] `models/account_course.rb` → `infrastructure/database/orm/account_course.rb`
- [ ] `models/account_role.rb` → `infrastructure/database/orm/account_role.rb`
- [ ] `models/attendance.rb` → `infrastructure/database/orm/attendance.rb`
- [ ] `models/course.rb` → `infrastructure/database/orm/course.rb`
- [ ] `models/event.rb` → `infrastructure/database/orm/event.rb`
- [ ] `models/location.rb` → `infrastructure/database/orm/location.rb`
- [ ] `models/role.rb` → `infrastructure/database/orm/role.rb`
- [ ] Delete empty `models/` folder
- [ ] Update `require_app.rb` to load from new path
- [ ] Run tests to verify

### 0.3 Move services

Move services to `application/services/`:

- [ ] `services/account_service.rb` → `application/services/account_service.rb`
- [ ] `services/attendance_service.rb` → `application/services/attendance_service.rb`
- [ ] `services/course_service.rb` → `application/services/course_service.rb`
- [ ] `services/event_service.rb` → `application/services/event_service.rb`
- [ ] `services/location_service.rb` → `application/services/location_service.rb`
- [ ] `services/sso_auth.rb` → `infrastructure/auth/sso_auth.rb`
- [ ] Delete empty `services/` folder
- [ ] Update `require_app.rb` to load from new paths
- [ ] Update `require_relative` paths in services for policies
- [ ] Run tests to verify

### 0.4 Move policies

Move policies to `application/policies/`:

- [ ] `policies/account_policy.rb` → `application/policies/account_policy.rb`
- [ ] `policies/attendance_policy.rb` → `application/policies/attendance_policy.rb`
- [ ] `policies/course_policy.rb` → `application/policies/course_policy.rb`
- [ ] `policies/course_scopes.rb` → `application/policies/course_scopes.rb`
- [ ] `policies/event_policy.rb` → `application/policies/event_policy.rb`
- [ ] `policies/location_policy.rb` → `application/policies/location_policy.rb`
- [ ] `policies/role_policy.rb` → `application/policies/role_policy.rb`
- [ ] Delete empty `policies/` folder
- [ ] Update `require_relative` paths in services
- [ ] Run tests to verify

### 0.5 Update controller requires

- [ ] Update `controllers/app.rb` require paths
- [ ] Update any other files with direct requires
- [ ] Run full test suite
- [ ] Commit: "Reorganize backend into DDD folder structure"

---

## Phase 1: Foundation - Domain Layer Setup

### 1.1 Add DDD dependencies

- [ ] Add `dry-struct` and `dry-types` to Gemfile
- [ ] Create `backend_app/domain/` folder structure
- [ ] Create loader/initializer for domain layer

### 1.2 Extract first entity: Course

- [ ] Create `domain/courses/entities/course.rb`
  - Pure Ruby class using Dry::Struct
  - No Sequel dependencies
  - Type-safe attributes: id, name, logo, start_at, end_at
  - Computed methods: `duration`, `active?`, `upcoming?`
- [ ] Create `domain/shared/values/time_range.rb` (start_at/end_at pair)

### 1.3 Create Course repository

- [ ] Create `infrastructure/database/repositories/courses.rb`
  - `find_id(id)` → returns Domain::Entity::Course
  - `find_all` → returns array of Domain::Entity::Course
  - `create(course_entity)` → persists and returns entity
  - `rebuild_entity(orm_record)` → private mapper method
- [ ] ORM remains in `orm/course.rb` (already moved in Phase 0)

### 1.4 Update CourseService to use repository

- [ ] Inject repository instead of direct ORM access
- [ ] Return domain entities instead of raw attributes

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

### 6.1 Service refactoring

- [ ] Use Dry::Transaction for railway-oriented flow
- [ ] Services return domain entities, not hashes

### 6.2 Request/Response objects

- [ ] Create request objects for input validation
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

**Phase**: 0.1 - Create folder structure
**Next Task**: Create `infrastructure/` and `application/` directories

---

## Reference

- Pattern source: `~/ossdev/projects/codepraise/api-codepraise`
- Key gems: dry-struct, dry-types, roar (for representers)

## Notes

- Controllers remain in `controllers/` (thin routing layer)
- `config/`, `db/`, `lib/` stay in place
- Specs will need path updates as code moves
