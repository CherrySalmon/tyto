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
- [ ] Slice 1: Assignments (backend → frontend → verify)
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

- [ ] 1.7 Add assignments tab/route to course detail page
- [ ] 1.8 Assignment list component (draft/published indicators for teaching staff)
- [ ] 1.9 Create/edit assignment dialog with submission requirements builder
- [ ] 1.10 Assignment detail view (rendered markdown, linked event, requirements list)

**Verify**:

- [ ] 1.11 Hybrid verification: Chrome walkthrough of assignment flows + manual developer pass

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

---

Last updated: 2026-03-03 (completed Slice 1 backend: tasks 1.1a–1.6 all done, 983 tests passing)
