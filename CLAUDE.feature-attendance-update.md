# Instructor Attendance Update

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-attendance-update`

## Goal

Allow course instructors and staff (not owners) to view and toggle recorded attendance for eligible participants of an ongoing or past event, to address technical or other issues that prevented a participant from marking their own attendance.

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing tests for the new update-attendance service (red)
2. **Backend implementation** — New service + policy + route to make tests pass (green)
3. **Frontend update** — Add attendance management UI to instructor's event view
4. **Verify** — Manual test confirms behavior

## Current State

- [x] Plan created
- [ ] Backend tests written (red)
- [ ] Backend implementation (green)
- [ ] Frontend UI
- [ ] Manual verification

## Key Findings

### Existing Capabilities

- **RecordAttendance service**: Students self-record with geo-fence + time-window checks. Uses `AttendanceEligibility` domain policy.
- **ListAttendancesByEvent service**: Teaching staff (owner/instructor/staff) can already view per-event attendance. Returns list of attendance entities.
- **AttendanceAuthorization policy**: Has `can_create?` (self-enrolled only), `can_view_all?` (teaching staff). No `can_update?` or `can_manage?` yet.
- **Attendances repository**: Has `create()` (find_or_create), `delete()`, `find_by_account_event()`. No `update` method, but create uses `find_or_create` so re-creating is idempotent.
- **Attendance entity**: Stores account_id, course_id, event_id, role_id, name, latitude, longitude.
- **Enrollment**: `teaching?` predicate covers owner + instructor + staff. Need `can_manage_attendance?` for instructor + staff (not owner).
- **Frontend**: `AttendanceEventCard.vue` shows events with map icon that fetches per-event attendances. No per-student toggle UI exists.
- **Router**: `SingleCourse` has child routes for `attendance`, `location`, `people`.

### Gaps to Fill

1. **New authorization method**: `can_manage_attendance?` — restricted to instructor or staff (not owner)
2. **New service**: `UpdateParticipantAttendance` — instructor/staff marks/unmarks attendance for a specific student at a specific event. Skips geo-fence/time-window but requires: event belongs to course, event is ongoing or past, target account is enrolled as student.
3. **New API route**: `PUT /api/course/:course_id/attendance/:event_id/participant/:account_id` — toggles attendance (creates or deletes)
4. **New frontend**: Event detail view showing enrolled students with attendance toggle checkboxes
5. **Representer**: May need an enrollment-with-attendance-status representer for the event participant list

### Design Decisions

- **Toggle semantics**: PUT with `{ attended: true/false }` — creates attendance when true, deletes when false. Simpler than separate PUT/DELETE endpoints.
- **No geo-fence for instructor/staff overrides**: Bypass eligibility checks — that's the whole point.
- **Event timing**: Event must be ongoing or past (not future) — can't mark attendance for an event that hasn't started.
- **Instructor + staff only**: Instructor and staff can manage. Owner cannot — owners are course administrators, not classroom staff.
- **Coordinates**: When instructor marks attendance, latitude/longitude are null (no geo-location).

## Questions

- ~~Should staff be able to manage attendance?~~ Yes — instructor and staff can manage. Owner cannot.
- ~~Should future events allow attendance management?~~ No — only ongoing or past events.
- [ ] Should there be an audit trail (who marked the attendance)? Deferred for now — existing schema doesn't track who recorded it.

## Scope

**In scope**:

- New `can_manage_attendance?` authorization check (instructor/staff only)
- New `UpdateParticipantAttendance` service (create/delete attendance for a student)
- New `ListEventParticipants` service (enrolled students + attendance status for an event)
- New API routes for the above
- Frontend: event detail dialog/view showing students with attendance checkboxes
- Tests for authorization, service, and route

**Out of scope**:

- Audit trail for who marked attendance
- Bulk attendance update (batch mark/unmark)
- Changing the existing self-service attendance flow

**Backend changes**:

- `AttendanceAuthorization`: Add `can_manage_attendance?` (instructor or staff)
- New service: `UpdateParticipantAttendance` — validates course, event, enrollment; creates or deletes attendance
- New service: `ListEventParticipants` — returns enrolled students with attendance status per event
- Routes: Add `PUT /api/course/:course_id/attendance/:event_id/participant/:account_id` and `GET /api/course/:course_id/attendance/:event_id/participants`
- Representer: New `EventParticipant` representer (enrollment info + attended boolean)

**Frontend changes**:

- New component or dialog: `ManageEventAttendance.vue` — shows when instructor clicks an event, lists students with toggle switches
- Update `AttendanceEventCard.vue` to open the new attendance management view

## Tasks

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Slice 1: Backend — Authorization + Service + Route

- [ ] 1.1a Test: `AttendanceAuthorization#can_manage_attendance?` — true for instructor, true for staff, false for owner, false for student
- [ ] 1.1b Test: `UpdateParticipantAttendance` service — success for instructor marking student attended, success for unmarking, failure for owner, failure for non-enrolled student, failure for future event, failure for event not in course
- [ ] 1.1c Test: `ListEventParticipants` service — returns enrolled students with attendance status, requires instructor/staff auth
- [ ] 1.2 Implement `can_manage_attendance?` in `AttendanceAuthorization`
- [ ] 1.3 Implement `UpdateParticipantAttendance` service
- [ ] 1.4 Implement `ListEventParticipants` service
- [ ] 1.5 Add new API routes and representer
- [ ] 1.6 Verify all tests pass

### Slice 2: Frontend — Attendance Management UI

- [ ] 2.1 Create `ManageEventAttendance.vue` component — student list with attendance toggles
- [ ] 2.2 Update `AttendanceEventCard.vue` — add click handler to open attendance management dialog
- [ ] 2.3 Wire up API calls (GET participants, PUT toggle)

### Verification

- [ ] 3.1 Manual verification: end-to-end test of instructor toggling student attendance

## Completed

(none yet)

---

Last updated: 2026-03-12
