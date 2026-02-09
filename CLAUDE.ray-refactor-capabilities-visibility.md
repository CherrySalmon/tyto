# Slice 6: Capabilities-Based Visibility

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`ray/refactor-capabilities-visibility`

## Goal

Replace frontend role string comparisons (`currentRole == 'owner'`, `currentRole != 'student'`) with a `policies` summary returned by the API. The frontend should check `course.policies.can_update` instead of reasoning about role hierarchies. This moves authorization knowledge to the backend where `CoursePolicy#summary` already exists.

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing test for new behavior (red)
2. **Backend implementation** — Make the test pass (green)
3. **Frontend update** — Remove old logic, consume new API
4. **Verify** — Manual or E2E test confirms behavior

## Current State

- [x] Plan created
- [x] Backend tests written (red)
- [x] Backend implementation (green)
- [x] Frontend updated
- [ ] Manual verification

## Key Findings

### Existing Policy Infrastructure

`CoursePolicy` already computes all needed capabilities:

- `can_view?` — enrolled users
- `can_update?` — teaching staff (owner, instructor, staff)
- `can_delete?` — admin or owner
- `summary` method returns hash of all checks

`EventPolicy` and `AttendanceAuthorization` follow the same pattern with `summary` methods.

### Reference Pattern (Credence)

The Credence project demonstrates the canonical flow:

1. **Policy** defines individual checks (`can_view?`, `can_edit?`, etc.) and a `summary` method that returns them all as a hash
2. **Service** instantiates the policy, authorizes the request, then merges `policy.summary` into the response: `project.full_details.merge(policies: policy.summary)`
3. **Controller** returns the merged result as JSON — no knowledge of policies

Tyto's DDD architecture adds a representer layer between service and controller. The adaptation: the service builds a Response DTO that includes the policy summary, and the representer serializes the `policies` field alongside other course data.

### Current Course Response (OpenStruct)

`GetCourse` and `ListUserCourses` use `OpenStruct` to compose course data with `enroll_identity` (role array). This is the anti-pattern identified in Slice 5 — no guaranteed shape.

### Frontend Role Checks to Replace

| Component | Check | Maps to |
| --------- | ----- | ------- |
| `SingleCourse.vue:8` | `currentRole == 'owner' \|\| 'instructor' \|\| 'staff'` | `policies.can_update` (teaching staff) |
| `SingleCourse.vue:31` | `currentRole != 'student'` | `policies.can_update` |
| `SingleCourse.vue:56` | `currentRole == 'student'` | `!policies.can_update` |
| `SingleCourse.vue:160` | `newRole == 'owner' \|\| 'instructor' \|\| 'staff'` | `policies.can_update` |
| `CourseInfoCard.vue:12` | `currentRole != 'student'` | `policies.can_update` |
| `AllCourse.vue:30,65` | `account.roles.includes('creator')` | **Out of scope** — global role, not course-specific |

### What `LocationCard` and `AttendanceEventCard` Use

`LocationCard.vue` accepts `currentRole` prop but does **not** use it for visibility — all actions (edit, delete, create) are always shown. The visibility is controlled by the parent `SingleCourse.vue` which only renders the teaching staff view when the role qualifies.

`AttendanceEventCard.vue` accepts `currentRole` prop and passes it through but does not gate any actions on it — the parent controls visibility.

**Conclusion**: The role-to-capability migration is concentrated in `SingleCourse.vue` and `CourseInfoCard.vue`. Other components receive `currentRole` as a prop but don't use it for gating.

## Questions

> Questions must be crossed off when resolved. Note the decision made.

- [x] ~~Should capabilities be embedded in every course response or a separate endpoint?~~ **Decision: Embedded in course response.** Follows the Credence pattern where the service merges `policy.summary` into the entity response. One request, no extra round-trip.
- [ ] What date format should the API return? (inherited from main plan — out of scope for this slice)

## Scope

### Response Shape

The `policies` key follows the Credence convention — the service merges `CoursePolicy#summary` into the response. The summary is returned **as-is** from the existing policy — no new predicates needed:

```json
{
  "id": 1,
  "name": "Course Name",
  "enroll_identity": ["owner"],
  "policies": {
    "can_view": true,
    "can_create": false,
    "can_update": true,
    "can_delete": true
  }
}
```

These map directly from `CoursePolicy#summary`:

- `can_view` — enrolled users (always true if you can see the course)
- `can_create` — global creator role (always false in course-specific context)
- `can_update` — teaching staff (owner, instructor, staff). **This is the key predicate** — it replaces all frontend role string comparisons for the management view, "Modify Course" button, and data fetching gates
- `can_delete` — admin or course owner

Note: `can_view_all` (admin-only) is omitted from the serialized response since it's not useful to the frontend.

### Response DTO Migration

Per the cross-cutting decision in the main plan, replace `OpenStruct` with a `Response::CourseDetails` DTO using `Data.define`. The DTO includes a `policies` field populated from `CoursePolicy#summary`. This applies to both `GetCourse` and `ListUserCourses` services.

### What's In Scope

- Response DTO: `Response::CourseDetails` replacing `OpenStruct` in `GetCourse` and `ListUserCourses`
- Policy summary computation from existing `CoursePolicy`
- Representer enhancement: `policies` property on `CourseWithEnrollment`
- Frontend: `SingleCourse.vue` and `CourseInfoCard.vue` use `policies` instead of role strings
- Route integration tests for `policies` in course responses

### What's Out of Scope

- `AllCourse.vue` global role check (`account.roles.includes('creator')`) — this is a global role, not course-specific
- `CreateCourse` service DTO migration — creator gets owner role automatically; policies can be added post-slice
- Event/location/attendance policy summaries — defer to future work if needed
- Removing `enroll_identity` from response — keep for backward compatibility (role selector still needs it)

**Backend changes**:

- New: `app/application/responses/course_details.rb` — `Data.define` DTO with `policies` field
- Modified: `app/application/services/courses/get_course.rb` — build DTO, merge `CoursePolicy#summary`
- Modified: `app/application/services/courses/list_user_courses.rb` — build DTO with policies per course
- Modified: `app/presentation/representers/course.rb` — add `policies` property to `CourseWithEnrollment`

**Frontend changes**:

- `SingleCourse.vue` — replace role string comparisons with `course.policies.can_update`
- `CourseInfoCard.vue` — replace `currentRole != 'student'` with `policies.can_update`

## Tasks

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Phase 1: Backend Tests (red)

- [x] 1a Add route test: `GET /api/course/:id` returns `policies` for owner (`can_update: true, can_delete: true`)
- [x] 1b Add route test: `GET /api/course/:id` returns `policies` for instructor (`can_update: true, can_delete: false`)
- [x] 1c Add route test: `GET /api/course/:id` returns `policies` for student (`can_update: false, can_delete: false`)
- [x] 1d Add route test: `GET /api/course` list includes `policies` per course

### Phase 2: Backend Implementation (green)

- [x] 2a Create `Response::CourseDetails` DTO in `app/application/responses/`
- [x] 2b Refactor `GetCourse` — build DTO, merge `CoursePolicy#summary` as `policies`
- [x] 2c Refactor `ListUserCourses` — build DTO with policies per course
- [x] 2d Update `CourseWithEnrollment` representer — add `policies` property

### Phase 3: Frontend Update

- [x] 3a `SingleCourse.vue` — replace role comparisons with `course.policies.can_update`
- [x] 3b `CourseInfoCard.vue` — replace `currentRole != 'student'` with `policies.can_update`

### Phase 4: Verification

- [ ] 4 Manual verification: test as owner, instructor, staff, student — confirm correct visibility

## Completed

- Phase 1: 4 route tests for policy assertions (owner, instructor, student, list)
- Phase 2: `Response::CourseDetails` DTO, `GetCourse` + `ListUserCourses` refactored, representer updated
- Phase 3: `SingleCourse.vue` (4 role checks → policies) + `CourseInfoCard.vue` (1 role check → policies)

## Future Work

- Rename `ListUserCourses` → `ListAccountCourses` (no `User` entity in domain)

---

Last updated: 2026-02-09
