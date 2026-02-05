# Refactor Frontend Domain Logic to Backend DDD API

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work.

## Branch

`refactor-frontend-ddd`

## Goal

Move all major domain logic from the Vue frontend to the backend's DDD-architected API. The frontend should become a thin presentation layer that consumes rich, pre-validated, pre-computed data from the backend.

## Current State

- [x] Plan created
- [x] Frontend domain logic analyzed
- [x] Backend DDD architecture reviewed
- [ ] Implementation started

## Key Findings

### Frontend Domain Logic to Move (Priority Order)

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

## Design

### Phase 1: Critical Security & Correctness (HIGH Priority)

#### 1.1 Server-side Attendance Validation

- Add `geo_fence_radius_m` column to `events` table (integer, default: 55 meters)
- Add `geo_fence_radius_m` attribute to `Event` entity
- Enhance `Services::Attendances::RecordAttendance` to:
  - Validate geo-fence using existing `Attendance#within_range?()` with event's radius
  - Check for duplicate attendance (same account + event)
  - Return specific error messages for validation failures
- Frontend: Remove geo-fence validation, show backend errors

#### 1.2 Role Assignment Permissions

- Create new endpoint: `GET /api/course/:id/assignable_roles`
  - Returns roles the current user can assign based on their enrollment
  - Uses existing policy infrastructure
- Frontend: Fetch assignable roles from API instead of hardcoding

#### 1.3 Attendance Report Generation

- Create new endpoint: `GET /api/course/:id/attendance_report`
  - Returns aggregated attendance data with statistics
  - Optional `?format=csv` for direct CSV download
- Frontend: Remove aggregation logic, call single endpoint

### Phase 2: API Enrichment (N+1 & Data Quality)

#### 2.1 Enriched Event Responses

- Modify event endpoints to include:
  - `course_name` (from parent course)
  - `location` object (embedded, not just ID)
  - `user_attendance_status` for the requesting user
- Frontend: Remove Promise.all enrichment loops

#### 2.2 Enrollment Response Enhancement

- Include `assignable_roles` in enrollment responses
- Include user's `capabilities` (what they can do, not just their role)

#### 2.3 Standardized Date Formatting

- Add `formatted_start_at`, `formatted_end_at` to responses
- Or: Document that frontend should use a single date utility

### Phase 3: API Contract Cleanup (MEDIUM Priority)

#### 3.1 Symmetric API Contracts

- Ensure API accepts same format it returns
- Remove need for frontend field deletion (id, enroll_identity)

#### 3.2 Email Validation

- Move email parsing/validation to `Contracts::Enrollments`
- Accept both single email and array/comma-separated

#### 3.3 Capabilities-Based Visibility

- Add `capabilities` to course response:

  ```json
  { "can_edit": true, "can_delete": false, "can_manage_enrollments": true }
  ```

- Frontend: Use capabilities instead of role string comparisons

### Phase 4: Frontend Cleanup

#### 4.1 Extract Shared Services

- Create `frontend_app/lib/geolocation.js` utility
- Create `frontend_app/lib/dateFormatter.js` utility

#### 4.2 Remove Redundant Logic

- Delete hardcoded role hierarchy from ManagePeopleCard
- Delete geo-fence validation from AttendanceTrack/AllCourse
- Delete CSV generation from AttendanceEventCard

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Should the geo-fence radius be configurable per-course or global?~~ **Decision: Per-event, in meters, default 55m** (0.0005 degrees ≈ 55 meters)
- [ ] Should CSV export be a streaming download or return data for frontend to format?
- [ ] What date format should the API return? ISO 8601 with timezone, or pre-formatted locale string?
- [ ] Should capabilities be embedded in every response or a separate endpoint?

## Tasks

### Phase 1: Critical Security

- [ ] 1.1a Add `geo_fence_radius_m` column to events table (migration, default: 55)
- [ ] 1.1b Add `geo_fence_radius_m` to Event entity and representer
- [ ] 1.1c Add geo-fence validation to RecordAttendance service (use event's radius)
- [ ] 1.2 Add duplicate attendance check to RecordAttendance service
- [ ] 1.3 Create assignable_roles endpoint
- [ ] 1.4 Create attendance_report endpoint
- [ ] 1.5 Update frontend AttendanceTrack to use backend validation
- [ ] 1.6 Update frontend ManagePeopleCard to fetch assignable roles
- [ ] 1.7 Update frontend AttendanceEventCard to use report endpoint

### Phase 2: API Enrichment
- [ ] 2.1 Enhance event representer with embedded location
- [ ] 2.2 Add user_attendance_status to event responses
- [ ] 2.3 Add course_name to event responses (or embed course)
- [ ] 2.4 Update frontend to remove N+1 fetching

### Phase 3: API Contracts
- [ ] 3.1 Add capabilities to course response
- [ ] 3.2 Standardize enrollment email handling in contracts
- [ ] 3.3 Ensure symmetric request/response formats

### Phase 4: Frontend Cleanup
- [ ] 4.1 Extract geolocation utility
- [ ] 4.2 Extract date formatting utility
- [ ] 4.3 Remove deprecated domain logic from components

## Completed

(none yet)

---

*Last updated: 2026-02-05*
