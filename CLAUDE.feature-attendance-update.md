# Instructor Attendance Update

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-attendance-update`

## Goal

Allow course instructors and staff (not owners) to view and toggle recorded attendance for eligible participants of an ongoing or past event, to address technical or other issues that prevented a participant from marking their own attendance.

## Strategy: Vertical Slice with TDD

Deliver a complete, testable feature end-to-end using red-green-refactor cycles:

1. **RED-GREEN cycles** — For each behavioral increment: write one failing test (RED), write minimum implementation to pass (GREEN), refactor if needed. Run the test suite between every phase.
2. **Frontend update** — Add attendance management UI to instructor's event view
3. **Verify** — Manual test confirms behavior

## Current State

- [x] Plan created
- [ ] Authorization RED-GREEN cycles
- [ ] UpdateParticipantAttendance RED-GREEN cycles
- [ ] ListEventParticipants RED-GREEN cycles
- [ ] Routes + representer
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
- **Policy flow to frontend**: The `ListEventParticipants` response includes an `AttendanceAuthorization` policy summary (with `can_manage_attendance`) alongside the participants list. This keeps attendance policies in `AttendanceAuthorization` (not `CoursePolicy`) and avoids cross-concern leakage. The frontend uses this to decide whether to show toggle controls. Existing `CoursePolicy` → `course.policies.can_update` continues to gate the instructor management tabs; the attendance policy only gates the toggle UI within those tabs.

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
- New service: `ListEventParticipants` — returns enrolled students with attendance status per event, plus `AttendanceAuthorization` policy summary
- Routes: Add `PUT /api/course/:course_id/attendance/:event_id/participant/:account_id` and `GET /api/course/:course_id/attendance/:event_id/participants`
- Representer: New `EventParticipants` representer (participants list + policies hash including `can_manage_attendance`)

**Frontend changes**:

- New component or dialog: `ManageEventAttendance.vue` — shows when instructor clicks an event, lists students with toggle switches
- Update `AttendanceEventCard.vue` to open the new attendance management view

## Tasks

> **TDD discipline**: Each task below is one RED-GREEN cycle. Write one failing test (RED), confirm it fails, write minimum implementation (GREEN), confirm it passes, refactor if needed. Run the test suite between every phase. Do not batch tests or implementations.

### Slice 1: Authorization — `can_manage_attendance?`

Order: test which roles grant access, then test that lacking those roles denies access. Note: users can have multiple roles, so tests should verify the presence/absence of the required roles (instructor, staff) — not enumerate specific excluded roles.

- [ ] 1.1 RED: test `can_manage_attendance?` returns true when enrollment includes instructor role → GREEN: add `can_manage_attendance?` method to `AttendanceAuthorization`
- [ ] 1.2 RED: test `can_manage_attendance?` returns true when enrollment includes staff role → GREEN: expand method (may already pass — if so, note and move on)
- [ ] 1.3 RED: test `can_manage_attendance?` returns false when enrollment has no instructor or staff role → GREEN: adjust if needed

### Slice 2: UpdateParticipantAttendance service

Order: happy path first, then error/edge cases.

- [ ] 2.1 RED: test instructor marks student as attended (creates attendance) → GREEN: implement service with authorize + create logic
- [ ] 2.2 RED: test instructor unmarks student attendance (deletes attendance) → GREEN: add delete path
- [ ] 2.3 RED: test rejects requestor without instructor or staff role (forbidden) → GREEN: adjust if needed
- [ ] 2.4 RED: test rejects non-enrolled target student → GREEN: add enrollment check
- [ ] 2.5 RED: test rejects future event → GREEN: add event timing check
- [ ] 2.6 RED: test rejects event not belonging to course → GREEN: add course-event validation

### Slice 3: ListEventParticipants service

Order: happy path, then authorization.

- [ ] 3.1 RED: test returns enrolled students with attendance status for an event → GREEN: implement service
- [ ] 3.2 RED: test response includes `can_manage_attendance` policy in summary → GREEN: add policy summary to service response
- [ ] 3.3 RED: test rejects non-instructor/staff (forbidden) → GREEN: adjust if needed

### Slice 4: Routes + Representer

- [ ] 4.1 Add `EventParticipants` representer (participants list + policies hash with `can_manage_attendance`)
- [ ] 4.2 Add PUT route `/api/course/:course_id/attendance/:event_id/participant/:account_id` wired to `UpdateParticipantAttendance`
- [ ] 4.3 Add GET route `/api/course/:course_id/attendance/:event_id/participants` wired to `ListEventParticipants`
- [ ] 4.4 Run full test suite — confirm all green

### Slice 5: Frontend — Attendance Management UI

- [ ] 5.1 Create `ManageEventAttendance.vue` component — student list with attendance toggles
- [ ] 5.2 Update `AttendanceEventCard.vue` — add click handler to open attendance management dialog
- [ ] 5.3 Wire up API calls (GET participants, PUT toggle); use `policies.can_manage_attendance` from GET response to show/hide toggles

### Verification

- [ ] 6.1 Manual verification: end-to-end test of instructor toggling student attendance

## Completed

(none yet)

---

Last updated: 2026-03-13
