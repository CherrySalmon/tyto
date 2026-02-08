# Branch Plan: ray/refactor-generate-report — Slice 4: Attendance Report Endpoint

## Status: COMPLETE

## Context

Move attendance report generation from frontend client-side (AttendanceEventCard.vue) to backend `GenerateReport` service following DDD architecture. The frontend currently fetches raw attendances/enrollments/events, builds a student x event matrix, computes per-student statistics, and generates CSV.

**Phase 1 (backend endpoint + frontend)**: COMPLETE — service, formatter, route, and frontend all working.

**Phase 2 (domain entity refactoring)**: COMPLETE — `AttendanceReport` entity with `.build` factory in domain layer, `StudentAttendanceRecord` value object, `Representer::AttendanceReport` for JSON serialization. Service delegates to entity, CSV formatter and route use entity attributes. 758 tests, 0 failures, 97.97% coverage.

**Phase 3 (push aggregation into value objects)**: COMPLETE — Extracted `AttendanceLookup` value object to own the attendance index. Added `.build` factory to `StudentAttendanceRecord` so it owns its own aggregation (sum, percent, per-event presence). `AttendanceReport.build` is now pure coordination. 763 tests, 0 failures, 97.99% coverage.

## Architecture

```
Route (course.rb)
  --> Service::Attendances::GenerateReport  (application layer — orchestration only)
      --> courses_repo.find_full()
      --> attendances_repo.find_by_course()
      --> AttendanceAuthorization.can_view_all?
      --> Entity::AttendanceReport.build(course:, attendances:)  (domain layer)
            --> AttendanceLookup.build(attendances:)   (index for O(1) queries)
            --> StudentAttendanceRecord.build(enrollment:, events:, lookup:)  (per student)
  --> Representer::AttendanceReport             (JSON, default)
  --> Presentation::Formatters::AttendanceReportCsv  (CSV, format=csv)
```

## Domain Design

**`AttendanceReport`** — domain entity in `domain/attendance/entities/`
- Attributes: `course_name`, `generated_at`, `events` (ReportEvent[]), `student_records` (StudentAttendanceRecord[])
- Nested `ReportEvent` struct (id + name) — avoids coupling to courses context
- Factory `.build(course:, attendances:)` — pure coordination: builds lookup, maps events, delegates student record creation

**`AttendanceLookup`** — value object in `domain/attendance/values/`
- Wraps `account_id → Set<event_id>` index for O(1) attendance queries
- Factory `.build(attendances:)` constructs the index from raw attendance records
- Query `#attended?(account_id, event_id)` — boolean lookup

**`StudentAttendanceRecord`** — value object in `domain/attendance/values/`
- Attributes: `email`, `attend_sum`, `attend_percent`, `event_attendance` (Hash {event_id => 0|1})
- Factory `.build(enrollment:, events:, lookup:)` — owns its own aggregation: computes sum, percent, per-event presence from an `AttendanceLookup`

## Files to Create

| File | Layer | Purpose |
|------|-------|---------|
| `backend_app/app/domain/attendance/values/attendance_lookup.rb` | Domain | Value object indexing attendance for O(1) queries |
| `backend_app/app/domain/attendance/values/student_attendance_record.rb` | Domain | Value object for per-student stats; `.build` factory owns aggregation |
| `backend_app/app/domain/attendance/entities/attendance_report.rb` | Domain | Entity with `.build` factory; coordinates value objects |
| `backend_app/app/presentation/representers/attendance_report.rb` | Presentation | Roar decorator for JSON serialization |
| `backend_app/spec/domain/attendance/entities/attendance_report_spec.rb` | Test | Entity factory, coordination |
| `backend_app/spec/domain/attendance/values/attendance_lookup_spec.rb` | Test | Lookup build + attended? queries |
| `backend_app/spec/domain/attendance/values/student_attendance_record_spec.rb` | Test | Construction + `.build` factory aggregation |

## Files to Modify

| File | Change |
|------|--------|
| `backend_app/app/application/services/attendances/generate_report.rb` | Remove `build_report`; delegate to `AttendanceReport.build` |
| `backend_app/app/presentation/formatters/attendance_report_csv.rb` | Hash access → entity method calls |
| `backend_app/app/application/controllers/routes/course.rb` | Use representer for JSON path |
| `backend_app/spec/application/services/attendances/generate_report_spec.rb` | Assertions use entity attributes |
| `backend_app/spec/presentation/formatters/attendance_report_csv_spec.rb` | Build entity instances, not hashes |
| `backend_app/spec/routes/course_route_spec.rb` | `student_rows` → `student_records` in JSON key check |

## Previously Created (Phase 1)

| File | Layer | Purpose |
|------|-------|---------|
| `backend_app/app/application/services/attendances/generate_report.rb` | Application | Report service |
| `backend_app/app/presentation/formatters/attendance_report_csv.rb` | Presentation | CSV formatter |
| `backend_app/spec/application/services/attendances/generate_report_spec.rb` | Test | Service spec |
| `backend_app/spec/presentation/formatters/attendance_report_csv_spec.rb` | Test | CSV formatter spec |

## Previously Modified (Phase 1)

| File | Change |
|------|--------|
| `backend_app/app/application/controllers/routes/course.rb` | Added `r.on 'report'` route |
| `backend_app/spec/routes/course_route_spec.rb` | Added route integration tests |
| `frontend_app/pages/course/components/AttendanceEventCard.vue` | Replaced client-side CSV with API call |

## CSV Formatter

`Presentation::Formatters::AttendanceReportCsv` — uses Ruby stdlib `CSV.generate`. Columns: `Student Email, attend_sum, attend_percent, ...event_names`. Output format unchanged by refactoring.

## Route

`GET /api/course/:id/attendance/report[?format=csv]`. JSON path uses `Representer::AttendanceReport`. CSV path uses `AttendanceReportCsv` formatter. Both consume the `AttendanceReport` entity.

## Tasks (Test-First)

### Phase 1: Backend Endpoint + Frontend

| Step | Task | Status |
|------|------|--------|
| 1 | Service spec — aggregation, statistics, authorization, edge cases | DONE |
| 2 | Implement `GenerateReport` service | DONE |
| 3 | CSV formatter spec | DONE |
| 4 | Implement `AttendanceReportCsv` formatter | DONE |
| 5 | Route integration tests (JSON + CSV + auth) | DONE |
| 6 | Add `report` route to `course.rb` | DONE |
| 7 | Update `AttendanceEventCard.vue` | DONE |
| 8 | Full test suite pass (747 tests, 0 failures, 97.95% coverage) | DONE |

### Phase 2: Domain Entity Refactoring

| Step | Task | Status |
|------|------|--------|
| 9 | Domain value spec — `StudentAttendanceRecord` construction | DONE |
| 10 | Implement `StudentAttendanceRecord` value object | DONE |
| 11 | Domain entity spec — `AttendanceReport.build` factory, aggregation, edge cases | DONE |
| 12 | Implement `AttendanceReport` entity with `.build` factory | DONE |
| 13 | Simplify `GenerateReport` service — remove `build_report`, delegate to entity | DONE |
| 14 | Update service spec assertions (hash keys → entity attributes) | DONE |
| 15 | Update CSV formatter to use entity attributes | DONE |
| 16 | Update CSV formatter spec (pass entities, not hashes) | DONE |
| 17 | Create `Representer::AttendanceReport` for JSON serialization | DONE |
| 18 | Update route to use representer for JSON path | DONE |
| 19 | Update route spec (`student_rows` → `student_records`) | DONE |
| 20 | Full test suite pass (758 tests, 0 failures, 97.97% coverage) | DONE |

### Phase 3: Push Aggregation into Value Objects

| Step | Task | Status |
|------|------|--------|
| 21 | Extract `AttendanceLookup` value object (wraps hash index, `#attended?` query) | DONE |
| 22 | `AttendanceLookup` spec (build from attendances, query hits/misses, empty case) | DONE |
| 23 | Add `.build` factory to `StudentAttendanceRecord` (owns sum/percent/event computation) | DONE |
| 24 | `StudentAttendanceRecord` `.build` specs (full, partial, zero events) | DONE |
| 25 | Simplify `AttendanceReport.build` to pure coordination (lookup → delegate) | DONE |
| 26 | Full test suite pass (763 tests, 0 failures, 97.99% coverage) | DONE |
