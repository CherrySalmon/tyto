# Refactor Domain Collections

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`refactor-domain-collections`

## Goal

Replace untyped `Types::Array.optional` child collections in Course entity with first-class domain collection value objects that encapsulate query behavior, enforce type safety, and follow the Null Object pattern already established for roles (`SystemRoles`/`NullSystemRoles`, `CourseRoles`).

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing test for new behavior (red)
2. **Backend implementation** — Make the test pass (green)
3. **Frontend update** — Remove old logic, consume new API (if applicable)
4. **Verify** — Manual or E2E test confirms behavior

## Current State

- [x] Plan created
- [x] Investigation complete
- [x] Implementation complete

## Key Findings

### Current `Types::Array` usage in entities

There are **5 occurrences** of `Types::Array` across the domain:

| Location | Declaration | Purpose |
| --- | --- | --- |
| `Course` entity | `attribute :events, Types::Array.optional.default(nil)` | Child event collection |
| `Course` entity | `attribute :locations, Types::Array.optional.default(nil)` | Child location collection |
| `Course` entity | `attribute :enrollments, Types::Array.optional.default(nil)` | Child enrollment collection |
| `SystemRoles` value | `attribute :roles, Types::Array.of(Types::Role)` | Typed role collection (already a value object) |
| `CourseRoles` value | `attribute :roles, Types::Array.of(Types::CourseRole)` | Typed role collection (already a value object) |

### What's already done well

- **SystemRoles** and **CourseRoles** are proper value objects wrapping `Types::Array.of(...)` with domain query methods (`has?`, `admin?`, `teaching?`, etc.) and Null Object variants.
- **Participant** is a proper value object for enrollment identity data.

### What needs refactoring

The three `Course` child collections (`events`, `locations`, `enrollments`) are raw `Types::Array.optional` — **untyped, no member constraints, and query logic lives in the Course entity itself**. This causes:

1. **No type safety**: Any value can be stored in these arrays (no `.of(...)` constraint).
2. **Misplaced logic**: Course has 10+ methods (`find_event`, `find_location`, `find_enrollment`, `event_count`, `enrollments_with_role`, `teaching_staff`, `students`, etc.) that belong on the collection objects.
3. **Inconsistent pattern**: Roles use value objects with Null Object pattern; child collections use `nil` with manual guard methods and `ChildrenNotLoadedError`.
4. **Boilerplate**: Each collection has its own `*_loaded?`, `require_*_loaded!`, and accessor methods repeated in Course.

### Target pattern

Follow the existing `SystemRoles`/`NullSystemRoles` pattern:

- **Collection value objects**: `Events`, `Locations`, `Enrollments` — each wraps a typed array and encapsulates query methods. Named as plural nouns (consistent with `SystemRoles`/`CourseRoles`).
- **Null collection objects**: Not used — `nil` for not-loaded state (decision documented in Questions).
- **Course simplification**: Course delegates to the collection value objects. Remove manual `require_*_loaded!` guards and `ChildrenNotLoadedError`.

### Consumers to update

- **Repository `Courses`**: `rebuild_entity` currently passes raw arrays or `nil`. Must pass collection value objects instead.
- **Service `GetEnrollments`**: Accesses `course_with_enrollments.enrollments` — will need to call `.to_a` or iterate the collection object.
- **Entity `AttendanceReport`**: Calls `@course.events_loaded?`, `@course.events`, `@course.students`, `@course.enrollments_loaded?`.
- **Presentation representers/formatters**: Access `.events`, `.enrollments` on Course.
- **Specs**: Course spec, AttendanceReport spec, and any specs constructing Course with `events: [...]`.

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Should we keep backward compatibility with raw array construction (`events: [event1, event2]`) via coercion, or require explicit `Events.new(...)` everywhere?~~ — **Decision**: ~~Use coercion in the type constructor so raw arrays auto-wrap into collection objects.~~ Revised: Drop coercion constructors entirely. Use `Types.Instance(...)` — callers must construct collection objects explicitly via `.from()`. Simpler, no hidden magic, and the coercion constructors were 30 lines of identical boilerplate.
- [x] ~~Should collection value objects be named `EventCollection` or `Events` (plural noun)?~~ — **Decision**: Use plural nouns (`Events`, `Locations`, `Enrollments`) — consistent with existing `SystemRoles`/`CourseRoles` convention, natural in domain language (`course.events.find(id)`), and aligned with Evans' DDD naming.
- [x] ~~Should collection value objects have Null Object variants (like `NullSystemRoles`)?~~ — **Decision**: No. Use `nil` for not-loaded, typed collection objects for loaded. Null sentinels are warranted when the object is passed around polymorphically (e.g., `SystemRoles` flows through policies/auth). Child collections are accessed only after deliberate loading — `nil` is sufficient and simpler. A `NoMethodError` on nil clearly signals "you forgot to load." Saves 3 classes of boilerplate.

## Scope

**In scope** (backend only — no frontend changes needed since API contracts don't change):

**Backend changes**:

- New value objects: `Events`, `Locations`, `Enrollments` (in `domain/courses/values/`)
- Refactor `Course` entity to use optional collection value objects (`nil` = not loaded)
- Move query methods from `Course` to respective collection value objects
- Update `Courses` repository to construct collection value objects
- Update `AttendanceReport` entity to work with collection interfaces
- Remove `ChildrenNotLoadedError` and `require_*_loaded!` guards from Course
- Update all affected specs

**Frontend changes**:

- None — the API response shape is defined by representers, which serialize to the same JSON regardless of internal collection type.

**Out of scope**:

- Refactoring `AttendanceRegister` (already a proper value object)
- Adding new domain behavior or API endpoints
- Changing database schema

## Tasks

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Slice 1: Events

- [x] 1.1a Write failing spec for `Events` value object (typed array of `Entity::Event`, `find(id)`, `count`, `to_a`, iteration)
- [x] 1.2 Implement `Events` value object
- [x] 1.3 Refactor `Course` entity — replace `events` attribute with optional `Events` (nil = not loaded), move `find_event`, `event_count` logic to collection, keep thin `events_loaded?` predicate
- [x] 1.4 Update `Courses` repository to construct `Events` instead of raw arrays
- [x] 1.5 Update Course spec and any consumers (`AttendanceReport`, etc.)

### Slice 2: Locations

- [x] 2.1a Write failing spec for `Locations` value object (typed array of `Entity::Location`, `find(id)`, `count`, `to_a`, iteration)
- [x] 2.2 Implement `Locations` value object
- [x] 2.3 Refactor `Course` entity — replace `locations` attribute with optional `Locations`, move `find_location`, `location_count` logic to collection
- [x] 2.4 Update `Courses` repository to construct `Locations`
- [x] 2.5 Update Course spec and any consumers

### Slice 3: Enrollments

- [x] 3.1a Write failing spec for `Enrollments` value object (typed array of `Entity::Enrollment`, `find_by_account(id)`, `with_role(role)`, `teaching_staff`, `students`, `count`, `to_a`, iteration)
- [x] 3.2 Implement `Enrollments` value object
- [x] 3.3 Refactor `Course` entity — replace `enrollments` attribute with optional `Enrollments`, move `find_enrollment`, `enrollment_count`, `enrollments_with_role`, `teaching_staff`, `students` logic to collection
- [x] 3.4 Update `Courses` repository to construct `Enrollments`
- [x] 3.5 Update Course spec, AttendanceReport, GetEnrollments service, and presentation layer

### Slice 4: Cleanup + Verification

- [x] 4.1 Remove `ChildrenNotLoadedError` and all `require_*_loaded!` guards from Course entity
- [x] 4.2 Run full test suite — all tests green (858 tests, 0 failures, 98.05% coverage)
- [x] 4.3 Clean up any dead code, unused requires, or leftover comments

### Slice 5: Drop coercion type constructors

- [x] 5.1 Replace `EventsType`/`LocationsType`/`EnrollmentsType` constructor constants with `Types.Instance(...)` on Course entity attributes
- [x] 5.2 Add explicit `require_relative` for value objects in Course entity (and entity requires in value objects) to resolve eager load-order dependencies
- [x] 5.3 Update `Courses` repository to wrap `rebuild_*` results with `.from()`
- [x] 5.4 Update all specs to construct collection objects explicitly via `.from()` instead of passing raw arrays
- [x] 5.5 Run full test suite — all tests green (858 tests, 0 failures, 98.15% coverage)

## Completed

All slices implemented and verified.

---

Last updated: 2026-02-10
