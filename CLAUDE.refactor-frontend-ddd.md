# Refactor Frontend Domain Logic to Backend DDD API

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.

> **SYNC REQUIRED**: This document must stay aligned with `CLAUDE.refactor-frontend-ddd[tests].md`. Task IDs must match across both files. When updating tasks in one file, update the other.

## Branch

`refactor-frontend-ddd`

## Goal

Move all major domain logic from the Vue frontend to the backend's DDD-architected API. The frontend should become a thin presentation layer that consumes rich, pre-validated, pre-computed data from the backend.

## Strategy: Vertical Slices

Each slice delivers a complete, end-to-end feature:
1. **Backend test** — Write failing test for new behavior
2. **Backend implementation** — Make the test pass
3. **Frontend update** — Remove old logic, consume new API
4. **Verify** — Manual or E2E test confirms behavior

This approach ensures we only build what the frontend actually needs, with immediate feedback on API design.

## Current State

- [x] Plan created
- [x] Frontend domain logic analyzed
- [x] Backend DDD architecture reviewed
- [x] Vertical slice strategy adopted
- [ ] Slice 1 started

## Key Findings

### Frontend Domain Logic to Move

| Issue | Location | Priority | Backend Status |
|-------|----------|----------|----------------|
| **Attendance Geo-fence Validation** | AttendanceTrack, AllCourse | HIGH | `Attendance#within_range?()` exists - not being used! |
| **Attendance Deduplication** | AttendanceTrack, AllCourse | HIGH | Should be backend validation |
| **Role-based Permission Hierarchy** | ManagePeopleCard | HIGH | Policies exist but frontend hardcodes role mapping |
| **Attendance Report/CSV Generation** | AttendanceEventCard | HIGH | Complex aggregation logic in frontend |
| **Event Data Enrichment (N+1)** | AttendanceTrack, AllCourse | HIGH | Backend can return enriched data |
| **Date/Time Transformation** | Multiple components | MEDIUM | Backend should return formatted strings |
| **Enrollment Email Parsing** | ManagePeopleCard | MEDIUM | Backend should validate |
| **Course Form Field Manipulation** | SingleCourse | MEDIUM | API contract issue |
| **Feature Visibility Logic** | AllCourse, SingleCourse | MEDIUM | Should be API-driven capabilities |
| **Geolocation Code Duplication** | 3 components | LOW | Frontend concern, but needs cleanup |

### Backend DDD Capabilities (Already Exists)

- **Domain Layer**: `Attendance#within_range?(max_distance_km)`, `GeoLocation#distance_to()`
- **Policies**: `CoursePolicy`, `AttendancePolicy` with role-based authorization
- **Services**: Railway-oriented operations with proper validation
- **Repositories**: Lazy loading strategies (find_full, find_with_events, etc.)

---

## Vertical Slices

### Slice 1: Geo-fence Attendance Validation

**Why first**: Security-critical; domain logic already exists but isn't wired up.

**Backend changes**:
- Add `geo_fence_radius_m` column to `events` table (integer, default: 55 meters)
- Add `geo_fence_radius_m` attribute to `Event` entity and representer
- Enhance `Services::Attendances::RecordAttendance` to:
  - Fetch event's location
  - Call `attendance.within_range?(location, event.geo_fence_radius_km)`
  - Return `:forbidden` with clear error message if outside range

**Frontend changes**:
- Remove geo-fence validation from `AttendanceTrack.vue` and `AllCourse.vue`
- Display backend error message when attendance is rejected

**Tasks**:
- [ ] 1.1a Add geo-fence acceptance test (within radius)
- [ ] 1.1b Add geo-fence rejection test (outside radius)
- [ ] 1.1c Add test for event-specific radius
- [ ] 1.1d Add test for default radius fallback
- [ ] 1.2 Add `geo_fence_radius_m` migration (default: 55)
- [ ] 1.3 Add `geo_fence_radius_m` to Event entity and representer
- [ ] 1.4 Wire up geo-fence check in RecordAttendance service
- [ ] 1.5 Update frontend to remove geo-fence logic and show backend errors
- [ ] 1.6 Manual verification: test inside/outside geo-fence scenarios

---

### Slice 2: Duplicate Attendance Prevention

**Why second**: Data integrity; closely related to Slice 1 (same service).

**Backend changes**:
- Add duplicate check to `RecordAttendance` service (same account + event)
- Return `:conflict` status with message "Attendance already recorded"
- Optionally return existing attendance record in response

**Frontend changes**:
- Remove any client-side duplicate checking
- Handle 409 Conflict response gracefully (show message, don't treat as error)

**Tasks**:
- [ ] 2.1a Add duplicate rejection test
- [ ] 2.1b Add error message clarity test
- [ ] 2.1c Add test allowing different events
- [ ] 2.2 Add duplicate check to RecordAttendance service
- [ ] 2.3 Update frontend to handle conflict response
- [ ] 2.4 Manual verification: attempt duplicate attendance

---

### Slice 3: Assignable Roles Endpoint

**Why third**: Correctness; frontend currently hardcodes role hierarchy.

**Backend changes**:
- Create `GET /api/courses/:id/assignable_roles` endpoint
- Create `Services::Enrollments::GetAssignableRoles` service
- Use existing policy infrastructure to determine what roles the requestor can assign
- Return array of role objects: `[{ "id": 1, "name": "student" }, ...]`

**Frontend changes**:
- Update `ManagePeopleCard.vue` to fetch assignable roles from API
- Remove hardcoded `ROLE_HIERARCHY` constant
- Populate role dropdown from API response

**Tasks**:
- [ ] 3.1a Create spec file with owner permission tests
- [ ] 3.1b Add instructor permission tests
- [ ] 3.1c Add student permission tests
- [ ] 3.1d Add route integration test
- [ ] 3.2 Create GetAssignableRoles service
- [ ] 3.3 Add route to course routes
- [ ] 3.4 Update ManagePeopleCard to fetch and use API roles
- [ ] 3.5 Manual verification: test role assignment as different user types

---

### Slice 4: Attendance Report Endpoint

**Why fourth**: Complexity reduction; removes significant frontend logic.

**Backend changes**:
- Create `GET /api/courses/:id/attendance_report` endpoint
- Create `Services::Attendances::GenerateReport` service
- Return aggregated data: attendance by event, counts by role, percentages
- Support `?format=csv` query param for direct CSV download

**Frontend changes**:
- Update `AttendanceEventCard.vue` to call report endpoint
- Remove attendance aggregation and CSV generation logic
- For CSV: trigger download from API response

**Tasks**:
- [ ] 4.1a Create spec file with aggregation tests
- [ ] 4.1b Add summary statistics tests
- [ ] 4.1c Add CSV format test
- [ ] 4.1d Add authorization test
- [ ] 4.1e Add route integration test
- [ ] 4.2 Create GenerateReport service with aggregation logic
- [ ] 4.3 Add CSV formatting support
- [ ] 4.4 Add route to course routes
- [ ] 4.5 Update AttendanceEventCard to use report endpoint
- [ ] 4.6 Manual verification: view report, download CSV

---

### Slice 5: Enriched Event Responses

**Why fifth**: Performance; eliminates N+1 fetching in frontend.

**Backend changes**:
- Modify event representer to include:
  - `course_name` (from parent course)
  - `location` object (embedded, not just ID)
  - `user_attendance_status` for requesting user (null, "recorded", etc.)

**Frontend changes**:
- Remove `Promise.all` loops that fetch course/location for each event
- Use embedded data directly from event response

**Tasks**:
- [ ] 5.1a Add embedded location test
- [ ] 5.1b Add course_name test
- [ ] 5.1c Add user_attendance_status tests
- [ ] 5.2 Update Event representer with embedded location
- [ ] 5.3 Add user_attendance_status to event responses
- [ ] 5.4 Update frontend to use enriched data
- [ ] 5.5 Manual verification: confirm no additional fetches in network tab

---

### Slice 6: Capabilities-Based Visibility

**Why sixth**: Cleaner authorization; frontend uses capabilities instead of role strings.

**Backend changes**:
- Add `capabilities` object to course response:
  ```json
  { "can_edit": true, "can_delete": false, "can_manage_enrollments": true }
  ```
- Derive from existing policy infrastructure

**Frontend changes**:
- Replace role string comparisons (`role === 'owner'`) with capability checks
- Use `course.capabilities.can_edit` pattern

**Tasks**:
- [ ] 6.1a Add capabilities tests for owner
- [ ] 6.1b Add capabilities tests for instructor
- [ ] 6.1c Add capabilities tests for student
- [ ] 6.2 Add capabilities to course representer
- [ ] 6.3 Update frontend to use capabilities
- [ ] 6.4 Manual verification: test visibility as different roles

---

### Slice 7: Frontend Utilities (Cleanup)

**Why last**: Pure frontend cleanup; no backend changes.

**Frontend changes**:
- Extract `frontend_app/lib/geolocation.js` utility (shared across components)
- Extract `frontend_app/lib/dateFormatter.js` utility
- Remove any remaining deprecated domain logic

**Tasks**:
- [ ] 7.1 Create geolocation utility with shared functions
- [ ] 7.2 Create date formatting utility
- [ ] 7.3 Update components to use utilities
- [ ] 7.4 Remove deprecated logic from components

---

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Should the geo-fence radius be configurable per-course or global?~~ **Decision: Per-event, in meters, default 55m**
- [ ] Should CSV export be a streaming download or return data for frontend to format?
- [ ] What date format should the API return? ISO 8601 with timezone, or pre-formatted locale string?
- [ ] Should capabilities be embedded in every response or a separate endpoint?

## Completed

(none yet)

---

*Last updated: 2026-02-06*
