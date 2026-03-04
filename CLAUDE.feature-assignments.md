# Feature: Assignments and Submissions

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`feature-assignments`

## Goal

Allow teaching staff to create assignments (with description, due date, submission requirements) for a course, and students to submit solutions (file upload or URL).

## Strategy: Vertical Slice

Deliver a complete, testable feature end-to-end:

1. **Backend test** — Write failing test for new behavior (red)
2. **Backend implementation** — Make the test pass (green)
3. **Frontend update** — Build UI to consume new API
4. **Verify** — Hybrid: Claude-in-Chrome walkthrough + manual pass by developer before merge

## Reference Documents

| Document | Contents | Status |
|----------|----------|--------|
| `CLAUDE.assignments-ddd-architecture.md` | Aggregate roots, entities, value objects, DB schemas, domain rules, repository patterns, direct-to-S3 presigned URL storage design | Reviewed — all review items (R1–R10) resolved and moved to design decisions doc |
| `CLAUDE.assignments-design-decisions.md` | All resolved design questions (Q1–Q12) and architecture review decisions (R1–R10) | Reviewed |

## Current State

- [x] Plan created
- [x] Design questions resolved (see design decisions doc)
- [x] Domain model defined (see domain model doc)
- [x] File storage strategy decided: direct-to-S3 via presigned URLs (see domain model doc)
- [x] **Architecture review complete** — R1–R10 resolved, decisions in design decisions doc
- [x] **Scope and tasks updated to reflect domain model** — reconciled with design decisions (R1–R10) on 2026-03-03
- [x] Slice 1: Assignments backend (domain, infrastructure, application, presentation — 983 tests passing)
- [x] Slice 1: Assignments frontend (tab, list, create/edit dialogs, detail view — build compiles)
- [x] Slice 1: Assignments verification (Chrome walkthrough complete — see review notes below)
- [ ] Slice 2: Submissions with local storage (backend → frontend → verify)
- [ ] Slice 3: Production S3 infrastructure (gateway, config, docs)

## Key Findings

### Existing Architecture

The codebase has four bounded contexts: **Accounts**, **Courses**, **Attendance**, **Shared**. The pattern for adding a new feature is well-established:

- **Domain**: entities (dry-struct), values, policies under `app/domain/<context>/`
- **Infrastructure**: ORM models (Sequel) + repositories that map ORM ↔ domain entities
- **Application**: services (Dry::Operation with monadic results), policies (authorization), routes (Roda)
- **Presentation**: Roar representers for JSON serialization
- **Tests**: Minitest spec-style, organized by layer

### Relevant Existing Pieces

- **Course enrollment system**: `account_course_roles` join table supports multiple roles (owner, instructor, staff, student) per account per course
- **CoursePolicy**: Existing pattern for role-based authorization (`can_view?`, `can_update?`, etc.)
- **Courses repository**: Demonstrates composable loading strategies (`find_with_events`, `find_full`, etc.)
- **Routes**: Currently singular (`/api/course/:course_id/`) — new routes will use plural convention (issue #46)
- **Domain types**: `types.rb` has constrained types and string enums for roles
- **FileUpload.vue**: A file upload component already exists in the frontend

## Scope

### In Scope

**Backend changes**:

- New `assignments` bounded context in domain layer
- Assignment aggregate root with SubmissionRequirement child entities
- Submission aggregate root with RequirementUpload child entities
- Domain types: AssignmentTitle, AssignmentStatus (draft/published/disabled), RequirementType (file/url)
- Draft/published/disabled lifecycle for assignments
- Database migrations for 4 tables: assignments, submission_requirements, submissions, submission_entries
- ORM models and repositories with composable loading
- Services: CreateAssignment, UpdateAssignment, DeleteAssignment, PublishAssignment, ListAssignments, GetAssignment, CreateSubmission, ListSubmissions, GetSubmission
- Policies: AssignmentPolicy (teaching staff CRUD; students view published only), SubmissionPolicy (students create/view own; teaching staff view all)
- Routes nested under `/api/course/:course_id/assignments/` (singular `course` matches current codebase; issue #46 will rename to plural later)
- Representers for Assignment and Submission JSON
- S3 file upload with storage abstraction (local adapter for dev/test)
- Input validation (contracts or inline)
- Late resubmit policy enforcement (`allow_late_resubmit` flag)

**Frontend changes**:

- Assignment list view (within course detail page)
- Assignment detail view (rendered markdown description, due date, linked event, submission requirements)
- Assignment creation/edit dialog (teaching staff): title, markdown description, due date, optional event, submission requirements, publish action
- Submission form per requirement (file upload or URL input)
- Submission list view (teaching staff: all students; students: own only)

### Out of Scope (deferred)

- Grading, scores, rubrics, feedback
- Submission file versioning / history
- Bulk assignment operations
- Assignment categories/tags
- Notifications (email/push) for new assignments or approaching deadlines
- Peer review (students viewing each other's submissions)

## Tasks

> **Test-first**: Write or update tests that fail (red) before writing the implementation to make them pass (green).

### Slice 1: Assignments (create, list, view, update, delete, publish — end-to-end)

**Backend test (red)**:

- [x] 1.1a Failing tests for Assignment entity, SubmissionRequirement entity, and value objects
- [x] 1.1b Failing tests for Assignment repository (including requirements loading, event loading)
- [x] 1.1c Failing tests for Assignment services (create, list, get, update, delete, publish — including submission requirements and optional event_id)
- [x] 1.1d Failing tests for Assignment policy (authorization, draft/published visibility)
- [x] 1.1e Failing tests for Assignment routes

**Backend implementation (green)**:

- [x] 1.2 Domain: Assignment entity, SubmissionRequirement entity, types, collection value objects
- [x] 1.3 Infrastructure: migrations (assignments + submission_requirements), ORM models, repository
- [x] 1.4 Application: services (CRUD + publish, with requirements management), policy, routes
- [x] 1.5 Presentation: Assignment representer (including nested requirements)
- [x] 1.6 All backend tests pass (983 tests, 0 failures, 98.31% coverage)

**🔍 REVIEW CHECKPOINT**: Pause for developer review of Slice 1 backend (domain, infrastructure, application, presentation). All backend tests should pass. Resume with frontend after review.

**Frontend**:

- [x] 1.7 Add assignments tab/route to course detail page
- [x] 1.8 Assignment list component (draft/published indicators for teaching staff)
- [x] 1.9 Create/edit assignment dialog with submission requirements builder
- [x] 1.10 Assignment detail view (rendered markdown, linked event, requirements list)

**Verify**:

- [x] 1.11 Hybrid verification: Chrome walkthrough of assignment flows (see review notes)
- [ ] 1.12 Resolve review notes from hybrid verification (see below)

**Review fixes (from 1.11 + developer review)**:

- [x] 1.12a Fix: Create Assignment card font/appearance larger than Create Event card — added `font-size: 14px`, `line-height: 2.5rem`, `text-align: center` to `.assignment-item` CSS (matching global `.event-item` style)
- [x] 1.12b Fix: "Late Resubmit" label → "Allow Late Resubmits?" in CreateAssignmentDialog + ModifyAssignmentDialog
- [x] 1.12c Issue: Date pickers don't show user's timezone — created GitHub issue #47 (cross-cutting, deferred)
- [x] 1.12d Fix: "+ Add Requirement" button disabled when empty requirement row exists (prevents adding blank rows)
- [ ] 1.12e Deferred: Sanitize markdown in AssignmentDetailDialog (DOMPurify) — add after Slice 2 (may apply to submissions too)

**Slice 1 extension — Draft requirements editing + Unpublish lifecycle**:

Resolves review note #1: requirements should be editable in draft mode, and published assignments with no submissions can be unpublished back to draft.

New lifecycle rules:
- **Draft**: full editing (metadata + requirements), can publish, can delete
- **Published (no submissions)**: can edit metadata, can unpublish back to draft, can delete
- **Published (with submissions)**: metadata only, no unpublish, no delete (use disable) — enforced when Slice 2 adds submissions

**Backend**:

- [ ] 1.13a Policy: add `can_unpublish?` method + update summary hash + tests
- [ ] 1.13b Repository: add `update_with_requirements` method + tests
- [ ] 1.13c New service: `UnpublishAssignment` (published → draft, with `has_submissions?` placeholder for Slice 2) + tests
- [ ] 1.13d Update service: `UpdateAssignment` accepts optional `submission_requirements` (allow if draft, reject if published) + tests
- [ ] 1.13e Routes: add `POST .../unpublish` endpoint + tests
- [ ] 1.13f All backend tests pass

**Frontend**:

- [ ] 1.14a `ModifyAssignmentDialog`: add requirements builder for draft assignments; read-only note for published
- [ ] 1.14b `SingleCourse`: change `editAssignment` to async fetch (to get requirements); add `unpublishAssignment` handler + event wiring
- [ ] 1.14c `AssignmentsCard`: add unpublish icon for published assignments

**Verify**:

- [ ] 1.15 Chrome walkthrough: create draft → edit requirements → publish → unpublish → edit requirements → republish

### Slice 2: Submissions (create, view, overwrite — end-to-end)

**Backend test (red)**:

- [ ] 2.1a Failing tests for Submission entity, RequirementUpload entity, and value objects
- [ ] 2.1b Failing tests for Submission repository
- [ ] 2.1c Failing tests for Submission services (create/overwrite, list, get — including late resubmit policy)
- [ ] 2.1d Failing tests for Submission policy (authorization, visibility)
- [ ] 2.1e Failing tests for Submission routes

**Backend implementation (green)**:

- [ ] 2.2 Domain: Submission entity, RequirementUpload entity, collection value objects
- [ ] 2.3 Infrastructure: migrations (submissions + submission_entries), ORM models, repository
- [ ] 2.4 Infrastructure: file storage — LocalGateway (dev/test filesystem adapter), Mapper, storage abstraction interface
- [ ] 2.5 Application: services (create/overwrite with file validation, late resubmit enforcement), policy, routes (including presign-upload and presign-download endpoints)
- [ ] 2.6 Presentation: Submission representer (including nested entries)
- [ ] 2.7 All backend tests pass

**🔍 REVIEW CHECKPOINT**: Pause for developer review of Slice 2 backend (domain, infrastructure, application, presentation). All backend tests should pass. Resume with frontend after review.

**Frontend**:

- [ ] 2.8 Submission form on assignment detail (per-requirement: file upload or URL input)
- [ ] 2.9 Student's own submission view (with resubmit capability)
- [ ] 2.10 Teaching staff submissions list (all students, late indicators)

**Verify**:

- [ ] 2.11 Hybrid verification: Chrome walkthrough of submission flows + manual developer pass

### Slice 3: Production S3 Infrastructure

- [ ] 3.1 Add `aws-sdk-s3` gem; S3 config entries in secrets.yml template
- [ ] 3.2 Gateway: real AWS SDK implementation (presign_upload, presign_download, head, delete)
- [ ] 3.3 Environment-based gateway selection (LocalGateway for dev/test, Gateway for production)
- [ ] 3.4 Guided walkthrough: AWS S3 bucket creation, IAM policy, CORS config, credentials in secrets.yml
- [ ] 3.5 Tests for Gateway (mocked AWS SDK) and gateway selection logic
- [ ] 3.6 All tests pass (including Slice 1 and 2 regression)

## Completed

- **1.1a** — Tests for Assignment entity (17 tests), SubmissionRequirement entity (11 tests), SubmissionRequirements collection value object (15 tests). All initially failed (red).
- **1.2** — Domain implementation: added `AssignmentTitle`, `AssignmentStatus`, `RequirementType` to `types.rb`; created `Assignment` entity (aggregate root with defaults for status/allow_late_resubmit), `SubmissionRequirement` child entity, `SubmissionRequirements` collection value object. All 43 tests now pass (green). Note: `Types::AssignmentStatus.default()` not supported by dry-types — used inline `Types::String.default('draft').enum(...)` instead.
- **1.1b** — Tests for Assignment repository (27 tests): CRUD, composable loading (find_id, find_with_requirements, find_by_course, find_by_course_and_status, find_by_course_with_requirements), cascade delete, round-trip integrity.
- **1.3** — Infrastructure: migrations 009 (assignments) + 010 (submission_requirements) with FK constraints and cascade rules; ORM models (`Assignment`, `SubmissionRequirement`); `Repository::Assignments` with composable loading pattern. Updated setup_spec for new tables. All 928 tests pass.
- **1.1d + 1.4 (policy)** — `AssignmentPolicy` with role-based authorization: teaching staff (owner/instructor/staff) get full CRUD; students can only view published. 12 policy tests pass.
- **1.1c + 1.4 (services)** — Six services implemented with tests: `CreateAssignment` (7 tests), `ListAssignments` (3 tests), `GetAssignment` (4 tests), `UpdateAssignment` (4 tests), `DeleteAssignment` (3 tests), `PublishAssignment` (4 tests). All 25 service tests pass.
- **1.5** — `Assignment` representer with nested `SubmissionRequirementRepr`, ISO8601 time formatting, `AssignmentsList` collection representer.
- **1.1e + 1.4 (routes)** — Assignment routes added to `Routes::Courses` under `r.on 'assignments'`: POST create, GET list, GET by ID, PUT update, DELETE, POST publish. 18 route tests pass.
- **1.6** — Full regression: 983 tests, 0 failures, 98.31% line coverage.
- **1.7** — Added `assignments` route as child of SingleCourse in `router/index.js`; added "Assignments" tab link in SingleCourse menu bar.
- **1.8** — `AssignmentsCard.vue`: card-based list component with status badges (draft=warning, published=success, disabled=info), due date display, create/edit/delete/publish action icons. Follows AttendanceEventCard pattern.
- **1.9** — `CreateAssignmentDialog.vue`: form with title, markdown description, due date picker, optional event selector, allow_late_resubmit switch, and dynamic submission requirements builder (add/remove requirements with format, description, allowed_types). `ModifyAssignmentDialog.vue`: metadata-only edit form (requirements frozen per R7). Both follow existing dialog patterns.
- **1.10** — `AssignmentDetailDialog.vue`: detail view with rendered markdown description (using `marked` library), status badge, due date, requirements table, linked event name, late resubmit policy indicator. Added `marked` npm dependency.

All wiring in `SingleCourse.vue`: imports, component registration, data properties (assignments, dialog visibility, forms), currentRole watcher (fetchAssignments), 8 methods (fetchAssignments, showCreateAssignment, createAssignment, editAssignment, updateAssignment, deleteAssignment with confirmation, publishAssignment with confirmation, viewAssignment with detail fetch), RouterView props/events, dialog instances. Frontend builds successfully.

- **1.11** — Chrome walkthrough verification of all assignment flows. Fixed `require 'ostruct'` bug in representer (Ruby 3.4 compatibility). All flows verified: create (with requirements builder), list (status badges, due dates), detail view (rendered markdown, requirements table, linked event), edit (metadata only, requirements frozen per R7), publish (status transition, icon removal), delete (confirmation + card removal). Tab switching regression check passed (Attendance Events, Locations, People all unaffected).

## Review Notes (Slice 1)

Issues noted during verification and developer review:

1. **~~Publish dialog wording~~** — **RESOLVED**: Requirements are now editable in draft mode. Published assignments can be unpublished back to draft (if no submissions). Publish confirmation wording will be updated when 1.13–1.14 are implemented. See "Slice 1 extension" tasks above.

2. **~~Bug fix~~** — **RESOLVED**: Added `require 'ostruct'` to `backend_app/app/presentation/representers/assignment.rb`. Ruby 3.4 no longer auto-loads OpenStruct.

3. **~~Card sizing~~** — **RESOLVED** (1.12a): Create Assignment card matched to Create Event card styling.

4. **~~Label wording~~** — **RESOLVED** (1.12b): "Late Resubmit" → "Allow Late Resubmits?"

5. **Timezone display** — Deferred to GitHub issue #47 (cross-cutting UX improvement).

6. **Markdown sanitization** — Deferred to post-Slice 2 (1.12e). `v-html` with `marked` in AssignmentDetailDialog is an XSS vector. Low risk (only teaching staff input) but should add DOMPurify.

7. **~~Add Requirement button~~** — **RESOLVED** (1.12d): Disabled when empty requirement row exists.

---

Last updated: 2026-03-04 (Slice 1 review in progress: review fixes applied, lifecycle extension planned as 1.13–1.15)
