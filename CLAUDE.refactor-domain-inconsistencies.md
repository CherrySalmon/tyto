# Refactor Domain Inconsistencies

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.

## Goal

Address structural inconsistencies in the domain layer discovered during the domain collections refactor review.

## Current State

- [x] Investigation complete
- [ ] Implementation planned
- [ ] Implementation complete

## Issues

### 1. GeoLocation lives in the wrong bounded context

**Severity**: Medium — real cross-context dependency
**Effort**: Small — move 2 files, update `require_relative` paths

`GeoLocation` and `NullGeoLocation` sit in `courses/values/`, but are imported by the Attendance context:

```
attendance/entities/attendance.rb:
  require_relative '../../courses/values/geo_location'
  require_relative '../../courses/values/null_geo_location'
```

GeoLocation is a general-purpose coordinate value object — not specific to courses. It belongs in `shared/values/` alongside `TimeRange`/`NullTimeRange`, which already follow this pattern (used by both Courses and Attendance).

**Impact**: The Attendance context has a physical dependency on Courses internals. If someone reorganizes `courses/values/`, Attendance breaks.

**Fix**: Move `geo_location.rb` and `null_geo_location.rb` from `courses/values/` to `shared/values/`. Update all `require_relative` paths in consumers:
- `attendance/entities/attendance.rb`
- `courses/entities/location.rb`
- `courses/values/geo_location.rb` (if it has internal refs)
- Any specs referencing these files

### 2. Entity namespace inconsistency

**Severity**: Low — structural smell, no runtime bug
**Effort**: Large — touches every entity file and all consumers

Entities use two different module namespaces:

- **`Tyto::Entity`** (flat) — Account, Course, Event, Location, Enrollment, Attendance, AttendanceReport
- **`Tyto::Domain::<Context>::Values`** (context-scoped) — SystemRoles, Events, Locations, Enrollments, etc.

Entities are flatly namespaced regardless of bounded context. A `Course` and an `Attendance` share the same module even though they're in different contexts. Value objects are properly namespaced (`Tyto::Domain::Courses::Values::Events`).

**Impact**: No module-level boundary between aggregates. If two contexts ever defined an entity with the same class name, they'd collide. Context membership is invisible in code — `Entity::Enrollment` doesn't indicate it belongs to the Courses context.

**Fix**: Namespace entities under their bounded context (`Tyto::Domain::Courses::Entities::Course`, etc.). This is a large refactor touching every entity file, repository, service, controller, representer, and spec.

**Recommendation**: Defer unless actively causing problems. Track as tech debt.

### 3. `AttendanceReport#raw_events` mixed return type

**Severity**: Low — works by duck typing today
**Effort**: Trivial

At `attendance/entities/attendance_report.rb:37`:

```ruby
def raw_events
  @raw_events ||= @course.events_loaded? ? @course.events : []
end
```

When events are loaded, `@course.events` returns an `Events` collection object (Enumerable). When not loaded, it returns `[]` (plain Array). So `raw_events` has two possible return types.

This works because both are iterable and both support `.empty?` and `.length`, which `StudentAttendanceRecord` calls. But it's a subtle duck-typing seam — fragile if the `Events` API ever diverges from `Array`.

**Fix**: Either:
- `@course.events_loaded? ? @course.events.to_a : []` (normalize to Array), or
- `@course.events_loaded? ? @course.events : Events.from([])` (normalize to Events)

## What was assessed and is NOT a problem

- **Attendance as independent aggregate**: Correct. Attendance records have their own lifecycle. `course_id` is a reference, not ownership.
- **AttendanceReport crossing contexts**: Expected for a read-side report entity that composes data from multiple aggregates.
- **Course aggregate scope**: Clear boundary — Course owns Events, Locations, Enrollments through collection value objects. Each child carries `course_id`.
- **Participant as anti-corruption snapshot**: Textbook pattern decoupling Courses from Accounts.

## Tasks

> Tasks will be planned when work begins.

- [ ] TBD

---

Last updated: 2026-02-10
