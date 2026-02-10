# Refactor Domain Inconsistencies

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`refactor-domain-inconsistencies`

## Goal

Fix structural inconsistencies in the domain layer: relocate GeoLocation to shared context, normalize AttendanceReport#raw_events return type, and align entity namespaces with value object convention.

## Strategy: Vertical Slice

Three independent slices — each is a self-contained fix with tests:

1. **Slice 1**: Move GeoLocation/NullGeoLocation to `shared/values/` and update all consumers
2. **Slice 2**: Normalize `AttendanceReport#raw_events` return type
3. **Slice 3**: Re-namespace entities from flat `Tyto::Entity` to context-scoped `Tyto::Domain::<Context>::Entities`

No frontend changes required — these are domain-layer fixes only.

## Current State

- [x] Plan created
- [ ] Slice 1: GeoLocation relocation
- [ ] Slice 2: raw_events return type normalization
- [ ] Slice 3: Entity namespace alignment
- [ ] All tests passing
- [ ] Manual verification

## Key Findings

### GeoLocation consumers (complete list)

**Domain layer**:

- `courses/entities/location.rb` — requires `../values/geo_location` and `../values/null_geo_location`
- `attendance/entities/attendance.rb` — requires `../../courses/values/geo_location` and `../../courses/values/null_geo_location` (cross-context dependency)

**Application layer**:

- `application/services/concerns/coordinate_validation.rb` — requires `../../../domain/courses/values/geo_location`, calls `Value::GeoLocation.build()` and catches `Value::GeoLocation::InvalidCoordinatesError`

**Specs**:

- `spec/domain/courses/values/geo_location_spec.rb`
- `spec/domain/courses/values/null_geo_location_spec.rb`
- `spec/domain/courses/entities/location_spec.rb` — references `Tyto::Value::GeoLocation` and `Tyto::Value::NullGeoLocation`
- `spec/infrastructure/database/repositories/locations_spec.rb`
- `spec/domain/attendance/entities/attendance_spec.rb`
- `spec/infrastructure/database/repositories/attendances_spec.rb`

### GeoLocation namespace

Both files use `module Tyto; module Value` — namespace is `Tyto::Value::GeoLocation` and `Tyto::Value::NullGeoLocation`. This already matches the shared value pattern (`Tyto::Value::TimeRange`). Only `require_relative` paths need updating; no class/module name changes.

### raw_events mixed type

`AttendanceReport#raw_events` returns either `Domain::Courses::Values::Events` (collection object) or `[]` (plain Array). Consumers call `.map`, `.each`, `.empty?`, `.length` — all supported by both. The `Events` collection has a factory `Events.from([])` that can produce an empty collection, making normalization straightforward.

### Entity namespace

Entities use flat `Tyto::Entity` namespace while values use context-scoped `Tyto::Domain::<Context>::Values`. This inconsistency means context membership is invisible in entity code — `Entity::Enrollment` doesn't indicate it belongs to Courses. If two contexts ever defined an entity with the same name, they'd collide.

**Target namespace**: `Tyto::Domain::<Context>::Entities::<ClassName>` (mirrors value object convention).

**7 entity files by context**:

- **Accounts**: `Account` (5 consumer files)
- **Courses**: `Course` (6), `Event` (13), `Location` (12), `Enrollment` (14)
- **Attendance**: `Attendance` (10), `AttendanceReport` (3)

**Consumer layers** (all reference `Entity::<Name>` or `Tyto::Entity::<Name>`):

- Domain: collection value objects (`events.rb`, `locations.rb`, `enrollments.rb`) use `Entity::` in type constraints; `attendance_eligibility.rb` policy
- Infrastructure: repositories (`accounts`, `courses`, `events`, `locations`, `attendances`)
- Application: services (`create_account`, `create_course`, `create_event`, `create_location`, `record_attendance`, `generate_report`, `list_user_courses`)
- Presentation: `attendance_report_csv_spec.rb`
- Specs: entity specs, repository specs, policy specs, value specs, service specs

**Note**: No base `Entity` module exists — each entity independently declares `module Tyto; module Entity`. The refactor replaces this with context-scoped modules.

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] Normalize raw_events to Array or Events? — **Decision**: Normalize to `Events` collection using `Events.from([])` for the empty case. This preserves the typed collection contract and is consistent with how the domain models collections.
- [x] Slice ordering dependency? — **Decision**: Slice 3 should run after Slices 1 and 2, since it touches entity files (`location.rb`, `attendance.rb`, `attendance_report.rb`) that those slices also modify. Running Slice 3 last avoids merge conflicts within the branch.

## Scope

**In scope**:

- Move `geo_location.rb` and `null_geo_location.rb` from `courses/values/` to `shared/values/`
- Update all `require_relative` paths in domain entities, application services, and specs
- Normalize `AttendanceReport#raw_events` to always return an `Events` collection
- Move spec files to match new source locations
- Re-namespace all 7 entity files from `Tyto::Entity` to `Tyto::Domain::<Context>::Entities`
- Update all consumers (repositories, services, policies, collection values, representers, specs)

**Out of scope**:

- Any changes to GeoLocation/NullGeoLocation class names or module namespaces (already correct as `Tyto::Value`)
- Frontend changes (none needed)

## Slice 1: Relocate GeoLocation to shared/values

> **Test-first**: Update spec file locations and require paths first, then move source files.

- [ ] 1.1a Move spec files `spec/domain/courses/values/geo_location_spec.rb` and `null_geo_location_spec.rb` to `spec/domain/shared/values/` and update their require paths
- [ ] 1.1b Verify moved specs fail (files not yet relocated)
- [ ] 1.2 Move `domain/courses/values/geo_location.rb` and `null_geo_location.rb` to `domain/shared/values/`
- [ ] 1.3 Update `require_relative` in `courses/entities/location.rb` — change `../values/geo_location` to `../../shared/values/geo_location` (same for null)
- [ ] 1.4 Update `require_relative` in `attendance/entities/attendance.rb` — change `../../courses/values/geo_location` to `../../shared/values/geo_location` (same for null)
- [ ] 1.5 Update `require_relative` in `application/services/concerns/coordinate_validation.rb` — change path from `courses/values/` to `shared/values/`
- [ ] 1.6 Run full test suite — all specs pass

## Slice 2: Normalize raw_events return type

- [ ] 2.1a Add/update test in `spec/domain/attendance/entities/attendance_report_spec.rb` asserting `raw_events` returns an `Events` collection even when events are not loaded
- [ ] 2.1b Verify new test fails (returns Array currently)
- [ ] 2.2 Update `AttendanceReport#raw_events` to return `Events.from([])` instead of `[]`
- [ ] 2.3 Ensure `attendance_report.rb` has the necessary `require_relative` for Events
- [ ] 2.4 Run full test suite — all specs pass

## Slice 3: Entity namespace alignment

Change entity namespaces from flat `Tyto::Entity::<Name>` to context-scoped `Tyto::Domain::<Context>::Entities::<Name>`, matching the value object convention.

### Namespace mapping

| Entity           | Current                          | Target                                                 |
| ---------------- | -------------------------------- | ------------------------------------------------------ |
| Account          | `Tyto::Entity::Account`          | `Tyto::Domain::Accounts::Entities::Account`            |
| Course           | `Tyto::Entity::Course`           | `Tyto::Domain::Courses::Entities::Course`              |
| Event            | `Tyto::Entity::Event`            | `Tyto::Domain::Courses::Entities::Event`               |
| Location         | `Tyto::Entity::Location`         | `Tyto::Domain::Courses::Entities::Location`            |
| Enrollment       | `Tyto::Entity::Enrollment`       | `Tyto::Domain::Courses::Entities::Enrollment`          |
| Attendance       | `Tyto::Entity::Attendance`       | `Tyto::Domain::Attendance::Entities::Attendance`       |
| AttendanceReport | `Tyto::Entity::AttendanceReport` | `Tyto::Domain::Attendance::Entities::AttendanceReport` |

### Consumer files (complete list)

**Entity source files** (namespace declaration changes):

- `domain/accounts/entities/account.rb`
- `domain/courses/entities/course.rb`
- `domain/courses/entities/event.rb`
- `domain/courses/entities/location.rb`
- `domain/courses/entities/enrollment.rb`
- `domain/attendance/entities/attendance.rb`
- `domain/attendance/entities/attendance_report.rb`

**Domain layer** (type references in collection values + policy):

- `domain/courses/values/events.rb` — `Entity::Event` in type constraint
- `domain/courses/values/locations.rb` — `Entity::Location` in type constraint
- `domain/courses/values/enrollments.rb` — `Entity::Enrollment` in type constraint
- `domain/attendance/policies/attendance_eligibility.rb` — `Entity::Event`, `Entity::Location`, `Entity::Attendance`

**Infrastructure layer** (repositories):

- `infrastructure/database/repositories/accounts.rb` — `Entity::Account`
- `infrastructure/database/repositories/courses.rb` — `Entity::Course`, `Entity::Event`, `Entity::Location`, `Entity::Enrollment`
- `infrastructure/database/repositories/events.rb` — `Entity::Event`
- `infrastructure/database/repositories/locations.rb` — `Entity::Location`
- `infrastructure/database/repositories/attendances.rb` — `Entity::Attendance`

**Application layer** (services):

- `application/services/accounts/create_account.rb` — `Entity::Account`
- `application/services/courses/create_course.rb` — `Entity::Course`
- `application/services/courses/list_user_courses.rb` — `Entity::Enrollment`
- `application/services/events/create_event.rb` — `Entity::Event`
- `application/services/locations/create_location.rb` — `Entity::Location`
- `application/services/attendances/record_attendance.rb` — `Entity::Attendance`
- `application/services/attendances/generate_report.rb` — `Entity::AttendanceReport`

**Specs** (all files referencing `Entity::`):

- `spec/domain/accounts/entities/account_spec.rb`
- `spec/domain/courses/entities/course_spec.rb`
- `spec/domain/courses/entities/event_spec.rb`
- `spec/domain/courses/entities/location_spec.rb`
- `spec/domain/courses/entities/enrollment_spec.rb`
- `spec/domain/courses/values/events_spec.rb`
- `spec/domain/courses/values/locations_spec.rb`
- `spec/domain/courses/values/enrollments_spec.rb`
- `spec/domain/attendance/entities/attendance_spec.rb`
- `spec/domain/attendance/entities/attendance_report_spec.rb`
- `spec/domain/attendance/values/student_attendance_record_spec.rb`
- `spec/domain/attendance/values/attendance_register_spec.rb`
- `spec/domain/attendance/policies/attendance_eligibility_spec.rb`
- `spec/infrastructure/database/repositories/accounts_spec.rb`
- `spec/infrastructure/database/repositories/courses_spec.rb`
- `spec/infrastructure/database/repositories/events_spec.rb`
- `spec/infrastructure/database/repositories/locations_spec.rb`
- `spec/infrastructure/database/repositories/attendances_spec.rb`
- `spec/application/services/auth/verify_google_token_spec.rb`
- `spec/application/policies/course_policy_spec.rb`
- `spec/application/policies/event_policy_spec.rb`
- `spec/application/policies/location_policy_spec.rb`
- `spec/application/policies/attendance_authorization_spec.rb`
- `spec/presentation/formatters/attendance_report_csv_spec.rb`

> **Context-at-a-time**: Refactor one bounded context at a time to keep changes reviewable. Within each context: update specs first, then source files, then consumers.

- [ ] 3.1 **Accounts context** — Re-namespace `Account`
  - [ ] 3.1a Update `account_spec.rb` to use `Tyto::Domain::Accounts::Entities::Account`; verify it fails
  - [ ] 3.1b Update `account.rb` namespace from `module Tyto; module Entity` to `module Tyto; module Domain; module Accounts; module Entities`
  - [ ] 3.1c Update consumers: `create_account.rb`, `accounts.rb` repository, `verify_google_token_spec.rb`, `accounts_spec.rb`
  - [ ] 3.1d Run test suite — verify all pass
- [ ] 3.2 **Courses context** — Re-namespace `Course`, `Event`, `Location`, `Enrollment`
  - [ ] 3.2a Update course entity specs to use new namespace; verify they fail
  - [ ] 3.2b Update 4 entity files' namespace declarations
  - [ ] 3.2c Update domain consumers: `events.rb`, `locations.rb`, `enrollments.rb` collection type constraints
  - [ ] 3.2d Update infrastructure: `courses.rb`, `events.rb`, `locations.rb` repositories
  - [ ] 3.2e Update application: `create_course.rb`, `create_event.rb`, `create_location.rb`, `list_user_courses.rb`
  - [ ] 3.2f Update all remaining specs referencing Courses entities
  - [ ] 3.2g Run test suite — verify all pass
- [ ] 3.3 **Attendance context** — Re-namespace `Attendance`, `AttendanceReport`
  - [ ] 3.3a Update attendance entity specs to use new namespace; verify they fail
  - [ ] 3.3b Update 2 entity files' namespace declarations
  - [ ] 3.3c Update domain consumers: `attendance_eligibility.rb` policy
  - [ ] 3.3d Update infrastructure: `attendances.rb` repository
  - [ ] 3.3e Update application: `record_attendance.rb`, `generate_report.rb`
  - [ ] 3.3f Update all remaining specs referencing Attendance entities
  - [ ] 3.3g Run test suite — verify all pass
- [ ] 3.4 Run full test suite — all specs pass

## Completed

(none yet)

---

Last updated: 2026-02-10
