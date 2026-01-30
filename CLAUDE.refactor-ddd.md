# DDD Refactoring Plan for Tyto

## Overview

This document tracks the incremental extraction of domain code into a clean DDD architecture, following the patterns established in `api-codepraise`.

## Target Architecture

```
backend_app/
├── app/
│   ├── domain/                    # Pure domain layer (no framework dependencies)
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
│   │   │   ├── orm/               # Sequel models (moved from models/)
│   │   │   └── repositories/      # Data mappers between ORM and domain
│   │   └── auth/                  # SSO/OAuth gateway
│   │
│   ├── application/               # Use cases and orchestration
│   │   ├── services/              # Refactored from services/
│   │   ├── requests/              # Input validation
│   │   └── responses/             # Response DTOs
│   │
│   └── presentation/              # API responses
│       └── representers/          # JSON serialization
│
├── controllers/                   # Keep existing Roda routes (thin)
├── policies/                      # Keep for now, eventually move to domain
├── config/
├── db/
└── spec/
```

## Bounded Contexts Identified

| Context | Entities | Values | Aggregate Root |
|---------|----------|--------|----------------|
| **Courses** | Course, Event, Location | TimeRange, GeoLocation | Course |
| **Accounts** | Account | Email, Role | Account |
| **Attendance** | Attendance | CheckInData | Attendance |
| **Enrollments** | Enrollment (AccountCourse) | CourseRole | Course (or separate) |

## Phase 1: Foundation (Current Phase)

### 1.1 Create folder structure
- [ ] Create `backend_app/app/domain/` directory structure
- [ ] Create `backend_app/app/infrastructure/database/` structure
- [ ] Add Dry::Struct gem to Gemfile

### 1.2 Extract first entity: Course
- [ ] Create `app/domain/courses/entities/course.rb`
  - Pure Ruby class using Dry::Struct
  - No Sequel dependencies
  - Type-safe attributes: id, name, logo, start_at, end_at
  - Computed methods: `duration`, `active?`, `upcoming?`
- [ ] Create `app/domain/shared/values/time_range.rb` (start_at/end_at pair)

### 1.3 Create Course repository
- [ ] Move `models/course.rb` to `app/infrastructure/database/orm/course_orm.rb`
- [ ] Create `app/infrastructure/database/repositories/courses.rb`
  - `find_id(id)` → returns Domain::Entity::Course
  - `find_all` → returns array of Domain::Entity::Course
  - `create(course_entity)` → persists and returns entity
  - `rebuild_entity(orm_record)` → private mapper method

### 1.4 Update CourseService to use repository
- [ ] Inject repository instead of direct ORM access
- [ ] Return domain entities instead of raw attributes

## Phase 2: Complete Courses Context

### 2.1 Event entity
- [ ] Create `app/domain/courses/entities/event.rb`
- [ ] Create `app/infrastructure/database/orm/event_orm.rb`
- [ ] Create `app/infrastructure/database/repositories/events.rb`

### 2.2 Location entity and GeoLocation value
- [ ] Create `app/domain/courses/entities/location.rb`
- [ ] Create `app/domain/courses/values/geo_location.rb`
- [ ] Create repository and ORM

### 2.3 Course as Aggregate Root
- [ ] Course entity owns: events, locations, enrollments
- [ ] Course repository loads full aggregate
- [ ] Child entities only accessed through Course

## Phase 3: Accounts Context

### 3.1 Account entity
- [ ] Create `app/domain/accounts/entities/account.rb`
- [ ] Create `app/domain/accounts/values/email.rb` (validated email)
- [ ] Create repository

### 3.2 Role handling
- [ ] Create `app/domain/shared/values/role.rb` (enum-like)
- [ ] System roles: admin, creator, member
- [ ] Course roles: owner, instructor, staff, student

## Phase 4: Attendance Context

### 4.1 Attendance entity
- [ ] Create `app/domain/attendance/entities/attendance.rb`
- [ ] Create `app/domain/attendance/values/check_in_data.rb`
- [ ] Repository with event-scoped queries

## Phase 5: Enrollments

### 5.1 Enrollment as first-class concept
- [ ] Decide: Enrollment as Course child or separate context
- [ ] Create enrollment entity/value object
- [ ] Move enrollment logic from CourseService

## Phase 6: Application Layer Refactoring

### 6.1 Service refactoring
- [ ] Move services to `app/application/services/`
- [ ] Use Dry::Transaction for railway-oriented flow
- [ ] Services return domain entities, not hashes

### 6.2 Request/Response objects
- [ ] Create request objects for input validation
- [ ] Create response DTOs for API output

## Phase 7: Presentation Layer

### 7.1 Representers
- [ ] Add Roar gem
- [ ] Create representers for JSON serialization
- [ ] Remove `attributes` methods from domain entities

## Migration Strategy

Each phase should:
1. Create new domain/infrastructure code alongside existing code
2. Update services to use new code
3. Verify tests pass
4. Remove old code only after new code is proven

## Current Status

**Phase**: 1.1 - Foundation setup
**Next Task**: Create folder structure and add Dry::Struct gem

## Reference

- Pattern source: `~/ossdev/projects/codepraise/api-codepraise`
- Key gems: dry-struct, dry-types, roar (for representers)

## Notes

- Keep existing `models/` working during transition
- Policies will eventually move into domain but can stay for now
- Controllers remain thin - just routing to services
