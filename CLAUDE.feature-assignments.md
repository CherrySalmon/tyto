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

- [ ] 1.1a Failing tests for Assignment entity, SubmissionRequirement entity, and value objects
- [ ] 1.1b Failing tests for Assignment repository (including requirements loading, event loading)
- [ ] 1.1c Failing tests for Assignment services (create, list, get, update, delete, publish — including submission requirements and optional event_id)
- [ ] 1.1d Failing tests for Assignment policy (authorization, draft/published visibility)
- [ ] 1.1e Failing tests for Assignment routes

**Backend implementation (green)**:

- [ ] 1.2 Domain: Assignment entity, SubmissionRequirement entity, types, collection value objects
- [ ] 1.3 Infrastructure: migrations (assignments + submission_requirements), ORM models, repository
- [ ] 1.4 Application: services (CRUD + publish, with requirements management), policy, routes
- [ ] 1.5 Presentation: Assignment representer (including nested requirements)
- [ ] 1.6 All backend tests pass

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

(none yet)

---

Last updated: 2026-03-03 (reconciled all docs: R1 submission_format, R2 S3 key, R2 unified .url storage, disabled status, route path, stale markers cleared)
